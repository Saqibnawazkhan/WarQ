# Warq — data model

Every value that appears in the mockups traces back to a table here. The SQL
itself lands in M1 under `supabase/migrations/`; this document is the shape it
will take and the reasoning behind it.

---

## Enumerations

| Type                  | Values                                                     | Notes                                                                   |
| --------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------- |
| `user_role`           | `main_admin`, `org_admin`, `teacher`                       | Mirrors `USER_ROLES` in `@warq/core`                                    |
| `account_status`      | `pending`, `active`, `suspended`                           | A person's own state, separate from their subscription's                |
| `subscription_plan`   | `monthly`, `yearly`, `permanent`                           |                                                                         |
| `subscription_status` | `pending`, `active`, `suspended`                           | **Stored** state only. `expiring_soon` and `expired` are always derived |
| `attendance_mark`     | `present`, `absent`, `late`                                |                                                                         |
| `assessment_type`     | `quiz`, `assignment`, `midterm`, `final`, `project`, `lab` |                                                                         |
| `contact_label`       | `father`, `mother`, `guardian`, `student`                  | From the student contact cards in the mobile mockup                     |
| `activity_type`       | `attendance`, `marks`, `alerts`, `admin`, `subscription`   | Matches the activity-feed filters                                       |
| `invitation_status`   | `sent`, `accepted`, `expired`, `revoked`                   |                                                                         |
| `channel`             | `email`, `whatsapp`, `in_app`                              |                                                                         |

### Why `expiring_soon` and `expired` are not stored

If they were columns, a missed cron run would leave the platform showing a stale
badge and — worse — granting access it should have withdrawn. Instead the stored
status holds only what an administrator decided, and the effective status is
computed from the dates on every read, by `effectiveStatus()` in `@warq/core` and
by a matching SQL function used inside the RLS policies. The scheduled job then
only has to send reminders, not to be correct about access.

---

## Identity and tenancy

### `profiles`

Extends `auth.users`. One row per person.

| Column            | Type                          | Notes                                                |
| ----------------- | ----------------------------- | ---------------------------------------------------- |
| `id`              | `uuid` PK → `auth.users`      |                                                      |
| `email`           | `citext` unique               |                                                      |
| `full_name`       | `text`                        |                                                      |
| `phone`           | `text` null                   |                                                      |
| `role`            | `user_role`                   |                                                      |
| `organization_id` | `uuid` null → `organizations` | Null for a Main Admin and for an independent teacher |
| `status`          | `account_status`              |                                                      |
| `created_at`      | `timestamptz`                 |                                                      |

A teacher with no `organization_id` is an **individual teacher** — they hold
their own subscription and appear on the Main Admin's Individual Teachers page.

### `organizations`

| Column             | Type               | Notes                                           |
| ------------------ | ------------------ | ----------------------------------------------- |
| `id`               | `uuid` PK          |                                                 |
| `name`             | `text`             |                                                 |
| `city`             | `text`             |                                                 |
| `email`, `phone`   | `text`             | Contact details shown in the Main Admin drawer  |
| `owner_profile_id` | `uuid` null        | The current Organization Admin, reassignable    |
| `status`           | `account_status`   |                                                 |
| `requested_at`     | `timestamptz`      | Shown as "Requested 6 Aug 2026" on pending rows |
| `approved_at`      | `timestamptz` null |                                                 |

### `invitations`

A teacher joining an organization, sent by email or WhatsApp.

`id`, `organization_id`, `email`, `full_name`, `token` (unique, single-use),
`status`, `sent_via`, `invited_by`, `expires_at`, `accepted_at`.

---

## Subscriptions

### `subscriptions`

Held either by an organization or by an individual teacher, never both.

| Column            | Type                   | Notes                                       |
| ----------------- | ---------------------- | ------------------------------------------- |
| `id`              | `uuid` PK              |                                             |
| `organization_id` | `uuid` null            | Exactly one of these two is set — a `CHECK` |
| `profile_id`      | `uuid` null            |                                             |
| `plan`            | `subscription_plan`    |                                             |
| `status`          | `subscription_status`  | Administrative state only                   |
| `starts_at`       | `date` null            |                                             |
| `ends_at`         | `date` null            | Null for `permanent`, and before approval   |
| `price_cents`     | `integer` null         | Modelled now; no gateway wired until asked  |
| `currency`        | `text` default `'PKR'` |                                             |

### `subscription_events`

