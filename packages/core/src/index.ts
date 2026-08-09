/**
 * @warq/core — the Warq domain, with no I/O and no framework.
 *
 * Web, mobile and the worker all import from here, so grading, attendance
 * arithmetic and the subscription state machine can only ever behave one way.
 */

export {
  addDays,
  addMonths,
  addYears,
  daysBetween,
  daysInMonth,
  formatCalendarDate,
  isCalendarDate,
  parseCalendarDate,
  toCalendarDate,
  today,
  type CalendarDate,
  type DateParts,
} from './calendar.js';

export {
  allowedPlatforms,
  canUsePlatform,
  isPlatform,
  isUserRole,
  landingRoute,
  PLATFORMS,
  platformDenialReason,
  requiresOrganization,
  roleLabel,
  USER_ROLES,
  type Platform,
  type UserRole,
} from './roles.js';

export {
  ADMINISTRATIVE_STATUSES,
  approve,
  daysRemaining,
  effectiveStatus,
  EXPIRING_SOON_DAYS,
  EXPIRY_REMINDER_DAYS,
  hasAccess,
  isSubscriptionPlan,
  isSubscriptionStatus,
  periodEnd,
  planLabel,
  reactivate,
  reminderDueToday,
  renew,
  statusLabel,
  SUBSCRIPTION_PLANS,
  SUBSCRIPTION_STATUSES,
  suspend,
  type AdministrativeStatus,
  type ReminderOffset,
  type Subscription,
  type SubscriptionPlan,
  type SubscriptionStatus,
} from './subscription.js';

export {
  aggregate,
  classAverage,
  DEFAULT_GRADE_SCALE,
  gradeFor,
  GRADES,
  isGrade,
  isValidGradeScale,
  percentage,
  type Aggregate,
  type Grade,
  type GradeBand,
  type ScoreLine,
} from './grading.js';

export {
  absentees,
  addTallies,
  ATTENDANCE_MARKS,
  attendancePercent,
  averageAttendance,
  combineTallies,
  DEFAULT_MARK,
  EMPTY_TALLY,
  isAttendanceMark,
  MARK_INITIAL,
  markLabel,
  sessionsCounted,
  tally,
  type AttendanceMark,
  type AttendanceTally,
} from './attendance.js';

export { initials, pluralize, possessive, seriesIndex } from './text.js';

export * from './schemas.js';
