/**
 * @warq/data — typed access to the Warq database.
 *
 * Web, mobile and the worker all talk to Supabase through this package, so
 * there is one client configuration, one set of row types, and one sign-in path.
 */

export {
  createBrowserClient,
  createServiceClient,
  type ClientConfig,
  type WarqClient,
} from './client.js';

export {
  EmailNotConfirmedError,
  getSession,
  PlatformNotPermittedError,
  requestPasswordReset,
  resendConfirmation,
  signIn,
  signOut,
} from './session.js';

export type {
  ActivityLog,
  Assessment,
  AttendanceRecord,
  AttendanceSession,
  Class,
  ClassAttendance,
  EffectiveSubscription,
  Enums,
  GradeScale,
  Insert,
  Invitation,
  Mark,
  Notification,
  Organization,
  OrgOverview,
  PlatformOverview,
  Profile,
  ReminderLog,
  Report,
  Row,
  Student,
  StudentContact,
  StudentPerformance,
  Subscription,
  SubscriptionEvent,
  Tables,
  Update,
  ViewRow,
  Views,
  WarqSession,
} from './types.js';

export {
  approveSubscription,
  getPlatformOverview,
  getReminderSchedule,
  listActivity,
  listExpiringSoon,
  listIndividualTeachers,
  listOrganizations,
  listOrgAdmins,
  listPendingRequests,
  listRecentActivity,
  listReminderLog,
  listSubscriptionHistory,
  listSubscriptions,
  reactivateSubscription,
  rejectSubscription,
  renewSubscription,
  setReminderSchedule,
  suspendSubscription,
  type ActivityFilter,
  type AdminIndividualTeacher,
  type AdminOrganization,
  type AdminOrgAdmin,
  type AdminSubscription,
  type PendingRequest,
} from './admin.js';

export {
  getClassDetail,
  getOrgOverview,
  inviteTeacher,
  listDailyAttendance,
  listInvitations,
  listOrgActivity,
  listOrgClasses,
  listOrgStudents,
  listOrgTeachers,
  removeTeacher,
  revokeInvitation,
  type InviteResult,
  type OrgClass,
  type OrgDailyAttendance,
  type OrgTeacher,
  type StudentPerformanceRow,
} from './org.js';

export type { Database } from './database.types.js';
