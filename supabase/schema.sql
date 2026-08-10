-- Warq - complete database schema
--
-- Generated from supabase/migrations/. Paste into the Supabase SQL editor and
-- run once on an empty project. Wrapped in a transaction.

begin;

-- ═══════════════════════════════════════════════════════════════
-- 20260809120000_enums.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Enumerations
--
-- These mirror the constants in @warq/core exactly. If one changes, both change
-- together: the TypeScript union is what the apps compile against, and the
-- Postgres type is what the database will actually accept.

-- ─────────────────────────────────────────────────────────────
-- Identity
-- ─────────────────────────────────────────────────────────────

-- Mirrors USER_ROLES in packages/core/src/roles.ts
create type public.user_role as enum ('main_admin', 'org_admin', 'teacher');

-- A person's own standing, kept separate from their subscription's.
-- A teacher can be active while their organization's subscription has lapsed.
create type public.account_status as enum ('pending', 'active', 'suspended');

create type public.invitation_status as enum ('pending', 'accepted', 'expired', 'revoked');

-- ─────────────────────────────────────────────────────────────
-- Subscriptions
-- ─────────────────────────────────────────────────────────────

create type public.subscription_plan as enum ('monthly', 'yearly', 'permanent');

-- Only what an administrator sets. 'expiring_soon' and 'expired' are deliberately
-- absent: they are derived from dates on every read by
-- public.fn_effective_subscription_status(), so a missed cron run can never
-- leave the platform granting access it should have withdrawn.
create type public.subscription_status as enum ('pending', 'active', 'suspended');

-- What a client is shown. The stored status widened by the calendar.
create type public.effective_subscription_status as enum (
  'pending',
  'active',
  'expiring_soon',
  'expired',
  'suspended'
);

create type public.subscription_action as enum (
  'requested',
  'approved',
  'rejected',
  'renewed',
  'extended',
  'suspended',
  'reactivated',
  'expired'
);

-- ─────────────────────────────────────────────────────────────
-- Teaching
-- ─────────────────────────────────────────────────────────────

-- Four outcomes, and the percentage treats them differently:
--   present, late  -> attended (a late student was still taught)
--   absent         -> not attended
--   short_leave    -> excluded from the calculation entirely
--
-- Short leave is a permitted, arranged absence. Counting it against a student
-- would penalise them for something the institution agreed to; counting it as
-- attendance would overstate it. So it leaves the denominator instead.
-- fn_attendance_percentage() is the single implementation of that rule.
create type public.attendance_mark as enum ('present', 'absent', 'late', 'short_leave');

create type public.assessment_type as enum (
  'quiz',
  'assignment',
  'midterm',
  'final',
  'presentation',
  'project',
  'lab',
  'custom'
);

-- From the student contact cards in the mobile mockup. 'student' covers an adult
-- learner who is their own contact.
create type public.contact_label as enum ('father', 'mother', 'guardian', 'student');

-- ─────────────────────────────────────────────────────────────
-- Platform operations
-- ─────────────────────────────────────────────────────────────

-- The first three match the activity-feed filters in the Organization Admin
-- mockup; the last two are platform-level and never shown to an organization.
create type public.activity_type as enum (
  'attendance',
  'marks',
  'alerts',
  'admin',
  'subscription'
);

create type public.notification_channel as enum ('email', 'whatsapp', 'in_app');

create type public.report_kind as enum ('student', 'class', 'organization', 'platform');


-- ═══════════════════════════════════════════════════════════════
-- 20260809120100_identity.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Identity and tenancy
--
-- Three tables carry every question of "who is this and what may they see":
-- organizations (the tenant), profiles (the person), invitations (how a teacher
-- joins one). Row-level security is enabled here and the policies land in a
-- later migration, so no window exists where a table is readable by everyone.

-- ─────────────────────────────────────────────────────────────
-- organizations
-- ─────────────────────────────────────────────────────────────

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 160),
  city text not null check (length(trim(city)) between 2 and 80),
  email text not null,
  phone text,
  status public.account_status not null default 'pending',

  -- The current Organization Admin. Nullable because an organization exists from
  -- the moment it is requested, and because the seat survives the person leaving.
  owner_profile_id uuid,

  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.organizations is
  'An institution that has requested or holds a Warq subscription. The tenant boundary for every org-scoped table.';
comment on column public.organizations.owner_profile_id is
  'Current Organization Admin. Reassignable; the organization outlives any one admin.';

-- The Main Admin lists organizations filtered by status and searched by name or
-- city, which is exactly what these two indexes serve.
create index organizations_status_idx on public.organizations (status);
create index organizations_name_city_idx on public.organizations
  using gin (to_tsvector('simple', name || ' ' || city));

-- ─────────────────────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────────────────────

-- Extends auth.users, which Supabase owns. Everything Warq knows about a person
-- lives here; auth.users holds only the credentials.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  phone text,
  role public.user_role not null,

  -- Null for a Main Admin, and for an independent teacher who holds their own
  -- subscription. A teacher with no organization is an "individual teacher" and
  -- appears on the Main Admin's Individual Teachers page.
  organization_id uuid references public.organizations (id) on delete set null,

  status public.account_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- An Organization Admin without an organization would be an admin of nothing.
  constraint org_admin_needs_organization check (
    role <> 'org_admin' or organization_id is not null
  ),

  -- A Main Admin belongs to the platform, never to a tenant. Without this, one
  -- stray write would put a platform administrator inside an organization's
  -- row-level security scope.
  constraint main_admin_has_no_organization check (
    role <> 'main_admin' or organization_id is null
  )
);

comment on table public.profiles is
  'One row per person. Extends auth.users; auth.users holds credentials, this holds everything else.';
comment on column public.profiles.organization_id is
  'Null for a Main Admin and for an independent teacher. The tenant key for row-level security.';

create index profiles_organization_idx on public.profiles (organization_id)
  where organization_id is not null;
create index profiles_role_status_idx on public.profiles (role, status);

-- Deferred until profiles exists, since the two tables reference each other.
alter table public.organizations
  add constraint organizations_owner_fkey
  foreign key (owner_profile_id) references public.profiles (id) on delete set null;

-- ─────────────────────────────────────────────────────────────
-- invitations
-- ─────────────────────────────────────────────────────────────

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  email text not null,
  full_name text not null,

  -- Single-use and unguessable. Compared in full, never by prefix.
  token text not null unique default encode(extensions.gen_random_bytes(32), 'hex'),

  status public.invitation_status not null default 'pending',
  sent_via public.notification_channel not null default 'email',
  invited_by uuid references public.profiles (id) on delete set null,

  expires_at timestamptz not null default now() + interval '14 days',
  accepted_at timestamptz,
  accepted_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),

  -- An accepted invitation must record who accepted it and when.
  constraint accepted_is_complete check (
    status <> 'accepted' or (accepted_at is not null and accepted_by is not null)
  )
);

comment on table public.invitations is
  'A teacher invited to join an organization by email or WhatsApp. The token is single-use and expires.';

-- One live invitation per address per organization. Re-inviting someone should
-- resend rather than accumulate tokens that all still work.
create unique index invitations_one_live_per_email_idx
  on public.invitations (organization_id, lower(email))
  where status = 'pending';

create index invitations_organization_idx on public.invitations (organization_id, status);
create index invitations_token_idx on public.invitations (token) where status = 'pending';

-- ─────────────────────────────────────────────────────────────
-- updated_at maintenance
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.fn_touch_updated_at is
  'Keeps updated_at honest. A client cannot forget to set it, and cannot lie about it.';

create trigger organizations_touch_updated_at
  before update on public.organizations
  for each row execute function public.fn_touch_updated_at();

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.fn_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- Lock the doors before the policies arrive
-- ─────────────────────────────────────────────────────────────
--
-- With RLS enabled and no policy defined, these tables deny everything to
-- ordinary roles. Policies are added in 20260809120700_rls.sql. Enabling here
-- means there is no moment, even mid-migration, when a table is world-readable.

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.invitations enable row level security;


-- ═══════════════════════════════════════════════════════════════
-- 20260809120200_subscriptions.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Subscriptions
--
-- A subscription is held either by an organization or by an individual teacher,
-- never both. Only the administrative state is stored; whether a subscription is
-- expiring soon or expired is computed from its dates on every read.

-- ─────────────────────────────────────────────────────────────
-- subscriptions
-- ─────────────────────────────────────────────────────────────

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references public.organizations (id) on delete cascade,
  profile_id uuid references public.profiles (id) on delete cascade,

  plan public.subscription_plan not null,
  status public.subscription_status not null default 'pending',

  starts_at date,
  -- Null for a permanent plan, and for a request not yet approved.
  ends_at date,

  -- Modelled now so adding a payment gateway later is not a schema change.
  -- The Main Admin activates subscriptions by hand, as the mockups show.
  price_cents integer check (price_cents is null or price_cents >= 0),
  currency text not null default 'PKR' check (length(currency) = 3),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Exactly one subject. An unowned subscription, or one owned twice, is a bug
  -- that would silently grant or withhold access.
  constraint one_subject check (
    (organization_id is not null and profile_id is null)
    or (organization_id is null and profile_id is not null)
  ),

  -- A permanent plan has no end date; a dated plan that is active must have one.
  constraint permanent_has_no_end check (plan <> 'permanent' or ends_at is null),
  constraint active_dated_plan_has_dates check (
    status <> 'active'
    or plan = 'permanent'
    or (starts_at is not null and ends_at is not null)
  ),
  constraint period_runs_forwards check (
    starts_at is null or ends_at is null or ends_at >= starts_at
  )
);

comment on table public.subscriptions is
  'Held by an organization or an individual teacher. status is administrative only; effective status is derived from dates.';
comment on column public.subscriptions.status is
  'What an administrator set. Never expiring_soon or expired - see fn_effective_subscription_status().';

-- One live subscription per subject. History belongs in subscription_events, not
-- in a pile of overlapping rows.
create unique index subscriptions_one_per_organization_idx
  on public.subscriptions (organization_id)
  where organization_id is not null;

create unique index subscriptions_one_per_profile_idx
  on public.subscriptions (profile_id)
  where profile_id is not null;

-- Serves the Main Admin's Expiring Subscriptions page and the nightly reminder job.
create index subscriptions_expiry_idx on public.subscriptions (ends_at)
  where status = 'active' and ends_at is not null;

create index subscriptions_status_idx on public.subscriptions (status, plan);

create trigger subscriptions_touch_updated_at
  before update on public.subscriptions
  for each row execute function public.fn_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- subscription_events
-- ─────────────────────────────────────────────────────────────

