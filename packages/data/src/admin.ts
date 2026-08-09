/**
 * Main Admin data access.
 *
 * Thin, typed wrappers over the admin views and the subscription-action
 * functions. Every one of them is still subject to row-level security — a
 * teacher calling `listOrganizations()` gets their own organization back, not
 * the platform. These read as "admin" queries because of who can usefully call
 * them, not because they are privileged.
 */

import type { WarqClient } from './client.js';
import type { Enums, ViewRow } from './types.js';

/** The activity-feed filter chips: All, Attendance, Marks, Alerts. */
export type ActivityFilter = Enums['activity_type'] | 'all';

export type AdminOrganization = ViewRow<'v_admin_organizations'>;
export type AdminIndividualTeacher = ViewRow<'v_admin_individual_teachers'>;
export type AdminOrgAdmin = ViewRow<'v_admin_org_admins'>;
export type AdminSubscription = ViewRow<'v_admin_subscriptions'>;
export type PendingRequest = ViewRow<'v_pending_requests'>;
export type PlatformOverview = ViewRow<'v_platform_overview'>;

/** Turns a PostgREST failure into a sentence rather than a code. */
function unwrap<T>(data: T | null, error: { message: string } | null, what: string): T {
  if (error) {
    throw new Error(`Could not load ${what}: ${error.message}`);
  }
  if (data === null) {
    throw new Error(`Could not load ${what}.`);
  }
  return data;
}

// ── Dashboard ───────────────────────────────────────────────

export async function getPlatformOverview(client: WarqClient): Promise<PlatformOverview> {
  const { data, error } = await client.from('v_platform_overview').select('*').single();
  return unwrap(data, error, 'the platform overview');
}

export async function listPendingRequests(client: WarqClient): Promise<PendingRequest[]> {
  const { data, error } = await client
    .from('v_pending_requests')
    .select('*')
    .order('requested_at', { ascending: true });

  return unwrap(data, error, 'pending requests');
}

/**
 * Subscriptions inside the warning window, soonest first.
 *
 * Ordered by days remaining rather than by end date so the list reads as a
 * queue: whoever needs chasing first is at the top.
 */
export async function listExpiringSoon(client: WarqClient): Promise<AdminSubscription[]> {
  const { data, error } = await client
    .from('v_admin_subscriptions')
    .select('*')
    .eq('status', 'expiring_soon')
    .order('days_remaining', { ascending: true });

  return unwrap(data, error, 'expiring subscriptions');
}

export async function listRecentActivity(client: WarqClient, limit = 12) {
  const { data, error } = await client
    .from('activity_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);

  return unwrap(data, error, 'recent activity');
}

// ── Accounts ────────────────────────────────────────────────

export async function listOrganizations(client: WarqClient): Promise<AdminOrganization[]> {
  const { data, error } = await client
    .from('v_admin_organizations')
    .select('*')
    .order('name', { ascending: true });

  return unwrap(data, error, 'organizations');
}

export async function listIndividualTeachers(
  client: WarqClient,
): Promise<AdminIndividualTeacher[]> {
  const { data, error } = await client
    .from('v_admin_individual_teachers')
    .select('*')
    .order('full_name', { ascending: true });

  return unwrap(data, error, 'individual teachers');
}

export async function listOrgAdmins(client: WarqClient): Promise<AdminOrgAdmin[]> {
  const { data, error } = await client
    .from('v_admin_org_admins')
    .select('*')
    .order('organization_name', { ascending: true });

  return unwrap(data, error, 'organization admins');
}

export async function listSubscriptions(client: WarqClient): Promise<AdminSubscription[]> {
  const { data, error } = await client
    .from('v_admin_subscriptions')
    .select('*')
    .order('ends_at', { ascending: true, nullsFirst: false });

  return unwrap(data, error, 'subscriptions');
}

export async function listSubscriptionHistory(client: WarqClient, subscriptionId: string) {
  const { data, error } = await client
    .from('subscription_events')
    .select('*')
    .eq('subscription_id', subscriptionId)
    .order('created_at', { ascending: false });

  return unwrap(data, error, 'the subscription history');
}

export async function listActivity(
  client: WarqClient,
  options: { limit?: number; type?: ActivityFilter } = {},
) {
  const base = client
    .from('activity_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(options.limit ?? 100);

  const query = options.type && options.type !== 'all' ? base.eq('type', options.type) : base;

  const { data, error } = await query;
  return unwrap(data, error, 'the activity log');
}

// ── Actions ─────────────────────────────────────────────────
//
// Each of these calls a function that checks is_main_admin() before it does
// anything. A teacher who calls them gets an error from the database, not a
// silently ignored request.

async function callAction(
  client: WarqClient,
  fn: 'approve_subscription' | 'reactivate_subscription' | 'renew_subscription',
  subscriptionId: string,
): Promise<void> {
  const { error } = await client.rpc(fn, { target_subscription: subscriptionId });
  if (error) throw new Error(error.message);
}

export function approveSubscription(client: WarqClient, subscriptionId: string) {
  return callAction(client, 'approve_subscription', subscriptionId);
}

export function reactivateSubscription(client: WarqClient, subscriptionId: string) {
  return callAction(client, 'reactivate_subscription', subscriptionId);
}

export function renewSubscription(client: WarqClient, subscriptionId: string) {
  return callAction(client, 'renew_subscription', subscriptionId);
}

export async function rejectSubscription(
  client: WarqClient,
  subscriptionId: string,
  reason?: string,
): Promise<void> {
  const { error } = await client.rpc('reject_subscription', {
    target_subscription: subscriptionId,
    ...(reason ? { reason } : {}),
  });
  if (error) throw new Error(error.message);
}

export async function suspendSubscription(
  client: WarqClient,
  subscriptionId: string,
  reason?: string,
): Promise<void> {
  const { error } = await client.rpc('suspend_subscription', {
    target_subscription: subscriptionId,
    ...(reason ? { reason } : {}),
  });
  if (error) throw new Error(error.message);
}

// ── Reminder schedule ───────────────────────────────────────

export async function getReminderSchedule(client: WarqClient): Promise<number[]> {
  const { data, error } = await client.from('reminder_settings').select('days').single();
  return unwrap(data, error, 'the reminder schedule').days;
}

export async function setReminderSchedule(client: WarqClient, days: number[]): Promise<void> {
  const { error } = await client
    .from('reminder_settings')
    .update({ days: [...days].sort((a, b) => b - a) })
    .eq('id', true);

  if (error) throw new Error(`Could not save the reminder schedule: ${error.message}`);
}

export async function listReminderLog(client: WarqClient, limit = 50) {
  const { data, error } = await client
    .from('reminder_logs')
    .select('*')
    .order('sent_at', { ascending: false })
    .limit(limit);

  return unwrap(data, error, 'the reminder log');
}
