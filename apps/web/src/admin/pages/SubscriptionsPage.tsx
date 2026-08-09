import { useMemo, useState } from 'react';

import { formatCalendarDate, planLabel, pluralize } from '@warq/core';
import type { AdminSubscription } from '@warq/data';

import { DataTable, SearchField, StatusPill, type Column } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';
import { StatusFilter } from '../components/StatusFilter.tsx';
import {
  countByStatus,
  matchesStatus,
  type StatusFilterValue,
} from '../components/status-filter.ts';
import { SubscriptionActions } from '../components/SubscriptionActions.tsx';
import { useExpiringSoon, useSubscriptions } from '../queries.ts';

/** Every subscription on the platform, whoever holds it. */
export function SubscriptionsPage() {
  return <SubscriptionTable variant="all" />;
}

/**
 * The same table, filtered to the warning window and ordered as a queue.
 *
 * One component rather than two near-identical ones: the difference is which
 * rows arrive and what the empty state says, not how a subscription is drawn.
 */
export function ExpiringPage() {
  return <SubscriptionTable variant="expiring" />;
}

function SubscriptionTable({ variant }: { variant: 'all' | 'expiring' }) {
  const all = useSubscriptions();
  const expiring = useExpiringSoon();
  const query = variant === 'all' ? all : expiring;

  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<StatusFilterValue>('all');

  // Memoised so the identity is stable between renders; otherwise the filter
  // below recomputes on every render rather than when the data changes.
  const rows = useMemo(() => query.data ?? [], [query.data]);

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();

    return rows.filter((row) => {
      if (variant === 'all' && !matchesStatus(row.status, filter)) return false;
      if (!needle) return true;

      return [row.subject_name, row.subject_email, row.city]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle));
    });
  }, [rows, search, filter, variant]);

  const columns: Column<AdminSubscription>[] = [
    {
      key: 'subject',
      header: 'Account',
      width: '2fr',
      render: (row) => (
        <>
          <p className="truncate text-[13.5px] font-bold">{row.subject_name}</p>
          <p className="truncate text-[11.5px] text-ink-muted">
            {row.kind === 'organization' ? 'Organization' : 'Individual teacher'}
            {row.city ? ` · ${row.city}` : ''}
          </p>
        </>
      ),
    },
    {
      key: 'plan',
      header: 'Plan',
      width: '0.9fr',
      render: (row) => (
        <p className="text-[12.5px] font-semibold text-ink-base">
          {row.plan ? planLabel(row.plan) : '�'}
        </p>
      ),
    },
    {
      key: 'expiry',
      header: 'Expiry',
      width: '1.1fr',
      render: (row) => (
        <p className="text-[12.5px] font-semibold text-ink-base">
          {row.plan === 'permanent' ? 'No expiry' : formatCalendarDate(row.ends_at)}
        </p>
      ),
    },
    {
      key: 'remaining',
      header: 'Remaining',
      width: '0.9fr',
      render: (row) =>
        row.days_remaining === null ? (
          <span className="text-[12.5px] text-ink-faint">�</span>
        ) : (
          <span
            className={`text-[12.5px] font-extrabold tabular-nums ${
              row.days_remaining < 0
                ? 'text-expired'
                : row.days_remaining <= 14
                  ? 'text-expiring'
                  : 'text-ink-base'
            }`}
          >
            {row.days_remaining < 0
              ? `${Math.abs(row.days_remaining)}d ago`
              : `${row.days_remaining}d`}
          </span>
        ),
    },
    {
      key: 'status',
      header: 'Status',
      width: '1.1fr',
      render: (row) => (row.status ? <StatusPill status={row.status} /> : '�'),
    },
    {
      key: 'actions',
      header: 'Actions',
      width: '2fr',
      align: 'end',
      render: (row) => (
        <SubscriptionActions
          subscriptionId={row.id}
          status={row.status}
          plan={row.plan}
          subjectName={row.subject_name ?? 'Account'}
        />
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title={variant === 'all' ? 'Subscriptions' : 'Expiring Soon'}
        subtitle={
          variant === 'all'
            ? `${pluralize(rows.length, 'subscription')} on the platform`
            : rows.length === 0
              ? 'Nothing expires in the next fortnight'
              : `${pluralize(rows.length, 'subscription')} inside the fourteen-day window, soonest first`
        }
        action={
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="Search accounts"
            label="Search subscriptions by account name or email"
          />
        }
      />

      {variant === 'all' && (
        <StatusFilter value={filter} onChange={setFilter} counts={countByStatus(rows)} />
      )}

      <DataTable
        rows={visible}
        columns={columns}
        rowKey={(row) => row.id ?? ''}
        loading={query.isLoading}
        empty={
          rows.length === 0
            ? variant === 'all'
              ? {
                  title: 'No subscriptions yet',
                  body: 'A subscription is created when an organization or a teacher registers, and becomes active when you approve it.',
                }
              : {
                  title: 'Nothing expiring',
                  body: 'Subscriptions appear here once they are within fourteen days of their end date.',
                }
            : { title: 'Nothing matches that', body: 'Try a different search or status.' }
        }
      />
    </div>
  );
}