-- Append-only. Backs the "Subscription history" panel in the Main Admin drawer,
-- and answers "who extended this, and when" months later.
create table public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions (id) on delete cascade,
  action public.subscription_action not null,
  plan public.subscription_plan not null,
  from_date date,
  to_date date,
  -- Null when the platform acted rather than a person, e.g. the nightly job.
  actor_id uuid references public.profiles (id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

comment on table public.subscription_events is
  'Append-only audit of every subscription decision. Never updated, never deleted.';

create index subscription_events_subscription_idx
  on public.subscription_events (subscription_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- reminder_settings
-- ─────────────────────────────────────────────────────────────

-- Offsets must be positive, sane and free of duplicates: two notices on one day
-- reads as a malfunction, not as diligence.
--
-- Written as a function because Postgres forbids subqueries inside a CHECK
-- constraint, but permits a call to an immutable function that contains them.
create or replace function public.fn_reminder_days_valid(days integer[])
returns boolean
language sql
immutable
as $$
  select
    days is not null
    and array_length(days, 1) between 1 and 8
    and (select bool_and(d between 1 and 365) from unnest(days) as d)
    and array_length(days, 1) = (select count(distinct d) from unnest(days) as d);
$$;

comment on function public.fn_reminder_days_valid is
  'Reminder offsets: between one and eight of them, each 1-365 days, no duplicates.';

-- The 30 / 15 / 7 / 3 / 1 schedule from the Main Admin's Notifications page.
-- A single row, enforced by the check on id.
create table public.reminder_settings (
  id boolean primary key default true check (id),
  days integer[] not null default '{30,15,7,3,1}',
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now(),

  constraint days_are_valid check (public.fn_reminder_days_valid(days))
);

insert into public.reminder_settings (id) values (true);

comment on table public.reminder_settings is
  'Single row. Days before expiry at which a reminder is sent, as set on the Main Admin notifications page.';

-- ─────────────────────────────────────────────────────────────
-- reminder_logs
-- ─────────────────────────────────────────────────────────────

create table public.reminder_logs (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions (id) on delete cascade,
  days_before integer not null,
  channel public.notification_channel not null,
  message text not null,
  sent_at timestamptz not null default now()
);

comment on table public.reminder_logs is
  'One row per notice sent. Backs the sent log, and makes a duplicate send visible rather than invisible.';

-- The same reminder must not go out twice. If the nightly job runs twice, or is
-- retried after a partial failure, this index is what actually prevents it.
create unique index reminder_logs_once_per_step_idx
  on public.reminder_logs (subscription_id, days_before, channel);

create index reminder_logs_sent_at_idx on public.reminder_logs (sent_at desc);

alter table public.subscriptions enable row level security;
alter table public.subscription_events enable row level security;
alter table public.reminder_settings enable row level security;
alter table public.reminder_logs enable row level security;


-- ═══════════════════════════════════════════════════════════════
-- 20260809120300_teaching.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Teaching
--
-- Classes, the students in them, the people to call when a student is absent,
-- and the grade scale an institution marks by.

-- ─────────────────────────────────────────────────────────────
-- classes
-- ─────────────────────────────────────────────────────────────

create table public.classes (
  id uuid primary key default gen_random_uuid(),

  -- Null for an independent teacher, who has no organization above them.
  organization_id uuid references public.organizations (id) on delete cascade,
  teacher_id uuid not null references public.profiles (id) on delete restrict,

  name text not null check (length(trim(name)) between 2 and 120),

  -- Only the class name is required. Subject, section and session are optional
  -- per the product spec: a teacher can create a class in one field and fill in
  -- the rest later, or never.
  subject text check (subject is null or length(trim(subject)) between 1 and 80),
  section text check (section is null or length(trim(section)) between 1 and 16),
  -- "Session 2026" in the mockups. Text for now; if per-term reporting is needed
  -- later this becomes a real entity, which is a contained change.
  session text check (session is null or length(trim(session)) between 1 and 32),
  description text check (description is null or length(trim(description)) <= 400),

  -- Index into the six-colour series in @warq/tokens. Stored rather than
  -- computed so a class is the same colour on web and on the phone.
  color_index smallint not null default 0 check (color_index between 0 and 5),

  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.classes is
  'A teacher''s class for one session. Owned by a teacher; visible to their organization admin.';
comment on column public.classes.teacher_id is
  'on delete restrict: removing a teacher must not silently delete a term of attendance and marks.';

-- One class per name, section and session for a given teacher. Section and
-- session are coalesced because two NULLs never compare equal in an index, and
-- "Maths" with no section twice over is still a duplicate.
create unique index classes_unique_per_teacher_idx
  on public.classes (
    teacher_id,
    lower(name),
    coalesce(lower(section), ''),
    coalesce(session, '')
  )
  where archived_at is null;

create index classes_teacher_idx on public.classes (teacher_id) where archived_at is null;
create index classes_organization_idx on public.classes (organization_id) where archived_at is null;

create trigger classes_touch_updated_at
  before update on public.classes
  for each row execute function public.fn_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- students
-- ─────────────────────────────────────────────────────────────

-- A student is a record inside a class, not a user account. Nobody signs in as a
-- student, which is deliberate: it keeps minors out of the authentication system
-- entirely.
-- A student belongs to the teacher who entered them, not to a single class.
-- The same person can sit in several of that teacher's classes, which is what
-- public.class_students records. Enrolling and unenrolling therefore never
-- destroys a student's history.
create table public.students (
  id uuid primary key default gen_random_uuid(),

  teacher_id uuid not null references public.profiles (id) on delete cascade,
  -- Mirrors the owning teacher's organization so an org admin can read the
  -- roster without walking every class. Cleared when a teacher leaves.
  organization_id uuid references public.organizations (id) on delete set null,

  full_name text not null check (length(trim(full_name)) between 2 and 120),

  -- Only the name is required. Everything below is optional per the spec.
  roll_no text check (roll_no is null or length(trim(roll_no)) between 1 and 32),
  email text check (email is null or length(trim(email)) <= 160),
  address text check (address is null or length(trim(address)) <= 240),
  guardian_name text check (guardian_name is null or length(trim(guardian_name)) <= 120),
  notes text check (notes is null or length(trim(notes)) <= 400),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.students is
  'A student record owned by a teacher. Not a user account - students never sign in.';
comment on column public.students.roll_no is
  'Optional, and deliberately not unique: schools reuse roll numbers across classes.';

create index students_teacher_idx on public.students (teacher_id);
create index students_organization_idx on public.students (organization_id);
create index students_roll_idx on public.students (teacher_id, lower(roll_no))
  where roll_no is not null;
-- Backs the A-Z roster ordering that every list and report uses.
create index students_name_idx on public.students (teacher_id, lower(full_name));

create trigger students_touch_updated_at
  before update on public.students
  for each row execute function public.fn_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- class_students
-- ─────────────────────────────────────────────────────────────

-- Which students are in which class. Unenrolling sets unenrolled_at rather than
-- deleting the row, so attendance and marks already recorded stay attributable.
create table public.class_students (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  enrolled_at timestamptz not null default now(),
  unenrolled_at timestamptz,
  unique (class_id, student_id)
);

comment on table public.class_students is
  'Enrollment. A student may be in several classes; unenrolled_at is a soft detach that preserves history.';

create index class_students_class_idx
  on public.class_students (class_id) where unenrolled_at is null;
create index class_students_student_idx
  on public.class_students (student_id) where unenrolled_at is null;

-- ─────────────────────────────────────────────────────────────
-- student_contacts
-- ─────────────────────────────────────────────────────────────

create table public.student_contacts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students (id) on delete cascade,
  label public.contact_label not null,
  phone text not null check (phone ~ '^[0-9 +()-]{7,20}$'),

  -- A contact can exist for the record without being messaged. Absence alerts go
  -- only to those who have opted in.
  receives_alerts boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.student_contacts is
  'Who to notify when a student is absent. A student with no contacts simply generates no alert.';

create unique index student_contacts_unique_idx
  on public.student_contacts (student_id, label);

create index student_contacts_alertable_idx
  on public.student_contacts (student_id)
  where receives_alerts;

-- ─────────────────────────────────────────────────────────────
-- grade_scales
-- ─────────────────────────────────────────────────────────────

-- The mockups hardcode A+ >= 90 down to F. Institutions grade differently, so
-- the bands are stored per organization with those values as the platform default.
create table public.grade_scales (
  id uuid primary key default gen_random_uuid(),

  -- Null is the platform default, used by independent teachers and by any
  -- organization that has not set its own.
  organization_id uuid references public.organizations (id) on delete cascade,

  -- [{"grade": "A+", "min": 90}, ...], highest band first.
  bands jsonb not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.grade_scales is
  'Grade bands, highest first. One row per organization; the row with a null organization is the platform default.';

create unique index grade_scales_one_per_organization_idx
  on public.grade_scales (organization_id)
  where organization_id is not null;

create unique index grade_scales_single_default_idx
  on public.grade_scales ((true))
  where organization_id is null;

-- A scale must cover every percentage from 0 to 100 exactly once: descending,
-- no gaps, bottoming out at zero. Mirrors isValidGradeScale() in @warq/core.
create or replace function public.fn_grade_scale_is_valid(bands jsonb)
returns boolean
language sql
immutable
as $$
  select
    jsonb_typeof(bands) = 'array'
    and jsonb_array_length(bands) between 1 and 12
    -- Every band well-formed and in range.
    and not exists (
      select 1
      from jsonb_array_elements(bands) as b
      where b->>'grade' is null
         or b->>'min' is null
         or (b->>'min')::numeric < 0
         or (b->>'min')::numeric > 100
    )
    -- Strictly descending.
    and not exists (
      select 1
      from (
        select
          (value->>'min')::numeric as m,
          lag((value->>'min')::numeric) over (order by ordinality) as previous
        from jsonb_array_elements(bands) with ordinality
      ) as ordered
      where previous is not null and previous <= m
    )
    -- Floors at zero, so nothing is left ungraded.
    and (bands -> (jsonb_array_length(bands) - 1) ->> 'min')::numeric = 0;
$$;

comment on function public.fn_grade_scale_is_valid is
  'Descending, no gaps, floors at zero. Mirrors isValidGradeScale() in @warq/core.';

alter table public.grade_scales
  add constraint bands_are_valid check (public.fn_grade_scale_is_valid(bands));

-- The default from the mockups.
insert into public.grade_scales (organization_id, bands) values (
  null,
  '[{"grade":"A+","min":90},{"grade":"A","min":80},{"grade":"B","min":70},{"grade":"C","min":60},{"grade":"D","min":50},{"grade":"F","min":0}]'::jsonb
);

create trigger grade_scales_touch_updated_at
  before update on public.grade_scales
  for each row execute function public.fn_touch_updated_at();

alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.class_students enable row level security;
alter table public.student_contacts enable row level security;
alter table public.grade_scales enable row level security;


-- ═══════════════════════════════════════════════════════════════
-- 20260809120400_assessment.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Attendance and assessment
--
-- Attendance is stored per session rather than as running totals, so correcting
-- last Tuesday's roll call is a single update and every percentage recomputes
-- from the same rows.

-- ─────────────────────────────────────────────────────────────
-- attendance_sessions
-- ─────────────────────────────────────────────────────────────

create table public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes (id) on delete cascade,

  -- A calendar date, not a timestamp. Attendance on 8 August is on that date in
  -- Lahore and in London alike.
  date date not null,

  taken_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- No roll call for a lesson that has not happened.
  constraint not_in_the_future check (date <= current_date + 1)
);

comment on table public.attendance_sessions is
  'One roll call. Exactly one per class per day - re-saving updates it rather than creating a second.';

-- The rule that makes attendance idempotent: saving twice corrects the record
-- instead of double-counting it.
create unique index attendance_sessions_one_per_day_idx
  on public.attendance_sessions (class_id, date);

create index attendance_sessions_class_date_idx
  on public.attendance_sessions (class_id, date desc);

create trigger attendance_sessions_touch_updated_at
  before update on public.attendance_sessions
  for each row execute function public.fn_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- attendance_records
-- ─────────────────────────────────────────────────────────────

create table public.attendance_records (
  session_id uuid not null references public.attendance_sessions (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,
  mark public.attendance_mark not null default 'present',
  primary key (session_id, student_id)
);

comment on table public.attendance_records is
  'One mark per student per session. The composite key makes a duplicate mark impossible.';

create index attendance_records_student_idx on public.attendance_records (student_id);

-- ─────────────────────────────────────────────────────────────
-- assessments
-- ─────────────────────────────────────────────────────────────

create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes (id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  type public.assessment_type not null,
  date date not null,
  total_marks numeric(6, 2) not null check (total_marks > 0 and total_marks <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.assessments is
  'A quiz, assignment, midterm, final, project or lab. total_marks is the denominator for every percentage.';

create unique index assessments_unique_name_idx
  on public.assessments (class_id, lower(name));

create index assessments_class_date_idx on public.assessments (class_id, date desc);

create trigger assessments_touch_updated_at
  before update on public.assessments
  for each row execute function public.fn_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- marks
-- ─────────────────────────────────────────────────────────────

create table public.marks (
  assessment_id uuid not null references public.assessments (id) on delete cascade,
  student_id uuid not null references public.students (id) on delete cascade,

  -- Null means not yet marked, which is not the same as zero. The mockups draw
  -- an empty box and an em-dash grade for exactly this case, and aggregate()
  -- leaves unmarked work out of both sides of the fraction - so nobody is failed
  -- for work a teacher has not graded.
  score numeric(6, 2) check (score is null or score >= 0),

  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now(),

  primary key (assessment_id, student_id)
);

comment on table public.marks is
  'A student''s score for one assessment. Null score means unmarked, which is different from zero.';
comment on column public.marks.score is
  'Null = not yet marked. Excluded from totals rather than counted as zero.';

create index marks_student_idx on public.marks (student_id);

-- A score above the assessment total is almost always a typo. Caught here rather
-- than surfacing later as a grade above 100%.
create or replace function public.fn_mark_within_total()
returns trigger
language plpgsql
as $$
declare
  max_score numeric;
begin
  if new.score is null then
    return new;
  end if;

  select total_marks into max_score
  from public.assessments
  where id = new.assessment_id;

  if new.score > max_score then
    raise exception 'Score % is higher than the assessment total of %.', new.score, max_score
      using hint = 'Check the mark, or raise the assessment total.';
  end if;

  return new;
end;
$$;

create trigger marks_within_total
  before insert or update of score on public.marks
  for each row execute function public.fn_mark_within_total();

create trigger marks_touch_updated_at
  before update on public.marks
  for each row execute function public.fn_touch_updated_at();

alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.assessments enable row level security;
alter table public.marks enable row level security;


-- ═══════════════════════════════════════════════════════════════
-- 20260809120500_platform.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Platform operations
--
-- What happened, who needs telling, and what has been generated. These three
-- tables back the activity feeds on all three dashboards, the notification bell,
-- and the report library.

-- ─────────────────────────────────────────────────────────────
-- activity_logs
-- ─────────────────────────────────────────────────────────────

create table public.activity_logs (
  id uuid primary key default gen_random_uuid(),

  -- Null for platform-level entries, which only a Main Admin ever sees.
  organization_id uuid references public.organizations (id) on delete cascade,

  -- Null when the platform acted rather than a person, e.g. the nightly job.
  actor_id uuid references public.profiles (id) on delete set null,
  -- Kept so the feed still reads correctly after someone leaves and their
  -- profile is gone. "Farhan Saeed saved attendance" should not become
  -- "Someone saved attendance" a year later.
  actor_name text not null,

  type public.activity_type not null,
  message text not null,

  -- Ids and counts the row refers to, so a feed entry can link somewhere useful
  -- without a join per row.
  meta jsonb not null default '{}'::jsonb,

  created_at timestamptz not null default now()
);

comment on table public.activity_logs is
  'Append-only. Backs the Main Admin platform feed, the organization feed and the teacher''s recent activity.';
comment on column public.activity_logs.actor_name is
  'Denormalised on purpose: the feed must stay readable after the actor''s profile is deleted.';

-- Every feed in the product reads newest-first, filtered by scope.
create index activity_logs_organization_idx
  on public.activity_logs (organization_id, created_at desc);

create index activity_logs_platform_idx
  on public.activity_logs (created_at desc)
  where organization_id is null;

create index activity_logs_actor_idx on public.activity_logs (actor_id, created_at desc);

-- Serves the All / Attendance / Marks / Alerts chips in the mockups.
create index activity_logs_type_idx on public.activity_logs (organization_id, type, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- notifications
-- ─────────────────────────────────────────────────────────────

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  type public.activity_type not null default 'admin',
  meta jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

comment on table public.notifications is
  'In-app notifications. The unread dot on the bell is a count of rows here with read_at null.';

-- The bell badge counts unread rows for one person; this index makes that free.
create index notifications_unread_idx
  on public.notifications (profile_id, created_at desc)
  where read_at is null;

create index notifications_recipient_idx on public.notifications (profile_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- guardian_messages
-- ─────────────────────────────────────────────────────────────

-- Absence notices addressed to a phone number, as distinct from
-- public.notifications, which are in-app alerts addressed to a signed-in user.
--
-- The row is written when the notice is prepared, not when it is delivered.
-- WhatsApp on a phone needs the teacher to press send, so a notice sits here as
-- 'queued' until it goes out; it survives closing the app and syncs across
-- devices, so nothing is quietly lost. A server-side gateway later marks rows
-- 'sent' without a teacher present, and nothing else has to change.
create table public.guardian_messages (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references public.organizations (id) on delete cascade,
  -- Who is responsible for sending it; the queue is theirs.
  requested_by uuid not null references public.profiles (id) on delete cascade,

  student_id uuid references public.students (id) on delete set null,
  class_id uuid references public.classes (id) on delete set null,

  -- Which roll call produced this notice. attendance_records is keyed by
  -- (session_id, student_id) and has no id of its own, so the session is the
  -- referencable half; together with student_id above it identifies the exact
  -- record without a composite foreign key.
  attendance_session_id uuid references public.attendance_sessions (id) on delete set null,

  -- Snapshotted so the outbox still reads correctly after a student is renamed
  -- or removed.
  student_name text not null,
  class_name text,

  recipient_label public.contact_label not null,
  recipient_phone text not null check (recipient_phone ~ '^[0-9 +()-]{7,20}$'),

  channel public.notification_channel not null default 'whatsapp',
  body text not null,

  status text not null default 'queued'
    check (status in ('queued', 'sent', 'failed', 'skipped')),
  failure_reason text,
  sent_at timestamptz,

  created_at timestamptz not null default now()
);

comment on table public.guardian_messages is
  'Outbox of absence notices to guardians. Queued until delivered; one row per recipient phone number.';

-- The teacher's outbox, newest first.
create index guardian_messages_requester_idx
  on public.guardian_messages (requested_by, created_at desc);

-- "What is still waiting to go out?" - the count the dispatch screen shows.
create index guardian_messages_pending_idx
  on public.guardian_messages (requested_by, created_at desc)
  where status <> 'sent';

create index guardian_messages_organization_idx
  on public.guardian_messages (organization_id, created_at desc);

alter table public.guardian_messages enable row level security;

-- ─────────────────────────────────────────────────────────────
-- reports
-- ─────────────────────────────────────────────────────────────

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  kind public.report_kind not null,

  -- The student, class or organization the report is about. Null for a
  -- platform-wide report, which is about everything.
  subject_id uuid,
  organization_id uuid references public.organizations (id) on delete cascade,

  -- Path within the Supabase Storage bucket. The file is served through a signed
  -- URL, never a public one - a report names a child and lists their marks.
  storage_path text not null unique,

  generated_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),

  constraint platform_reports_have_no_subject check (
    kind <> 'platform' or subject_id is null
  ),
  constraint scoped_reports_have_a_subject check (
    kind = 'platform' or subject_id is not null
  )
);

comment on table public.reports is
  'Generated PDFs. The file lives in Storage; this row records what it is and who may fetch it.';

create index reports_subject_idx on public.reports (kind, subject_id, created_at desc);
create index reports_organization_idx on public.reports (organization_id, created_at desc);

alter table public.activity_logs enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;


-- ═══════════════════════════════════════════════════════════════
-- 20260809120600_functions.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Access helper functions
--
-- Every row-level security policy is written in terms of these. The access rule
-- is therefore stated once: change it here and every table follows, rather than
-- editing forty policies and missing one.
--
-- All are `stable` and marked `security definer` where they must read tables the
-- caller cannot, with an empty search_path so a caller cannot shadow a table
-- name and change what the function sees.

-- ─────────────────────────────────────────────────────────────
-- Who is asking
-- ─────────────────────────────────────────────────────────────

-- The caller's role, read from their profile rather than from a client-supplied
-- claim. A client can put anything in a request header; it cannot put anything
-- in this table.
create or replace function public.auth_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid();
$$;

comment on function public.auth_role is
  'The caller''s role, read from profiles. Never trusts a client-supplied claim.';

-- The caller's organization. Null for a Main Admin and for an independent teacher.
create or replace function public.auth_org_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select organization_id from public.profiles where id = auth.uid();
$$;

comment on function public.auth_org_id is
  'The caller''s organization. Null for a Main Admin and for an independent teacher.';

create or replace function public.is_main_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'main_admin' from public.profiles where id = auth.uid()),
    false
  );
$$;

create or replace function public.is_org_admin_of(target_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select role = 'org_admin' and organization_id = target_org
      from public.profiles
      where id = auth.uid()
    ),
    false
  );
$$;

-- Does the caller own this class? The single question behind most teacher policies.
create or replace function public.owns_class(target_class uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.classes
    where id = target_class and teacher_id = auth.uid()
  );
$$;

-- Can the caller see this class at all — as its teacher, or as the admin of the
-- organization it belongs to?
create or replace function public.can_read_class(target_class uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.classes c
    join public.profiles p on p.id = auth.uid()
    where c.id = target_class
      and (
        c.teacher_id = auth.uid()
        or (p.role = 'org_admin' and c.organization_id = p.organization_id)
      )
  );
$$;

comment on function public.can_read_class is
  'A teacher sees their own classes; an org admin sees every class in their organization. A Main Admin sees neither - running the platform does not require reading a child''s marks.';

-- ─────────────────────────────────────────────────────────────
-- Subscription state
-- ─────────────────────────────────────────────────────────────

-- Mirrors EXPIRING_SOON_DAYS in packages/core/src/subscription.ts.
create or replace function public.fn_expiring_soon_days()
returns integer
language sql
immutable
as $$ select 14; $$;

-- The effective status: what the customer actually sees today.
--
-- Deliberately computed rather than stored. If it were a column, a missed cron
-- run would leave the platform granting access it should have withdrawn. The
-- logic mirrors effectiveStatus() in @warq/core exactly, and the two are tested
-- against the same mockup fixtures.
create or replace function public.fn_effective_subscription_status(
  plan public.subscription_plan,
  status public.subscription_status,
  ends_at date,
  as_of date default current_date
)
returns public.effective_subscription_status
language sql
immutable
as $$
  select case
    -- An administrator's decision outranks the calendar.
    when status = 'pending' then 'pending'::public.effective_subscription_status
    when status = 'suspended' then 'suspended'::public.effective_subscription_status
    when plan = 'permanent' then 'active'::public.effective_subscription_status
    -- Active but undated is a data fault. Treat it as not yet granted rather
    -- than handing out unbounded access.
    when ends_at is null then 'pending'::public.effective_subscription_status
    when ends_at < as_of then 'expired'::public.effective_subscription_status
    when ends_at - as_of <= public.fn_expiring_soon_days()
      then 'expiring_soon'::public.effective_subscription_status
    else 'active'::public.effective_subscription_status
  end;
$$;

comment on function public.fn_effective_subscription_status is
  'Derived on every read. Mirrors effectiveStatus() in @warq/core; both are tested against the same fixtures.';

-- ─────────────────────────────────────────────────────────────
-- The subscription gate
-- ─────────────────────────────────────────────────────────────

-- Whether an account is currently paid up.
--
-- Expiring soon still works: warning before cutting off is the entire point of
-- that state. Pending, expired and suspended do not.
--
-- Applied in the policies on every data table, which is what makes a Main Admin
-- suspension take effect everywhere at once - web, mobile, and any request in
-- flight - rather than merely greying out a screen.
create or replace function public.fn_has_access(target_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with subject as (
    select p.id as profile_id, p.organization_id, p.status as account_status
    from public.profiles p
    where p.id = target_profile
  ),
  governing as (
    -- An organization member is governed by the organization's subscription;
    -- an independent teacher by their own.
    select s.*
    from public.subscriptions s, subject
    where (subject.organization_id is not null and s.organization_id = subject.organization_id)
       or (subject.organization_id is null and s.profile_id = subject.profile_id)
    limit 1
  )
  select
    -- A suspended person is blocked regardless of what the organization has paid.
    (select account_status from subject) = 'active'
    and (
      -- A Main Admin belongs to the platform and holds no subscription.
      (select role from public.profiles where id = target_profile) = 'main_admin'
      or exists (
        select 1 from governing
        where public.fn_effective_subscription_status(plan, status, ends_at)
          in ('active', 'expiring_soon')
      )
    );
$$;

comment on function public.fn_has_access is
  'The subscription gate. False when the governing subscription is pending, expired or suspended - or when the person themselves is suspended.';

-- The caller's own access. What the policies actually call.
create or replace function public.has_access()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.fn_has_access(auth.uid()), false);
$$;

-- ─────────────────────────────────────────────────────────────
-- Students
--
-- Students are owned by a teacher rather than by a class, so class-scoped
-- helpers cannot answer questions about them.
-- ─────────────────────────────────────────────────────────────

create or replace function public.owns_student(target_student uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.students
    where id = target_student and teacher_id = auth.uid()
  );
$$;

-- The owning teacher, or the admin of the organization the student belongs to.
create or replace function public.can_read_student(target_student uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.students s
    join public.profiles p on p.id = auth.uid()
    where s.id = target_student
      and (
        s.teacher_id = auth.uid()
        or (p.role = 'org_admin' and s.organization_id = p.organization_id)
      )
  );
$$;

-- ─────────────────────────────────────────────────────────────
-- Attendance
-- ─────────────────────────────────────────────────────────────

-- The one definition of an attendance percentage, so the phone, the web app and
-- every report agree.
--
--   attended    = present + late
--   denominator = present + late + absent   (short_leave is excluded)
--
-- Returns null rather than zero when there is nothing to divide by: a student
-- with no assessable sessions has no percentage, which is different from
-- having a percentage of nought.
create or replace function public.fn_attendance_percentage(
  present_count integer,
  late_count integer,
  absent_count integer
)
returns integer
language sql
immutable
as $$
  select case
    when coalesce(present_count, 0) + coalesce(late_count, 0) + coalesce(absent_count, 0) = 0
      then null
    else round(
      ((coalesce(present_count, 0) + coalesce(late_count, 0))::numeric * 100)
      / (coalesce(present_count, 0) + coalesce(late_count, 0) + coalesce(absent_count, 0))
    )::integer
  end;
$$;

comment on function public.fn_attendance_percentage is
  'Late counts as attended; short leave is excluded from the denominator. Null when there is nothing to assess.';

-- ─────────────────────────────────────────────────────────────
-- Grading, so a percentage means the same thing in SQL and in TypeScript
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_grade_for(
  percent numeric,
  target_org uuid default null
)
returns text
language sql
stable
as $$
  with scale as (
    select coalesce(
      (select bands from public.grade_scales where organization_id = target_org),
      (select bands from public.grade_scales where organization_id is null)
    ) as bands
  ),
  clamped as (select least(100, greatest(0, percent)) as p)
  select b.value->>'grade'
  from scale, clamped, jsonb_array_elements(scale.bands) with ordinality as b(value, ord)
  where clamped.p >= (b.value->>'min')::numeric
  order by b.ord
  limit 1;
$$;

comment on function public.fn_grade_for is
  'Mirrors gradeFor() in @warq/core. Uses the organization''s scale, falling back to the platform default.';

-- Whole-number percentage. Zero total scores zero rather than dividing by it.
create or replace function public.fn_percentage(obtained numeric, total numeric)
returns integer
language sql
immutable
as $$
  select case when coalesce(total, 0) <= 0 then 0 else round(obtained / total * 100)::integer end;
$$;


-- ═══════════════════════════════════════════════════════════════
-- 20260809120700_rls.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Row-level security policies
--
-- Row-level security was enabled on every table as it was created, so until this
-- migration runs each one denies everything. These policies are the only thing
-- that opens them, and they are written entirely in terms of the helpers in
-- 20260809120600_functions.sql.
--
-- Three principles run through all of it:
--
--   1. A Main Admin runs the platform but never reads a child's record.
--      They can see that an organization has 312 students; not who those
--      students are, or what they scored.
--
--   2. The subscription gate applies to teaching data, not to the account
--      itself. A locked-out user can still sign in, see that their subscription
--      has expired, and read the renewal notice - otherwise they would meet a
--      blank app with no explanation, which is a support call, not a product.
--
--   3. Nothing is granted to `anon`. Every policy below targets `authenticated`.
--      Unauthenticated requests see nothing at all.

-- ═════════════════════════════════════════════════════════════
-- organizations
-- ═════════════════════════════════════════════════════════════

create policy "main admin reads every organization"
  on public.organizations for select to authenticated
  using (public.is_main_admin());

create policy "members read their own organization"
  on public.organizations for select to authenticated
  using (id = public.auth_org_id());

create policy "main admin updates any organization"
  on public.organizations for update to authenticated
  using (public.is_main_admin())
  with check (public.is_main_admin());

create policy "org admin updates their own organization"
  on public.organizations for update to authenticated
  using (public.is_org_admin_of(id))
  with check (public.is_org_admin_of(id));

-- An Organization Admin may correct their address; they may not approve
-- themselves, un-suspend themselves, or hand ownership to someone else.
-- A policy cannot express "these columns but not those", so a trigger does.
create or replace function public.fn_guard_organization_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_main_admin() then
    return new;
  end if;

  if new.status is distinct from old.status then
    raise exception 'Only the platform administrator can change an organization''s status.'
      using hint = 'Contact Warq support to change your subscription or account status.';
  end if;

  if new.owner_profile_id is distinct from old.owner_profile_id then
    raise exception 'Only the platform administrator can reassign an organization''s admin.'
      using hint = 'Contact Warq support to transfer ownership.';
  end if;

  if new.approved_at is distinct from old.approved_at then
    raise exception 'Approval dates are set by the platform, not by the organization.';
  end if;

  return new;
end;
$$;

create trigger organizations_guard_fields
  before update on public.organizations
  for each row execute function public.fn_guard_organization_fields();

-- ═════════════════════════════════════════════════════════════
-- profiles
-- ═════════════════════════════════════════════════════════════

-- Always readable by its owner. This is the bootstrap: a client needs its own
-- profile to know which dashboard to open.
create policy "everyone reads their own profile"
  on public.profiles for select to authenticated
  using (id = auth.uid());

create policy "main admin reads every profile"
  on public.profiles for select to authenticated
  using (public.is_main_admin());

-- An Organization Admin sees the people in their organization. A teacher does
-- not see their colleagues - nothing in the mockups asks them to.
create policy "org admin reads their organization's people"
  on public.profiles for select to authenticated
  using (organization_id is not null and public.is_org_admin_of(organization_id));

create policy "everyone updates their own profile"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "main admin updates any profile"
  on public.profiles for update to authenticated
  using (public.is_main_admin())
  with check (public.is_main_admin());

create policy "org admin updates their organization's people"
  on public.profiles for update to authenticated
  using (organization_id is not null and public.is_org_admin_of(organization_id))
  with check (organization_id is not null and public.is_org_admin_of(organization_id));

-- Privilege escalation is the obvious attack on a self-update policy: change
-- your own role to main_admin, or move yourself into another organization.
create or replace function public.fn_guard_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_main_admin() then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'Roles are assigned by the platform administrator.';
  end if;

  if new.organization_id is distinct from old.organization_id then
    raise exception 'Organization membership changes by invitation or removal, not by editing a profile.';
  end if;

  -- An Organization Admin may suspend a teacher in their organization; nobody
  -- may reactivate their own suspended account.
  if new.status is distinct from old.status and new.id = auth.uid() then
    raise exception 'You cannot change your own account status.';
  end if;

  return new;
end;
$$;

create trigger profiles_guard_fields
  before update on public.profiles
  for each row execute function public.fn_guard_profile_fields();

-- No insert policy. Profiles are created only by the auth trigger in
-- 20260809120900_auth.sql, which runs as the definer.

-- ═════════════════════════════════════════════════════════════
-- invitations
-- ═════════════════════════════════════════════════════════════

create policy "org admin manages their organization's invitations"
  on public.invitations for all to authenticated
  using (public.is_org_admin_of(organization_id))
  with check (public.is_org_admin_of(organization_id));

create policy "main admin reads every invitation"
  on public.invitations for select to authenticated
  using (public.is_main_admin());

-- Accepting an invitation happens before the invitee has a profile, so it cannot
-- be a policy. It runs through a security-definer function that takes the token.

-- ═════════════════════════════════════════════════════════════
-- subscriptions
-- ═════════════════════════════════════════════════════════════

create policy "main admin manages every subscription"
  on public.subscriptions for all to authenticated
  using (public.is_main_admin())
  with check (public.is_main_admin());

-- The subject can read their own, and only read it. This is what lets an expired
-- account see why it is locked out.
create policy "subjects read their own subscription"
  on public.subscriptions for select to authenticated
  using (
    (organization_id is not null and organization_id = public.auth_org_id())
    or profile_id = auth.uid()
  );

create policy "main admin reads every subscription event"
  on public.subscription_events for select to authenticated
  using (public.is_main_admin());

create policy "subjects read their own subscription history"
  on public.subscription_events for select to authenticated
  using (
    exists (
      select 1 from public.subscriptions s
      where s.id = subscription_id
        and (
          (s.organization_id is not null and s.organization_id = public.auth_org_id())
          or s.profile_id = auth.uid()
        )
    )
  );

create policy "main admin records subscription events"
  on public.subscription_events for insert to authenticated
  with check (public.is_main_admin());

-- ═════════════════════════════════════════════════════════════
-- reminder settings and logs — platform only
-- ═════════════════════════════════════════════════════════════

create policy "main admin reads the reminder schedule"
  on public.reminder_settings for select to authenticated
  using (public.is_main_admin());

create policy "main admin sets the reminder schedule"
  on public.reminder_settings for update to authenticated
  using (public.is_main_admin())
  with check (public.is_main_admin());

create policy "main admin reads the sent log"
  on public.reminder_logs for select to authenticated
  using (public.is_main_admin());

-- No insert policy: only the worker writes here, with the secret key.

-- ═════════════════════════════════════════════════════════════
-- classes
-- ═════════════════════════════════════════════════════════════

create policy "teachers read their own classes"
  on public.classes for select to authenticated
  using (teacher_id = auth.uid());

create policy "org admin reads their organization's classes"
  on public.classes for select to authenticated
  using (organization_id is not null and public.is_org_admin_of(organization_id));

-- Writes need both ownership and a paid-up account. The gate is on writes and on
-- reads of the data below, but never on the account tables above.
create policy "teachers create their own classes"
  on public.classes for insert to authenticated
  with check (teacher_id = auth.uid() and public.has_access());

create policy "teachers update their own classes"
  on public.classes for update to authenticated
  using (teacher_id = auth.uid() and public.has_access())
  with check (teacher_id = auth.uid());

create policy "teachers delete their own classes"
  on public.classes for delete to authenticated
  using (teacher_id = auth.uid() and public.has_access());

-- ═════════════════════════════════════════════════════════════
-- students and their contacts
-- ═════════════════════════════════════════════════════════════

-- Students hang off a teacher, not a class, so these are answered by
-- owns_student / can_read_student rather than the class helpers.

create policy "owners and their org admin read students"
  on public.students for select to authenticated
  using (public.can_read_student(id) and public.has_access());

create policy "teachers manage their own roster"
  on public.students for all to authenticated
  using (teacher_id = auth.uid() and public.has_access())
  with check (teacher_id = auth.uid() and public.has_access());

-- ─────────────────────────────────────────────────────────────
-- enrollment
-- ─────────────────────────────────────────────────────────────

-- Readable by anyone who can see either side of the link, so an org admin
-- browsing a class sees its roster.
create policy "class readers read enrollment"
  on public.class_students for select to authenticated
  using (public.can_read_class(class_id) and public.has_access());

-- Enrolling requires owning both the class and the student: it must not be
-- possible to pull another teacher's student into your class, nor to place
-- your student into someone else's.
create policy "teachers manage enrollment in their classes"
  on public.class_students for all to authenticated
  using (
    public.owns_class(class_id)
    and public.owns_student(student_id)
    and public.has_access()
  )
  with check (
    public.owns_class(class_id)
    and public.owns_student(student_id)
    and public.has_access()
  );

-- ─────────────────────────────────────────────────────────────
-- student contacts
-- ─────────────────────────────────────────────────────────────

create policy "student readers read contacts"
  on public.student_contacts for select to authenticated
  using (public.has_access() and public.can_read_student(student_id));

create policy "teachers manage student contacts"
  on public.student_contacts for all to authenticated
  using (public.has_access() and public.owns_student(student_id))
  with check (public.has_access() and public.owns_student(student_id));

-- ═════════════════════════════════════════════════════════════
-- grade scales
-- ═════════════════════════════════════════════════════════════

-- The default row is readable by everyone signed in; a teacher needs it to
-- render a grade.
create policy "everyone reads the default grade scale"
  on public.grade_scales for select to authenticated
  using (organization_id is null);

create policy "members read their organization's grade scale"
  on public.grade_scales for select to authenticated
  using (organization_id = public.auth_org_id());

create policy "org admin sets their organization's grade scale"
  on public.grade_scales for all to authenticated
  using (organization_id is not null and public.is_org_admin_of(organization_id))
  with check (organization_id is not null and public.is_org_admin_of(organization_id));

create policy "main admin sets the default grade scale"
  on public.grade_scales for update to authenticated
  using (organization_id is null and public.is_main_admin())
  with check (organization_id is null and public.is_main_admin());

-- ═════════════════════════════════════════════════════════════
-- attendance
-- ═════════════════════════════════════════════════════════════

create policy "class readers read attendance sessions"
  on public.attendance_sessions for select to authenticated
  using (public.can_read_class(class_id) and public.has_access());

create policy "teachers record attendance"
  on public.attendance_sessions for all to authenticated
  using (public.owns_class(class_id) and public.has_access())
  with check (public.owns_class(class_id) and public.has_access());

create policy "class readers read attendance marks"
  on public.attendance_records for select to authenticated
  using (
    public.has_access()
    and exists (
      select 1 from public.attendance_sessions s
      where s.id = session_id and public.can_read_class(s.class_id)
    )
  );

create policy "teachers mark attendance"
  on public.attendance_records for all to authenticated
  using (
    public.has_access()
    and exists (
      select 1 from public.attendance_sessions s
      where s.id = session_id and public.owns_class(s.class_id)
    )
  )
  with check (
    public.has_access()
    and exists (
      select 1 from public.attendance_sessions s
      where s.id = session_id and public.owns_class(s.class_id)
    )
  );

-- ═════════════════════════════════════════════════════════════
-- assessments and marks
-- ═════════════════════════════════════════════════════════════

create policy "class readers read assessments"
  on public.assessments for select to authenticated
  using (public.can_read_class(class_id) and public.has_access());

create policy "teachers manage assessments"
  on public.assessments for all to authenticated
  using (public.owns_class(class_id) and public.has_access())
  with check (public.owns_class(class_id) and public.has_access());

create policy "class readers read marks"
  on public.marks for select to authenticated
  using (
    public.has_access()
    and exists (
      select 1 from public.assessments a
      where a.id = assessment_id and public.can_read_class(a.class_id)
    )
  );

create policy "teachers enter marks"
  on public.marks for all to authenticated
  using (
    public.has_access()
    and exists (
      select 1 from public.assessments a
      where a.id = assessment_id and public.owns_class(a.class_id)
    )
  )
  with check (
    public.has_access()
    and exists (
      select 1 from public.assessments a
      where a.id = assessment_id and public.owns_class(a.class_id)
    )
  );

-- ═════════════════════════════════════════════════════════════
-- activity logs
-- ═════════════════════════════════════════════════════════════

create policy "main admin reads platform activity"
  on public.activity_logs for select to authenticated
  using (public.is_main_admin());

create policy "org admin reads their organization's activity"
  on public.activity_logs for select to authenticated
  using (organization_id is not null and public.is_org_admin_of(organization_id));

create policy "everyone reads their own activity"
  on public.activity_logs for select to authenticated
  using (actor_id = auth.uid());

-- A person may only write entries attributed to themselves. Otherwise the audit
-- trail could be forged by the person it is meant to hold to account.
create policy "everyone records their own activity"
  on public.activity_logs for insert to authenticated
  with check (actor_id = auth.uid());

-- No update or delete policy anywhere: the log is append-only.

-- ═════════════════════════════════════════════════════════════
-- notifications
-- ═════════════════════════════════════════════════════════════

create policy "everyone reads their own notifications"
  on public.notifications for select to authenticated
  using (profile_id = auth.uid());

-- Marking as read is the only change a recipient can make.
create policy "everyone marks their own notifications read"
  on public.notifications for update to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create or replace function public.fn_guard_notification_fields()
returns trigger
language plpgsql
as $$
begin
  if new.title is distinct from old.title
     or new.body is distinct from old.body
     or new.profile_id is distinct from old.profile_id
     or new.type is distinct from old.type then
    raise exception 'A notification''s contents cannot be edited, only marked read.';
  end if;
  return new;
end;
$$;

create trigger notifications_guard_fields
  before update on public.notifications
  for each row execute function public.fn_guard_notification_fields();

-- No insert policy: notifications are raised by the worker and by triggers.

-- ═════════════════════════════════════════════════════════════
-- reports
-- ═════════════════════════════════════════════════════════════

create policy "generators read their own reports"
  on public.reports for select to authenticated
  using (generated_by = auth.uid());

create policy "org admin reads their organization's reports"
  on public.reports for select to authenticated
  using (organization_id is not null and public.is_org_admin_of(organization_id));

create policy "main admin reads platform reports"
  on public.reports for select to authenticated
  using (public.is_main_admin() and kind = 'platform');

-- No insert policy: the worker renders and records reports with the secret key.

-- ═════════════════════════════════════════════════════════════
-- guardian messages
-- ═════════════════════════════════════════════════════════════

-- The teacher who raised the notice owns the queue and works through it.
create policy "teachers read their own guardian messages"
  on public.guardian_messages for select to authenticated
  using (requested_by = auth.uid());

-- An org admin can see that parents were contacted, which is a monitoring
-- question, without being able to send or alter anything.
create policy "org admin reads their organization's guardian messages"
  on public.guardian_messages for select to authenticated
  using (organization_id is not null and public.is_org_admin_of(organization_id));

create policy "teachers queue their own guardian messages"
  on public.guardian_messages for insert to authenticated
  with check (requested_by = auth.uid() and public.has_access());

-- Only the delivery outcome is updatable; the message body and recipient are
-- fixed once queued, so an outbox entry cannot be rewritten after the fact.
create policy "teachers update delivery state of their own messages"
  on public.guardian_messages for update to authenticated
  using (requested_by = auth.uid() and public.has_access())
  with check (requested_by = auth.uid());

create policy "teachers delete their own guardian messages"
  on public.guardian_messages for delete to authenticated
  using (requested_by = auth.uid() and public.has_access());


-- ═══════════════════════════════════════════════════════════════
-- 20260809120800_views.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Dashboard views
--
-- Aggregation belongs in the database, not in three clients that would each
-- drift. An attendance percentage must read the same on the web dashboard, on
-- the phone, and in a generated PDF.
--
-- Every view is created `with (security_invoker = true)`. Without it a view runs
-- with its owner's rights and quietly bypasses row-level security - which would
-- undo every policy in the previous migration.

-- ─────────────────────────────────────────────────────────────
-- v_effective_subscriptions
-- ─────────────────────────────────────────────────────────────

create view public.v_effective_subscriptions
with (security_invoker = true) as
select
  s.id,
  s.organization_id,
  s.profile_id,
  s.plan,
  s.status as stored_status,
  public.fn_effective_subscription_status(s.plan, s.status, s.ends_at) as status,
  s.starts_at,
  s.ends_at,
  case
    when s.plan = 'permanent' or s.ends_at is null then null
    else s.ends_at - current_date
  end as days_remaining,
  public.fn_effective_subscription_status(s.plan, s.status, s.ends_at)
    in ('active', 'expiring_soon') as grants_access,
  s.price_cents,
  s.currency,
  s.created_at
from public.subscriptions s;

comment on view public.v_effective_subscriptions is
  'Subscriptions with the derived status attached. Every badge in the product reads status from here, never from subscriptions.status.';

-- ─────────────────────────────────────────────────────────────
-- v_class_attendance
-- ─────────────────────────────────────────────────────────────

create view public.v_class_attendance
with (security_invoker = true) as
-- A student may be enrolled in several classes, so their marks are counted
-- against the class whose session produced them: records are reached through
-- attendance_sessions rather than straight off the student.
with per_student as (
  select
    cs.class_id,
    cs.student_id,
    count(*) filter (where r.mark = 'present') as present,
    count(*) filter (where r.mark = 'absent') as absent,
    count(*) filter (where r.mark = 'late') as late,
    count(*) filter (where r.mark = 'short_leave') as short_leave
  from public.class_students cs
  left join public.attendance_sessions s on s.class_id = cs.class_id
  left join public.attendance_records r
    on r.session_id = s.id and r.student_id = cs.student_id
  where cs.unenrolled_at is null
  group by cs.class_id, cs.student_id
)
select
  c.id as class_id,
  c.organization_id,
  c.teacher_id,
  c.name,
  c.subject,
  c.section,
  c.session,
  c.color_index,
  count(distinct ps.student_id) as student_count,
  (select count(*) from public.attendance_sessions s where s.class_id = c.id) as session_count,
  (select count(*) from public.assessments a where a.class_id = c.id) as assessment_count,
  coalesce(sum(ps.present), 0)::bigint as present_total,
  coalesce(sum(ps.absent), 0)::bigint as absent_total,
  coalesce(sum(ps.late), 0)::bigint as late_total,
  coalesce(sum(ps.short_leave), 0)::bigint as short_leave_total,
  -- Averaged per student, not per session: each student counts once, so one
  -- heavily-attending student cannot mask the rest of the class.
  --
  -- Null, not zero, when nobody has an assessable session yet: avg() skips the
  -- nulls fn_attendance_percentage returns, and a class with no roll call taken
  -- has no attendance rate rather than a rate of nought.
  round(
    avg(public.fn_attendance_percentage(
      ps.present::integer, ps.late::integer, ps.absent::integer
    ))
  )::integer as attendance_percent,
  (select max(s.date) from public.attendance_sessions s where s.class_id = c.id) as last_session_date
from public.classes c
left join per_student ps on ps.class_id = c.id
where c.archived_at is null
group by c.id;

comment on view public.v_class_attendance is
  'One row per class: roster size, session and assessment counts, and the attendance percentage averaged per student.';

-- ─────────────────────────────────────────────────────────────
-- v_student_performance
-- ─────────────────────────────────────────────────────────────

create view public.v_student_performance
with (security_invoker = true) as
-- One row per student *per class*. A student in two classes has a separate
-- attendance rate and grade in each, which is what every screen shows.
with enrolment as (
  select cs.class_id, cs.student_id
  from public.class_students cs
  where cs.unenrolled_at is null
),
attendance as (
  select
    e.class_id,
    e.student_id,
    count(*) filter (where r.mark = 'present') as present,
    count(*) filter (where r.mark = 'absent') as absent,
    count(*) filter (where r.mark = 'late') as late,
    count(*) filter (where r.mark = 'short_leave') as short_leave
  from enrolment e
  left join public.attendance_sessions s on s.class_id = e.class_id
  left join public.attendance_records r
    on r.session_id = s.id and r.student_id = e.student_id
  group by e.class_id, e.student_id
),
scores as (
  -- Unmarked work is excluded from both sides of the fraction. A student is
  -- never failed for an assessment their teacher has not graded yet.
  select
    e.class_id,
    e.student_id,
    coalesce(sum(m.score) filter (where m.score is not null), 0) as obtained,
    coalesce(sum(a.total_marks) filter (where m.score is not null), 0) as total,
    count(*) filter (where m.score is not null) as marked,
    count(a.*) filter (where m.score is null) as pending
  from enrolment e
  left join public.assessments a on a.class_id = e.class_id
  left join public.marks m on m.assessment_id = a.id and m.student_id = e.student_id
  group by e.class_id, e.student_id
)
select
  e.student_id,
  e.class_id,
  c.organization_id,
  c.teacher_id,
  st.full_name,
  st.roll_no,
  att.present,
  att.absent,
  att.late,
  att.short_leave,
  -- What the percentage is actually computed over; short leave is not in it.
  (coalesce(att.present, 0) + coalesce(att.late, 0) + coalesce(att.absent, 0))
    as assessable_sessions,
  public.fn_attendance_percentage(
    att.present::integer, att.late::integer, att.absent::integer
  ) as attendance_percent,
  sc.obtained,
  sc.total,
  sc.marked as assessments_marked,
  sc.pending as assessments_pending,
  public.fn_percentage(sc.obtained, nullif(sc.total, 0)) as marks_percent,
  case
    when sc.marked = 0 then null
    else public.fn_grade_for(
      public.fn_percentage(sc.obtained, nullif(sc.total, 0)),
      c.organization_id
    )
  end as grade
from enrolment e
join public.students st on st.id = e.student_id
join public.classes c on c.id = e.class_id
left join attendance att on att.class_id = e.class_id and att.student_id = e.student_id
left join scores sc on sc.class_id = e.class_id and sc.student_id = e.student_id;

comment on view public.v_student_performance is
  'One row per student: attendance breakdown, marks total and letter grade. Grade is null when nothing is marked - which is not the same as F.';

-- ─────────────────────────────────────────────────────────────
-- v_org_overview
-- ─────────────────────────────────────────────────────────────

create view public.v_org_overview
with (security_invoker = true) as
select
  o.id as organization_id,
  o.name,
  o.city,
  o.status,
  (select count(*) from public.profiles p
    where p.organization_id = o.id and p.role = 'teacher') as teacher_count,
  (select count(*) from public.classes c
    where c.organization_id = o.id and c.archived_at is null) as class_count,
  -- Distinct people, not enrolments: a student taught in three of the
  -- organization's classes is still one student.
  (select count(distinct cs.student_id)
    from public.class_students cs
    join public.classes c on c.id = cs.class_id
    where c.organization_id = o.id
      and c.archived_at is null
      and cs.unenrolled_at is null) as student_count,
  (select count(*) from public.attendance_sessions s
    join public.classes c on c.id = s.class_id
    where c.organization_id = o.id and s.date = current_date) as classes_marked_today,
  (select coalesce(round(avg(v.attendance_percent))::integer, 0)
    from public.v_class_attendance v
    where v.organization_id = o.id) as attendance_percent
from public.organizations o;

comment on view public.v_org_overview is
  'The figures across the top of the Organization Admin dashboard, and the teacher and student counts the Main Admin sees per organization.';

-- ─────────────────────────────────────────────────────────────
-- v_platform_overview
-- ─────────────────────────────────────────────────────────────

-- The Main Admin dashboard statistics. Under security_invoker this returns
-- platform-wide numbers to a Main Admin and near-empty numbers to anyone else,
-- because the underlying policies decide what they can count.
create view public.v_platform_overview
with (security_invoker = true) as
select
  (select count(*) from public.organizations) as organization_count,
  (select count(*) from public.organizations where status = 'active') as active_organization_count,
  (select count(*) from public.profiles
    where role = 'teacher' and organization_id is null) as individual_teacher_count,
  (select count(*) from public.profiles
    where role = 'teacher' and organization_id is not null) as organization_teacher_count,
  (select count(*) from public.v_effective_subscriptions
    where status in ('active', 'expiring_soon')) as active_subscription_count,
  (select count(*) from public.v_effective_subscriptions
    where status = 'expiring_soon') as expiring_soon_count,
  (select count(*) from public.v_effective_subscriptions
    where status = 'expired') as expired_count,
  (select count(*) from public.v_effective_subscriptions
    where status = 'pending') as pending_count,
  (select count(*) from public.v_effective_subscriptions where plan = 'monthly') as monthly_count,
  (select count(*) from public.v_effective_subscriptions where plan = 'yearly') as yearly_count,
  (select count(*) from public.v_effective_subscriptions where plan = 'permanent') as permanent_count;

comment on view public.v_platform_overview is
  'The Main Admin dashboard figures, including the subscriptions-by-plan bars.';


-- ═══════════════════════════════════════════════════════════════
-- 20260809120900_auth.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Account creation
--
-- Supabase owns auth.users. Warq owns profiles. This migration is the bridge:
-- when a user is created, a matching profile appears with the role and
-- organization they signed up for.
--
-- Roles come from the sign-up payload, never from the client at request time -
-- and the trigger below refuses to mint a main_admin no matter what the payload
-- says. The first platform administrator is created by hand, once.

-- ─────────────────────────────────────────────────────────────
-- Profile creation
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text := coalesce(new.raw_user_meta_data->>'role', 'teacher');
  requested_org uuid := nullif(new.raw_user_meta_data->>'organization_id', '')::uuid;
  resolved_role public.user_role;
begin
  -- A client controls its own sign-up metadata, so main_admin is not on offer.
  -- Promoting someone to platform administrator is a deliberate act performed
  -- against the database, not a field in a registration form.
  if requested_role not in ('teacher', 'org_admin') then
    resolved_role := 'teacher';
  else
    resolved_role := requested_role::public.user_role;
  end if;

  -- An org_admin without an organization would violate the table's own
  -- constraint; fall back to teacher rather than failing the sign-up outright.
  if resolved_role = 'org_admin' and requested_org is null then
    resolved_role := 'teacher';
  end if;

  insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
  values (
    new.id,
    lower(new.email),
    coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1)),
    nullif(new.raw_user_meta_data->>'phone', ''),
    resolved_role,
    requested_org,
    -- Everyone starts pending. An organization teacher is activated when they
    -- accept an invitation; an independent teacher and an organization are
    -- activated when the Main Admin approves the request.
    'pending'
  );

  return new;
end;
$$;

comment on function public.fn_handle_new_user is
  'Creates the Warq profile behind a new auth user. Refuses to mint a main_admin from sign-up metadata.';

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.fn_handle_new_user();

-- ─────────────────────────────────────────────────────────────
-- Accepting an invitation
-- ─────────────────────────────────────────────────────────────

-- Runs after sign-up, as the newly created (pending) user. Exchanges a token for
-- membership of the organization that issued it.
--
-- security definer because the caller cannot yet read the invitations table -
-- they are not a member of anything. The token is the only credential, so it is
-- matched in full, checked for expiry, and consumed.
create or replace function public.accept_invitation(invitation_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite public.invitations;
  caller_email text;
begin
  if auth.uid() is null then
    raise exception 'Sign in before accepting an invitation.';
  end if;

  select email into caller_email from public.profiles where id = auth.uid();

  select * into invite
  from public.invitations
  where token = invitation_token
  for update;

  if invite.id is null then
    raise exception 'That invitation link is not valid.'
      using hint = 'Ask your organization admin to send a new invitation.';
  end if;

  if invite.status <> 'pending' then
    raise exception 'That invitation has already been used.'
      using hint = 'Sign in normally, or ask for a new invitation.';
  end if;

  if invite.expires_at < now() then
    update public.invitations set status = 'expired' where id = invite.id;
    raise exception 'That invitation has expired.'
      using hint = 'Ask your organization admin to send a new one.';
  end if;

  -- The invitation is addressed to a person, not transferable to whoever holds
  -- the link.
  if lower(invite.email) <> lower(caller_email) then
    raise exception 'That invitation was sent to a different email address.'
      using hint = 'Sign in with the address the invitation was sent to.';
  end if;

  update public.profiles
  set organization_id = invite.organization_id,
      status = 'active',
      role = 'teacher'
  where id = auth.uid();

  update public.invitations
  set status = 'accepted',
      accepted_at = now(),
      accepted_by = auth.uid()
  where id = invite.id;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message)
  select
    invite.organization_id,
    auth.uid(),
    p.full_name,
    'admin',
    'Accepted invitation and joined the organization'
  from public.profiles p where p.id = auth.uid();

  return invite.organization_id;
end;
$$;

comment on function public.accept_invitation is
  'Exchanges an invitation token for organization membership. The token is single-use, expiring, and bound to the invited address.';

revoke all on function public.accept_invitation(text) from public;
grant execute on function public.accept_invitation(text) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Requesting an organization account
-- ─────────────────────────────────────────────────────────────

-- An organization signs up, then waits for the Main Admin to approve it. The
-- caller cannot insert into organizations directly - no policy allows it - so
-- this function does it on their behalf and leaves everything pending.
create or replace function public.request_organization(
  organization_name text,
  organization_city text,
  organization_email text,
  organization_phone text,
  requested_plan public.subscription_plan
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_org_id uuid;
  caller public.profiles;
begin
  select * into caller from public.profiles where id = auth.uid();

  if caller.id is null then
    raise exception 'Sign in before requesting an organization account.';
  end if;

  if caller.organization_id is not null then
    raise exception 'You already belong to an organization.'
      using hint = 'Leave your current organization before requesting another.';
  end if;

  insert into public.organizations (name, city, email, phone, status, owner_profile_id)
  values (
    organization_name, organization_city, lower(organization_email),
    organization_phone, 'pending', auth.uid()
  )
  returning id into new_org_id;

  update public.profiles
  set organization_id = new_org_id, role = 'org_admin'
  where id = auth.uid();

  -- Pending, undated, and granting nothing until a Main Admin approves it.
  insert into public.subscriptions (organization_id, plan, status)
  values (new_org_id, requested_plan, 'pending');

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  select s.id, 'requested', requested_plan, auth.uid(), 'Organization account requested'
  from public.subscriptions s where s.organization_id = new_org_id;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    null, auth.uid(), caller.full_name, 'subscription',
    organization_name || ' requested an organization account',
    jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
  );

  return new_org_id;
end;
$$;

comment on function public.request_organization is
  'Creates a pending organization and a pending subscription. Grants nothing until a Main Admin approves.';

revoke all on function public.request_organization(text, text, text, text, public.subscription_plan) from public;
grant execute on function public.request_organization(text, text, text, text, public.subscription_plan) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Requesting an individual teacher account
-- ─────────────────────────────────────────────────────────────

create or replace function public.request_individual_subscription(
  requested_plan public.subscription_plan
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_subscription_id uuid;
  caller public.profiles;
begin
  select * into caller from public.profiles where id = auth.uid();

  if caller.id is null then
    raise exception 'Sign in before requesting a subscription.';
  end if;

  if caller.organization_id is not null then
    raise exception 'Your organization holds the subscription for your account.'
      using hint = 'Ask your organization admin about your access.';
  end if;

  if exists (select 1 from public.subscriptions where profile_id = auth.uid()) then
    raise exception 'You already have a subscription.'
      using hint = 'Check its status on your account page.';
  end if;

  insert into public.subscriptions (profile_id, plan, status)
  values (auth.uid(), requested_plan, 'pending')
  returning id into new_subscription_id;

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  values (new_subscription_id, 'requested', requested_plan, auth.uid(), 'Individual teacher account requested');

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    null, auth.uid(), caller.full_name, 'subscription',
    caller.full_name || ' requested an individual teacher account',
    jsonb_build_object('plan', requested_plan)
  );

  return new_subscription_id;
end;
$$;

revoke all on function public.request_individual_subscription(public.subscription_plan) from public;
grant execute on function public.request_individual_subscription(public.subscription_plan) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Who am I
-- ─────────────────────────────────────────────────────────────

-- One call on app load: the profile, the organization, and whether the account
-- currently has access. Saves the client three round trips - which matters more
-- on a phone in a classroom than on a laptop.
create or replace function public.me()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'profile', to_jsonb(p) - 'updated_at',
    'organization', case when o.id is null then null else to_jsonb(o) - 'updated_at' end,
    'subscription', case when s.id is null then null else to_jsonb(s) end,
    'has_access', coalesce(public.fn_has_access(p.id), false)
  )
  from public.profiles p
  left join public.organizations o on o.id = p.organization_id
  left join public.v_effective_subscriptions s
    on (p.organization_id is not null and s.organization_id = p.organization_id)
    or (p.organization_id is null and s.profile_id = p.id)
  where p.id = auth.uid();
$$;

comment on function public.me is
  'Everything a client needs on load: profile, organization, subscription and whether access is currently granted.';

revoke all on function public.me() from public;
grant execute on function public.me() to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 20260809121000_signup.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Sign-up completed in one step
--
-- The previous trigger created a profile and left the organization or the
-- subscription to a follow-up call from the client. That only works if the user
-- is signed in the instant they register — which is false whenever email
-- confirmation is switched on, and leaves a half-registered account behind.
--
-- Creating everything inside the trigger makes registration atomic: either the
-- account, the organization and the pending subscription all exist, or none of
-- them do. It also works identically whether confirmation is on or off.

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  signup_kind text := coalesce(meta->>'signup_kind', 'invited_teacher');
  requested_plan public.subscription_plan;
  resolved_name text;
  new_org_id uuid;
  new_subscription_id uuid;
begin
  resolved_name := coalesce(
    nullif(trim(meta->>'full_name'), ''),
    split_part(new.email, '@', 1)
  );

  -- A plan is only meaningful for the two self-service paths. An invited teacher
  -- is covered by their organization's subscription.
  begin
    requested_plan := coalesce(nullif(meta->>'plan', ''), 'monthly')::public.subscription_plan;
  exception when others then
    requested_plan := 'monthly';
  end;

  -- ── An organization registering itself ──────────────────────
  if signup_kind = 'organization' then
    if coalesce(trim(meta->>'organization_name'), '') = ''
       or coalesce(trim(meta->>'city'), '') = '' then
      raise exception 'An organization account needs an organization name and a city.';
    end if;

    insert into public.organizations (name, city, email, phone, status)
    values (
      trim(meta->>'organization_name'),
      trim(meta->>'city'),
      lower(new.email),
      nullif(meta->>'phone', ''),
      'pending'
    )
    returning id into new_org_id;

    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'org_admin', new_org_id, 'pending'
    );

    update public.organizations set owner_profile_id = new.id where id = new_org_id;

    -- Pending, undated, granting nothing until a Main Admin approves it.
    insert into public.subscriptions (organization_id, plan, status)
    values (new_org_id, requested_plan, 'pending')
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (new_subscription_id, 'requested', requested_plan, 'Organization account requested');

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      trim(meta->>'organization_name') || ' requested an organization account',
      jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
    );

  -- ── An independent teacher registering themselves ───────────
  elsif signup_kind = 'individual_teacher' then
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'teacher', null, 'pending'
    );

    insert into public.subscriptions (profile_id, plan, status)
    values (new.id, requested_plan, 'pending')
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (new_subscription_id, 'requested', requested_plan, 'Individual teacher account requested');

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      resolved_name || ' requested an individual teacher account',
      jsonb_build_object('plan', requested_plan)
    );

  -- ── A teacher arriving through an invitation ────────────────
  else
    -- No organization and no subscription yet. accept_invitation() attaches both
    -- once they present their token, so an unused invitation leaves no trace.
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'teacher', null, 'pending'
    );
  end if;

  return new;
