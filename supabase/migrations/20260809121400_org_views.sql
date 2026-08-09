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
  (select count(*) from public.students st
    join public.classes c on c.id = st.class_id
    where c.teacher_id = p.id and c.archived_at is null) as student_count,
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
  public.fn_percentage(
    count(r.*) filter (where r.mark = 'present'),
    nullif(count(r.*), 0)
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
    and status = 'sent';

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
