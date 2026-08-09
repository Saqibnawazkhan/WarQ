import type { SubscriptionStatus } from '@warq/core';

export type StatusFilterValue = SubscriptionStatus | 'all';

/** Applies the filter. A row with no status only survives the "All" option. */
export function matchesStatus(rowStatus: string | null, filter: StatusFilterValue): boolean {
  if (filter === 'all') return true;
  return rowStatus === filter;
}

/** How many rows sit behind each chip, so a filter says what it will do before it is used. */
export function countByStatus(
  rows: readonly { status: string | null }[],
): Partial<Record<StatusFilterValue, number>> {
  const counts: Partial<Record<StatusFilterValue, number>> = { all: rows.length };

  for (const row of rows) {
    if (!row.status) continue;
    const key = row.status as StatusFilterValue;
    counts[key] = (counts[key] ?? 0) + 1;
  }

  return counts;
}