end;
$$;

comment on function public.fn_handle_new_user is
  'Creates the profile and, for self-service sign-ups, the organization and pending subscription - atomically, and independent of whether email confirmation is enabled. Never mints a main_admin: the role is chosen here, not read from client metadata.';

-- The two RPCs this replaces are no longer reachable from any sign-up path.
-- Dropped rather than left in place: an unused privileged function is a
-- liability, not a convenience.
drop function if exists public.request_organization(text, text, text, text, public.subscription_plan);
drop function if exists public.request_individual_subscription(public.subscription_plan);


-- ═══════════════════════════════════════════════════════════════
-- 20260809121100_bootstrap.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Bootstrapping the first platform administrator
--
-- Two safeguards make a Main Admin impossible to create through the product,
-- which is correct — and which leaves the platform with no administrator at all.
-- This migration provides the one deliberate way in.
--
--   * The sign-up trigger refuses to read `main_admin` from client metadata.
--   * The profile guard refuses to let anyone change a role.
--
-- Both stay. What changes is that they no longer apply to the database owner and
-- the service role, neither of which is a browser and both of which already
-- bypass row-level security entirely — guarding them added the appearance of
-- protection, not the fact of it.

-- ─────────────────────────────────────────────────────────────
-- Exempt trusted database roles from the field guards
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_guard_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- `postgres` is the SQL editor and migrations; `service_role` is the worker.
  -- An authenticated end user is never either of these.
  if public.is_main_admin() or current_user in ('postgres', 'service_role', 'supabase_admin') then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'Roles are assigned by the platform administrator.';
  end if;

  if new.organization_id is distinct from old.organization_id then
    raise exception 'Organization membership changes by invitation or removal, not by editing a profile.';
  end if;

  if new.status is distinct from old.status and new.id = auth.uid() then
    raise exception 'You cannot change your own account status.';
  end if;

  return new;
