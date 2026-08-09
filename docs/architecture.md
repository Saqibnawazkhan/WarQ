# EDU Manager — architecture (Phase 1)

This document explains how the Flutter app in `mobile/` is put together and how
Phase 2 (React web + shared backend) plugs into it.

---

## 1. Layers

```
presentation/     Widgets and screen controllers. Knows nothing about storage.
      │  reads/writes through
      ▼
domain/           Services and computed value objects. Pure Dart, no Flutter UI.
      │  depends on repository interfaces only
      ▼
data/             Models, repository contracts, local implementations, storage.
      │
core/             Theme, routing, utils, errors — shared by everything above.
```

Two rules keep this honest:

1. **No screen imports a repository implementation.** Screens receive
   `AppDependencies`, which exposes only interfaces (`ClassRepository`, not
   `LocalClassRepository`).
2. **No widget does arithmetic.** Percentages, grades, attendance rates and
   grade distributions are computed once in `domain/services/` so the dashboard,
   the roster, the performance screen and the PDF can never disagree.

### Directory map

| Path | Contents |
| --- | --- |
| `lib/app/` | Composition root (`app_dependencies.dart`), root widget, role gate |
| `lib/core/constants/` | App constants and storage keys |
| `lib/core/theme/` | Colour palette, semantic theme extension, Material 3 themes, spacing scale |
| `lib/core/routing/` | Route names, typed route arguments, the route table |
| `lib/core/utils/` | Dates, formatting, validators, JSON readers, id generation |
| `lib/core/error/` | `AppFailure` — the single error type crossing the data boundary |
| `lib/data/models/` | Entity classes with `toJson`/`fromJson`/`copyWith` |
| `lib/data/local/` | Key-value abstraction, generic JSON collection store, database, change bus |
| `lib/data/repositories/` | Repository **contracts** |
| `lib/data/repositories/local/` | On-device implementations of those contracts |
| `lib/data/seed/` | Deterministic demo dataset |
| `lib/domain/entities/` | Computed value objects (performance, summaries, dashboards) |
| `lib/domain/services/` | Grading, analytics, absence notifications, reports |
| `lib/domain/services/pdf/` | PDF theme and the two report documents |
| `lib/presentation/state/` | One `ChangeNotifier` controller per screen |
| `lib/presentation/widgets/` | Reusable UI: cards, badges, charts, state views, dialogs |
| `lib/presentation/screens/` | Screens, grouped by role and feature |

---

## 2. Data model

Fifteen persisted collections, named and shaped the way the backend tables will
be.

| Entity | Key relationships | Notes |
| --- | --- | --- |
| `AppUser` | → `Organization` (nullable) | One table for all roles; `role` + `organizationId` drive visibility |
| `AuthCredential` | 1:1 `AppUser` | Salted SHA-256 digest. Disappears when the backend owns auth |
| `Organization` | owner → `AppUser` | Individual teachers simply have no organization |
| `SchoolClass` | → `AppUser` (teacher), → `Organization` | Only `name` is required |
| `Student` | → `AppUser` (owner), → `Organization` | Only `fullName` is required; every phone is optional |
| `ClassEnrollment` | `SchoolClass` ⇄ `Student` | Join table, so one student can sit in several classes |
| `AttendanceSession` | → `SchoolClass` | At most one per (class, calendar day) |
| `AttendanceRecord` | → session, → student | Carries `notified` so guardians are never messaged twice |
| `Assessment` | → `SchoolClass` | Quiz / assignment / midterm / final / presentation / project / custom |
| `AssessmentMark` | → assessment, → student | `marksObtained` is **nullable**: blank ≠ zero |
| `GradeScale` / `GradeBand` | → `Organization` (nullable) | Platform default plus optional per-organization scale |
| `Invitation` | → `Organization` | Email-keyed; accepted automatically at sign-up |
| `AppNotification` | → `AppUser` | In-app alerts |
| `OutboundMessage` | → student, class, attendance record | The guardian-message outbox |
| `ActivityLog` | → actor, → `Organization` | Append-only audit trail |

### Decisions worth knowing

**Students belong to teachers, not to classes.** Enrollment is a join row.
Removing a student from a class is a soft detach, so their attendance and marks
survive; deleting the *student* is the destructive operation, and it is behind a
separate confirmation.

**A blank mark is not a zero.** `AssessmentMark.marksObtained` is nullable and
ungraded assessments are excluded from *both* sides of the percentage. A quiz
nobody has marked yet cannot drag a class average towards zero. An explicitly
*absent* student does score zero, and is flagged as such in reports.

