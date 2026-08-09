-- Warq · M1 · Subscriptions
--
-- A subscription is held either by an organization or by an individual teacher,
-- never both. Only the administrative state is stored; whether a subscription is
-- expiring soon or expired is computed from its dates on every read.

-- ─────────────────────────────────────────────────────────────
-- subscriptions
-- ─────────────────────────────────────────────────────────────

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),

  organization_id uuid references public.organizations (id) on delete cascade,
  profile_id uuid references public.profiles (id) on delete cascade,

  plan public.subscription_plan not null,
  status public.subscription_status not null default 'pending',

  starts_at date,
  -- Null for a permanent plan, and for a request not yet approved.
  ends_at date,

  -- Modelled now so adding a payment gateway later is not a schema change.
  -- The Main Admin activates subscriptions by hand, as the mockups show.
  price_cents integer check (price_cents is null or price_cents >= 0),
  currency text not null default 'PKR' check (length(currency) = 3),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- Exactly one subject. An unowned subscription, or one owned twice, is a bug
  -- that would silently grant or withhold access.
  constraint one_subject check (
    (organization_id is not null and profile_id is null)
    or (organization_id is null and profile_id is not null)
  ),

  -- A permanent plan has no end date; a dated plan that is active must have one.
  constraint permanent_has_no_end check (plan <> 'permanent' or ends_at is null),
  constraint active_dated_plan_has_dates check (
    status <> 'active'
    or plan = 'permanent'
    or (starts_at is not null and ends_at is not null)
  ),
  constraint period_runs_forwards check (
    starts_at is null or ends_at is null or ends_at >= starts_at
  )
);

comment on table public.subscriptions is
  'Held by an organization or an individual teacher. status is administrative only; effective status is derived from dates.';
comment on column public.subscriptions.status is
  'What an administrator set. Never expiring_soon or expired - see fn_effective_subscription_status().';

-- One live subscription per subject. History belongs in subscription_events, not
-- in a pile of overlapping rows.
create unique index subscriptions_one_per_organization_idx
  on public.subscriptions (organization_id)
  where organization_id is not null;

create unique index subscriptions_one_per_profile_idx
  on public.subscriptions (profile_id)
  where profile_id is not null;

-- Serves the Main Admin's Expiring Subscriptions page and the nightly reminder job.
create index subscriptions_expiry_idx on public.subscriptions (ends_at)
  where status = 'active' and ends_at is not null;

create index subscriptions_status_idx on public.subscriptions (status, plan);

create trigger subscriptions_touch_updated_at
  before update on public.subscriptions
  for each row execute function public.fn_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- subscription_events
-- ─────────────────────────────────────────────────────────────

-- Append-only. Backs the "Subscription history" panel in the Main Admin drawer,
-- and answers "who extended this, and when" months later.
create table public.subscription_events (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions (id) on delete cascade,
  action public.subscription_action not null,
  plan public.subscription_plan not null,
  from_date date,
  to_date date,
  -- Null when the platform acted rather than a person, e.g. the nightly job.
  actor_id uuid references public.profiles (id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

comment on table public.subscription_events is
  'Append-only audit of every subscription decision. Never updated, never deleted.';

create index subscription_events_subscription_idx
  on public.subscription_events (subscription_id, created_at desc);

-- ─────────────────────────────────────────────────────────────
-- reminder_settings
-- ─────────────────────────────────────────────────────────────

-- Offsets must be positive, sane and free of duplicates: two notices on one day
-- reads as a malfunction, not as diligence.
--
-- Written as a function because Postgres forbids subqueries inside a CHECK
-- constraint, but permits a call to an immutable function that contains them.
create or replace function public.fn_reminder_days_valid(days integer[])
returns boolean
language sql
immutable
as $$
  select
    days is not null
    and array_length(days, 1) between 1 and 8
    and (select bool_and(d between 1 and 365) from unnest(days) as d)
    and array_length(days, 1) = (select count(distinct d) from unnest(days) as d);
$$;

comment on function public.fn_reminder_days_valid is
  'Reminder offsets: between one and eight of them, each 1-365 days, no duplicates.';

-- The 30 / 15 / 7 / 3 / 1 schedule from the Main Admin's Notifications page.
-- A single row, enforced by the check on id.
create table public.reminder_settings (
  id boolean primary key default true check (id),
  days integer[] not null default '{30,15,7,3,1}',
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now(),

  constraint days_are_valid check (public.fn_reminder_days_valid(days))
);

insert into public.reminder_settings (id) values (true);

comment on table public.reminder_settings is
  'Single row. Days before expiry at which a reminder is sent, as set on the Main Admin notifications page.';

-- ─────────────────────────────────────────────────────────────
-- reminder_logs
-- ─────────────────────────────────────────────────────────────

create table public.reminder_logs (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions (id) on delete cascade,
  days_before integer not null,
  channel public.notification_channel not null,
  message text not null,
  sent_at timestamptz not null default now()
);

comment on table public.reminder_logs is
  'One row per notice sent. Backs the sent log, and makes a duplicate send visible rather than invisible.';

-- The same reminder must not go out twice. If the nightly job runs twice, or is
-- retried after a partial failure, this index is what actually prevents it.
create unique index reminder_logs_once_per_step_idx
  on public.reminder_logs (subscription_id, days_before, channel);

create index reminder_logs_sent_at_idx on public.reminder_logs (sent_at desc);

alter table public.subscriptions enable row level security;
alter table public.subscription_events enable row level security;
alter table public.reminder_settings enable row level security;
alter table public.reminder_logs enable row level security;
