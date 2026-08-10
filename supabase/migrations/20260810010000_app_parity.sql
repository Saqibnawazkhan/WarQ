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
