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

export interface Me {
  profile: {
    id: string
    full_name: string
    email: string
    role: 'teacher' | 'org_admin' | 'main_admin'
    status: AccountStatus
    organization_id: string | null
  } | null
  organization: unknown
  subscription: unknown
  has_access: boolean
}
