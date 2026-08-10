-- Warq · A teacher's "today" is their own, not the server's
--
-- save_attendance refused any date after current_date. The database runs in
-- UTC and Warq's teachers are in Pakistan, five hours ahead, so between
-- midnight and 5am local the server is still on yesterday: a teacher who opened
-- the register early was told "A register cannot be taken for a future date"
-- about the date their own calendar was showing.
--
-- attendance_sessions already allows it. Its constraint is
--
--   check (date <= current_date + 1)
--
-- with the comment "No roll call for a lesson that has not happened" - the one
-- day of slack is there precisely so a client's local date is never rejected
-- for being ahead of UTC. The function was stricter than the table it writes
-- to, which is the part that was wrong.
--
-- A day of slack still refuses a register for next week, which is what the rule
-- is actually for.

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

  -- Matches attendance_sessions.not_in_the_future: one day of slack, so a
  -- teacher ahead of UTC is never refused their own current date.
  if p_date > current_date + 1 then
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
