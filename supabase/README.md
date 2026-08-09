# Supabase

The single source of truth: Postgres with row-level security, authentication,
realtime and file storage. Everything in this directory lands in **M1**.

```
migrations/   schema, enums, views and RLS policies, as versioned SQL
functions/    edge functions — accept invitation, approve organization, session guard
seed.sql      the mockup fixtures, so a fresh database renders the designs
```

## Getting set up (M1)

```bash
npm install -g supabase          # or: npx supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push                 # apply migrations
supabase db seed                 # load the fixtures
```

Copy the project URL and anon key into `.env` — see `.env.example`. The
service-role key belongs only in the Railway worker's environment.

## Principles

- **Migrations are forward-only and versioned.** Never edit an applied migration; add another.
- **Every table has row-level security enabled**, with no exceptions and no "temporarily open" policies.
- **Policies use the shared helpers** — `auth_role()`, `auth_org_id()`, `is_main_admin()`, `fn_has_access()` — so the access rule is written once. See [`../docs/RBAC.md`](../docs/RBAC.md).
- **Derived state is not stored.** `expiring_soon` and `expired` are computed from dates on every read, so a missed cron run can never grant access it should have withdrawn. See [`../docs/DATA-MODEL.md`](../docs/DATA-MODEL.md).
