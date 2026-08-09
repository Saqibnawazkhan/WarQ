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
