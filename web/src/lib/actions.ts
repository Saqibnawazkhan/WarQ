import { supabase } from './supabase'

/// The five things an administrator can do to a subscription.
///
/// Each is a database function that checks is_main_admin() itself and writes
/// its own subscription_events row, so the audit trail cannot be skipped by
/// calling from somewhere else. The dashboard never updates the subscriptions
/// table directly.
export const subscriptionActions = {
  approve: (id: string) => call('approve_subscription', { target_subscription: id }),

  reject: (id: string, reason: string | null) =>
    call('reject_subscription', { target_subscription: id, reason: clean(reason) }),

  suspend: (id: string, reason: string | null) =>
    call('suspend_subscription', { target_subscription: id, reason: clean(reason) }),

  reactivate: (id: string) => call('reactivate_subscription', { target_subscription: id }),

  renew: (id: string) => call('renew_subscription', { target_subscription: id }),
}

async function call(fn: string, params: Record<string, unknown>): Promise<void> {
  const { error } = await supabase.rpc(fn, params)
  if (error) throw error
}

function clean(reason: string | null): string | null {
  const trimmed = reason?.trim() ?? ''
  return trimmed === '' ? null : trimmed
}
