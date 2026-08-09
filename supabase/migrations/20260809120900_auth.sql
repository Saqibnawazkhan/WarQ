-- Warq · M1 · Account creation
--
-- Supabase owns auth.users. Warq owns profiles. This migration is the bridge:
-- when a user is created, a matching profile appears with the role and
-- organization they signed up for.
--
-- Roles come from the sign-up payload, never from the client at request time -
-- and the trigger below refuses to mint a main_admin no matter what the payload
-- says. The first platform administrator is created by hand, once.

-- ─────────────────────────────────────────────────────────────
-- Profile creation
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_role text := coalesce(new.raw_user_meta_data->>'role', 'teacher');
  requested_org uuid := nullif(new.raw_user_meta_data->>'organization_id', '')::uuid;
  resolved_role public.user_role;
begin
  -- A client controls its own sign-up metadata, so main_admin is not on offer.
  -- Promoting someone to platform administrator is a deliberate act performed
  -- against the database, not a field in a registration form.
  if requested_role not in ('teacher', 'org_admin') then
    resolved_role := 'teacher';
  else
    resolved_role := requested_role::public.user_role;
  end if;

  -- An org_admin without an organization would violate the table's own
  -- constraint; fall back to teacher rather than failing the sign-up outright.
  if resolved_role = 'org_admin' and requested_org is null then
    resolved_role := 'teacher';
  end if;

  insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
  values (
    new.id,
    lower(new.email),
    coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1)),
    nullif(new.raw_user_meta_data->>'phone', ''),
    resolved_role,
    requested_org,
    -- Everyone starts pending. An organization teacher is activated when they
    -- accept an invitation; an independent teacher and an organization are
    -- activated when the Main Admin approves the request.
    'pending'
  );

  return new;
end;
$$;

comment on function public.fn_handle_new_user is
  'Creates the Warq profile behind a new auth user. Refuses to mint a main_admin from sign-up metadata.';

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.fn_handle_new_user();

-- ─────────────────────────────────────────────────────────────
-- Accepting an invitation
-- ─────────────────────────────────────────────────────────────

-- Runs after sign-up, as the newly created (pending) user. Exchanges a token for
-- membership of the organization that issued it.
--
-- security definer because the caller cannot yet read the invitations table -
-- they are not a member of anything. The token is the only credential, so it is
-- matched in full, checked for expiry, and consumed.
create or replace function public.accept_invitation(invitation_token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite public.invitations;
  caller_email text;
begin
  if auth.uid() is null then
    raise exception 'Sign in before accepting an invitation.';
  end if;

  select email into caller_email from public.profiles where id = auth.uid();

  select * into invite
  from public.invitations
  where token = invitation_token
  for update;

  if invite.id is null then
    raise exception 'That invitation link is not valid.'
      using hint = 'Ask your organization admin to send a new invitation.';
  end if;

  if invite.status <> 'pending' then
    raise exception 'That invitation has already been used.'
      using hint = 'Sign in normally, or ask for a new invitation.';
  end if;

  if invite.expires_at < now() then
    update public.invitations set status = 'expired' where id = invite.id;
    raise exception 'That invitation has expired.'
      using hint = 'Ask your organization admin to send a new one.';
  end if;

  -- The invitation is addressed to a person, not transferable to whoever holds
  -- the link.
  if lower(invite.email) <> lower(caller_email) then
    raise exception 'That invitation was sent to a different email address.'
      using hint = 'Sign in with the address the invitation was sent to.';
  end if;

  update public.profiles
  set organization_id = invite.organization_id,
      status = 'active',
      role = 'teacher'
  where id = auth.uid();

  update public.invitations
  set status = 'accepted',
      accepted_at = now(),
      accepted_by = auth.uid()
  where id = invite.id;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message)
  select
    invite.organization_id,
    auth.uid(),
    p.full_name,
    'admin',
    'Accepted invitation and joined the organization'
  from public.profiles p where p.id = auth.uid();

  return invite.organization_id;
end;
$$;

comment on function public.accept_invitation is
  'Exchanges an invitation token for organization membership. The token is single-use, expiring, and bound to the invited address.';

revoke all on function public.accept_invitation(text) from public;
grant execute on function public.accept_invitation(text) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Requesting an organization account
-- ─────────────────────────────────────────────────────────────