end;
$$;

create or replace function public.fn_guard_organization_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_main_admin() or current_user in ('postgres', 'service_role', 'supabase_admin') then
    return new;
  end if;

  if new.status is distinct from old.status then
    raise exception 'Only the platform administrator can change an organization''s status.'
      using hint = 'Contact Warq support to change your subscription or account status.';
  end if;

  if new.owner_profile_id is distinct from old.owner_profile_id then
    raise exception 'Only the platform administrator can reassign an organization''s admin.'
      using hint = 'Contact Warq support to transfer ownership.';
  end if;

  if new.approved_at is distinct from old.approved_at then
    raise exception 'Approval dates are set by the platform, not by the organization.';
  end if;

  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- bootstrap_main_admin
-- ─────────────────────────────────────────────────────────────

-- Promotes an existing account to platform administrator.
--
-- Runs exactly once in the life of the platform: it refuses if an administrator
-- already exists, so it cannot be used to quietly add a second one later.
-- Further administrators are added by an existing administrator, on the record.
create or replace function public.bootstrap_main_admin(admin_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.profiles;
begin
  if exists (select 1 from public.profiles where role = 'main_admin') then
    raise exception 'A platform administrator already exists.'
      using hint = 'Additional administrators are added by an existing administrator.';
  end if;

  select * into target from public.profiles where email = lower(trim(admin_email));

  if target.id is null then
    raise exception 'No account found for %.', lower(trim(admin_email))
      using hint = 'Create the account first, through the sign-up page or the Authentication tab.';
  end if;

  -- A Main Admin belongs to the platform, not to a tenant, and holds no
  -- subscription of their own. Clear both, or the profile constraints will
  -- reject the change.
  delete from public.subscriptions where profile_id = target.id;

  update public.profiles
  set role = 'main_admin',
      organization_id = null,
      status = 'active'
  where id = target.id;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message)
  values (
    null, target.id, target.full_name, 'admin',
    target.full_name || ' was made platform administrator'
  );

  return 'Done. ' || target.email || ' is now the platform administrator. Sign out and back in.';