The history panel in the Main Admin drawer. Append-only: `subscription_id`,
`action` (`requested`, `approved`, `renewed`, `extended`, `suspended`,
`reactivated`, `rejected`), `plan`, `from_date`, `to_date`, `actor_id`,
`created_at`.

### `reminder_settings` and `reminder_logs`

The 30 / 15 / 7 / 3 / 1 schedule and its sent log. Settings hold a `days`
integer array; logs record `subscription_id`, `days_before`, `channel`,
`sent_at`, `message` — one row per notice, so a duplicate send is visible.

---

## Teaching

### `classes`

`id`, `organization_id` (null for an independent teacher), `teacher_id`, `name`,
`section`, `session`, `color_index`, `created_at`.

`color_index` keeps a class the same colour on web and on mobile without either
app deciding for itself.

### `students`

`id`, `class_id`, `full_name`, `roll_no`, `created_at`.
Unique on `(class_id, roll_no)`.

### `student_contacts`

`id`, `student_id`, `label`, `phone`, `receives_alerts`.

Absence alerts go only to contacts with `receives_alerts` set. A student with no
contacts — Usman Tariq in the mockup — simply generates no alert, which the save
message says plainly rather than failing.

### `grade_scales`

`id`, `organization_id` (null row is the platform default), `bands` `jsonb`.
Validated by `isValidGradeScale()` before it is written: descending, no gaps,
bottoming out at zero.

---

## Attendance and assessment

### `attendance_sessions`

`id`, `class_id`, `date`, `taken_by`, `created_at`.
**Unique on `(class_id, date)`** — one roll call per class per day. Re-saving
updates the existing session rather than creating a second.

### `attendance_records`

`session_id`, `student_id`, `mark`. Primary key `(session_id, student_id)`.

Storing marks per session rather than as running totals means a correction to
last Tuesday's roll call is a single update, and every percentage recomputes from
the same rows.

### `assessments`

`id`, `class_id`, `name`, `type`, `date`, `total_marks`, `created_at`.

### `marks`

`assessment_id`, `student_id`, `score` (`numeric`, nullable).
Primary key `(assessment_id, student_id)`.

**A null score means not yet marked, which is not the same as zero.** The mockup
draws an empty box and an em-dash grade for exactly this case, and
`aggregate()` leaves unmarked work out of both sides of the fraction so a student
is never failed for work a teacher has not graded.

---

## Platform operations

### `activity_logs`

`id`, `organization_id` (null for platform-level entries), `actor_id`, `type`,
`message`, `meta` `jsonb`, `created_at`.

Backs three surfaces: the Main Admin's platform activity, the Organization
Admin's filtered feed, and the teacher's recent activity.

### `notifications`

`id`, `profile_id`, `title`, `body`, `kind`, `read_at`, `created_at`.

### `reports`

`id`, `kind` (`student`, `class`, `organization`, `platform`), `subject_id`,
`storage_path`, `generated_by`, `created_at`. The file itself lives in Supabase
Storage and is served through a signed URL.

---

## Views

Aggregation belongs in the database, not in three clients that would each drift.

| View                        | Serves                                                                     |
| --------------------------- | -------------------------------------------------------------------------- |
| `v_class_attendance`        | Per-class attendance percentage and session counts                         |
| `v_student_performance`     | Per-student marks total, percentage and grade                              |
| `v_org_overview`            | An organization's teacher, class and student counts and today's attendance |
| `v_platform_overview`       | The Main Admin dashboard figures                                           |
| `v_effective_subscriptions` | Subscriptions with the derived status and days remaining attached          |

---

## No seed data

The database ships empty apart from one row: the default grade scale.

The mockup fixtures — Punjab College of IT, the twenty-seven students, their
marks and attendance — are a **specification of what the screens must handle**,
not data to load. Real records are entered through the product.

That is a deliberate choice with two effects:

- **Empty states are real screens.** A Main Admin dashboard with no organizations
  yet is what someone sees on day one. The mockups only draw the populated case,
  so each empty state is designed rather than left as a blank panel.
- **The onboarding path gets exercised.** An organization signs up, a Main Admin
  approves it, a teacher is invited and accepts, a class is created. Seeding
  around that flow would leave it untested until the first real customer hit it.

The fixtures still earn their keep as test data: `@warq/core` asserts its
grading, attendance and subscription logic against the exact numbers in the
mockups, so the calculations are verified without any of it reaching the
database.
