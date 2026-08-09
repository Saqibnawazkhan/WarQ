-- Warq · M1 · Bootstrapping the first platform administrator
--
-- Two safeguards make a Main Admin impossible to create through the product,
-- which is correct — and which leaves the platform with no administrator at all.
-- This migration provides the one deliberate way in.
--
--   * The sign-up trigger refuses to read `main_admin` from client metadata.
--   * The profile guard refuses to let anyone change a role.
--
-- Both stay. What changes is that they no longer apply to the database owner and
-- the service role, neither of which is a browser and both of which already
-- bypass row-level security entirely — guarding them added the appearance of
-- protection, not the fact of it.

-- ─────────────────────────────────────────────────────────────
-- Exempt trusted database roles from the field guards
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_guard_profile_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- `postgres` is the SQL editor and migrations; `service_role` is the worker.
  -- An authenticated end user is never either of these.
  if public.is_main_admin() or current_user in ('postgres', 'service_role', 'supabase_admin') then
    return new;
  end if;

  if new.role is distinct from old.role then
    raise exception 'Roles are assigned by the platform administrator.';
  end if;

  if new.organization_id is distinct from old.organization_id then
    raise exception 'Organization membership changes by invitation or removal, not by editing a profile.';
  end if;

  if new.status is distinct from old.status and new.id = auth.uid() then
    raise exception 'You cannot change your own account status.';
  end if;

  return new;
end;
$$;

create or replace function public.fn_guard_organization_fields()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.is_main_admin() or current_user in ('postgres', 'service_role', 'supabase_admin') then
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

-- ─────────────────────────────────────────────────────────────
-- bootstrap_main_admin
-- ─────────────────────────────────────────────────────────────

-- Promotes an existing account to platform administrator.
--
-- Runs exactly once in the life of the platform: it refuses if an administrator
-- already exists, so it cannot be used to quietly add a second one later.
-- Further administrators are added by an existing administrator, on the record.
create or replace function public.bootstrap_main_admin(admin_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.profiles;
begin
  if exists (select 1 from public.profiles where role = 'main_admin') then
    raise exception 'A platform administrator already exists.'
      using hint = 'Additional administrators are added by an existing administrator.';
  end if;

  select * into target from public.profiles where email = lower(trim(admin_email));

  if target.id is null then
    raise exception 'No account found for %.', lower(trim(admin_email))
      using hint = 'Create the account first, through the sign-up page or the Authentication tab.';
  end if;

  -- A Main Admin belongs to the platform, not to a tenant, and holds no
  -- subscription of their own. Clear both, or the profile constraints will
  -- reject the change.
  delete from public.subscriptions where profile_id = target.id;

  update public.profiles
  set role = 'main_admin',
      organization_id = null,
      status = 'active'
  where id = target.id;

  insert into public.activity_logs (organization_id, actor_id, actor_name, type, message)
  values (
    null, target.id, target.full_name, 'admin',
    target.full_name || ' was made platform administrator'
  );

  return 'Done. ' || target.email || ' is now the platform administrator. Sign out and back in.';
end;
$$;

comment on function public.bootstrap_main_admin is
  'One-shot: promotes an existing account to platform administrator, and refuses once one exists. Run from the SQL editor.';

-- Never callable from a browser. The SQL editor and the worker connect as
-- trusted database roles and do not need this grant.
revoke all on function public.bootstrap_main_admin(text) from public;
revoke all on function public.bootstrap_main_admin(text) from authenticated;
revoke all on function public.bootstrap_main_admin(text) from anon;
