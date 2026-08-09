import { useMemo, useState } from 'react';

import { formatCalendarDate, planLabel } from '@warq/core';
import type { AdminOrganization } from '@warq/data';

import { DataTable, Drawer, SearchField, StatusPill, type Column } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';
import { StatusFilter } from '../components/StatusFilter.tsx';
import {
  countByStatus,
  matchesStatus,
  type StatusFilterValue,
} from '../components/status-filter.ts';
import { SubscriptionActions } from '../components/SubscriptionActions.tsx';
import { useOrganizations, useSubscriptionHistory } from '../queries.ts';

export function OrganizationsPage() {
  const organizations = useOrganizations();
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<StatusFilterValue>('all');
  const [openId, setOpenId] = useState<string | null>(null);

  const rows = useMemo(() => organizations.data ?? [], [organizations.data]);

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();

    return rows.filter((row) => {
      if (!matchesStatus(row.status, filter)) return false;
      if (!needle) return true;

      return [row.name, row.city, row.admin_name, row.email]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle));
    });
  }, [rows, search, filter]);

  const selected = rows.find((row) => row.id === openId) ?? null;

  const columns: Column<AdminOrganization>[] = [
    {
      key: 'name',
      header: 'Organization',
      width: '2.2fr',
      render: (row) => (
        <>
          <p className="truncate text-[13.5px] font-bold">{row.name}</p>
          <p className="truncate text-[11.5px] text-ink-muted">{row.city}</p>
        </>
      ),
    },
    {
      key: 'admin',
      header: 'Admin',
      width: '1.6fr',
      render: (row) => (
        <p className="truncate text-[12.5px] font-semibold text-ink-base">
          {row.admin_name ?? '�'}
        </p>
      ),
    },
    {
      key: 'plan',
      header: 'Plan',
      width: '1fr',
      render: (row) => (
        <p className="text-[12.5px] font-semibold text-ink-base">
          {row.plan ? planLabel(row.plan) : '�'}
        </p>
      ),
    },
    {
      key: 'teachers',
      header: 'Teachers',
      width: '0.8fr',
      render: (row) => (
        <p className="text-[12.5px] font-bold tabular-nums">{row.teacher_count ?? 0}</p>
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
      key: 'status',
      header: 'Status',
      width: '1.1fr',
      render: (row) => (row.status ? <StatusPill status={row.status} /> : '�'),
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Organizations"
        subtitle={`${rows.length} on the platform`}
        action={
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="Search organizations"
            label="Search organizations by name, city or admin"
          />
        }
      />

      <StatusFilter value={filter} onChange={setFilter} counts={countByStatus(rows)} />

      <DataTable
        rows={visible}
        columns={columns}
        rowKey={(row) => row.id ?? ''}
        onRowClick={(row) => setOpenId(row.id)}
        loading={organizations.isLoading}
        empty={
          rows.length === 0
            ? {
                title: 'No organizations yet',
                body: 'Institutions appear here when they register. Their requests land in Pending Requests for you to approve.',
              }
            : {
                title: 'Nothing matches that',
                body: 'Try a different search, or clear the status filter.',
              }
        }
      />

      <OrganizationDrawer
        organization={selected}
        open={openId !== null}
        onClose={() => setOpenId(null)}
      />
    </div>
  );
}

function OrganizationDrawer({
  organization,
  open,
  onClose,
}: {
  organization: AdminOrganization | null;
  open: boolean;
  onClose: () => void;
}) {
  const history = useSubscriptionHistory(organization?.subscription_id ?? null);

  if (!organization) return null;

  const facts: [string, string][] = [
    ['Organization admin', organization.admin_name ?? 'Not assigned'],
    ['Email', organization.email ?? '�'],
    ['Phone', organization.phone ?? '�'],
    ['Plan', organization.plan ? planLabel(organization.plan) : '�'],
    ['Start', formatCalendarDate(organization.starts_at)],
    [
      'Expiry',
      organization.plan === 'permanent' ? 'No expiry' : formatCalendarDate(organization.ends_at),
    ],
    ['Teachers', String(organization.teacher_count ?? 0)],
    ['Classes', String(organization.class_count ?? 0)],
    ['Students', String(organization.student_count ?? 0)],
  ];

  return (
    <Drawer open={open} onClose={onClose} title={organization.name ?? 'Organization'}>
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h2 className="font-display text-[19px] font-bold">{organization.name}</h2>
          <p className="mt-0.5 text-[12.5px] text-ink-muted">
            {organization.city} · requested{' '}
            {formatCalendarDate(dateOnly(organization.requested_at))}
          </p>
        </div>
        {organization.status && <StatusPill status={organization.status} />}
      </div>

      <dl className="mt-4 flex flex-col gap-2 rounded-tile border border-line-subtle px-4 py-3.5">
        {facts.map(([label, value]) => (
          <div key={label} className="flex justify-between gap-4 text-[13px]">
            <dt className="font-semibold text-ink-muted">{label}</dt>
            <dd className="truncate text-right font-bold text-ink-base">{value}</dd>
          </div>
        ))}
      </dl>

      <h3 className="mt-5 mb-2 font-display text-[13.5px] font-bold">Subscription history</h3>
      {history.isLoading ? (
        <p className="text-[12.5px] text-ink-muted">Loading⬦</p>
      ) : (history.data?.length ?? 0) === 0 ? (
        <p className="text-[12.5px] text-ink-muted">
          Nothing yet � the history starts when this subscription is approved.
        </p>
      ) : (
        <ul className="flex flex-col gap-2">
          {history.data?.map((event) => (
            <li
              key={event.id}
              className="flex items-baseline justify-between gap-3 rounded-control border border-line-subtle px-3.5 py-2.5 text-[12.5px]"
            >
              <span className="font-bold capitalize">{event.action}</span>
              <span className="text-right font-semibold text-ink-muted">
                {event.to_date
                  ? `until ${formatCalendarDate(event.to_date)}`
                  : formatCalendarDate(dateOnly(event.created_at))}
              </span>
            </li>
          ))}
        </ul>
      )}

      <h3 className="mt-5 mb-2 font-display text-[13.5px] font-bold">Actions</h3>
      <div className="flex justify-start">
        <SubscriptionActions
          subscriptionId={organization.subscription_id}
          status={organization.status}
          plan={organization.plan}
          subjectName={organization.name ?? 'Organization'}
          size="md"
          onDone={onClose}
        />
      </div>
    </Drawer>
  );
}

/** A timestamp column rendered as the calendar date it falls on. */
function dateOnly(timestamp: string | null): string | null {
  return timestamp ? timestamp.slice(0, 10) : null;
}
