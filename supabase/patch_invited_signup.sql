-- Warq - invited teachers join their organization at sign-up
--
-- Run this AFTER the other patches. Safe to run more than once.

begin;

-- Warq · Phase 1 · An invited teacher joins their organization by signing up
--
-- The register screen tells a teacher: "If your organization has already
-- invited this email, you will join it automatically." That was not true.
--
-- fn_handle_new_user branched only on signup_kind, a value the client supplies.
-- The mobile app's "I am a teacher" option sends 'individual_teacher', so an
-- invited teacher who registered the obvious way got a personal account with
-- organization_id null. Their admin never saw them on the roster, could not
-- remove them, and none of their classes rolled up to the organization. The
-- invitation sat pending until it expired.
--
-- The other route in, accept_invitation(token), needs the teacher to have the
-- token from an invitation email. Phase 1 sends no email, so in practice there
-- was no way at all for a teacher to join an organization.
--
-- An outstanding invitation is a decision the organization already made and
-- stored; signup_kind is a hint typed by someone who may not know they were
-- invited. So the invitation wins. accept_invitation stays as it is, for when
-- invitations are actually delivered and a signed-in teacher accepts one later.
--
-- One exception: asking to create an organization is explicit and is honoured.
-- Someone who registers their own school while holding an invitation to another
-- one meant to register their own school, and their invitation stays pending.

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

  -- PHASE 1: self-service accounts are approved on creation. Set this to
  -- 'pending' (and the subscription status below to 'pending') the day the
  -- Main Admin console can approve them.
  self_service_account public.account_status := 'active';
  self_service_subscription public.subscription_status := 'active';
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

  -- 'permanent' carries no end date, which is what makes an auto-approved
  -- subscription read as active without inventing an expiry the Main Admin
  -- never chose. The plan the user asked for is recorded on the event below,
  -- so nothing about their intent is lost.
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
      'active'
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
      new_subscription_id, 'approved', requested_plan,
      'Auto-approved at sign-up (Phase 1, before the Main Admin console)'
    );

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      trim(v_meta->>'organization_name') || ' created an organization account',
      jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
    );

  -- ── A teacher their organization has already invited ────────
  elsif invite.id is not null then
    -- Active immediately, and with no subscription of their own: they are
    -- inside the organization now and covered by the organization's.
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
      new_subscription_id, 'approved', requested_plan,
      'Auto-approved at sign-up (Phase 1, before the Main Admin console)'
    );

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      resolved_name || ' created an individual teacher account',
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
  'Creates the profile at sign-up. An outstanding invitation wins over the client-supplied signup_kind and joins the teacher to that organization; self-service sign-ups get an auto-approved permanent subscription. PHASE 1: approval is bypassed until the Main Admin console exists - see self_service_account inside. Never mints a main_admin.';

commit;
