/// Row shapes returned by the admin views.
///
/// Hand-written rather than generated: these mirror the views in
/// supabase/migrations/ and change only when those do, and a generated file
/// would need a service-role key to produce.

/// public.account_status. Being turned down is stored as suspended rather than
/// a state of its own, so there is no 'rejected' here.
export type AccountStatus = 'pending' | 'active' | 'suspended'

/// public.effective_subscription_status: what a client is shown, which is the
/// stored status widened by the calendar. 'expiring_soon' and 'expired' are
/// derived on every read rather than stored, so a missed job can never leave
/// the platform granting access it should have withdrawn.
export type SubscriptionStatus =
  | 'pending'
  | 'active'
  | 'expiring_soon'
  | 'expired'
  | 'suspended'

export type SubscriptionPlan = 'monthly' | 'yearly' | 'permanent' | 'trial'

export type SubjectKind = 'organization' | 'individual_teacher'

export interface PlatformOverview {
  organization_count: number
  active_organization_count: number
  individual_teacher_count: number
  organization_teacher_count: number
  active_subscription_count: number
  expiring_soon_count: number
  expired_count: number
  pending_count: number
  monthly_count: number
  yearly_count: number
  permanent_count: number
}

export interface PendingRequest {
  subscription_id: string
  plan: SubscriptionPlan
  requested_at: string
  kind: SubjectKind
  organization_id: string | null
  profile_id: string | null
  subject_name: string | null
  subject_email: string | null
  city: string | null
  phone: string | null
  teacher_count: number
}

export interface AdminOrganization {
  id: string
  name: string
  city: string | null
  email: string | null
  phone: string | null
  account_status: AccountStatus
  requested_at: string | null
  approved_at: string | null
  created_at: string
  admin_profile_id: string | null
  admin_name: string | null
  admin_email: string | null
  subscription_id: string | null
  plan: SubscriptionPlan | null
  status: SubscriptionStatus | null
  stored_status: SubscriptionStatus | null
  starts_at: string | null
  ends_at: string | null
  days_remaining: number | null
  grants_access: boolean | null
  teacher_count: number
  student_count: number
  class_count: number
}

export interface AdminIndividualTeacher {
  id: string
  full_name: string
  email: string
  phone: string | null
  account_status: AccountStatus
  created_at: string
  subscription_id: string | null
  plan: SubscriptionPlan | null
  status: SubscriptionStatus | null
  starts_at: string | null
  ends_at: string | null
  days_remaining: number | null
  grants_access: boolean | null
  class_count: number
  student_count: number
}

export interface AdminSubscription {
  id: string
  plan: SubscriptionPlan
  status: SubscriptionStatus
  stored_status: SubscriptionStatus
  starts_at: string | null
  ends_at: string | null
  days_remaining: number | null
  grants_access: boolean
  price_cents: number | null
  currency: string | null
  created_at: string
  kind: SubjectKind
  organization_id: string | null
  profile_id: string | null
  subject_name: string | null
  subject_email: string | null
  city: string | null
}

export interface ActivityRow {
  id: string
  organization_id: string | null
  actor_id: string | null
  actor_name: string
  type: string
  message: string
  meta: Record<string, unknown>
  created_at: string
}

export type UserRole = 'teacher' | 'org_admin' | 'main_admin'

export interface Profile {
  id: string
  full_name: string
  email: string
  phone: string | null
  role: UserRole
  status: AccountStatus
  organization_id: string | null
  title: string | null
  bio: string | null
  created_at: string
}

export interface Organization {
  id: string
  name: string
  city: string | null
  email: string | null
  phone: string | null
  address: string | null
  website: string | null
  status: AccountStatus
  owner_profile_id: string | null
}

export interface Me {
  profile: Profile | null
  organization: Organization | null
  subscription: unknown
  has_access: boolean
}

// ── Teaching ────────────────────────────────────────────────

export type AttendanceMark = 'present' | 'absent' | 'late' | 'short_leave'

export type AssessmentType =
  | 'quiz'
  | 'assignment'
  | 'midterm'
  | 'final'
  | 'presentation'
  | 'project'
  | 'lab'
  | 'custom'

export interface SchoolClass {
  id: string
  organization_id: string | null
  teacher_id: string
  name: string
  section: string | null
  session: string | null
  subject: string | null
  description: string | null
  color_index: number
  archived_at: string | null
  created_at: string
  updated_at: string | null
}

export interface StudentContact {
  id: string
  student_id: string
  label: 'father' | 'mother' | 'student' | 'guardian'
  phone: string
  receives_alerts: boolean
}

export interface Student {
  id: string
  teacher_id: string
  organization_id: string | null
  full_name: string
  roll_no: string | null
  email: string | null
  address: string | null
  guardian_name: string | null
  notes: string | null
  created_at: string
  student_contacts?: StudentContact[]
}

export interface TeacherToday {
  class_id: string
  teacher_id: string
  name: string
  section: string | null
  color_index: number
  student_count: number
  session_id: string | null
  taken: boolean
  present: number
  absent: number
  late: number
  short_leave: number
}

export interface ClassAttendance {
  class_id: string
  organization_id: string | null
  teacher_id: string
  name: string
  subject: string | null
  section: string | null
  session: string | null
  color_index: number
  student_count: number
  session_count: number
  assessment_count: number
  present_total: number
  absent_total: number
  late_total: number
  short_leave_total: number
  attendance_percent: number | null
  last_session_date: string | null
}

export interface StudentPerformance {
  student_id: string
  class_id: string
  full_name: string
  roll_no: string | null
  present: number
  absent: number
  late: number
  short_leave: number
  assessable_sessions: number
  attendance_percent: number | null
  obtained: number
  total: number
  assessments_marked: number
  assessments_pending: number
  marks_percent: number | null
  grade: string | null
}

export interface AttendanceSession {
  id: string
  class_id: string
  date: string
  taken_by: string | null
  note: string | null
  created_at: string
}

export interface AttendanceRecord {
  session_id: string
  student_id: string
  mark: AttendanceMark
  notified: boolean
}

export interface Assessment {
  id: string
  class_id: string
  name: string
  type: AssessmentType
  date: string
  total_marks: number
  custom_type_label: string | null
  description: string | null
  weight: number | null
  created_at: string
}

export interface Mark {
  assessment_id: string
  student_id: string
  score: number | null
  absent: boolean
  remarks: string | null
  updated_at: string
}

// ── Organization admin ──────────────────────────────────────

export interface OrgTeacher {
  id: string
  organization_id: string
  full_name: string
  email: string
  phone: string | null
  account_status: AccountStatus
  joined_at: string
  class_count: number
  student_count: number
  session_count: number
  assessment_count: number
  last_attendance_date: string | null
  last_assessment_date: string | null
  activity_state: 'active' | 'idle'
}

export interface Invitation {
  id: string
  organization_id: string
  email: string
  full_name: string
  status: 'pending' | 'accepted' | 'expired' | 'revoked'
  expires_at: string
  accepted_at: string | null
  created_at: string
}

export interface OrgOverview {
  id: string
  name: string
  city: string | null
  status: AccountStatus
  teacher_count: number
  class_count: number
  student_count: number
  classes_marked_today: number
  attendance_percent: number
}
