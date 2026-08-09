# Warq — build plan

**Revision 1 · 9 August 2026**

From four approved mockups to a running multi-tenant SaaS: one database, three
roles, two platforms, eleven milestones.

---

## 1. Stack

Supabase ships its own managed Postgres, so Railway does not host a second
database. It hosts the work Supabase handles poorly: headless-Chrome PDF
rendering, scheduled subscription transitions, and outbound email and WhatsApp.

| Host         | Runs                                                                        | Why it is there                                                                   |
| ------------ | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| **Supabase** | Postgres with RLS, Auth, Realtime, Storage                                  | The single source of truth, and the place tenant boundaries are actually enforced |
| **Vercel**   | The React web app — Main Admin, Org Admin, Teacher                          | Production URL on every push to `main`, preview URL on every branch               |
| **Railway**  | Node worker: cron, PDF rendering, notification dispatch, service-role tasks | Long-running and privileged work that must never touch a client                   |
| **Expo/EAS** | The React Native app — Teacher and Org Admin                                | Real iOS and Android builds, sharing code with web through the monorepo           |

---

## 2. Repository

One monorepo so the logic is written once. Grading, attendance percentages, the
subscription state machine and the design tokens are identical on web and
mobile — they live in shared packages and get imported, not copied.

See the layout in the [README](../README.md#layout).

---

## 3. Access control

The platform restriction is enforced in three places, because hiding a route is
not security.

| Layer                  | What it does                                                                                                               |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Route guard**        | The mobile app has no Main Admin screen compiled into it. Each app's router redirects on an unexpected role claim.         |
| **Session guard**      | Clients send `x-client-platform`. An edge function refuses to mint a mobile session for a Main Admin, with a clear reason. |
| **Row-level security** | Every table filters on the caller's role and `org_id`. A suspended or expired subscription fails the same check.           |

The matrix itself lives in code, once, in `@warq/core/roles.ts`. Everything else
reads it from there. Detail in [`RBAC.md`](RBAC.md).

---

## 4. Data model

Every value in the mockups traces back to a table, and the fixtures inside them
become the seed data — so a fresh database renders exactly what was designed.
Detail in [`DATA-MODEL.md`](DATA-MODEL.md).

Rules carried over from the mockups:

- **Plans** — Monthly, Yearly, Permanent
- **Statuses** — Pending, Active, Expiring Soon, Expired, Suspended
- **Grades** — A+ ≥ 90, A ≥ 80, B ≥ 70, C ≥ 60, D ≥ 50, otherwise F. Configurable per organization; these are the default.
- **Attendance** — Present, Absent, Late. One session per class per day. Late does not count toward the attendance percentage.
- **Expiring soon** — within 14 days of the end date. Derived from the mockups, where an organization 7 days out and a teacher 10 days out are both flagged while a teacher 24 days out is not.

---

## 5. Milestones

Each is a branch, a review and a push. The order is a dependency chain, not a
preference.

### M0 — Foundation · shipped

Monorepo with Turborepo, strict TypeScript, ESLint and Prettier. `@warq/tokens`
and `@warq/core` extracted from the mockups with full test coverage. Mockups
committed to `design/`. CI running format, lint, typecheck, test and build.
Vercel and Railway configuration in place.

### M1 — Schema, security and authentication · Supabase

Every table, enum, view and RLS policy as versioned SQL. Seed data drawn from the
mockup fixtures. Sign-up for an organization request and an individual teacher
request, sign-in with role and tenant claims in the JWT, password reset, and the
role-based routing contract both apps follow.

### M2 — Main Admin web dashboard · Vercel

The full navigation from the specification, not only the four sections the mockup
shows: Dashboard, Organizations, Individual Teachers, Organization Admins,
Subscriptions, Pending Requests, Expiring Subscriptions, Notifications, Activity
Logs, Reports, Settings. Approve, reject, extend, renew, suspend, reactivate and
notify all writing to real records. **First shareable live URL.**

### M3 — Organization Admin web dashboard · Vercel

Dashboard, teachers with email and WhatsApp invitations, classes, students,
attendance review, marks and grades review, student performance, organization
reports, activity feed with filters, member management. Removing a teacher keeps
their historical records with the organization, as the mockup promises.

### M4 — Teacher web dashboard · Vercel

The access matrix gives teachers web access, but the mockups only cover them on
mobile. A responsive build from the same component set: classes, roster,
attendance marking, marks entry, student performance and report generation —
comfortable on a laptop rather than a phone layout stretched wide.

### M5 — Mobile · Teacher · Expo

Login with role routing, home, classes, class detail with Students and
Assessments tabs, attendance with Today and History, the P · A · L toggle,
All-present and save; marks entry with live grade calculation; student profile
with contacts and performance; notifications; and the action sheet behind the
centre button. Attendance is written locally first and synced on reconnect,
because classrooms lose signal.

### M6 — Mobile · Organization Admin · Expo

Organization dashboard, teachers with the invite sheet, teacher detail and
removal, classes, activity with filters, notifications. Same permissions as the
web dashboard, deliberately fewer screens.

### M7 — Notifications and lifecycle automation · Railway

The daily job that moves subscriptions between states and sends reminders at the
configured 30, 15, 7, 3 and 1 day offsets, writing each to the sent log. Absence
alerts to guardians the moment attendance is saved. Channel adapters for email,
WhatsApp and in-app, with a log-only adapter so development never messages a real
parent.

### M8 — Reports and PDF generation · Railway

Student, class, organization and platform reports — rendered with the same
typography as the app, stored in Supabase Storage, returned as a signed link.

### M9 — Realtime cross-platform sync · all

Both apps subscribe to their organization's channel and refresh the affected
queries: a teacher invited on web shows up on the phone, marks update while
someone watches, and a Main Admin suspension locks the organization everywhere at
once.

### M10 — Hardening and release · all

Unit tests over grading, attendance arithmetic and the subscription state
machine; end-to-end tests for each role's login-to-dashboard path; tests that
prove the RLS policies actually deny; a security review; an accessibility pass;
error boundaries and rate limits; EAS builds for TestFlight and Play internal
testing.

---

## 6. Working agreement

- A branch per milestone — `feat/m2-main-admin-web` — with conventional commits.
- A push after every working slice, not only at the end of a milestone. Each push redeploys the Vercel preview.
- Review at each milestone boundary: a live URL or an Expo Go link before the next one starts.
- Secrets never enter the repository. `.env.example` documents every key; real values live in Vercel, Railway and Expo.

---

## 7. Assumptions

The mockups are silent on these. The reversible option was taken in each case.

| Question                     | Assumption                                                                                                                                                                                                     |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Payments**                 | Plans carry a price and currency in the schema, but no gateway is wired. The Main Admin activates subscriptions manually, as the mockups show. Stripe or a local processor drops in later without a migration. |
| **Organization Admins page** | Listing them separately from organizations implies independent management. One admin per organization, reassignable, with the seat kept if the person leaves.                                                  |
| **Grade scale**              | Hardcoded in the mockups; stored per organization instead, with the mockup's bands as the default. Institutions grade differently.                                                                             |
| **Academic session**         | "Session 2026" starts as a text field on a class. If per-term reporting is needed later it becomes a real entity — a contained change.                                                                         |
