# EDU Manager — Flutter mobile app

Android and iOS app for teachers and organization admins. Phase 1: everything
runs on-device, no backend required.

```bash
flutter pub get
flutter run
flutter analyze                          # 0 issues
flutter test                             # 115 unit + widget tests
flutter test integration_test -d <id>    # 9 on-device tests (real storage + PDF)
flutter build apk --release              # installable APK
```

Verified on an Infinix X6886 (Android 15, arm64): release APK builds, installs
and passes the full on-device suite.

## Demo accounts

Seeded on first launch and listed on the sign-in screen. Two classes, ~30
students, six weeks of attendance and several graded assessments are created so
every screen has real data.

| Role | Email | Password |
| --- | --- | --- |
| Individual teacher | `teacher@edu.com` | `password123` |
| Organization admin | `admin@edu.com` | `password123` |
| Organization teacher | `sarah@edu.com` | `password123` |

Profile → *Reset demo data* restores this dataset at any time.

## What the teacher app does

**Dashboard** — total classes, total students, present/absent today, pending
attendance, recent classes, recent assessments, activity feed, and six quick
actions (create class, add student, mark attendance, create quiz, add marks,
generate report).

**Classes** — create, edit, archive, delete. Name is the only required field;
subject, section, session and description are optional. Deleting a class
cascades its attendance, assessments and marks but keeps the student records.

**Students** — add, edit, delete, search across all classes, enroll an existing
student into another class. Only the name is required; roll number and all three
phone numbers are optional. The roster is A–Z with letter headers, plus sorting
(name, roll number, attendance, performance) and quick filters (low attendance,
at risk, top performers, not graded). Each row shows name, roll number,
attendance %, overall % and grade.

**Attendance** — pick a date, everyone defaults to present, mark the exceptions,
save. Mark-all-present / mark-all-absent, four statuses (present, absent, late,
excused), unsaved-changes guard, and editing a past session. Full history with
class / student / date-range / status filters, grouped by day and expandable to
individual students.

**Absence notices via WhatsApp** — saving a sheet with absences prepares one
message per recorded number (student, father, mother) and opens a dispatch
sheet. Tapping **Send** on a row opens WhatsApp with that parent's chat and the
message already written; the row is ticked off when you come back. Students with
no usable number are skipped and listed. Anything you don't send stays in
**Notifications → Guardian messages** and can be sent later.

Numbers saved in national format (`03001112222`) need a default dialling code —
set it once in **Profile → Messaging**. Numbers already in international format
(`+92 300 …`) work without it. If WhatsApp cannot handle a number the app falls
back to the SMS composer.

**Assessments and marks** — quiz, assignment, midterm, final exam, presentation,
project, custom. Enter marks per student with live percentage and grade, mark a
student absent, add remarks, bulk-fill, and see grading progress. Percentages
and grades are automatic.

**Performance** — per-student screen with contact details, attendance donut,
marks progression line chart, per-assessment breakdown, totals, percentage and
grade.

**Reports** — individual student PDF and complete class PDF. Preview, print,
save to the device, or share through the system share sheet.

## What the organization admin app does

Dashboard (teachers, classes, students, attendance, weekly sessions, activity
feed), teacher directory with search, per-teacher monitoring (account details,
classes, attendance activity, assessment activity, grade distribution, recent
activity), read-only class and student views, organization-wide reports, teacher
invitations (create, track, revoke, resend) and teacher removal with a
confirmation dialog that preserves the teacher's data.

Every query is scoped to the admin's own organization.

## Notes

* **Grading** — default scale A+ 90 / A 80 / B 70 / C 60 / D 50 / F 0. An
  organization admin can customise the bands and the pass mark; individual
  teachers use the platform default.
* **Attendance maths** — `(present + late) / (present + absent + late)`. Excused
  sessions are excluded. No data shows `—`, never `0%`.
* **Ungraded work** — a blank mark is excluded from percentage totals entirely;
  it is not treated as zero. An explicitly absent student does score zero.
* **Theme** — light and dark, following the system by default; switchable in
  Profile → Appearance.
* **Storage** — `shared_preferences`, one JSON document per collection, loaded
  into memory at startup.
* **WhatsApp** — delivery is a one-tap hand-off, not silent automation. Sending
  with no tap at all requires Meta's WhatsApp Cloud API, which needs a server to
  hold the access token and message templates approved by Meta; that arrives
  with the Phase 2 backend. Swapping it in is one new `MessagingProvider`.

Architecture, data model and the Phase 2 migration path:
[`../docs/architecture.md`](../docs/architecture.md).
