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
