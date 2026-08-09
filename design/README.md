# Design source — read only

The approved mockups, exactly as delivered. They are the reference for every
screen in Warq, and the fixtures inside them become the seed data.

**Do not edit these files.** They are excluded from linting, formatting and diffs
(`.gitattributes` marks them vendored). When a design changes, replace the file
and note what moved.

| File                               | Surface                              | Covers                                                                                                                                       |
| ---------------------------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `EDU Manager Admin Web.dc.html`    | Main / SaaS Admin — web              | Dashboard, pending approvals, expiring soon, subscriptions by plan, organizations table with filters and detail drawer, individual teachers, expiry reminder schedule and sent log |
| `EDU Manager Org Web.dc.html`      | Organization Admin — web             | Dashboard, teacher activity, weekly attendance chart, teachers table, invite modal, classes, activity feed with filters, teacher drawer, remove confirmation |
| `EDU Manager Mobile.dc.html`       | Teacher **and** Org Admin — mobile   | Login with role toggle, teacher home, classes, class detail, attendance with history, marks entry, student performance, notifications, action sheet — plus the organization dashboard, teachers, classes and activity |
| `EDU Manager Mobile-print.dc.html` | Storyboard                           | The twelve-page screen inventory                                                                                                              |
| `ios-frame.jsx`, `support.js`, `doc-page.js` | Harness                    | The renderer the mockups run in                                                                                                               |

`EDU Manager Mobile App.html` and `EDU Manager Org Admin.html` are the
self-contained exports of the two interactive prototypes — open either directly
in a browser.

## What was extracted from them

- **`packages/tokens`** — the full palette, type scale, radii, shadows and motion timings.
- **`packages/core`** — the grade bands, the attendance rules, the subscription plans and statuses, and the date format.
- **`supabase/seed.sql`** (M1) — the seven organizations, six individual teachers, three classes, twenty-seven students and their assessment history.

Everything is dated against **8 August 2026**, the day the mockups are drawn on.
The seed keeps that date so every "Expiring Soon" badge matches the design.

## Where the mockups stop

Two parts of the specification have no mockup, and are being built from the same
component set:

- **Seven Main Admin sections** — Organization Admins, Subscriptions, Pending Requests, Expiring Subscriptions, Activity Logs, Reports and Settings (M2).
- **The Teacher web dashboard** — the access matrix grants it, but the mockups only cover teachers on mobile (M4).
