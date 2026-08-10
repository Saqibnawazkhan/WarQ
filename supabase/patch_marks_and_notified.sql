-- Warq - absence notices and mark absence
--
-- Run this AFTER the other patches. Safe to run more than once.

begin;

-- Warq · Phase 1 · Remember which absences have already been messaged
--
-- Absence alerts go to a parent's WhatsApp. A register is editable all day and
-- the app re-saves the whole sheet each time, so without somewhere to record
-- "this one has been sent", a teacher correcting one student's mark at noon
-- would message every absent student's parent a second time.
--
-- The local implementation kept this as a flag on the attendance record and
-- deliberately preserved it across re-saves. This is the same flag.
--
-- guardian_messages already records what was actually sent, and stays the
-- source of truth for delivery and failure. It cannot answer this question on
-- its own though: a student whose parents have no phone number produces no
-- message at all, and re-reading an empty result as "not yet notified" would
-- retry them on every save forever.
--
-- save_attendance updates only the mark on conflict, so the flag survives a
-- correction without any change to that function.

alter table public.attendance_records
  add column if not exists notified boolean not null default false;

comment on column public.attendance_records.notified is
  'True once an absence notice for this record has been dispatched. Set by the app after sending; never cleared by re-saving the register.';

-- ─────────────────────────────────────────────────────────────
-- mark_absences_notified
-- ─────────────────────────────────────────────────────────────

-- One call rather than one update per student: the app sets these immediately
-- after dispatching, and a partial write here means duplicate messages later.
--
-- Scoped to the caller's own class by owns_class, so this cannot be used to
-- suppress another teacher's alerts.
create or replace function public.mark_absences_notified(
  p_session_id uuid,
  p_student_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_class_id uuid;
  v_updated integer;
begin
  select class_id into v_class_id
  from public.attendance_sessions
  where id = p_session_id;

  if v_class_id is null then
    raise exception 'No such attendance session.';
  end if;

  if not public.owns_class(v_class_id) then
    raise exception 'You can only update your own class.';
  end if;

  update public.attendance_records
  set notified = true
  where session_id = p_session_id
    and student_id = any (p_student_ids);

  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

grant execute on function public.mark_absences_notified(uuid, uuid[]) to authenticated;

-- Warq · Phase 1 · Marks: absence, remarks, and an assessment weight
--
-- Three gaps between what the app records against an assessment and what the
-- database could store.
--
-- 1. save_marks deleted any entry whose score was null, on the reasoning that
--    an empty box means "not marked yet" rather than zero. That is right for an
--    empty box, but the parity patch had since added marks.absent for a student
--    who missed the assessment, and an absent student has no score by
--    construction — the absent_has_no_score constraint requires it. So marking
--    somebody absent wrote a row the very next save silently deleted.
--
-- 2. Remarks were never written at all.
--
-- 3. assessments had no weight column, so AssessmentDraft.weight was dropped on
--    the floor. Nothing sets it today - it is there for a weighted-average
--    grading mode the app already models - but a field that is accepted and
--    discarded is worse than one that is stored and unused.
--
-- The three cases the app distinguishes, and what each now stores:
--   a score            -> the score, absent false
--   absent             -> a row with a null score and absent true
--   nothing at all     -> no row, which is what "not marked yet" means
-- A remark with no score keeps its row, because a teacher who wrote a note has
-- marked something even if they have not put a number to it.

alter table public.assessments
  add column if not exists weight numeric(6, 2)
    check (weight is null or weight >= 0);

comment on column public.assessments.weight is
  'Relative weight in a weighted average. Null means this assessment counts the same as every other, which is how grading works today.';

-- ─────────────────────────────────────────────────────────────
-- save_marks
-- ─────────────────────────────────────────────────────────────

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

  -- Genuinely cleared boxes: no score, not absent, nothing written. Anything
  -- else the teacher touched is kept.
  delete from public.marks
  where assessment_id = p_assessment_id
    and student_id in (
      select (entry->>'student_id')::uuid
      from jsonb_array_elements(p_entries) as entry
      where entry->>'score' is null
        and coalesce((entry->>'absent')::boolean, false) = false
        and coalesce(nullif(trim(entry->>'remarks'), ''), '') = ''
    );

  -- Everything the teacher did record. An absent student is stored with a null
  -- score on purpose: absent_has_no_score forbids carrying both, and reporting
  -- reads the absent flag rather than inferring it from a zero.
  insert into public.marks (assessment_id, student_id, score, absent, remarks, updated_by)
  select
    p_assessment_id,
    (entry->>'student_id')::uuid,
    case
      when coalesce((entry->>'absent')::boolean, false) then null
      else (entry->>'score')::numeric
    end,
    coalesce((entry->>'absent')::boolean, false),
    nullif(trim(entry->>'remarks'), ''),
    auth.uid()
  from jsonb_array_elements(p_entries) as entry
  where (
      entry->>'score' is not null
      or coalesce((entry->>'absent')::boolean, false)
      or coalesce(nullif(trim(entry->>'remarks'), ''), '') <> ''
    )
    and exists (
      select 1 from public.class_students cs
      where cs.student_id = (entry->>'student_id')::uuid
        and cs.class_id = assessment.class_id
        and cs.unenrolled_at is null
    )
  on conflict (assessment_id, student_id)
    do update set
      score = excluded.score,
      absent = excluded.absent,
      remarks = excluded.remarks,
      updated_by = auth.uid(),
      updated_at = now();

  -- What "marked" counts for the progress line on the marks screen: a score, or
  -- a recorded absence. Both are a decision the teacher has made.
  select count(*) into marked_count
  from public.marks
  where assessment_id = p_assessment_id
    and (score is not null or absent);

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

commit;
