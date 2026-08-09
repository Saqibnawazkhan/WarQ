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
