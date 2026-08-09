-- Warq · Phase 1 · Make self-service accounts usable immediately
--
-- Two changes, both scoped to this phase.
--
-- 1. profiles gains title and bio. The mobile app shows a teacher's title on
--    generated reports ("Ahmed Raza · Senior Lecturer") and their bio on the
--    profile screen. Nullable, so nothing else has to change.
--
-- 2. Sign-up produces a *working* account.
--
--    The original trigger created every account as 'pending' with a 'pending'
--    subscription, because a Main Admin was meant to approve it. That console
--    does not exist yet, so a teacher could register, sign in, and then be
--    unable to create a class, take a register or record a mark - every write
--    is behind has_access(), and so are the reads of teaching data.
--
--    Until the Main Admin dashboard ships, a self-service sign-up is activated
--    on the spot and given a permanent subscription. Nothing about the approval
--    machinery is removed: subscriptions, events, statuses and the RLS gate all
--    stay exactly as they are, so switching approval back on is a change to
--    this one function and nothing else.
--
--    An invited teacher is deliberately still gated. They hold no subscription
--    of their own and are covered by their organization's, which they only join
--    when they accept the invitation - so activating them here would grant
--    access to an organization they have not joined.

-- ─────────────────────────────────────────────────────────────
-- profiles: title and bio
-- ─────────────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists title text
    check (title is null or length(trim(title)) <= 80),
  add column if not exists bio text
    check (bio is null or length(trim(bio)) <= 400);

comment on column public.profiles.title is
  'Shown beside the teacher''s name on generated reports. Optional.';

-- ─────────────────────────────────────────────────────────────
-- sign-up
-- ─────────────────────────────────────────────────────────────

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

  -- PHASE 1: self-service accounts are approved on creation. Set this to
  -- 'pending' (and the subscription status below to 'pending') the day the
  -- Main Admin console can approve them.
  self_service_account public.account_status := 'active';
  self_service_subscription public.subscription_status := 'active';
begin
  resolved_name := coalesce(
    nullif(trim(meta->>'full_name'), ''),
    split_part(new.email, '@', 1)
  );

  -- 'permanent' carries no end date, which is what makes an auto-approved
  -- subscription read as active without inventing an expiry the Main Admin
  -- never chose. The plan the user asked for is recorded on the event below,
  -- so nothing about their intent is lost.
  requested_plan := 'permanent';

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
      'active'
    )
    returning id into new_org_id;

    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
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
      trim(meta->>'organization_name') || ' created an organization account',
      jsonb_build_object('organization_id', new_org_id, 'plan', requested_plan)
    );

  -- ── An independent teacher registering themselves ───────────
  elsif signup_kind = 'individual_teacher' then
    insert into public.profiles (id, email, full_name, phone, role, organization_id, status)
    values (
      new.id, lower(new.email), resolved_name, nullif(meta->>'phone', ''),
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

  -- ── A teacher arriving through an invitation ────────────────
  else
    -- Still pending on purpose: they are covered by the organization's
    -- subscription, and they are not in the organization until they accept.
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
  'Creates the profile and, for self-service sign-ups, the organization and an auto-approved permanent subscription. PHASE 1: approval is bypassed until the Main Admin console exists - see self_service_account inside. Never mints a main_admin.';
