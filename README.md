# Warq

Education management for teachers and institutions — attendance, marks, grades and reports, on the web and on a phone, backed by one database.

Warq serves three roles. A **Main Admin** runs the platform: organizations, individual teachers, subscriptions and approvals. An **Organization Admin** runs one institution: its teachers, classes and student records. A **Teacher** runs their own classes: roll call, assessments, marks and reports.

| Role               | Web | Mobile  | Lands on   |
| ------------------ | --- | ------- | ---------- |
| Main / SaaS Admin  | Yes | Blocked | `/admin`   |
| Organization Admin | Yes | Yes     | `/org`     |
| Teacher            | Yes | Yes     | `/teacher` |

---

## Getting started

Requires **Node 22** (see `.nvmrc`) and npm 10 or newer.

```bash
npm install          # installs every workspace
npm run verify       # lint, typecheck, test and build — what CI runs
npm run dev          # web app on http://localhost:5173
```

Useful single steps:

```bash
npm run build                      # build every package
npm run test                       # run every test suite
npm run format                     # apply Prettier
npm run dev -w @warq/web           # just the web app
npm run dev -w @warq/worker        # just the worker, on :8080
```

Copy `.env.example` to `.env` before running anything that talks to Supabase. Real
values live in Vercel, Railway and Expo — never in the repository.

---

## Layout

```
apps/
  web/        React 19 + Vite + Tailwind 4 — all three dashboards      → Vercel
  worker/     Fastify + scheduled jobs, PDF rendering, notifications   → Railway
  mobile/     Expo — Teacher and Organization Admin              (from M5)
packages/
  core/       domain model: roles, subscriptions, grading, attendance
  tokens/     the palette, type scale and shape language
  data/       typed Supabase client and query hooks                (from M1)
supabase/
  migrations/ schema, views and row-level security as versioned SQL (from M1)
  functions/  edge functions                                      (from M1)
design/       the approved mockups, kept as the reference source
docs/         plan, data model, access rules, design system
```

### Why the shared packages exist

Grading, attendance arithmetic and the subscription state machine must behave
identically on a laptop and on a phone. They live in `@warq/core` — no I/O, no
framework, fully tested — and both apps import them rather than reimplementing
them. `@warq/tokens` does the same for colour, type and spacing: it compiles to a
Tailwind theme for web and to a StyleSheet theme for native, from one source.

---

## Where the build is

| Milestone | Delivers                                  | State   |
| --------- | ----------------------------------------- | ------- |
| M0        | Foundation — monorepo, tokens, core, CI   | Shipped |
| M1        | Supabase schema, row-level security, auth | Next    |
| M2        | Main Admin web dashboard                  | Planned |
| M3        | Organization Admin web dashboard          | Planned |
| M4        | Teacher web dashboard                     | Planned |
| M5        | Mobile — Teacher                          | Planned |
| M6        | Mobile — Organization Admin               | Planned |
| M7        | Notifications and lifecycle automation    | Planned |
| M8        | Reports and PDF generation                | Planned |
| M9        | Realtime cross-platform sync              | Planned |
| M10       | Hardening and release                     | Planned |

Full detail in [`docs/PLAN.md`](docs/PLAN.md).

---

## Deployment

- **Supabase** — Postgres, authentication, realtime and storage. The single source of truth.
- **Vercel** — the web app. `vercel.json` at the repository root builds `@warq/web` through Turborepo and rewrites unknown paths to `index.html` for client-side routing.
- **Railway** — the worker. Built from `apps/worker/Dockerfile` at the repository root so the shared packages come along; health check on `/health`.

---

## Conventions

- **TypeScript everywhere**, strict, with `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes` on.
- **Zod at every boundary.** Types vanish at runtime; a form submit or an API payload is validated, not trusted.
- **Calendar dates are `YYYY-MM-DD` strings**, never timestamps. A subscription that ends on 15 August ends on that date everywhere. Arithmetic runs in UTC in `@warq/core`.
- **Errors say what to do next**, not only what went wrong.
- **Never commit secrets.** `.env` is ignored; `.env.example` documents every key.

### Notes on pinned versions

- **TypeScript is pinned to 6.0.3.** TypeScript 7 is released, but `typescript-eslint@8` still declares `typescript <6.1.0`. Move both together once the linter supports it.
- **Fonts load from Google Fonts in M0** so the preview matches the mockups. M2 replaces this with self-hosted `woff2` files and removes the third-party request.

---

## Design source

`design/` holds the approved mockups exactly as delivered — the Main Admin web
dashboard, the Organization Admin web dashboard, and the mobile app covering both
Teacher and Organization Admin. They are the reference for every screen, and the
fixtures inside them become the seed data. Treat them as read-only.

Run `npm run dev -w @warq/web` and open `/design` to see the tokens rendered:
palette, type scale, status pills, buttons, filters, the attendance toggle and
the grade bands — all generated from `@warq/tokens`, so the page cannot drift
from what the product uses.
