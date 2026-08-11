-- Warq · Invited teachers get an account and a password by email
--
-- Until now an invitation was only a row. The organization admin had to tell
-- the teacher out of band to go and register with exactly the right address,
-- and if they used a different one they landed outside the organization.
--
-- The teacher now receives an email with a temporary password and signs in
-- directly. Creating an auth account needs the service-role key, so the work
-- happens in the invite-teacher edge function; this migration is the part the
-- database owns.
--
-- ── Why the password is temporary ────────────────────────────
--
-- A password sent by email is a password written down somewhere nobody
-- controls: mail is not encrypted at rest, it stays in the mailbox for years,
-- and whoever reads that mailbox later can sign in. The exposure cannot be
-- removed, so it is bounded instead — the teacher must set their own password
-- the first time they sign in, and until they do, the one from the email is the
-- only thing it can be used for.

alter table public.profiles
  add column if not exists must_change_password boolean not null default false;

comment on column public.profiles.must_change_password is
  'Set when an account is created with a password somebody else chose. The apps refuse to go anywhere but the change-password screen until it is cleared.';

-- ─────────────────────────────────────────────────────────────
-- fn_password_changed
-- ─────────────────────────────────────────────────────────────

-- Called by the app immediately after a successful password change.
--
-- Deliberately takes no argument and trusts nothing from the client: it clears
-- the flag for the caller and nobody else, so the worst a tampered client can
-- do is clear its own.
create or replace function public.fn_password_changed()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set must_change_password = false
  where id = auth.uid();
end;
$$;

grant execute on function public.fn_password_changed() to authenticated;

-- ─────────────────────────────────────────────────────────────
-- me()
-- ─────────────────────────────────────────────────────────────

-- The apps decide where to send someone from the answer to me(), so the flag
-- has to travel with it. Rewritten whole rather than patched, because the
-- function returns one jsonb object built in one statement.
--
-- v_ prefix on the variable: activity_logs has a column called meta, and a
-- variable of that name is ambiguous inside any statement that puts the table's
-- columns in scope. Postgres only reports it at run time.
create or replace function public.me()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
  v_org public.organizations;
  v_sub jsonb;
begin
  select * into v_profile from public.profiles where id = auth.uid();

  if v_profile.id is null then
    return jsonb_build_object('profile', null, 'has_access', false);
  end if;

  if v_profile.organization_id is not null then
    select * into v_org from public.organizations where id = v_profile.organization_id;
  end if;

  select to_jsonb(s) into v_sub
  from public.v_effective_subscriptions s
  where (v_profile.organization_id is not null and s.organization_id = v_profile.organization_id)
     or (v_profile.organization_id is null and s.profile_id = v_profile.id)
  limit 1;

  return jsonb_build_object(
    'profile', to_jsonb(v_profile),
    'organization', case when v_org.id is null then null else to_jsonb(v_org) end,
    'subscription', v_sub,
    'has_access', public.fn_has_access(v_profile.id)
  );
end;
$$;

grant execute on function public.me() to authenticated;