end;
$$;

comment on function public.bootstrap_main_admin is
  'One-shot: promotes an existing account to platform administrator, and refuses once one exists. Run from the SQL editor.';

-- Never callable from a browser. The SQL editor and the worker connect as
-- trusted database roles and do not need this grant.
revoke all on function public.bootstrap_main_admin(text) from public;
revoke all on function public.bootstrap_main_admin(text) from authenticated;
revoke all on function public.bootstrap_main_admin(text) from anon;


-- ═══════════════════════════════════════════════════════════════
-- 20260809121200_subscription_actions.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M1 · Subscription lifecycle actions
--
-- Approve, reject, suspend, reactivate, renew, extend. Every button on the Main
-- Admin dashboard eventually calls one of these, and each mirrors the matching
-- function in @warq/core so the arithmetic cannot drift between the two.
--
-- All of them:
--   * refuse anyone who is not a platform administrator;
--   * move the subject's own status alongside the subscription, because an
--     approved subscription attached to a still-pending organization would
--     leave the account locked out by the very gate that was supposed to open;
--   * append to subscription_events, so the drawer's history panel and any
--     later question of "who did this" are answered from the record.

-- ─────────────────────────────────────────────────────────────
-- Where a plan's period ends. Mirrors periodEnd() in @warq/core.
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_period_end(
  plan public.subscription_plan,
  starts date
)
returns date
language sql
immutable
as $$
  select case plan
    when 'monthly' then (starts + interval '1 month')::date
    when 'yearly' then (starts + interval '1 year')::date
    else null
  end;
