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
