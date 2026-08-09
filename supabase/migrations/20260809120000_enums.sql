-- Warq · M1 · Enumerations
--
-- These mirror the constants in @warq/core exactly. If one changes, both change
-- together: the TypeScript union is what the apps compile against, and the
-- Postgres type is what the database will actually accept.

-- ─────────────────────────────────────────────────────────────
-- Identity
-- ─────────────────────────────────────────────────────────────

-- Mirrors USER_ROLES in packages/core/src/roles.ts
create type public.user_role as enum ('main_admin', 'org_admin', 'teacher');

-- A person's own standing, kept separate from their subscription's.
-- A teacher can be active while their organization's subscription has lapsed.
create type public.account_status as enum ('pending', 'active', 'suspended');

create type public.invitation_status as enum ('pending', 'accepted', 'expired', 'revoked');

-- ─────────────────────────────────────────────────────────────
-- Subscriptions
-- ─────────────────────────────────────────────────────────────

create type public.subscription_plan as enum ('monthly', 'yearly', 'permanent');

-- Only what an administrator sets. 'expiring_soon' and 'expired' are deliberately
-- absent: they are derived from dates on every read by
-- public.fn_effective_subscription_status(), so a missed cron run can never
-- leave the platform granting access it should have withdrawn.
create type public.subscription_status as enum ('pending', 'active', 'suspended');

-- What a client is shown. The stored status widened by the calendar.
create type public.effective_subscription_status as enum (
  'pending',
  'active',
  'expiring_soon',
  'expired',
  'suspended'
);

create type public.subscription_action as enum (
  'requested',
  'approved',
  'rejected',
  'renewed',
  'extended',
  'suspended',
  'reactivated',
  'expired'
);

-- ─────────────────────────────────────────────────────────────
-- Teaching
-- ─────────────────────────────────────────────────────────────

-- Four outcomes, and the percentage treats them differently:
--   present, late  -> attended (a late student was still taught)
--   absent         -> not attended
--   short_leave    -> excluded from the calculation entirely
--
-- Short leave is a permitted, arranged absence. Counting it against a student
-- would penalise them for something the institution agreed to; counting it as
-- attendance would overstate it. So it leaves the denominator instead.
-- fn_attendance_percentage() is the single implementation of that rule.
create type public.attendance_mark as enum ('present', 'absent', 'late', 'short_leave');

create type public.assessment_type as enum (
  'quiz',
  'assignment',
  'midterm',
  'final',
  'presentation',
  'project',
  'lab',
  'custom'
);

-- From the student contact cards in the mobile mockup. 'student' covers an adult
-- learner who is their own contact.
create type public.contact_label as enum ('father', 'mother', 'guardian', 'student');

-- ─────────────────────────────────────────────────────────────
-- Platform operations
-- ─────────────────────────────────────────────────────────────

-- The first three match the activity-feed filters in the Organization Admin
-- mockup; the last two are platform-level and never shown to an organization.
create type public.activity_type as enum (
  'attendance',
  'marks',
  'alerts',
  'admin',
  'subscription'
);

create type public.notification_channel as enum ('email', 'whatsapp', 'in_app');

create type public.report_kind as enum ('student', 'class', 'organization', 'platform');