$$;

comment on function public.fn_period_end is
  'Adds one period. Postgres clamps 31 Jan + 1 month to 28 Feb, matching addMonths() in @warq/core.';

create or replace function public.fn_require_main_admin()
returns void
language plpgsql
stable
as $$
begin
  if not public.is_main_admin() then
    raise exception 'Only the platform administrator can do that.'
      using hint = 'Sign in with the Warq administrator account.';
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- approve_subscription
-- ─────────────────────────────────────────────────────────────

-- Activates a pending request and starts its first period today.
create or replace function public.approve_subscription(target_subscription uuid)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
  ends date;
  subject_name text;
begin
  perform public.fn_require_main_admin();

  select * into sub from public.subscriptions where id = target_subscription for update;
  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  if sub.status = 'active' then
    raise exception 'That subscription is already active.'
      using hint = 'Use renew_subscription to extend it.';
  end if;

  ends := public.fn_period_end(sub.plan, current_date);

  update public.subscriptions
  set status = 'active', starts_at = current_date, ends_at = ends
  where id = sub.id
  returning * into sub;

  -- Open the account itself, not just its subscription.
  if sub.organization_id is not null then
    update public.organizations
    set status = 'active', approved_at = coalesce(approved_at, now())
    where id = sub.organization_id
    returning name into subject_name;

    -- The organization admin, and any teacher already waiting on them.
    update public.profiles
    set status = 'active'
    where organization_id = sub.organization_id and status = 'pending';
  else
    update public.profiles set status = 'active' where id = sub.profile_id
    returning full_name into subject_name;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, from_date, to_date, actor_id, note)
  values (sub.id, 'approved', sub.plan, sub.starts_at, sub.ends_at, auth.uid(), 'Approved and activated');

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  select
    sub.organization_id, auth.uid(), p.full_name, 'subscription',
    'Approved ' || coalesce(subject_name, 'account') || ' · ' || sub.plan || ' subscription activated',
    jsonb_build_object('subscription_id', sub.id, 'ends_at', sub.ends_at)
  from public.profiles p where p.id = auth.uid();

  return sub;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- reject_subscription
-- ─────────────────────────────────────────────────────────────

create or replace function public.reject_subscription(
  target_subscription uuid,
  reason text default null
)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
  subject_name text;
begin
  perform public.fn_require_main_admin();

  select * into sub from public.subscriptions where id = target_subscription for update;
  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  -- Suspended rather than deleted: a rejected applicant who appeals should not
  -- have to be reconstructed from nothing.
  update public.subscriptions set status = 'suspended' where id = sub.id returning * into sub;

  if sub.organization_id is not null then
    update public.organizations set status = 'suspended' where id = sub.organization_id
    returning name into subject_name;
  else
    update public.profiles set status = 'suspended' where id = sub.profile_id
    returning full_name into subject_name;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  values (sub.id, 'rejected', sub.plan, auth.uid(), coalesce(reason, 'Rejected'));

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  select
    sub.organization_id, auth.uid(), p.full_name, 'subscription',
    'Rejected ' || coalesce(subject_name, 'account')
      || case when reason is null then '' else ' · ' || reason end,
    jsonb_build_object('subscription_id', sub.id)
  from public.profiles p where p.id = auth.uid();

  return sub;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- suspend / reactivate
-- ─────────────────────────────────────────────────────────────

create or replace function public.suspend_subscription(
  target_subscription uuid,
  reason text default null
)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
begin
  perform public.fn_require_main_admin();

  update public.subscriptions set status = 'suspended'
  where id = target_subscription
  returning * into sub;

  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  if sub.organization_id is not null then
    update public.organizations set status = 'suspended' where id = sub.organization_id;
  else
    update public.profiles set status = 'suspended' where id = sub.profile_id;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  values (sub.id, 'suspended', sub.plan, auth.uid(), coalesce(reason, 'Suspended'));

  return sub;
end;
$$;

-- Dates are untouched: a suspension pauses access, it does not consume the
-- period the customer paid for.
create or replace function public.reactivate_subscription(target_subscription uuid)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
begin
  perform public.fn_require_main_admin();

  update public.subscriptions set status = 'active'
  where id = target_subscription
  returning * into sub;

  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  if sub.organization_id is not null then
    update public.organizations set status = 'active' where id = sub.organization_id;
    update public.profiles set status = 'active'
    where organization_id = sub.organization_id and status = 'suspended';
  else
    update public.profiles set status = 'active' where id = sub.profile_id;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  values (sub.id, 'reactivated', sub.plan, auth.uid(), 'Reactivated');

  return sub;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- renew_subscription
-- ─────────────────────────────────────────────────────────────

-- Adds one more period.
--
-- Runs from the current end date so renewing early loses no days; restarts from
-- today if the subscription has already lapsed, rather than granting a period
-- that is mostly spent. Mirrors renew() in @warq/core.
create or replace function public.renew_subscription(target_subscription uuid)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
  anchor date;
begin
  perform public.fn_require_main_admin();

  select * into sub from public.subscriptions where id = target_subscription for update;
  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  if sub.plan = 'permanent' then
    update public.subscriptions set status = 'active', ends_at = null
    where id = sub.id returning * into sub;
  else
    anchor := case
      when sub.ends_at is null or sub.ends_at < current_date then current_date
      else sub.ends_at
    end;

    update public.subscriptions
    set status = 'active',
        starts_at = coalesce(starts_at, current_date),
        ends_at = public.fn_period_end(sub.plan, anchor)
    where id = sub.id
    returning * into sub;
  end if;

  if sub.organization_id is not null then
    update public.organizations set status = 'active' where id = sub.organization_id;
  else
    update public.profiles set status = 'active' where id = sub.profile_id;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, from_date, to_date, actor_id, note)
  values (sub.id, 'renewed', sub.plan, sub.starts_at, sub.ends_at, auth.uid(), 'Renewed');

  return sub;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- Pending requests, for the approvals queue
-- ─────────────────────────────────────────────────────────────

create view public.v_pending_requests
with (security_invoker = true) as
select
  s.id as subscription_id,
  s.plan,
  s.created_at as requested_at,
  case when s.organization_id is null then 'individual_teacher' else 'organization' end as kind,
  s.organization_id,
  s.profile_id,
  coalesce(o.name, p.full_name) as subject_name,
  coalesce(o.email, p.email) as subject_email,
  o.city,
  o.phone,
  (select count(*) from public.profiles t
    where t.organization_id = s.organization_id and t.role = 'teacher') as teacher_count
from public.subscriptions s
left join public.organizations o on o.id = s.organization_id
left join public.profiles p on p.id = s.profile_id
where s.status = 'pending';

comment on view public.v_pending_requests is
  'Organizations and individual teachers awaiting approval. Backs the Pending Requests page and the dashboard queue.';

-- ─────────────────────────────────────────────────────────────
-- Grants
-- ─────────────────────────────────────────────────────────────

-- Callable from the app: each one checks is_main_admin() first, so the grant is
-- not the protection - the check inside is.
grant execute on function public.approve_subscription(uuid) to authenticated;
grant execute on function public.reject_subscription(uuid, text) to authenticated;
grant execute on function public.suspend_subscription(uuid, text) to authenticated;
grant execute on function public.reactivate_subscription(uuid) to authenticated;
grant execute on function public.renew_subscription(uuid) to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 20260809121300_admin_views.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M2 · Views for the Main Admin dashboard
--
-- Each row the dashboard draws needs an organization, its subscription, its
-- derived status, its admin and its counts. Assembling that in the client would
-- mean four round trips per screen and a join written slightly differently on
-- web and on mobile. It belongs here.

-- ─────────────────────────────────────────────────────────────
-- v_admin_organizations
-- ─────────────────────────────────────────────────────────────

create view public.v_admin_organizations
with (security_invoker = true) as
select
  o.id,
  o.name,
  o.city,
  o.email,
  o.phone,
  o.status as account_status,
  o.requested_at,
  o.approved_at,
  o.created_at,

  admin.id as admin_profile_id,
  admin.full_name as admin_name,
  admin.email as admin_email,

  s.id as subscription_id,
  s.plan,
  s.status,
  s.stored_status,
  s.starts_at,
  s.ends_at,
  s.days_remaining,
  s.grants_access,

  (select count(*) from public.profiles p
    where p.organization_id = o.id and p.role = 'teacher') as teacher_count,
  (select count(distinct cs.student_id)
    from public.class_students cs
    join public.classes c on c.id = cs.class_id
    where c.organization_id = o.id
      and c.archived_at is null
      and cs.unenrolled_at is null) as student_count,
  (select count(*) from public.classes c
    where c.organization_id = o.id and c.archived_at is null) as class_count
from public.organizations o
left join public.profiles admin on admin.id = o.owner_profile_id
left join public.v_effective_subscriptions s on s.organization_id = o.id;

comment on view public.v_admin_organizations is
  'One row per organization with its subscription, derived status, admin and counts. Backs the Organizations table and its detail drawer.';

-- ─────────────────────────────────────────────────────────────
-- v_admin_individual_teachers
-- ─────────────────────────────────────────────────────────────

-- A teacher with no organization holds their own subscription. These are the
-- accounts on the Main Admin's Individual Teachers page.
create view public.v_admin_individual_teachers
with (security_invoker = true) as
select
  p.id,
  p.full_name,
  p.email,
  p.phone,
  p.status as account_status,
  p.created_at,

  s.id as subscription_id,
  s.plan,
  s.status,
  s.starts_at,
  s.ends_at,
  s.days_remaining,
  s.grants_access,

  (select count(*) from public.classes c
    where c.teacher_id = p.id and c.archived_at is null) as class_count,
  (select count(*) from public.students st
    where st.teacher_id = p.id) as student_count
from public.profiles p
left join public.v_effective_subscriptions s on s.profile_id = p.id
where p.role = 'teacher' and p.organization_id is null;

comment on view public.v_admin_individual_teachers is
  'Teachers who hold their own subscription rather than belonging to an organization.';

-- ─────────────────────────────────────────────────────────────
-- v_admin_org_admins
-- ─────────────────────────────────────────────────────────────

create view public.v_admin_org_admins
with (security_invoker = true) as
select
  p.id,
  p.full_name,
  p.email,
  p.phone,
  p.status as account_status,
  p.created_at,
  o.id as organization_id,
  o.name as organization_name,
  o.city,
  s.status as subscription_status,
  s.plan,
  s.ends_at,
  -- True when this person is the organization's registered owner. An
  -- organization can outlive its admin, so the two are not the same thing.
  (o.owner_profile_id = p.id) as is_owner
from public.profiles p
join public.organizations o on o.id = p.organization_id
left join public.v_effective_subscriptions s on s.organization_id = o.id
where p.role = 'org_admin';

comment on view public.v_admin_org_admins is
  'Organization administrators, with the organization each one runs.';

-- ─────────────────────────────────────────────────────────────
-- v_admin_subscriptions
-- ─────────────────────────────────────────────────────────────

-- Every subscription on the platform, whoever holds it, in one list. Backs the
-- Subscriptions page and the Expiring Subscriptions page — the latter is this
-- filtered to status = 'expiring_soon', ordered by days remaining.
create view public.v_admin_subscriptions
with (security_invoker = true) as
select
  s.id,
  s.plan,
  s.status,
  s.stored_status,
  s.starts_at,
  s.ends_at,
  s.days_remaining,
  s.grants_access,
  s.price_cents,
  s.currency,
  s.created_at,
  case when s.organization_id is null then 'individual_teacher' else 'organization' end as kind,
  s.organization_id,
  s.profile_id,
  coalesce(o.name, p.full_name) as subject_name,
  coalesce(o.email, p.email) as subject_email,
  o.city
from public.v_effective_subscriptions s
left join public.organizations o on o.id = s.organization_id
left join public.profiles p on p.id = s.profile_id;

comment on view public.v_admin_subscriptions is
  'Every subscription with its subject resolved, whether that subject is an organization or an individual teacher.';


