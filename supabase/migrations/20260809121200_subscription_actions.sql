-- Warq · M1 · Subscription lifecycle actions
--
-- Approve, reject, suspend, reactivate, renew, extend. Every button on the Main
-- Admin dashboard eventually calls one of these, and each mirrors the matching
-- function in @warq/core so the arithmetic cannot drift between the two.
--
-- All of them:
--   * refuse anyone who is not a platform administrator;
--   * move the subject's own status alongside the subscription, because an
--     approved subscription attached to a still-pending organization would
--     leave the account locked out by the very gate that was supposed to open;
--   * append to subscription_events, so the drawer's history panel and any
--     later question of "who did this" are answered from the record.

-- ─────────────────────────────────────────────────────────────
-- Where a plan's period ends. Mirrors periodEnd() in @warq/core.
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_period_end(
  plan public.subscription_plan,
  starts date
)
returns date
language sql
immutable
as $$
  select case plan
    when 'monthly' then (starts + interval '1 month')::date
    when 'yearly' then (starts + interval '1 year')::date
    else null
  end;
$$;

comment on function public.fn_period_end is
  'Adds one period. Postgres clamps 31 Jan + 1 month to 28 Feb, matching addMonths() in @warq/core.';

create or replace function public.fn_require_main_admin()
returns void
language plpgsql
stable
as $$
begin
  if not public.is_main_admin() then
    raise exception 'Only the platform administrator can do that.'
      using hint = 'Sign in with the Warq administrator account.';
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- approve_subscription
-- ─────────────────────────────────────────────────────────────

-- Activates a pending request and starts its first period today.
create or replace function public.approve_subscription(target_subscription uuid)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
  ends date;
  subject_name text;
begin
  perform public.fn_require_main_admin();

  select * into sub from public.subscriptions where id = target_subscription for update;
  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  if sub.status = 'active' then
    raise exception 'That subscription is already active.'
      using hint = 'Use renew_subscription to extend it.';
  end if;

  ends := public.fn_period_end(sub.plan, current_date);

  update public.subscriptions
  set status = 'active', starts_at = current_date, ends_at = ends
  where id = sub.id
  returning * into sub;

  -- Open the account itself, not just its subscription.
  if sub.organization_id is not null then
    update public.organizations
    set status = 'active', approved_at = coalesce(approved_at, now())
    where id = sub.organization_id
    returning name into subject_name;

    -- The organization admin, and any teacher already waiting on them.
    update public.profiles
    set status = 'active'
    where organization_id = sub.organization_id and status = 'pending';
  else
    update public.profiles set status = 'active' where id = sub.profile_id
    returning full_name into subject_name;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, from_date, to_date, actor_id, note)
  values (sub.id, 'approved', sub.plan, sub.starts_at, sub.ends_at, auth.uid(), 'Approved and activated');

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  select
    sub.organization_id, auth.uid(), p.full_name, 'subscription',
    'Approved ' || coalesce(subject_name, 'account') || ' · ' || sub.plan || ' subscription activated',
    jsonb_build_object('subscription_id', sub.id, 'ends_at', sub.ends_at)
  from public.profiles p where p.id = auth.uid();

  return sub;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- reject_subscription
-- ─────────────────────────────────────────────────────────────

create or replace function public.reject_subscription(
  target_subscription uuid,
  reason text default null
)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
  subject_name text;
begin
  perform public.fn_require_main_admin();

  select * into sub from public.subscriptions where id = target_subscription for update;
  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  -- Suspended rather than deleted: a rejected applicant who appeals should not
  -- have to be reconstructed from nothing.
  update public.subscriptions set status = 'suspended' where id = sub.id returning * into sub;

  if sub.organization_id is not null then
    update public.organizations set status = 'suspended' where id = sub.organization_id
    returning name into subject_name;
  else
    update public.profiles set status = 'suspended' where id = sub.profile_id
    returning full_name into subject_name;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  values (sub.id, 'rejected', sub.plan, auth.uid(), coalesce(reason, 'Rejected'));

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message, meta)
  select
    sub.organization_id, auth.uid(), p.full_name, 'subscription',
    'Rejected ' || coalesce(subject_name, 'account')
      || case when reason is null then '' else ' · ' || reason end,
    jsonb_build_object('subscription_id', sub.id)
  from public.profiles p where p.id = auth.uid();

  return sub;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- suspend / reactivate
