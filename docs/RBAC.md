# Warq — roles, permissions and platform access

The rule is stated once, in `packages/core/src/roles.ts`. Route guards, the
session guard and the database policies all read it from there, so they cannot
drift apart.

---

## Platform access

| Role               | Web | Mobile  | Lands on   |
| ------------------ | --- | ------- | ---------- |
| Main / SaaS Admin  | Yes | Blocked | `/admin`   |
| Organization Admin | Yes | Yes     | `/org`     |
| Teacher            | Yes | Yes     | `/teacher` |

A Main Admin manages the whole estate from a desk. The mobile app has no
administrator surface, and that is deliberate rather than incidental.

---

## Enforced in three places

Hiding a route is not security. A determined request skips the interface
entirely, so the same rule is applied at three depths.

### 1. Route guard — the client

The mobile app has no Main Admin screen compiled into its bundle. Each app's
router checks the role claim and redirects anything unexpected to that role's own
landing route. This layer exists for the honest user who mistyped a URL.

### 2. Session guard — the edge

Every client sends `x-client-platform: web` or `x-client-platform: mobile`. An
edge function refuses to mint a mobile session for a Main Admin and returns the
reason from `platformDenialReason()`:

> The Main Admin dashboard is web only. Sign in at the web address on a computer.

This layer exists for a request that bypasses the app.

### 3. Row-level security — the database

Every table filters on the caller's role and organization. This layer exists for
a request that bypasses everything else, and it is the one that actually
guarantees the boundary.

---

## Data scope

| Role                   | Can read                                                                                                | Can write                                                                       |
| ---------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| **Main Admin**         | Every organization, profile, subscription and platform activity log                                     | Organization and subscription state; reminder settings. **Not** student records |
| **Organization Admin** | Everything where `organization_id` matches their own                                                    | Teachers, invitations, organization settings, reports                           |
| **Teacher**            | Their own classes and everything hanging off them; their own organization's name and subscription state | Their own classes, students, attendance sessions and marks                      |

A Main Admin can see that Punjab College of IT has 312 students. They cannot see
who those students are, or their marks. Running the platform does not require
reading a child's report card.

---

## Policy helpers

Three SQL functions, used by every policy so the logic is written once:

```sql
auth_role()      -- user_role from the JWT claim
auth_org_id()    -- uuid or null from the JWT claim
is_main_admin()  -- auth_role() = 'main_admin'
```

A representative policy:

```sql
create policy "teachers read their own classes"
  on classes for select
  using (
    teacher_id = auth.uid()
    or (auth_role() = 'org_admin' and organization_id = auth_org_id())
  );
```

---

## The subscription gate

Access is not only about who you are — it is also about whether the account is
paid up. `fn_has_access(profile_id)` returns false when the governing
subscription is pending, expired or suspended, and it is applied in the policies
on every data table.

Two consequences worth stating plainly:

- **Expiring Soon still works.** Warning before cutting off is the entire point of the state.
- **A suspension by the Main Admin takes effect everywhere at once** — web, mobile, and any request in flight — because the block lives in the database, not in a screen.

---

## Claims

The JWT carries `role` and `organization_id`. Both are set from `profiles` by a
Supabase auth hook at sign-in, so a client cannot assert its own role by editing
a request. They are read by:

- the web and mobile routers, to choose a dashboard;
- the RLS helper functions, to scope every query;
- the worker, when acting on a user's behalf rather than with the service role.

---

## The secret key

`SUPABASE_SECRET_KEY` — the `sb_secret_…` key — bypasses row-level security
completely. It exists in exactly one place, the Railway worker, and is used only
for work that has no user behind it: nightly subscription transitions, reminder
dispatch, report rendering.

Everything else uses `SUPABASE_PUBLISHABLE_KEY`, which is safe in a browser and
on a phone precisely because the policies above still apply to it.

It is never in the web app, never in the mobile app, never in a CI log. The
worker's Fastify logger redacts `authorization` and `x-supabase-key` headers so
it cannot leak through a stack trace either.
