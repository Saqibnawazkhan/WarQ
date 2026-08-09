/**
 * Readable aliases over the generated schema types.
 *
 * `database.types.ts` is regenerated from the live database by
 * `npm run db:types` and must never be edited by hand. Everything downstream
 * imports from here instead, so a column rename shows up as a type error in one
 * file rather than as `Database['public']['Tables'][…]` scattered everywhere.
 */

import type { Database } from './database.types.js';

type Schema = Database['public'];

export type Tables = Schema['Tables'];
export type Views = Schema['Views'];
export type Enums = Schema['Enums'];

export type Row<T extends keyof Tables> = Tables[T]['Row'];
export type Insert<T extends keyof Tables> = Tables[T]['Insert'];
export type Update<T extends keyof Tables> = Tables[T]['Update'];
export type ViewRow<T extends keyof Views> = Views[T]['Row'];

// ── Identity ────────────────────────────────────────────────

export type Profile = Row<'profiles'>;
export type Organization = Row<'organizations'>;
export type Invitation = Row<'invitations'>;

// ── Subscriptions ───────────────────────────────────────────

export type Subscription = Row<'subscriptions'>;
export type SubscriptionEvent = Row<'subscription_events'>;
export type ReminderLog = Row<'reminder_logs'>;

/** A subscription with its derived status attached. Read badges from this, never from `subscriptions.status`. */
export type EffectiveSubscription = ViewRow<'v_effective_subscriptions'>;

// ── Teaching ────────────────────────────────────────────────

export type Class = Row<'classes'>;
export type Student = Row<'students'>;
export type StudentContact = Row<'student_contacts'>;
export type GradeScale = Row<'grade_scales'>;

// ── Attendance and assessment ───────────────────────────────

export type AttendanceSession = Row<'attendance_sessions'>;
export type AttendanceRecord = Row<'attendance_records'>;
export type Assessment = Row<'assessments'>;
export type Mark = Row<'marks'>;

// ── Platform ────────────────────────────────────────────────

export type ActivityLog = Row<'activity_logs'>;
export type Notification = Row<'notifications'>;
export type Report = Row<'reports'>;

// ── Aggregates ──────────────────────────────────────────────

export type ClassAttendance = ViewRow<'v_class_attendance'>;
export type StudentPerformance = ViewRow<'v_student_performance'>;
export type OrgOverview = ViewRow<'v_org_overview'>;
export type PlatformOverview = ViewRow<'v_platform_overview'>;

/**
 * What `me()` returns: everything a client needs on load, in one round trip.
 *
 * `hasAccess` is the subscription gate. It is false for a pending, expired or
 * suspended account — such a user can still sign in and read why, but the
 * database will refuse them any teaching data.
 */
export interface WarqSession {
  readonly profile: Profile;
  readonly organization: Organization | null;
  readonly subscription: EffectiveSubscription | null;
  readonly hasAccess: boolean;
}