-- ─────────────────────────────────────────────────────────────

create or replace function public.suspend_subscription(
  target_subscription uuid,
  reason text default null
)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
begin
  perform public.fn_require_main_admin();

  update public.subscriptions set status = 'suspended'
  where id = target_subscription
  returning * into sub;

  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  if sub.organization_id is not null then
    update public.organizations set status = 'suspended' where id = sub.organization_id;
  else
    update public.profiles set status = 'suspended' where id = sub.profile_id;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  values (sub.id, 'suspended', sub.plan, auth.uid(), coalesce(reason, 'Suspended'));

  return sub;
end;
$$;

-- Dates are untouched: a suspension pauses access, it does not consume the
-- period the customer paid for.
create or replace function public.reactivate_subscription(target_subscription uuid)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
begin
  perform public.fn_require_main_admin();

  update public.subscriptions set status = 'active'
  where id = target_subscription
  returning * into sub;

  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  if sub.organization_id is not null then
    update public.organizations set status = 'active' where id = sub.organization_id;
    update public.profiles set status = 'active'
    where organization_id = sub.organization_id and status = 'suspended';
  else
    update public.profiles set status = 'active' where id = sub.profile_id;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, actor_id, note)
  values (sub.id, 'reactivated', sub.plan, auth.uid(), 'Reactivated');

  return sub;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- renew_subscription
-- ─────────────────────────────────────────────────────────────

-- Adds one more period.
--
-- Runs from the current end date so renewing early loses no days; restarts from
-- today if the subscription has already lapsed, rather than granting a period
-- that is mostly spent. Mirrors renew() in @warq/core.
create or replace function public.renew_subscription(target_subscription uuid)
returns public.subscriptions
language plpgsql
security definer
set search_path = ''
as $$
declare
  sub public.subscriptions;
  anchor date;
begin
  perform public.fn_require_main_admin();

  select * into sub from public.subscriptions where id = target_subscription for update;
  if sub.id is null then
    raise exception 'No such subscription.';
  end if;

  if sub.plan = 'permanent' then
    update public.subscriptions set status = 'active', ends_at = null
    where id = sub.id returning * into sub;
  else
    anchor := case
      when sub.ends_at is null or sub.ends_at < current_date then current_date
      else sub.ends_at
    end;

    update public.subscriptions
    set status = 'active',
        starts_at = coalesce(starts_at, current_date),
        ends_at = public.fn_period_end(sub.plan, anchor)
    where id = sub.id
    returning * into sub;
  end if;

  if sub.organization_id is not null then
    update public.organizations set status = 'active' where id = sub.organization_id;
  else
    update public.profiles set status = 'active' where id = sub.profile_id;
  end if;

  insert into public.subscription_events (subscription_id, action, plan, from_date, to_date, actor_id, note)
  values (sub.id, 'renewed', sub.plan, sub.starts_at, sub.ends_at, auth.uid(), 'Renewed');

  return sub;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- Pending requests, for the approvals queue
-- ─────────────────────────────────────────────────────────────

create view public.v_pending_requests
with (security_invoker = true) as
select
  s.id as subscription_id,
  s.plan,
  s.created_at as requested_at,
  case when s.organization_id is null then 'individual_teacher' else 'organization' end as kind,
  s.organization_id,
  s.profile_id,
  coalesce(o.name, p.full_name) as subject_name,
  coalesce(o.email, p.email) as subject_email,
  o.city,
  o.phone,
  (select count(*) from public.profiles t
    where t.organization_id = s.organization_id and t.role = 'teacher') as teacher_count
from public.subscriptions s
left join public.organizations o on o.id = s.organization_id
left join public.profiles p on p.id = s.profile_id
where s.status = 'pending';

comment on view public.v_pending_requests is
  'Organizations and individual teachers awaiting approval. Backs the Pending Requests page and the dashboard queue.';

-- ─────────────────────────────────────────────────────────────
-- Grants
-- ─────────────────────────────────────────────────────────────

-- Callable from the app: each one checks is_main_admin() first, so the grant is
-- not the protection - the check inside is.
grant execute on function public.approve_subscription(uuid) to authenticated;
grant execute on function public.reject_subscription(uuid, text) to authenticated;
grant execute on function public.suspend_subscription(uuid, text) to authenticated;
grant execute on function public.reactivate_subscription(uuid) to authenticated;
grant execute on function public.renew_subscription(uuid) to authenticated;