**Excused absences leave the denominator.** Attendance percentage is
`(present + late) / (present + absent + late)`. A sanctioned absence neither
helps nor hurts. With no assessable sessions the percentage is `null`, which the
UI renders as `—` instead of a misleading `0%`.

**Dates are calendar days.** Everything attendance-related is normalised to
local midnight, so a session cannot land on two days across a time-zone change.

---

## 3. State management

`provider` + one `ChangeNotifier` controller per screen, all extending
`BaseController`, which owns:

* the `idle → loading → ready | empty | error` state machine (`ViewStatus`);
* `guardLoad` / `guardAction`, which convert any thrown object into a message a
  teacher can read, and separate "page is loading" from "button is busy";
* `safeNotify`, so an async callback landing after a screen is popped is a
  no-op rather than a crash;
* subscriptions to the **data event bus**.

### The data event bus

Repositories emit a `DataEvent` after every write. Controllers subscribe to the
entities they render and reload themselves. This is why adding a student on the
class screen updates the dashboard counters, and why marking attendance in a
pushed route refreshes the class list underneath — without one god-provider and
without manual `setState` plumbing between screens.

### Provider scope

Long-lived providers (`AppDependencies`, `SessionController`,
`AppSettingsController`) are installed **above** `MaterialApp` so pushed routes
can reach them. Screen controllers are created by the screen itself. Pushed
routes therefore construct their own controller (the org-admin invite and
invitation screens do exactly this) — they stay in sync through the bus.

---

## 4. Notable subsystems

### Grading

`GradingService` is the only place a percentage becomes a letter. The default
scale is the one from the spec (A+ 90 / A 80 / B 70 / C 60 / D 50 / F 0). Bands
are sorted highest-first on construction, so `bandFor()` is a single top-down
scan whatever order a caller supplies. An organization admin can replace the
scale; every class in that organization re-grades immediately because nothing
caches a letter.

### Absence notifications

`AbsenceNotificationService` implements the rules the spec asks for:

* every recorded number — student, father, mother — receives a message;
* a recipient with **no** number is silently skipped, and the teacher gets one
  summary notification naming the students who could not be reached;
* a student already notified for that session is never messaged twice, so
  editing a saved sheet is safe.

Delivery goes through the `MessagingProvider` interface. Two implementations
ship:

| Provider | Behaviour |
| --- | --- |
| `WhatsAppMessagingProvider` (default) | Opens WhatsApp on a `wa.me` link with the message pre-filled; falls back to the SMS composer. No server, no API key, no per-message cost. |
| `QueuedMessagingProvider` | Records to the outbox and sends nothing. Used by tests and as a dry-run mode. |

`MessagingProvider.requiresUserAction` is what makes both shapes work through
one pipeline. WhatsApp can only open one chat at a time and needs the teacher to
press send, so it returns `true` and the absence pipeline *queues* the notices
for the dispatch sheet to hand over one at a time. A server-side gateway returns
`false` and everything is sent during the save.

`canReach` lets a provider reject an address it cannot use. A number stored as
`03001112222` is unusable without a dialling code, so the student is reported
alongside those with no number at all rather than being queued for a delivery
that would never happen. `PhoneNumber` does the E.164 normalisation, and the
default dialling code lives in `AppSettingsController` (Profile → Messaging),
which rebuilds the provider whenever it changes.

**Fully unattended WhatsApp** requires Meta's Cloud API: a permanent access
token, which must live on a server rather than in the APK, and message templates
approved by Meta for business-initiated conversations. That is a Phase 2
provider — one new class plus one line in `AppDependencies`, with no model,
repository or screen changes. Nothing outside `domain/services/messaging/` names
a vendor.

### PDF reports

`pdf` + `printing`, with no network access: reports use the fonts built into the
`pdf` package. Those cover Latin-1 only, so `PdfTheme.pdfText` folds typographic
characters (em dash, ellipsis, curly quotes) to ASCII — without it they render
as blanks in the printed file. Preview, print and share use the platform's own
sheets via `printing`; "save" writes into the app documents directory.

The student report is portrait; the class report is landscape and drops the
per-assessment matrix past ten assessments, where it stops being legible.

### Charts

Hand-drawn with `CustomPainter` (donut, trend line) and Material primitives
(bars). No charting dependency, so there is no third-party API to chase across
Flutter releases, and the charts inherit the app's semantic colours in both
light and dark mode.

---

## 5. Testing

115 tests, `flutter test`:

