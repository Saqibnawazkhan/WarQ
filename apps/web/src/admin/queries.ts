/**
 * TanStack Query hooks over `@warq/data`.
 *
 * One place for the query keys, so a mutation can invalidate everything an
 * action touched without each page inventing its own key.
 */

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  approveSubscription,
  getPlatformOverview,
  getReminderSchedule,
  listActivity,
  listExpiringSoon,
  listIndividualTeachers,
  listOrganizations,
  listOrgAdmins,
  listPendingRequests,
  listReminderLog,
  listSubscriptionHistory,
  listSubscriptions,
  reactivateSubscription,
  rejectSubscription,
  renewSubscription,
  setReminderSchedule,
  suspendSubscription,
  type ActivityFilter,
} from '@warq/data';

import { supabase } from '../lib/supabase.ts';

export const adminKeys = {
  all: ['admin'] as const,
  overview: () => [...adminKeys.all, 'overview'] as const,
  pending: () => [...adminKeys.all, 'pending'] as const,
  expiring: () => [...adminKeys.all, 'expiring'] as const,
  organizations: () => [...adminKeys.all, 'organizations'] as const,
  teachers: () => [...adminKeys.all, 'teachers'] as const,
  orgAdmins: () => [...adminKeys.all, 'org-admins'] as const,
  subscriptions: () => [...adminKeys.all, 'subscriptions'] as const,
  history: (id: string) => [...adminKeys.all, 'history', id] as const,
  activity: (filter: ActivityFilter) => [...adminKeys.all, 'activity', filter] as const,
  reminderSchedule: () => [...adminKeys.all, 'reminder-schedule'] as const,
  reminderLog: () => [...adminKeys.all, 'reminder-log'] as const,
};

export function useOverview() {
  return useQuery({
    queryKey: adminKeys.overview(),
    queryFn: () => getPlatformOverview(supabase),
  });
}

export function usePendingRequests() {
  return useQuery({
    queryKey: adminKeys.pending(),
    queryFn: () => listPendingRequests(supabase),
  });
}

export function useExpiringSoon() {
  return useQuery({
    queryKey: adminKeys.expiring(),
    queryFn: () => listExpiringSoon(supabase),
  });
}

export function useOrganizations() {
  return useQuery({
    queryKey: adminKeys.organizations(),
    queryFn: () => listOrganizations(supabase),
  });
}

export function useIndividualTeachers() {
  return useQuery({
    queryKey: adminKeys.teachers(),
    queryFn: () => listIndividualTeachers(supabase),
  });
}

export function useOrgAdmins() {
  return useQuery({
    queryKey: adminKeys.orgAdmins(),
    queryFn: () => listOrgAdmins(supabase),
  });
}

export function useSubscriptions() {
  return useQuery({
    queryKey: adminKeys.subscriptions(),
    queryFn: () => listSubscriptions(supabase),
  });
}

export function useSubscriptionHistory(subscriptionId: string | null) {
  return useQuery({
    queryKey: adminKeys.history(subscriptionId ?? 'none'),
    queryFn: () => listSubscriptionHistory(supabase, subscriptionId ?? ''),
    enabled: subscriptionId !== null,
  });
}

export function useActivity(filter: ActivityFilter) {
  return useQuery({
    queryKey: adminKeys.activity(filter),
    queryFn: () => listActivity(supabase, { type: filter, limit: 150 }),
  });
}

export function useReminderSchedule() {
  return useQuery({
    queryKey: adminKeys.reminderSchedule(),
    queryFn: () => getReminderSchedule(supabase),
  });
}

export function useReminderLog() {
  return useQuery({
    queryKey: adminKeys.reminderLog(),
    queryFn: () => listReminderLog(supabase),
  });
}

/** The sidebar badge counts. Cheap enough to keep fresher than the rest. */
export function useAdminBadges() {
  return useQuery({
    queryKey: [...adminKeys.all, 'badges'],
    queryFn: async () => {
      const [pending, expiring] = await Promise.all([
        listPendingRequests(supabase),
        listExpiringSoon(supabase),
      ]);
      return { pending: pending.length, expiring: expiring.length };
    },
    staleTime: 30_000,
  });
}

type SubscriptionAction =
  | { kind: 'approve'; subscriptionId: string }
  | { kind: 'reject'; subscriptionId: string; reason?: string }
  | { kind: 'suspend'; subscriptionId: string; reason?: string }
  | { kind: 'reactivate'; subscriptionId: string }
  | { kind: 'renew'; subscriptionId: string };

/**
 * Every subscription action, behind one mutation.
 *
 * All of them touch the same handful of lists — approving a request removes it
 * from the queue, activates an organization, changes the counts and appends to
 * the activity log — so they all invalidate `admin` wholesale rather than each
 * page guessing which keys it broke.
 */
export function useSubscriptionAction() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: async (action: SubscriptionAction) => {
      switch (action.kind) {
        case 'approve':
          return approveSubscription(supabase, action.subscriptionId);
        case 'reject':
          return rejectSubscription(supabase, action.subscriptionId, action.reason);
        case 'suspend':
          return suspendSubscription(supabase, action.subscriptionId, action.reason);
        case 'reactivate':
          return reactivateSubscription(supabase, action.subscriptionId);
        case 'renew':
          return renewSubscription(supabase, action.subscriptionId);
      }
    },
    onSettled: () => client.invalidateQueries({ queryKey: adminKeys.all }),
  });
}

export function useSaveReminderSchedule() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (days: number[]) => setReminderSchedule(supabase, days),
    onSettled: () => client.invalidateQueries({ queryKey: adminKeys.reminderSchedule() }),
  });
}
