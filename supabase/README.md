# Supabase

The single source of truth: Postgres with row-level security, authentication,
realtime and file storage. Everything in this directory lands in **M1**.

```
migrations/   schema, enums, views and RLS policies, as versioned SQL
functions/    edge functions — accept invitation, approve organization, session guard
seed.sql      the mockup fixtures, so a fresh database renders the designs
```

## Getting set up

Creating the project and collecting its credentials is a one-time job, written
up step by step in [`../docs/SUPABASE-SETUP.md`](../docs/SUPABASE-SETUP.md).

Once the project exists and `.env` is filled in:

```bash
npx supabase login
npx supabase link --project-ref <your-project-ref>
npx supabase db push                 # apply migrations
npx supabase db seed                 # load the fixtures
```

## Principles

- **Migrations are forward-only and versioned.** Never edit an applied migration; add another.
- **Every table has row-level security enabled**, with no exceptions and no "temporarily open" policies.
- **Policies use the shared helpers** — `auth_role()`, `auth_org_id()`, `is_main_admin()`, `fn_has_access()` — so the access rule is written once. See [`../docs/RBAC.md`](../docs/RBAC.md).
- **Derived state is not stored.** `expiring_soon` and `expired` are computed from dates on every read, so a missed cron run can never grant access it should have withdrawn. See [`../docs/DATA-MODEL.md`](../docs/DATA-MODEL.md).
