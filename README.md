# EDU Manager

Classroom management for teachers and education organizations.

This repository is laid out as a monorepo so the planned React web application
can be added alongside the mobile app without restructuring anything.

```
WarQ_2.0/
├── mobile/     Flutter mobile app (Android + iOS) — Phase 1, this deliverable
├── docs/       Architecture and data-model notes
└── README.md
```

A `web/` directory (React) and a `backend/` directory will join this layout in
Phase 2. Nothing in `mobile/` needs to move when they do.

---

## Phase 1 — Flutter mobile application (delivered)

A complete, production-quality Flutter app for two roles:

| Role | What they get |
| --- | --- |
| **Teacher** | Classes, students, attendance, assessments, marks, grades, performance, PDF reports |
| **Organization Admin** | Teacher directory and monitoring, invitations, organization-wide classes and reports |

The Platform (SaaS) Admin console is **deliberately not built** — it belongs to
the Phase 2 React dashboard, as specified.

Everything runs on-device: there is no backend in this phase, so the app is
fully usable offline the moment it launches.

### Run it

```bash
cd mobile
flutter pub get
flutter run            # attach an Android or iOS device/emulator
```

Sign in with a seeded demo account (they are listed on the sign-in screen):

| Account | Email | Password |
| --- | --- | --- |
| Individual teacher | `teacher@edu.com` | `password123` |
| Organization admin | `admin@edu.com` | `password123` |
| Organization teacher | `sarah@edu.com` | `password123` |

Or create a fresh teacher / organization account from the sign-up screen.

### Verify it

```bash
cd mobile
flutter analyze        # 0 issues
flutter test           # 115 tests
```

---

## Phase 2 — not started

The React web application, Main Admin dashboard, subscription and access
management are **out of scope for this phase** and have not been implemented.

The mobile app was built so that phase is a swap, not a rewrite:

* every screen talks to a repository **interface**, never an implementation;
* all persisted entities already carry backend-shaped ids, timestamps and
  foreign keys, and serialize to the JSON an API would return;
* the whole object graph is assembled in one file
  (`mobile/lib/app/app_dependencies.dart`) — pointing it at HTTP-backed
  repositories is the migration.

See [`docs/architecture.md`](docs/architecture.md) for the layer boundaries, the
entity model, and the concrete Phase 2 migration path.
