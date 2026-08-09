import { useMemo, useState } from 'react';

import { formatCalendarDate, planLabel } from '@warq/core';
import type { AdminOrgAdmin } from '@warq/data';

import { DataTable, SearchField, StatusPill, type Column } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';
import { useOrgAdmins } from '../queries.ts';

export function OrgAdminsPage() {
  const admins = useOrgAdmins();
  const [search, setSearch] = useState('');

  const rows = useMemo(() => admins.data ?? [], [admins.data]);

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return rows;

    return rows.filter((row) =>
      [row.full_name, row.email, row.organization_name, row.city]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle)),
    );
  }, [rows, search]);

  const columns: Column<AdminOrgAdmin>[] = [
    {
      key: 'name',
      header: 'Administrator',
      width: '1.8fr',
      render: (row) => (
        <>
          <p className="truncate text-[13.5px] font-bold">{row.full_name}</p>
          <p className="truncate text-[11.5px] text-ink-muted">{row.email}</p>
        </>
      ),
    },
    {
      key: 'organization',
      header: 'Organization',
      width: '1.8fr',
      render: (row) => (
        <>
          <p className="truncate text-[12.5px] font-semibold text-ink-base">
            {row.organization_name}
          </p>
          <p className="truncate text-[11.5px] text-ink-muted">{row.city}</p>
        </>
      ),
    },
    {
      key: 'owner',
      header: 'Seat',
      width: '0.9fr',
      // An organization outlives any one administrator, so being the registered
      // owner and merely holding admin rights are different things.
      render: (row) => (
        <span className="text-[12px] font-bold text-ink-base">
          {row.is_owner ? 'Owner' : 'Admin'}
        </span>
      ),
    },
    {
      key: 'plan',
      header: 'Plan',
      width: '0.9fr',
      render: (row) => (
        <p className="text-[12.5px] font-semibold text-ink-base">
          {row.plan ? planLabel(row.plan) : '—'}
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
      key: 'status',
      header: 'Subscription',
      width: '1.1fr',
      render: (row) =>
        row.subscription_status ? <StatusPill status={row.subscription_status} /> : '—',
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Organization Admins"
        subtitle="The person running each organization, and whether they hold the owner seat"
        action={
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="Search admins"
            label="Search administrators by name, email or organization"
          />
        }
      />

      <DataTable
        rows={visible}
        columns={columns}
        rowKey={(row) => row.id ?? ''}
        loading={admins.isLoading}
        empty={
          rows.length === 0
            ? {
                title: 'No organization admins yet',
                body: 'Whoever registers an organization becomes its administrator. They appear here once the organization exists.',
              }
            : { title: 'Nothing matches that', body: 'Try a different search.' }
        }
      />
    </div>
  );
}