-- An organization signs up, then waits for the Main Admin to approve it. The
-- caller cannot insert into organizations directly - no policy allows it - so
-- this function does it on their behalf and leaves everything pending.
create or replace function public.request_organization(
  organization_name text,
  organization_city text,
  organization_email text,
  organization_phone text,
  requested_plan public.subscription_plan
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_org_id uuid;
  caller public.profiles;
begin
  select * into caller from public.profiles where id = auth.uid();

  if caller.id is null then
    raise exception 'Sign in before requesting an organization account.';
  end if;

  if caller.organization_id is not null then
    raise exception 'You already belong to an organization.'
      using hint = 'Leave your current organization before requesting another.';
  end if;

  insert into public.organizations (name, city, email, phone, status, owner_profile_id)
  values (
    organization_name, organization_city, lower(organization_email),
    organization_phone, 'pending', auth.uid()
  )
  returning id into new_org_id;

  update public.profiles
  set organization_id = new_org_id, role = 'org_admin'
  where id = auth.uid();

  -- Pending, undated, and granting nothing until a Main Admin approves it.
  insert into public.subscriptions (organization_id, plan, status)
  values (new_org_id, requested_plan, 'pending');

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  select s.id, 'requested', requested_plan, auth.uid(), 'Organization account requested'
  from public.subscriptions s where s.organization_id = new_org_id;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    null, auth.uid(), caller.full_name, 'subscription',
    organization_name || ' requested an organization account',
    jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
  );

  return new_org_id;
end;
$$;

comment on function public.request_organization is
  'Creates a pending organization and a pending subscription. Grants nothing until a Main Admin approves.';

revoke all on function public.request_organization(text, text, text, text, public.subscription_plan) from public;
grant execute on function public.request_organization(text, text, text, text, public.subscription_plan) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Requesting an individual teacher account
-- ─────────────────────────────────────────────────────────────

create or replace function public.request_individual_subscription(
  requested_plan public.subscription_plan
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_subscription_id uuid;
  caller public.profiles;
begin
  select * into caller from public.profiles where id = auth.uid();

  if caller.id is null then
    raise exception 'Sign in before requesting a subscription.';
  end if;

  if caller.organization_id is not null then
    raise exception 'Your organization holds the subscription for your account.'
      using hint = 'Ask your organization admin about your access.';
  end if;

  if exists (select 1 from public.subscriptions where profile_id = auth.uid()) then
    raise exception 'You already have a subscription.'
      using hint = 'Check its status on your account page.';
  end if;

  insert into public.subscriptions (profile_id, plan, status)
  values (auth.uid(), requested_plan, 'pending')
  returning id into new_subscription_id;

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  values (new_subscription_id, 'requested', requested_plan, auth.uid(), 'Individual teacher account requested');

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  values (
    null, auth.uid(), caller.full_name, 'subscription',
    caller.full_name || ' requested an individual teacher account',
    jsonb_build_object('plan', requested_plan)
  );

  return new_subscription_id;
end;
$$;

revoke all on function public.request_individual_subscription(public.subscription_plan) from public;
grant execute on function public.request_individual_subscription(public.subscription_plan) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Who am I
-- ─────────────────────────────────────────────────────────────

-- One call on app load: the profile, the organization, and whether the account
-- currently has access. Saves the client three round trips - which matters more
-- on a phone in a classroom than on a laptop.
create or replace function public.me()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'profile', to_jsonb(p) - 'updated_at',
    'organization', case when o.id is null then null else to_jsonb(o) - 'updated_at' end,
    'subscription', case when s.id is null then null else to_jsonb(s) end,
    'has_access', coalesce(public.fn_has_access(p.id), false)
  )
  from public.profiles p
  left join public.organizations o on o.id = p.organization_id
  left join public.v_effective_subscriptions s
    on (p.organization_id is not null and s.organization_id = p.organization_id)
    or (p.organization_id is null and s.profile_id = p.id)
  where p.id = auth.uid();
$$;

comment on function public.me is
  'Everything a client needs on load: profile, organization, subscription and whether access is currently granted.';

revoke all on function public.me() from public;
grant execute on function public.me() to authenticated;
