-- Warq - require approval for new sign-ups
--
-- Run this AFTER the other patches. Safe to run more than once.
-- Only affects accounts created after it runs.

begin;

-- Warq · Sign-ups wait for the platform administrator again
--
-- When the access patch landed, self-service sign-ups were activated on the
-- spot. That was not a preference: has_access() gates the reads *and* the
-- writes of teaching data, so a pending teacher could sign in and then do
-- nothing at all, and there was no console anywhere in which to approve them.
-- Auto-approval was the only setting that produced a working product.
--
-- The platform admin dashboard now exists, and with it the queue, the approve
-- and reject buttons, and the audit trail behind them. So the reason is gone
-- and the flags go back to what they were always meant to be.
--
-- What changes: someone registering a new account, or a new organization, is
-- created pending and waits. approve_subscription() opens the subscription, the
-- organization and every profile attached to it in one go, so approving from
-- the dashboard is all that is needed.
--
-- What does not change:
--
--   * Existing accounts. This only affects rows created after it runs; nobody
--     already working is interrupted.
--   * Invited teachers. Their organization already decided to admit them, and
--     they are covered by its subscription rather than holding one, so they
--     join active exactly as before. Approval is about who gets onto the
--     platform, not about who an admitted organization may employ.
--
-- To go back to letting everyone straight in, set the two flags below to
-- 'active' again. Nothing else needs to move.

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- v_ prefix throughout: activity_logs has a column called meta, and a
  -- variable of the same name is ambiguous inside any statement that puts that
  -- table's columns in scope. Postgres only reports it at run time.
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  signup_kind text := coalesce(v_meta->>'signup_kind', 'invited_teacher');
  requested_plan public.subscription_plan;
  resolved_name text;
  invite public.invitations;
  new_org_id uuid;
  new_subscription_id uuid;

  -- A self-service sign-up waits for the platform administrator. Set both to
  -- 'active' to let everyone in automatically again.
  self_service_account public.account_status := 'pending';
  self_service_subscription public.subscription_status := 'pending';

  -- An organization is only open for business once its subscription is
  -- approved, and approve_subscription() is what opens it.
  self_service_org public.account_status := 'pending';
begin
  -- A live invitation for this address, if there is one. Expired and revoked
  -- invitations are ignored, which drops the signer through to an ordinary
  -- individual account rather than failing their registration.
  select * into invite
  from public.invitations
  where lower(email) = lower(new.email)
    and status = 'pending'
    and expires_at > now()
  order by created_at desc
  limit 1;

  -- What they typed, else the name their admin invited them under, else the
  -- local part of the address.
  resolved_name := coalesce(
    nullif(trim(v_meta->>'full_name'), ''),
    nullif(trim(invite.full_name), ''),
    split_part(new.email, '@', 1)
  );

  -- The plan a self-service sign-up is recorded against until an administrator
  -- chooses otherwise. approve_subscription() sets the real dates from it.
  requested_plan := 'permanent';

  -- ── An organization registering itself ──────────────────────
  if signup_kind = 'organization' then
    if coalesce(trim(v_meta->>'organization_name'), '') = ''
       or coalesce(trim(v_meta->>'city'), '') = '' then
      raise exception 'An organization account needs an organization name and a city.';
    end if;

    insert into public.organizations (name, city, email, phone, status)
    values (
      trim(v_meta->>'organization_name'),
      trim(v_meta->>'city'),
      lower(new.email),
      nullif(v_meta->>'phone', ''),
      self_service_org
    )
    returning id into new_org_id;

    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(v_meta->>'phone', ''),
      'org_admin', new_org_id, self_service_account
    );

    update public.organizations set owner_profile_id = new.id where id = new_org_id;

    insert into public.subscriptions (organization_id, plan, status, starts_at)
    values (new_org_id, requested_plan, self_service_subscription, current_date)
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (
      new_subscription_id, 'requested', requested_plan,
      'Requested at sign-up'
    );

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      trim(v_meta->>'organization_name') || ' requested an organization account',
      jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
    );

  -- ── A teacher their organization has already invited ────────
  elsif invite.id is not null then
    -- Active immediately, and with no subscription of their own: the
    -- organization already decided to admit them, and they are covered by its
    -- subscription. If that subscription is not approved yet, has_access()
    -- holds them back for exactly as long as it holds their admin back.
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(v_meta->>'phone', ''),
      'teacher', invite.organization_id, 'active'
    );

    -- After the profile exists: accepted_by is a foreign key to it, and
    -- accepted_is_complete requires both columns to be set together.
    update public.invitations
    set status = 'accepted', accepted_at = now(), accepted_by = new.id
    where id = invite.id;

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      invite.organization_id, new.id, resolved_name, 'admin',
      resolved_name || ' joined the organization',
      jsonb_build_object('invitation_id', invite.id, 'via', 'sign-up')
    );

  -- ── An independent teacher registering themselves ───────────
  elsif signup_kind = 'individual_teacher' then
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(v_meta->>'phone', ''),
      'teacher', null, self_service_account
    );

    insert into public.subscriptions (profile_id, plan, status, starts_at)
    values (new.id, requested_plan, self_service_subscription, current_date)
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (
      new_subscription_id, 'requested', requested_plan,
      'Requested at sign-up'
    );

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      resolved_name || ' requested an individual teacher account',
      jsonb_build_object('plan', requested_plan)
    );

  -- ── Someone expecting an invitation that is not there ───────
  else
    -- Pending on purpose. The invitation may have expired, been revoked, or
    -- been sent to a different address; accept_invitation can still rescue
    -- this account once they have a token.
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(v_meta->>'phone', ''),
      'teacher', null, 'pending'
    );
  end if;

  return new;
end;
$$;

comment on function public.fn_handle_new_user is
  'Creates the profile at sign-up. A self-service sign-up waits for the platform administrator; an outstanding invitation wins over the client-supplied signup_kind and joins the teacher to that organization immediately. Never mints a main_admin.';

commit;