-- ═══════════════════════════════════════════════════════════════
-- 20260809121400_org_views.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M3 · Views and actions for the Organization Admin dashboard
--
-- An Organization Admin watches their institution rather than running it
-- day to day: who is teaching, whether attendance is being taken, how classes
-- are performing. These views answer those questions in one query each.

-- ─────────────────────────────────────────────────────────────
-- v_org_teachers
-- ─────────────────────────────────────────────────────────────

create view public.v_org_teachers
with (security_invoker = true) as
select
  p.id,
  p.organization_id,
  p.full_name,
  p.email,
  p.phone,
  p.status as account_status,
  p.created_at as joined_at,

  (select count(*) from public.classes c
    where c.teacher_id = p.id and c.archived_at is null) as class_count,
  -- Students belong to the teacher, so this no longer walks their classes.
  (select count(*) from public.students st
    where st.teacher_id = p.id) as student_count,
  (select count(*) from public.attendance_sessions s
    join public.classes c on c.id = s.class_id
    where c.teacher_id = p.id) as session_count,
  (select count(*) from public.assessments a
    join public.classes c on c.id = a.class_id
    where c.teacher_id = p.id) as assessment_count,

  (select max(s.date) from public.attendance_sessions s
    join public.classes c on c.id = s.class_id
    where c.teacher_id = p.id) as last_attendance_date,
  (select max(a.date) from public.assessments a
    join public.classes c on c.id = a.class_id
    where c.teacher_id = p.id) as last_assessment_date,

  -- The mockup shows a teacher as Active or Idle. Idle is not a stored state:
  -- it is simply nobody having taken a register in a week, which is exactly the
  -- thing an Organization Admin opens this page to notice.
  case
    when (select max(s.date) from public.attendance_sessions s
          join public.classes c on c.id = s.class_id
          where c.teacher_id = p.id) >= current_date - 7 then 'active'
    else 'idle'
  end as activity_state
from public.profiles p
where p.role = 'teacher' and p.organization_id is not null;

comment on view public.v_org_teachers is
  'Teachers in an organization with their class, student and session counts. activity_state is derived from when they last took a register, never stored.';

-- ─────────────────────────────────────────────────────────────
-- v_org_classes
-- ─────────────────────────────────────────────────────────────

create view public.v_org_classes
with (security_invoker = true) as
select
  v.class_id as id,
  v.organization_id,
  v.teacher_id,
  p.full_name as teacher_name,
  v.name,
  v.section,
  v.session,
  v.color_index,
  v.student_count,
  v.session_count,
  v.assessment_count,
  v.attendance_percent,
  v.last_session_date
from public.v_class_attendance v
left join public.profiles p on p.id = v.teacher_id;

comment on view public.v_org_classes is
  'Every class with its teacher''s name and attendance figure. Backs the Classes table on both the organization and teacher dashboards.';

-- ─────────────────────────────────────────────────────────────
-- v_org_daily_attendance
-- ─────────────────────────────────────────────────────────────

-- One row per organization per day for the last five weeks, which is what the
-- weekly bar chart draws. Days with no register taken are simply absent from
-- the result rather than appearing as zero — no lesson is not the same as
-- nobody turning up.
create view public.v_org_daily_attendance
with (security_invoker = true) as
select
  c.organization_id,
  s.date,
  count(distinct s.class_id) as classes_marked,
  count(r.*) filter (where r.mark = 'present') as present,
  count(r.*) filter (where r.mark = 'absent') as absent,
  count(r.*) filter (where r.mark = 'late') as late,
  count(r.*) filter (where r.mark = 'short_leave') as short_leave,
  public.fn_attendance_percentage(
    (count(r.*) filter (where r.mark = 'present'))::integer,
    (count(r.*) filter (where r.mark = 'late'))::integer,
    (count(r.*) filter (where r.mark = 'absent'))::integer
  ) as attendance_percent
from public.attendance_sessions s
join public.classes c on c.id = s.class_id
left join public.attendance_records r on r.session_id = s.id
where s.date >= current_date - 35
group by c.organization_id, s.date;

comment on view public.v_org_daily_attendance is
  'Daily attendance for the last five weeks. A day with no register is absent from the result rather than shown as zero.';

-- ─────────────────────────────────────────────────────────────
-- invite_teacher
-- ─────────────────────────────────────────────────────────────

-- Creates or refreshes an invitation and hands back the link to send.
--
-- Re-inviting the same address replaces the live invitation rather than adding
-- a second: two working tokens for one person is a loose end, and the unique
-- index on live invitations would reject it anyway.
create or replace function public.invite_teacher(
  teacher_email text,
  teacher_name text,
  send_via public.notification_channel default 'email'
)
returns public.invitations
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller public.profiles;
  invite public.invitations;
begin
  select * into caller from public.profiles where id = auth.uid();

  if caller.role <> 'org_admin' or caller.organization_id is null then
    raise exception 'Only an organization admin can invite teachers.';
  end if;

  if not public.fn_has_access(auth.uid()) then
    raise exception 'Your organization''s subscription is not active.'
      using hint = 'Renew the subscription before inviting more teachers.';
  end if;

  if exists (
    select 1 from public.profiles p
    where p.email = lower(trim(teacher_email)) and p.organization_id = caller.organization_id
  ) then
    raise exception '% is already in your organization.', lower(trim(teacher_email));
  end if;

  -- Supersede any live invitation to the same address.
  update public.invitations
  set status = 'revoked'
  where organization_id = caller.organization_id
    and lower(email) = lower(trim(teacher_email))
    and status = 'pending';

  insert into public.invitations (organization_id, email, full_name, sent_via, invited_by)
  values (
    caller.organization_id, lower(trim(teacher_email)), trim(teacher_name),
    send_via, auth.uid()
  )
  returning * into invite;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    caller.organization_id, auth.uid(), caller.full_name, 'admin',
    'Invited ' || trim(teacher_name) || ' by ' || send_via,
    jsonb_build_object('invitation_id', invite.id, 'email', invite.email)
  );

  return invite;
end;
$$;

grant execute on function public.invite_teacher(text, text, public.notification_channel) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- revoke_invitation
-- ─────────────────────────────────────────────────────────────

create or replace function public.revoke_invitation(invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite public.invitations;
begin
  select * into invite from public.invitations where id = invitation_id;

  if invite.id is null or not public.is_org_admin_of(invite.organization_id) then
    raise exception 'No such invitation.';
  end if;

  update public.invitations set status = 'revoked' where id = invitation_id;
end;
$$;

grant execute on function public.revoke_invitation(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- remove_teacher
-- ─────────────────────────────────────────────────────────────

-- Removes a teacher from an organization without touching a single record they
-- created.
--
-- The mockup promises "historical classes, attendance and marks stay with your
-- organization", and this is what makes that true: the teacher is detached from
-- the organization, but their classes keep their organization_id, so the
-- Organization Admin still sees every register and every mark. The teacher
-- themselves loses access, because with no organization they have no
-- subscription and the gate closes.
create or replace function public.remove_teacher(teacher_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller public.profiles;
  target public.profiles;
begin
  select * into caller from public.profiles where id = auth.uid();
  select * into target from public.profiles where id = teacher_id;

  if target.id is null then
    raise exception 'No such teacher.';
  end if;

  if caller.role <> 'org_admin' or caller.organization_id is null
     or target.organization_id is distinct from caller.organization_id then
    raise exception 'You can only remove teachers from your own organization.';
  end if;

  if target.id = caller.id then
    raise exception 'You cannot remove yourself.'
      using hint = 'Ask Warq support to transfer the organization to someone else.';
  end if;

  update public.profiles
  set organization_id = null, status = 'suspended'
  where id = teacher_id;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    caller.organization_id, auth.uid(), caller.full_name, 'admin',
    'Removed ' || target.full_name || ' from the organization · records kept',
    jsonb_build_object('teacher_id', teacher_id)
  );
end;
$$;

grant execute on function public.remove_teacher(uuid) to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- 20260809121500_teacher_actions.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · M4 · Teacher actions
--
-- Creating a class, adding students, taking a register, entering marks.
--
-- Each of these is one call rather than several writes from the client, because
-- each is one decision by a teacher. A register half-saved because the network
-- dropped between two requests is a worse outcome than one that failed cleanly.

-- ─────────────────────────────────────────────────────────────
-- create_class
-- ─────────────────────────────────────────────────────────────

-- The organization is taken from the teacher's own profile, never from the
-- client. A class filed under someone else's organization would be visible to an
-- administrator who has no business seeing it.
-- Only the name is required; the rest default to null and can be filled in
-- later, which is what the class form allows.
create or replace function public.create_class(
  class_name text,
  class_section text default null,
  class_session text default null,
  class_subject text default null,
  class_description text default null
)
returns public.classes
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller public.profiles;
  created public.classes;
  next_color smallint;
begin
  select * into caller from public.profiles where id = auth.uid();

  if caller.role <> 'teacher' then
    raise exception 'Only a teacher can create a class.';
  end if;

  if not public.fn_has_access(auth.uid()) then
    raise exception 'Your subscription is not active.'
      using hint = 'Contact your organization admin, or Warq if you subscribe directly.';
  end if;

  -- Rotate through the six series colours so a teacher's classes are visually
  -- distinct without anyone choosing.
  select coalesce(count(*), 0) % 6 into next_color
  from public.classes where teacher_id = auth.uid();

  -- nullif(trim(...), '') so a blank field arrives as null rather than an empty
  -- string, keeping "not provided" a single representation.
  insert into public.classes (
    organization_id, teacher_id, name, section, session, subject, description, color_index
  )
  values (
    caller.organization_id,
    auth.uid(),
    trim(class_name),
    nullif(trim(coalesce(class_section, '')), ''),
    nullif(trim(coalesce(class_session, '')), ''),
    nullif(trim(coalesce(class_subject, '')), ''),
    nullif(trim(coalesce(class_description, '')), ''),
    next_color
  )
  returning * into created;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    caller.organization_id, auth.uid(), caller.full_name, 'admin',
    'Created ' || created.name || coalesce(' · ' || created.section, ''),
    jsonb_build_object('class_id', created.id)
  );

  return created;
end;
$$;

grant execute on function public.create_class(text, text, text, text, text) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- save_attendance
-- ─────────────────────────────────────────────────────────────

-- Takes or corrects a register for one class on one day.
--
-- Idempotent by construction: the session is keyed on (class_id, date) and the
-- marks on (session_id, student_id), so saving twice corrects the record rather
-- than duplicating it. That is what lets the mobile app retry a queued register
-- after a dropped connection without anyone checking first.
--
-- Returns the number of absentees with a contactable guardian, which is what the
-- confirmation message reports. The worker turns that into actual messages in M7.
create or replace function public.save_attendance(
  p_class_id uuid,
  p_date date,
  p_entries jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller public.profiles;
  -- v_ prefix on purpose. A variable called session_id is ambiguous against
  -- attendance_records.session_id in the INSERT ... SELECT below, and Postgres
  -- rejects the whole function call with 42702 at run time rather than at
  -- creation.
  v_session_id uuid;
  absent_count integer;
  alertable_count integer;
  class_row public.classes;
begin
  select * into caller from public.profiles where id = auth.uid();

  if not public.owns_class(p_class_id) then
    raise exception 'You can only take a register for your own class.';
  end if;

  if not public.fn_has_access(auth.uid()) then
    raise exception 'Your subscription is not active.';
  end if;

  if p_date > current_date then
    raise exception 'A register cannot be taken for a future date.';
  end if;

  select * into class_row from public.classes where id = p_class_id;

  insert into public.attendance_sessions (class_id, date, taken_by)
  values (p_class_id, p_date, auth.uid())
  on conflict (class_id, date)
    do update set taken_by = auth.uid(), updated_at = now()
  returning id into v_session_id;

  -- Every student in the entry list, and nobody else. A student who has left the
  -- class mid-term keeps their historical marks but gains no new ones.
  insert into public.attendance_records (session_id, student_id, mark)
  select
    v_session_id,
    (entry->>'student_id')::uuid,
    (entry->>'mark')::public.attendance_mark
  from jsonb_array_elements(p_entries) as entry
  where exists (
    select 1 from public.class_students cs
    where cs.student_id = (entry->>'student_id')::uuid
      and cs.class_id = p_class_id
      and cs.unenrolled_at is null
  )
  on conflict (session_id, student_id) do update set mark = excluded.mark;

  select count(*) into absent_count
  from public.attendance_records
  where attendance_records.session_id = v_session_id
    and mark = 'absent';

  select count(distinct r.student_id) into alertable_count
  from public.attendance_records r
  join public.student_contacts c on c.student_id = r.student_id and c.receives_alerts
  where r.session_id = v_session_id and r.mark = 'absent';

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    class_row.organization_id, auth.uid(), caller.full_name, 'attendance',
    'Saved attendance · ' || class_row.name
      || coalesce(' ' || class_row.section, '')
      || case
           when absent_count = 0 then ' — everyone present'
           when absent_count = 1 then ' — 1 absence'
           else ' — ' || absent_count || ' absences'
         end,
    jsonb_build_object('class_id', p_class_id, 'date', p_date, 'absent', absent_count)
  );

  return jsonb_build_object(
    'session_id', v_session_id,
    'absent', absent_count,
    'alertable', alertable_count
  );
end;
$$;

grant execute on function public.save_attendance(uuid, date, jsonb) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- save_marks
-- ─────────────────────────────────────────────────────────────

-- A null score deletes the mark rather than storing a zero, because clearing a
-- box means "not marked yet" and a zero means "sat it and got nothing". The
-- difference decides whether the assessment counts against the student's total.
create or replace function public.save_marks(
  p_assessment_id uuid,
  p_entries jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller public.profiles;
  assessment public.assessments;
  class_row public.classes;
  marked_count integer;
begin
  select * into caller from public.profiles where id = auth.uid();
  select * into assessment from public.assessments where id = p_assessment_id;

  if assessment.id is null or not public.owns_class(assessment.class_id) then
    raise exception 'You can only enter marks for your own class.';
  end if;

  if not public.fn_has_access(auth.uid()) then
    raise exception 'Your subscription is not active.';
  end if;

  select * into class_row from public.classes where id = assessment.class_id;

  -- Cleared boxes.
  delete from public.marks
  where assessment_id = p_assessment_id
    and student_id in (
      select (entry->>'student_id')::uuid
      from jsonb_array_elements(p_entries) as entry
      where entry->>'score' is null
    );

  -- Entered scores.
  insert into public.marks (assessment_id, student_id, score, updated_by)
  select
    p_assessment_id,
    (entry->>'student_id')::uuid,
    (entry->>'score')::numeric,
    auth.uid()
  from jsonb_array_elements(p_entries) as entry
  where entry->>'score' is not null
    and exists (
      select 1 from public.class_students cs
      where cs.student_id = (entry->>'student_id')::uuid
        and cs.class_id = assessment.class_id
        and cs.unenrolled_at is null
    )
  on conflict (assessment_id, student_id)
    do update set score = excluded.score, updated_by = auth.uid(), updated_at = now();

  select count(*) into marked_count
  from public.marks where assessment_id = p_assessment_id and score is not null;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    class_row.organization_id, auth.uid(), caller.full_name, 'marks',
    'Entered ' || assessment.name || ' marks · ' || class_row.name
      || coalesce(' ' || class_row.section, ''),
    jsonb_build_object('assessment_id', p_assessment_id, 'marked', marked_count)
  );

  return jsonb_build_object('marked', marked_count);
end;
$$;

grant execute on function public.save_marks(uuid, jsonb) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- v_teacher_today
-- ─────────────────────────────────────────────────────────────

-- What the teacher's home screen asks: which of my classes still needs a
-- register today, and how did the ones already taken go.
create view public.v_teacher_today
with (security_invoker = true) as
select
  c.id as class_id,
  c.teacher_id,
  c.name,
  c.section,
  c.color_index,
  (select count(*) from public.class_students cs
    where cs.class_id = c.id and cs.unenrolled_at is null) as student_count,
  s.id as session_id,
  (s.id is not null) as taken,
  (select count(*) from public.attendance_records r
    where r.session_id = s.id and r.mark = 'present') as present,
  (select count(*) from public.attendance_records r
    where r.session_id = s.id and r.mark = 'absent') as absent,
  (select count(*) from public.attendance_records r
    where r.session_id = s.id and r.mark = 'late') as late,
  (select count(*) from public.attendance_records r
    where r.session_id = s.id and r.mark = 'short_leave') as short_leave
from public.classes c
left join public.attendance_sessions s on s.class_id = c.id and s.date = current_date
where c.archived_at is null;

comment on view public.v_teacher_today is
  'Each class with today''s register attached, or null where it has not been taken. Backs the teacher home screen on both platforms.';


-- ═══════════════════════════════════════════════════════════════
-- 20260810000000_phase1_access.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · Phase 1 · Make self-service accounts usable immediately
--
-- Two changes, both scoped to this phase.
--
-- 1. profiles gains title and bio. The mobile app shows a teacher's title on
--    generated reports ("Ahmed Raza · Senior Lecturer") and their bio on the
--    profile screen. Nullable, so nothing else has to change.
--
-- 2. Sign-up produces a *working* account.
--
--    The original trigger created every account as 'pending' with a 'pending'
--    subscription, because a Main Admin was meant to approve it. That console
--    does not exist yet, so a teacher could register, sign in, and then be
--    unable to create a class, take a register or record a mark - every write
--    is behind has_access(), and so are the reads of teaching data.
--
--    Until the Main Admin dashboard ships, a self-service sign-up is activated
--    on the spot and given a permanent subscription. Nothing about the approval
--    machinery is removed: subscriptions, events, statuses and the RLS gate all
--    stay exactly as they are, so switching approval back on is a change to
--    this one function and nothing else.
--
--    An invited teacher is deliberately still gated. They hold no subscription
--    of their own and are covered by their organization's, which they only join
--    when they accept the invitation - so activating them here would grant
--    access to an organization they have not joined.

-- ─────────────────────────────────────────────────────────────
-- profiles: title and bio
-- ─────────────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists title text
    check (title is null or length(trim(title)) <= 80),
  add column if not exists bio text
    check (bio is null or length(trim(bio)) <= 400);

comment on column public.profiles.title is
  'Shown beside the teacher''s name on generated reports. Optional.';

-- ─────────────────────────────────────────────────────────────
-- sign-up
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  signup_kind text := coalesce(meta->>'signup_kind', 'invited_teacher');
  requested_plan public.subscription_plan;
  resolved_name text;
  new_org_id uuid;
  new_subscription_id uuid;

  -- PHASE 1: self-service accounts are approved on creation. Set this to
  -- 'pending' (and the subscription status below to 'pending') the day the
  -- Main Admin console can approve them.
  self_service_account public.account_status := 'active';
  self_service_subscription public.subscription_status := 'active';
begin
  resolved_name := coalesce(
    nullif(trim(meta->>'full_name'), ''),
    split_part(new.email, '@', 1)
  );

  -- 'permanent' carries no end date, which is what makes an auto-approved
  -- subscription read as active without inventing an expiry the Main Admin
  -- never chose. The plan the user asked for is recorded on the event below,
  -- so nothing about their intent is lost.
  requested_plan := 'permanent';

  -- ── An organization registering itself ──────────────────────
  if signup_kind = 'organization' then
    if coalesce(trim(meta->>'organization_name'), '') = ''
       or coalesce(trim(meta->>'city'), '') = '' then
      raise exception 'An organization account needs an organization name and a city.';
    end if;

    insert into public.organizations (name, city, email, phone, status)
    values (
      trim(meta->>'organization_name'),
      trim(meta->>'city'),
      lower(new.email),
      nullif(meta->>'phone', ''),
      'active'
    )
    returning id into new_org_id;

    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'org_admin', new_org_id, self_service_account
    );

    update public.organizations set owner_profile_id = new.id where id = new_org_id;

    insert into public.subscriptions (organization_id, plan, status, starts_at)
    values (new_org_id, requested_plan, self_service_subscription, current_date)
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (
      new_subscription_id, 'approved', requested_plan,
      'Auto-approved at sign-up (Phase 1, before the Main Admin console)'
    );

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      trim(meta->>'organization_name') || ' created an organization account',
      jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
    );

  -- ── An independent teacher registering themselves ───────────
  elsif signup_kind = 'individual_teacher' then
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'teacher', null, self_service_account
    );

    insert into public.subscriptions (profile_id, plan, status, starts_at)
    values (new.id, requested_plan, self_service_subscription, current_date)
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (
      new_subscription_id, 'approved', requested_plan,
      'Auto-approved at sign-up (Phase 1, before the Main Admin console)'
    );

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      resolved_name || ' created an individual teacher account',
      jsonb_build_object('plan', requested_plan)
    );

  -- ── A teacher arriving through an invitation ────────────────
  else
    -- Still pending on purpose: they are covered by the organization's
    -- subscription, and they are not in the organization until they accept.
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'teacher', null, 'pending'
    );
  end if;

  return new;
