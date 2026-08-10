# WarQ · platform admin

The dashboard for running WarQ itself: every organization and independent
teacher on the platform, their subscriptions, and the audit trail.

Not for teachers. They and their organization admins use the mobile app; this
is the console behind it. Sign-in refuses any account that is not a platform
administrator, and every view it reads is behind `is_main_admin()` in the
database, so the check in the browser is a courtesy rather than the protection.

## Running it

```
npm install
npm run dev      # http://localhost:5173
npm run build    # production bundle into dist/
```

It talks to the same Supabase project as the mobile app, so anything approved
or suspended here takes effect on a teacher's phone immediately.

To point it at a different project, set `VITE_SUPABASE_URL` and
`VITE_SUPABASE_ANON_KEY`. The committed defaults are the production project's
publishable key, which is public by design — it identifies the project, not the
caller. The service-role key bypasses row-level security entirely and must never
appear in this directory.

## The first administrator

There is no sign-up here on purpose: an administration console that lets people
enrol themselves is not one. The first administrator is promoted once, by hand,
from an account that already exists:

```sql
select public.bootstrap_main_admin('you@example.com');
```

Run it in the Supabase SQL editor. It refuses if an administrator already
exists, so it cannot be used quietly a second time.

## What each page is for

| Page | Answers |
| --- | --- |
| Overview | Is anybody waiting on me, and is anything about to lapse |
| Pending requests | Who is asking to be let in |
| Organizations | Every institution, its admin, its counts, its subscription |
| Individual teachers | Teachers subscribing directly, with no organization |
| Subscriptions | Everything, soonest to expire first |
| Activity | The append-only audit trail |

## Notes

Subscriptions are only ever changed through the database functions
(`approve_subscription`, `reject_subscription`, `suspend_subscription`,
`reactivate_subscription`, `renew_subscription`). Each one checks the caller is
an administrator and writes its own `subscription_events` row, so the audit
trail cannot be sidestepped by writing to the table directly — and this
dashboard never does.
