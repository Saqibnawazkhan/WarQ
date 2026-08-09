-- Warq · M1 · Access helper functions
--
-- Every row-level security policy is written in terms of these. The access rule
-- is therefore stated once: change it here and every table follows, rather than
-- editing forty policies and missing one.
--
-- All are `stable` and marked `security definer` where they must read tables the
-- caller cannot, with an empty search_path so a caller cannot shadow a table
-- name and change what the function sees.

-- ─────────────────────────────────────────────────────────────
-- Who is asking
-- ─────────────────────────────────────────────────────────────

-- The caller's role, read from their profile rather than from a client-supplied
-- claim. A client can put anything in a request header; it cannot put anything
-- in this table.
create or replace function public.auth_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid();
$$;

comment on function public.auth_role is
  'The caller''s role, read from profiles. Never trusts a client-supplied claim.';

-- The caller's organization. Null for a Main Admin and for an independent teacher.
create or replace function public.auth_org_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select organization_id from public.profiles where id = auth.uid();
$$;

comment on function public.auth_org_id is
  'The caller''s organization. Null for a Main Admin and for an independent teacher.';

create or replace function public.is_main_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'main_admin' from public.profiles where id = auth.uid()),
    false
  );
$$;

create or replace function public.is_org_admin_of(target_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select role = 'org_admin' and organization_id = target_org
      from public.profiles
      where id = auth.uid()
    ),
    false
  );
$$;

-- Does the caller own this class? The single question behind most teacher policies.
create or replace function public.owns_class(target_class uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.classes
    where id = target_class and teacher_id = auth.uid()
  );
$$;

-- Can the caller see this class at all — as its teacher, or as the admin of the
-- organization it belongs to?
create or replace function public.can_read_class(target_class uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.classes c
    join public.profiles p on p.id = auth.uid()
    where c.id = target_class
      and (
        c.teacher_id = auth.uid()
        or (p.role = 'org_admin' and c.organization_id = p.organization_id)
      )
  );
$$;

comment on function public.can_read_class is
  'A teacher sees their own classes; an org admin sees every class in their organization. A Main Admin sees neither - running the platform does not require reading a child''s marks.';

-- ─────────────────────────────────────────────────────────────
-- Subscription state
-- ─────────────────────────────────────────────────────────────

-- Mirrors EXPIRING_SOON_DAYS in packages/core/src/subscription.ts.
create or replace function public.fn_expiring_soon_days()
returns integer
language sql
immutable
as $$ select 14; $$;

-- The effective status: what the customer actually sees today.
--
-- Deliberately computed rather than stored. If it were a column, a missed cron
-- run would leave the platform granting access it should have withdrawn. The
-- logic mirrors effectiveStatus() in @warq/core exactly, and the two are tested
-- against the same mockup fixtures.
create or replace function public.fn_effective_subscription_status(
  plan public.subscription_plan,
  status public.subscription_status,
  ends_at date,
  as_of date default current_date
)
returns public.effective_subscription_status
language sql
immutable
as $$
  select case
    -- An administrator's decision outranks the calendar.
    when status = 'pending' then 'pending'::public.effective_subscription_status
    when status = 'suspended' then 'suspended'::public.effective_subscription_status
    when plan = 'permanent' then 'active'::public.effective_subscription_status
    -- Active but undated is a data fault. Treat it as not yet granted rather
    -- than handing out unbounded access.
    when ends_at is null then 'pending'::public.effective_subscription_status
    when ends_at < as_of then 'expired'::public.effective_subscription_status
    when ends_at - as_of <= public.fn_expiring_soon_days()
      then 'expiring_soon'::public.effective_subscription_status
    else 'active'::public.effective_subscription_status
  end;
$$;

comment on function public.fn_effective_subscription_status is
  'Derived on every read. Mirrors effectiveStatus() in @warq/core; both are tested against the same fixtures.';

-- ─────────────────────────────────────────────────────────────
-- The subscription gate
-- ─────────────────────────────────────────────────────────────

-- Whether an account is currently paid up.
--
-- Expiring soon still works: warning before cutting off is the entire point of
-- that state. Pending, expired and suspended do not.
--
-- Applied in the policies on every data table, which is what makes a Main Admin
-- suspension take effect everywhere at once - web, mobile, and any request in
-- flight - rather than merely greying out a screen.
create or replace function public.fn_has_access(target_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with subject as (
    select p.id as profile_id, p.organization_id, p.status as account_status
    from public.profiles p
    where p.id = target_profile
  ),
  governing as (
    -- An organization member is governed by the organization's subscription;
    -- an independent teacher by their own.
    select s.*
    from public.subscriptions s, subject
    where (subject.organization_id is not null and s.organization_id = subject.organization_id)
       or (subject.organization_id is null and s.profile_id = subject.profile_id)
    limit 1
  )
  select
    -- A suspended person is blocked regardless of what the organization has paid.
    (select account_status from subject) = 'active'
    and (
      -- A Main Admin belongs to the platform and holds no subscription.
      (select role from public.profiles where id = target_profile) = 'main_admin'
      or exists (
        select 1 from governing
        where public.fn_effective_subscription_status(plan, status, ends_at)
          in ('active', 'expiring_soon')
      )
    );
$$;

comment on function public.fn_has_access is
  'The subscription gate. False when the governing subscription is pending, expired or suspended - or when the person themselves is suspended.';

-- The caller's own access. What the policies actually call.
create or replace function public.has_access()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.fn_has_access(auth.uid()), false);
$$;

-- ─────────────────────────────────────────────────────────────
-- Grading, so a percentage means the same thing in SQL and in TypeScript
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_grade_for(
  percent numeric,
  target_org uuid default null
)
returns text
language sql
stable
as $$
  with scale as (
    select coalesce(
      (select bands from public.grade_scales where organization_id = target_org),
      (select bands from public.grade_scales where organization_id is null)
    ) as bands
  ),
  clamped as (select least(100, greatest(0, percent)) as p)
  select b.value->>'grade'
  from scale, clamped, jsonb_array_elements(scale.bands) with ordinality as b(value, ord)
  where clamped.p >= (b.value->>'min')::numeric
  order by b.ord
  limit 1;
$$;

comment on function public.fn_grade_for is
  'Mirrors gradeFor() in @warq/core. Uses the organization''s scale, falling back to the platform default.';

-- Whole-number percentage. Zero total scores zero rather than dividing by it.
create or replace function public.fn_percentage(obtained numeric, total numeric)
returns integer
language sql
immutable
as $$
  select case when coalesce(total, 0) <= 0 then 0 else round(obtained / total * 100)::integer end;
$$;
