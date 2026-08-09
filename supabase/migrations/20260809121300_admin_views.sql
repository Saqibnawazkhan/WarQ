-- Warq · M2 · Views for the Main Admin dashboard
--
-- Each row the dashboard draws needs an organization, its subscription, its
-- derived status, its admin and its counts. Assembling that in the client would
-- mean four round trips per screen and a join written slightly differently on
-- web and on mobile. It belongs here.

-- ─────────────────────────────────────────────────────────────
-- v_admin_organizations
-- ─────────────────────────────────────────────────────────────

create view public.v_admin_organizations
with (security_invoker = true) as
select
  o.id,
  o.name,
  o.city,
  o.email,
  o.phone,
  o.status as account_status,
  o.requested_at,
  o.approved_at,
  o.created_at,

  admin.id as admin_profile_id,
  admin.full_name as admin_name,
  admin.email as admin_email,

  s.id as subscription_id,
  s.plan,
  s.status,
  s.stored_status,
  s.starts_at,
  s.ends_at,
  s.days_remaining,
  s.grants_access,

  (select count(*) from public.profiles p
    where p.organization_id = o.id and p.role = 'teacher') as teacher_count,
  (select count(distinct cs.student_id)
    from public.class_students cs
    join public.classes c on c.id = cs.class_id
    where c.organization_id = o.id
      and c.archived_at is null
      and cs.unenrolled_at is null) as student_count,
  (select count(*) from public.classes c
    where c.organization_id = o.id and c.archived_at is null) as class_count
from public.organizations o
left join public.profiles admin on admin.id = o.owner_profile_id
left join public.v_effective_subscriptions s on s.organization_id = o.id;

comment on view public.v_admin_organizations is
  'One row per organization with its subscription, derived status, admin and counts. Backs the Organizations table and its detail drawer.';

-- ─────────────────────────────────────────────────────────────
-- v_admin_individual_teachers
-- ─────────────────────────────────────────────────────────────

-- A teacher with no organization holds their own subscription. These are the
-- accounts on the Main Admin's Individual Teachers page.
create view public.v_admin_individual_teachers
with (security_invoker = true) as
select
  p.id,
  p.full_name,
  p.email,
  p.phone,
  p.status as account_status,
  p.created_at,

  s.id as subscription_id,
  s.plan,
  s.status,
  s.starts_at,
  s.ends_at,
  s.days_remaining,
  s.grants_access,

  (select count(*) from public.classes c
    where c.teacher_id = p.id and c.archived_at is null) as class_count,
  (select count(*) from public.students st
    where st.teacher_id = p.id) as student_count
from public.profiles p
left join public.v_effective_subscriptions s on s.profile_id = p.id
where p.role = 'teacher' and p.organization_id is null;

comment on view public.v_admin_individual_teachers is
  'Teachers who hold their own subscription rather than belonging to an organization.';

-- ─────────────────────────────────────────────────────────────
-- v_admin_org_admins
-- ─────────────────────────────────────────────────────────────

create view public.v_admin_org_admins
with (security_invoker = true) as
select
  p.id,
  p.full_name,
  p.email,
  p.phone,
  p.status as account_status,
  p.created_at,
  o.id as organization_id,
  o.name as organization_name,
  o.city,
  s.status as subscription_status,
  s.plan,
  s.ends_at,
  -- True when this person is the organization's registered owner. An
  -- organization can outlive its admin, so the two are not the same thing.
  (o.owner_profile_id = p.id) as is_owner
from public.profiles p
join public.organizations o on o.id = p.organization_id
left join public.v_effective_subscriptions s on s.organization_id = o.id
where p.role = 'org_admin';

comment on view public.v_admin_org_admins is
  'Organization administrators, with the organization each one runs.';

-- ─────────────────────────────────────────────────────────────
-- v_admin_subscriptions
-- ─────────────────────────────────────────────────────────────

-- Every subscription on the platform, whoever holds it, in one list. Backs the
-- Subscriptions page and the Expiring Subscriptions page — the latter is this
-- filtered to status = 'expiring_soon', ordered by days remaining.
create view public.v_admin_subscriptions
with (security_invoker = true) as
select
  s.id,
  s.plan,
  s.status,
  s.stored_status,
  s.starts_at,
  s.ends_at,
  s.days_remaining,
  s.grants_access,
  s.price_cents,
  s.currency,
  s.created_at,
  case when s.organization_id is null then 'individual_teacher' else 'organization' end as kind,
  s.organization_id,
  s.profile_id,
  coalesce(o.name, p.full_name) as subject_name,
  coalesce(o.email, p.email) as subject_email,
  o.city
from public.v_effective_subscriptions s
left join public.organizations o on o.id = s.organization_id
left join public.profiles p on p.id = s.profile_id;

comment on view public.v_admin_subscriptions is
  'Every subscription with its subject resolved, whether that subject is an organization or an individual teacher.';