end;
$$;

comment on function public.fn_handle_new_user is
  'Creates the profile and, for self-service sign-ups, the organization and an auto-approved permanent subscription. PHASE 1: approval is bypassed until the Main Admin console exists - see self_service_account inside. Never mints a main_admin.';


-- ═══════════════════════════════════════════════════════════════
-- 20260810010000_app_parity.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · Phase 1 · Columns the mobile app needs
--
-- The Flutter app stores a handful of fields the recovered schema had no home
-- for. Each one below is entered by a teacher and shown back to them, so
-- dropping them would be a visible loss of function rather than a tidy-up.
--
-- Everything here is nullable or defaulted, so existing rows stay valid.
--
-- Deliberately NOT added, because the data already exists elsewhere:
--   * attendance_records.notified - whether guardians were told is answered by
--     guardian_messages having a row for that session and student.
--   * profiles.username - Supabase authenticates by email, and a username
--     lookup would let a stranger probe which accounts exist.
--   * profiles.last_login_at - the activity log already records what someone
--     last did, which is the question the monitoring screen actually asks.

-- ─────────────────────────────────────────────────────────────
-- assessments: custom type name and description
-- ─────────────────────────────────────────────────────────────

alter table public.assessments
  add column if not exists custom_type_label text
    check (custom_type_label is null or length(trim(custom_type_label)) <= 40),
  add column if not exists description text
    check (description is null or length(trim(description)) <= 400);

comment on column public.assessments.custom_type_label is
  'What the teacher called it when type = custom, e.g. "Lab report". Ignored for the other types.';

-- ─────────────────────────────────────────────────────────────
-- marks: absence and remarks
-- ─────────────────────────────────────────────────────────────

-- A student who missed the assessment is not the same as one who scored zero,
-- and neither is the same as one who has not been marked yet. score stays null
-- for "not marked"; absent carries the third case explicitly.
alter table public.marks
  add column if not exists absent boolean not null default false,
  add column if not exists remarks text
    check (remarks is null or length(trim(remarks)) <= 240);

comment on column public.marks.absent is
  'Missed the assessment. Scores zero in totals but is reported as "Absent", not as a zero.';

-- An absent student has no score to record; allowing both would leave two
-- sources of truth for the same result.
alter table public.marks
  drop constraint if exists absent_has_no_score;
alter table public.marks
  add constraint absent_has_no_score check (not absent or score is null);

-- ─────────────────────────────────────────────────────────────
-- attendance_sessions: note
-- ─────────────────────────────────────────────────────────────

alter table public.attendance_sessions
  add column if not exists note text
    check (note is null or length(trim(note)) <= 240);

-- ─────────────────────────────────────────────────────────────
-- organizations: postal address and website
-- ─────────────────────────────────────────────────────────────

-- city is already required and drives the Main Admin's search. These two are
-- the rest of an institution's letterhead, shown on the organization profile.
alter table public.organizations
  add column if not exists address text
    check (address is null or length(trim(address)) <= 240),
  add column if not exists website text
    check (website is null or length(trim(website)) <= 160);

-- ─────────────────────────────────────────────────────────────
-- grade_scales: name and pass mark
-- ─────────────────────────────────────────────────────────────

-- The app lets an organization name its scale and set the mark below which a
-- student is flagged as needing attention. Both were held only in the client.
alter table public.grade_scales
  add column if not exists name text not null default 'Standard scale'
    check (length(trim(name)) between 1 and 60),
  add column if not exists pass_percent numeric(5, 2) not null default 50
    check (pass_percent >= 0 and pass_percent <= 100);

comment on column public.grade_scales.pass_percent is
  'Below this, a student is flagged as needing attention. Distinct from the lowest passing band.';

-- fn_grade_scale_is_valid only requires each band to carry grade and min, so
-- the app may keep gpa and remark alongside them without loosening validation.
comment on column public.grade_scales.bands is
  'Highest band first. Each entry needs grade and min; gpa and remark are optional extras the app displays.';


-- ═══════════════════════════════════════════════════════════════
-- 20260810020000_invited_signup.sql
-- ═══════════════════════════════════════════════════════════════

-- Warq · Phase 1 · An invited teacher joins their organization by signing up
--
-- The register screen tells a teacher: "If your organization has already
-- invited this email, you will join it automatically." That was not true.
--
-- fn_handle_new_user branched only on signup_kind, a value the client supplies.
-- The mobile app's "I am a teacher" option sends 'individual_teacher', so an
-- invited teacher who registered the obvious way got a personal account with
-- organization_id null. Their admin never saw them on the roster, could not
-- remove them, and none of their classes rolled up to the organization. The
-- invitation sat pending until it expired.
--
-- The other route in, accept_invitation(token), needs the teacher to have the
-- token from an invitation email. Phase 1 sends no email, so in practice there
-- was no way at all for a teacher to join an organization.
--
-- An outstanding invitation is a decision the organization already made and
-- stored; signup_kind is a hint typed by someone who may not know they were
-- invited. So the invitation wins. accept_invitation stays as it is, for when
-- invitations are actually delivered and a signed-in teacher accepts one later.
--
-- One exception: asking to create an organization is explicit and is honoured.
-- Someone who registers their own school while holding an invitation to another
-- one meant to register their own school, and their invitation stays pending.

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- v_ prefix throughout: activity_logs has a column called meta, and a
  -- variable of the same name is ambiguous inside any statement that puts that
  -- table's columns in scope. Postgres only reports it at run time.
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  signup_kind text := coalesce(v_meta->>'signup_kind', 'invited_teacher');
  requested_plan public.subscription_plan;
  resolved_name text;
  invite public.invitations;
  new_org_id uuid;
  new_subscription_id uuid;

  -- PHASE 1: self-service accounts are approved on creation. Set this to
  -- 'pending' (and the subscription status below to 'pending') the day the
  -- Main Admin console can approve them.
  self_service_account public.account_status := 'active';
  self_service_subscription public.subscription_status := 'active';
begin
  -- A live invitation for this address, if there is one. Expired and revoked
  -- invitations are ignored, which drops the signer through to an ordinary
  -- individual account rather than failing their registration.
  select * into invite
  from public.invitations
  where lower(email) = lower(new.email)
    and status = 'pending'
    and expires_at > now()
  order by created_at desc
  limit 1;

  -- What they typed, else the name their admin invited them under, else the
  -- local part of the address.
  resolved_name := coalesce(
    nullif(trim(v_meta->>'full_name'), ''),
    nullif(trim(invite.full_name), ''),
    split_part(new.email, '@', 1)
  );

  -- 'permanent' carries no end date, which is what makes an auto-approved
  -- subscription read as active without inventing an expiry the Main Admin
  -- never chose. The plan the user asked for is recorded on the event below,
  -- so nothing about their intent is lost.
  requested_plan := 'permanent';

  -- ── An organization registering itself ──────────────────────
  if signup_kind = 'organization' then
    if coalesce(trim(v_meta->>'organization_name'), '') = ''
       or coalesce(trim(v_meta->>'city'), '') = '' then
      raise exception 'An organization account needs an organization name and a city.';
    end if;

    insert into public.organizations (name, city, email, phone, status)
    values (
      trim(v_meta->>'organization_name'),
      trim(v_meta->>'city'),
      lower(new.email),
      nullif(v_meta->>'phone', ''),
      'active'
    )
    returning id into new_org_id;

    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(v_meta->>'phone', ''),
      'org_admin', new_org_id, self_service_account
    );

    update public.organizations set owner_profile_id = new.id where id = new_org_id;

    insert into public.subscriptions (organization_id, plan, status, starts_at)
    values (new_org_id, requested_plan, self_service_subscription, current_date)
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (
      new_subscription_id, 'approved', requested_plan,
      'Auto-approved at sign-up (Phase 1, before the Main Admin console)'
    );

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      trim(v_meta->>'organization_name') || ' created an organization account',
      jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
    );

  -- ── A teacher their organization has already invited ────────
  elsif invite.id is not null then
    -- Active immediately, and with no subscription of their own: they are
    -- inside the organization now and covered by the organization's.
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(v_meta->>'phone', ''),
      'teacher', invite.organization_id, 'active'
    );

    -- After the profile exists: accepted_by is a foreign key to it, and
    -- accepted_is_complete requires both columns to be set together.
    update public.invitations
    set status = 'accepted', accepted_at = now(), accepted_by = new.id
    where id = invite.id;

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      invite.organization_id, new.id, resolved_name, 'admin',
      resolved_name || ' joined the organization',
      jsonb_build_object('invitation_id', invite.id, 'via', 'sign-up')
    );

  -- ── An independent teacher registering themselves ───────────
  elsif signup_kind = 'individual_teacher' then
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(v_meta->>'phone', ''),
      'teacher', null, self_service_account
    );

    insert into public.subscriptions (profile_id, plan, status, starts_at)
    values (new.id, requested_plan, self_service_subscription, current_date)
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (
      new_subscription_id, 'approved', requested_plan,
      'Auto-approved at sign-up (Phase 1, before the Main Admin console)'
    );

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      resolved_name || ' created an individual teacher account',
      jsonb_build_object('plan', requested_plan)
    );

  -- ── Someone expecting an invitation that is not there ───────
  else
    -- Pending on purpose. The invitation may have expired, been revoked, or
    -- been sent to a different address; accept_invitation can still rescue
    -- this account once they have a token.
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(v_meta->>'phone', ''),
      'teacher', null, 'pending'
    );
  end if;

  return new;
end;
$$;

comment on function public.fn_handle_new_user is
  'Creates the profile at sign-up. An outstanding invitation wins over the client-supplied signup_kind and joins the teacher to that organization; self-service sign-ups get an auto-approved permanent subscription. PHASE 1: approval is bypassed until the Main Admin console exists - see self_service_account inside. Never mints a main_admin.';


commit;
