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
create or replace function public.create_class(
  class_name text,
  class_section text,
  class_session text
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

  insert into public.classes (organization_id, teacher_id, name, section, session, color_index)
  values (
    caller.organization_id, auth.uid(), trim(class_name),
    trim(class_section), trim(class_session), next_color
  )
  returning * into created;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    caller.organization_id, auth.uid(), caller.full_name, 'admin',
    'Created ' || created.name || ' · ' || created.section,
    jsonb_build_object('class_id', created.id)
  );

  return created;
end;
$$;

grant execute on function public.create_class(text, text, text) to authenticated;

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
  session_id uuid;
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
  returning id into session_id;

  -- Every student in the entry list, and nobody else. A student who has left the
  -- class mid-term keeps their historical marks but gains no new ones.
  insert into public.attendance_records (session_id, student_id, mark)
  select
    session_id,
    (entry->>'student_id')::uuid,
    (entry->>'mark')::public.attendance_mark
  from jsonb_array_elements(p_entries) as entry
  where exists (
    select 1 from public.students s
    where s.id = (entry->>'student_id')::uuid and s.class_id = p_class_id
  )
  on conflict (session_id, student_id) do update set mark = excluded.mark;

  select count(*) into absent_count
  from public.attendance_records
  where attendance_records.session_id = save_attendance.session_id
    and mark = 'absent';

  select count(distinct r.student_id) into alertable_count
  from public.attendance_records r
  join public.student_contacts c on c.student_id = r.student_id and c.receives_alerts
  where r.session_id = save_attendance.session_id and r.mark = 'absent';

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    class_row.organization_id, auth.uid(), caller.full_name, 'attendance',
    'Saved attendance · ' || class_row.name || ' ' || class_row.section
      || case
           when absent_count = 0 then ' — everyone present'
           when absent_count = 1 then ' — 1 absence'
           else ' — ' || absent_count || ' absences'
         end,
    jsonb_build_object('class_id', p_class_id, 'date', p_date, 'absent', absent_count)
  );

  return jsonb_build_object(
    'session_id', session_id,
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
      select 1 from public.students s
      where s.id = (entry->>'student_id')::uuid and s.class_id = assessment.class_id
    )
  on conflict (assessment_id, student_id)
    do update set score = excluded.score, updated_by = auth.uid(), updated_at = now();

  select count(*) into marked_count
  from public.marks where assessment_id = p_assessment_id and score is not null;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    class_row.organization_id, auth.uid(), caller.full_name, 'marks',
    'Entered ' || assessment.name || ' marks · ' || class_row.name || ' ' || class_row.section,
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
  (select count(*) from public.students st where st.class_id = c.id) as student_count,
  s.id as session_id,
  (s.id is not null) as taken,
  (select count(*) from public.attendance_records r
    where r.session_id = s.id and r.mark = 'present') as present,
  (select count(*) from public.attendance_records r
    where r.session_id = s.id and r.mark = 'absent') as absent,
  (select count(*) from public.attendance_records r
    where r.session_id = s.id and r.mark = 'late') as late
from public.classes c
left join public.attendance_sessions s on s.class_id = c.id and s.date = current_date
where c.archived_at is null;

comment on view public.v_teacher_today is
  'Each class with today''s register attached, or null where it has not been taken. Backs the teacher home screen on both platforms.';