| Area | What is covered |
| --- | --- |
| `test/domain/grading_service_test.dart` | Every band boundary, weighted aggregation, distribution, ungraded exclusion |
| `test/domain/attendance_summary_test.dart` | Late counts as attended, excused leaves the denominator, null vs zero |
| `test/domain/analytics_service_test.dart` | Performance maths, at-risk flags, distinct student counts, dashboard emptiness |
| `test/domain/absence_notification_test.dart` | All numbers messaged, missing numbers skipped and reported, failures recorded, message wording |
| `test/domain/whatsapp_messaging_test.dart` | E.164 normalisation across formats, `wa.me` link construction, SMS fallback, queue-don't-send behaviour, unusable numbers |
| `test/domain/report_service_test.dart` | Both PDFs produce valid bytes, including the empty-data cases |
| `test/data/auth_repository_test.dart` | Sign-in, identical error for unknown-email and wrong-password, reset flow, invitation auto-join |
| `test/data/student_repository_test.dart` | A–Z ordering, multi-class enrollment, soft detach preserves history, delete cascades |
| `test/data/attendance_repository_test.dart` | Sheet round-trip, no duplicate sessions, newly-absent detection, filters |
| `test/data/assessment_repository_test.dart` | All assessment types, blank vs zero, mark bounds, total-marks guard |
| `test/data/organization_repository_test.dart` | Invitations, teacher removal preserving data, organization data isolation |
| `test/widget_test.dart` | Sign-in validation and errors, role-based routing, session restore, empty state |

Tests run against the **real** repositories and services; only the storage
engine (`InMemoryKeyValueStore`) and the messaging gateway are substituted. See
`test/helpers/test_harness.dart`.

### On-device integration tests

`integration_test/app_test.dart` — 9 tests, run on real hardware:

```bash
flutter test integration_test -d <device-id>
```

These use the **real** platform: actual `shared_preferences`, the real
filesystem through `path_provider`, and real PDF generation. They cover cold
start and persistence across a reload, sign-in and role routing for both roles,
opening a class and its A–Z roster, marking attendance end-to-end and verifying
it reached storage, the student performance screen, and writing both PDF
reports to disk.

They earn their keep: they are what caught the duplicate FAB hero tags, the
swallowed tap on student rows, and the full-screen bottom bar described below —
none of which reproduce in the widget-test harness.

> The suite clears app storage at the start of each test so the seeder produces
> a known dataset. Running it against a device leaves the app holding fresh
> demo data.

### Layout pitfalls these tests locked down

* **`ContentWidth` fills its height by default.** It is built on `Center`, which
  *expands* under bounded constraints. That is required for a scrollable page
  body (a `ListView` must be given a bounded height) but wrong inside
  `Scaffold.bottomNavigationBar`, where it stretched the save bar over the whole
  screen and pushed the confirmation snackbar off-screen. Pass
  `fillHeight: false` in any bounded, shrink-wrap context.
* **One gesture detector per card.** `AppCard` owns both `onTap` and
  `onLongPress`; nesting another `InkWell` in its child wins the gesture arena
  and silently swallows the tap.
* **Every `FloatingActionButton` needs an explicit `heroTag`.** Shell tabs stay
  alive in an `IndexedStack`, so two FABs sharing the default tag throw during
  any route transition.
* **Confirmations are shown after popping.** The messenger is captured before
  the async gap, the route is popped, then the snackbar is shown — so it lands
  on the destination screen rather than the one being dismissed.
* **Bottom sheets need an explicit height cap.** Passing `constraints` to
  `showModalBottomSheet` replaces the defaults wholesale, dropping the height
  limit; `AppSheet` therefore bounds itself so its `Flexible` body can scroll
  instead of running off the bottom of the screen with its actions unreachable.

---

## 6. Phase 2 migration path

When the backend and React app arrive:

1. **Add HTTP repositories.** Write `ApiClassRepository`, `ApiStudentRepository`
   and so on against the existing contracts in `lib/data/repositories/`. The
   local classes become the offline cache.
2. **Repoint the composition root.** `AppDependencies.bootstrap()` is the only
   file that names an implementation.
3. **Move authentication server-side.** `AuthRepository` already returns an
   `AppUser` and persists a session; swap the body for token exchange and delete
   `AuthCredential` + `PasswordHasher`.
4. **Wire access control.** `AccountStatus` already has `pending`, `suspended`
   and `removed`; `LocalAuthRepository.signIn` already refuses to sign in
   anything but `active` and already blocks `UserRole.mainAdmin` from the mobile
   app. Subscription checks slot into the same place.
5. **Connect messaging.** Implement `MessagingProvider` for the chosen gateway.

The JSON each model emits is the payload shape the API should return, so the
React app and the Flutter app can share one schema without a translation layer.
