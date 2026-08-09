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
  section text not null check (length(trim(section)) between 1 and 16),
  -- "Session 2026" in the mockups. Text for now; if per-term reporting is needed
  -- later this becomes a real entity, which is a contained change.
  session text not null check (length(trim(session)) between 4 and 32),

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

-- One class per name, section and session for a given teacher.
create unique index classes_unique_per_teacher_idx
  on public.classes (teacher_id, lower(name), lower(section), session)
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
create table public.students (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes (id) on delete cascade,
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  roll_no text not null check (length(trim(roll_no)) between 1 and 32),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.students is
  'A student record within a class. Not a user account - students never sign in.';

create unique index students_roll_unique_idx
  on public.students (class_id, lower(roll_no));

create index students_class_idx on public.students (class_id);

create trigger students_touch_updated_at
  before update on public.students
  for each row execute function public.fn_touch_updated_at();

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
alter table public.student_contacts enable row level security;
alter table public.grade_scales enable row level security;
