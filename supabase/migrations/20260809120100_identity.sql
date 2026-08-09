-- Warq · M1 · Identity and tenancy
--
-- Three tables carry every question of "who is this and what may they see":
-- organizations (the tenant), profiles (the person), invitations (how a teacher
-- joins one). Row-level security is enabled here and the policies land in a
-- later migration, so no window exists where a table is readable by everyone.

-- ─────────────────────────────────────────────────────────────
-- organizations
-- ─────────────────────────────────────────────────────────────

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 160),
  city text not null check (length(trim(city)) between 2 and 80),
  email text not null,
  phone text,
  status public.account_status not null default 'pending',

  -- The current Organization Admin. Nullable because an organization exists from
  -- the moment it is requested, and because the seat survives the person leaving.
  owner_profile_id uuid,

  requested_at timestamptz not null default now(),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.organizations is
  'An institution that has requested or holds a Warq subscription. The tenant boundary for every org-scoped table.';
comment on column public.organizations.owner_profile_id is
  'Current Organization Admin. Reassignable; the organization outlives any one admin.';

-- The Main Admin lists organizations filtered by status and searched by name or
-- city, which is exactly what these two indexes serve.
create index organizations_status_idx on public.organizations (status);
create index organizations_name_city_idx on public.organizations
  using gin (to_tsvector('simple', name || ' ' || city));

-- ─────────────────────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────────────────────

-- Extends auth.users, which Supabase owns. Everything Warq knows about a person
-- lives here; auth.users holds only the credentials.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  full_name text not null check (length(trim(full_name)) between 2 and 120),
  phone text,
  role public.user_role not null,

  -- Null for a Main Admin, and for an independent teacher who holds their own
  -- subscription. A teacher with no organization is an "individual teacher" and
  -- appears on the Main Admin's Individual Teachers page.
  organization_id uuid references public.organizations (id) on delete set null,

  status public.account_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- An Organization Admin without an organization would be an admin of nothing.
  constraint org_admin_needs_organization check (
    role <> 'org_admin' or organization_id is not null
  ),

  -- A Main Admin belongs to the platform, never to a tenant. Without this, one
  -- stray write would put a platform administrator inside an organization's
  -- row-level security scope.
  constraint main_admin_has_no_organization check (
    role <> 'main_admin' or organization_id is null
  )
);

comment on table public.profiles is
  'One row per person. Extends auth.users; auth.users holds credentials, this holds everything else.';
comment on column public.profiles.organization_id is
  'Null for a Main Admin and for an independent teacher. The tenant key for row-level security.';

create index profiles_organization_idx on public.profiles (organization_id)
  where organization_id is not null;
create index profiles_role_status_idx on public.profiles (role, status);

-- Deferred until profiles exists, since the two tables reference each other.
alter table public.organizations
  add constraint organizations_owner_fkey
  foreign key (owner_profile_id) references public.profiles (id) on delete set null;

-- ─────────────────────────────────────────────────────────────
-- invitations
-- ─────────────────────────────────────────────────────────────

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  email text not null,
  full_name text not null,

  -- Single-use and unguessable. Compared in full, never by prefix.
  token text not null unique default encode(extensions.gen_random_bytes(32), 'hex'),

  status public.invitation_status not null default 'sent',
  sent_via public.notification_channel not null default 'email',
  invited_by uuid references public.profiles (id) on delete set null,

  expires_at timestamptz not null default now() + interval '14 days',
  accepted_at timestamptz,
  accepted_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),

  -- An accepted invitation must record who accepted it and when.
  constraint accepted_is_complete check (
    status <> 'accepted' or (accepted_at is not null and accepted_by is not null)
  )
);

comment on table public.invitations is
  'A teacher invited to join an organization by email or WhatsApp. The token is single-use and expires.';

-- One live invitation per address per organization. Re-inviting someone should
-- resend rather than accumulate tokens that all still work.
create unique index invitations_one_live_per_email_idx
  on public.invitations (organization_id, lower(email))
  where status = 'sent';

create index invitations_organization_idx on public.invitations (organization_id, status);
create index invitations_token_idx on public.invitations (token) where status = 'sent';

-- ─────────────────────────────────────────────────────────────
-- updated_at maintenance
-- ─────────────────────────────────────────────────────────────

create or replace function public.fn_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.fn_touch_updated_at is
  'Keeps updated_at honest. A client cannot forget to set it, and cannot lie about it.';

create trigger organizations_touch_updated_at
  before update on public.organizations
  for each row execute function public.fn_touch_updated_at();

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.fn_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- Lock the doors before the policies arrive
-- ─────────────────────────────────────────────────────────────
--
-- With RLS enabled and no policy defined, these tables deny everything to
-- ordinary roles. Policies are added in 20260809120700_rls.sql. Enabling here
-- means there is no moment, even mid-migration, when a table is world-readable.

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.invitations enable row level security;
