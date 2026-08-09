-- Warq · M1 · Sign-up completed in one step
--
-- The previous trigger created a profile and left the organization or the
-- subscription to a follow-up call from the client. That only works if the user
-- is signed in the instant they register — which is false whenever email
-- confirmation is switched on, and leaves a half-registered account behind.
--
-- Creating everything inside the trigger makes registration atomic: either the
-- account, the organization and the pending subscription all exist, or none of
-- them do. It also works identically whether confirmation is on or off.

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  signup_kind text := coalesce(meta->>'signup_kind', 'invited_teacher');
  requested_plan public.subscription_plan;
  resolved_name text;
  new_org_id uuid;
  new_subscription_id uuid;
begin
  resolved_name := coalesce(
    nullif(trim(meta->>'full_name'), ''),
    split_part(new.email, '@', 1)
  );

  -- A plan is only meaningful for the two self-service paths. An invited teacher
  -- is covered by their organization's subscription.
  begin
    requested_plan := coalesce(nullif(meta->>'plan', ''), 'monthly')::public.subscription_plan;
  exception when others then
    requested_plan := 'monthly';
  end;

  -- ── An organization registering itself ──────────────────────
  if signup_kind = 'organization' then
    if coalesce(trim(meta->>'organization_name'), '') = ''
       or coalesce(trim(meta->>'city'), '') = '' then
      raise exception 'An organization account needs an organization name and a city.';
    end if;

    insert into public.organizations (name, city, email, phone, status)
    values (
      trim(meta->>'organization_name'),
      trim(meta->>'city'),
      lower(new.email),
      nullif(meta->>'phone', ''),
      'pending'
    )
    returning id into new_org_id;

    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'org_admin', new_org_id, 'pending'
    );

    update public.organizations set owner_profile_id = new.id where id = new_org_id;

    -- Pending, undated, granting nothing until a Main Admin approves it.
    insert into public.subscriptions (organization_id, plan, status)
    values (new_org_id, requested_plan, 'pending')
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (new_subscription_id, 'requested', requested_plan, 'Organization account requested');

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      trim(meta->>'organization_name') || ' requested an organization account',
      jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
    );

  -- ── An independent teacher registering themselves ───────────
  elsif signup_kind = 'individual_teacher' then
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'teacher', null, 'pending'
    );

    insert into public.subscriptions (profile_id, plan, status)
    values (new.id, requested_plan, 'pending')
    returning id into new_subscription_id;

    insert into public.subscription_events (subscription_id, action, plan, note)
    values (new_subscription_id, 'requested', requested_plan, 'Individual teacher account requested');

    insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
    values (
      null, new.id, resolved_name, 'subscription',
      resolved_name || ' requested an individual teacher account',
      jsonb_build_object('plan', requested_plan)
    );

  -- ── A teacher arriving through an invitation ────────────────
  else
    -- No organization and no subscription yet. accept_invitation() attaches both
    -- once they present their token, so an unused invitation leaves no trace.
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
      'teacher', null, 'pending'
    );
  end if;

  return new;
end;
$$;

comment on function public.fn_handle_new_user is
  'Creates the profile and, for self-service sign-ups, the organization and pending subscription - atomically, and independent of whether email confirmation is enabled. Never mints a main_admin: the role is chosen here, not read from client metadata.';

-- The two RPCs this replaces are no longer reachable from any sign-up path.
-- Dropped rather than left in place: an unused privileged function is a
-- liability, not a convenience.
drop function if exists public.request_organization(text, text, text, text, public.subscription_plan);
drop function if exists public.request_individual_subscription(public.subscription_plan);
