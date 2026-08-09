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
  getSession,
  PlatformNotPermittedError,
  requestPasswordReset,
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

export type { Database } from './database.types.js';
