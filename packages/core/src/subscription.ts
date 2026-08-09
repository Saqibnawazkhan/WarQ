/**
 * Subscription lifecycle.
 *
 * A subscription carries two kinds of state. The *administrative* state is what
 * a Main Admin sets — pending, active, suspended. The *effective* state adds
 * what the calendar says: an active yearly plan two days from its end date is
 * expiring soon, and one day past it is expired. Only the administrative state
 * is stored; the effective state is always derived, so a missed cron run can
 * never leave the platform showing a stale badge.
 */

import { addMonths, addYears, daysBetween, type CalendarDate } from './calendar.js';

export const SUBSCRIPTION_PLANS = ['monthly', 'yearly', 'permanent'] as const;
export type SubscriptionPlan = (typeof SUBSCRIPTION_PLANS)[number];

export const SUBSCRIPTION_STATUSES = [
  'pending',
  'active',
  'expiring_soon',
  'expired',
  'suspended',
] as const;
export type SubscriptionStatus = (typeof SUBSCRIPTION_STATUSES)[number];

/** The subset a Main Admin can set directly. The rest are derived from dates. */
export const ADMINISTRATIVE_STATUSES = ['pending', 'active', 'suspended'] as const;
export type AdministrativeStatus = (typeof ADMINISTRATIVE_STATUSES)[number];

/**
 * How close to the end date a subscription starts reading as "expiring soon".
 *
 * Derived from the mockups: an organization 7 days out and a teacher 10 days
 * out are both flagged, while a teacher 24 days out is still plain active.
 * A fortnight sits inside that window and lines up with the 15-day reminder.
 */
export const EXPIRING_SOON_DAYS = 14;

/** Reminder offsets, in days before expiry. Matches the Main Admin schedule UI. */
export const EXPIRY_REMINDER_DAYS = [30, 15, 7, 3, 1] as const;
export type ReminderOffset = (typeof EXPIRY_REMINDER_DAYS)[number];

export interface Subscription {
  readonly plan: SubscriptionPlan;
  readonly status: AdministrativeStatus;
  readonly startsAt: CalendarDate | null;
  /** `null` for a permanent plan, or for a request that has not been approved. */
  readonly endsAt: CalendarDate | null;
}

const STATUS_LABEL: Readonly<Record<SubscriptionStatus, string>> = {
  pending: 'Pending',
  active: 'Active',
  expiring_soon: 'Expiring Soon',
  expired: 'Expired',
  suspended: 'Suspended',
};

const PLAN_LABEL: Readonly<Record<SubscriptionPlan, string>> = {
  monthly: 'Monthly',
  yearly: 'Yearly',
  permanent: 'Permanent',
};

export function isSubscriptionPlan(value: string): value is SubscriptionPlan {
  return (SUBSCRIPTION_PLANS as readonly string[]).includes(value);
}

export function isSubscriptionStatus(value: string): value is SubscriptionStatus {
  return (SUBSCRIPTION_STATUSES as readonly string[]).includes(value);
}

export function statusLabel(status: SubscriptionStatus): string {
  return STATUS_LABEL[status];
}

export function planLabel(plan: SubscriptionPlan): string {
  return PLAN_LABEL[plan];
}

/** What the customer actually sees today. */
export function effectiveStatus(
  subscription: Subscription,
  asOf: CalendarDate,
): SubscriptionStatus {
  const { plan, status, endsAt } = subscription;

  // An administrator's decision outranks the calendar.
  if (status === 'pending' || status === 'suspended') return status;

  if (plan === 'permanent') return 'active';

  // Active but undated is a data fault; treat it as not yet granted rather than
  // handing out unbounded access.
  if (endsAt === null) return 'pending';

  const remaining = daysBetween(asOf, endsAt);
  if (remaining < 0) return 'expired';
  if (remaining <= EXPIRING_SOON_DAYS) return 'expiring_soon';
  return 'active';
}

/**
 * Whether this subscription currently permits use of the product.
 *
 * Expiring soon still works — that is the point of warning first. Pending,
 * expired and suspended do not.
 */
export function hasAccess(status: SubscriptionStatus): boolean {
  return status === 'active' || status === 'expiring_soon';
}

/** Days left, or `null` for a permanent plan or an unapproved request. */
export function daysRemaining(subscription: Subscription, asOf: CalendarDate): number | null {
  if (subscription.plan === 'permanent' || subscription.endsAt === null) return null;
  return daysBetween(asOf, subscription.endsAt);
}

/** Where a plan's period ends when it starts on `from`. `null` for permanent. */
export function periodEnd(plan: SubscriptionPlan, from: CalendarDate): CalendarDate | null {
  switch (plan) {
    case 'monthly':
      return addMonths(from, 1);
    case 'yearly':
      return addYears(from, 1);
    case 'permanent':
      return null;
  }
}

/**
 * Extends a subscription by one more period.
 *
 * Renewal runs from the current end date so a customer who renews early keeps
 * the days they paid for. A lapsed subscription restarts from today instead,
 * rather than granting a period that is already spent.
 */
export function renew(subscription: Subscription, asOf: CalendarDate): Subscription {
  if (subscription.plan === 'permanent') {
    return { ...subscription, status: 'active', endsAt: null };
  }

  const lapsed = subscription.endsAt === null || daysBetween(asOf, subscription.endsAt) < 0;
  const anchor = lapsed ? asOf : subscription.endsAt;

  return {
    ...subscription,
    status: 'active',
    startsAt: subscription.startsAt ?? asOf,
    endsAt: periodEnd(subscription.plan, anchor ?? asOf),
  };
}

/** Approves a pending request, starting the first period today. */
export function approve(subscription: Subscription, asOf: CalendarDate): Subscription {
  return {
    ...subscription,
    status: 'active',
    startsAt: asOf,
    endsAt: periodEnd(subscription.plan, asOf),
  };
}

export function suspend(subscription: Subscription): Subscription {
  return { ...subscription, status: 'suspended' };
}

export function reactivate(subscription: Subscription): Subscription {
  return { ...subscription, status: 'active' };
}

/**
 * Which reminder offsets fall due today, given the ones the platform has enabled.
 *
 * Returns at most one offset: exactly the schedule step whose day count matches
 * the days remaining. Sending two notices on one day is a bug, not a courtesy.
 */
export function reminderDueToday(
  subscription: Subscription,
  asOf: CalendarDate,
  enabled: readonly number[] = EXPIRY_REMINDER_DAYS,
): number | null {
  if (subscription.status !== 'active') return null;

  const remaining = daysRemaining(subscription, asOf);
  if (remaining === null || remaining < 0) return null;

  return enabled.includes(remaining) ? remaining : null;
}
