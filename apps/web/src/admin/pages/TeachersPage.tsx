import { useMemo, useState } from 'react';

import { formatCalendarDate, planLabel } from '@warq/core';
import type { AdminIndividualTeacher } from '@warq/data';

import { DataTable, SearchField, StatusPill, type Column } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';
import { StatusFilter } from '../components/StatusFilter.tsx';
import {
  countByStatus,
  matchesStatus,
  type StatusFilterValue,
} from '../components/status-filter.ts';
import { SubscriptionActions } from '../components/SubscriptionActions.tsx';
import { useIndividualTeachers } from '../queries.ts';

export function TeachersPage() {
  const teachers = useIndividualTeachers();
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<StatusFilterValue>('all');

  const rows = useMemo(() => teachers.data ?? [], [teachers.data]);

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();

    return rows.filter((row) => {
      if (!matchesStatus(row.status, filter)) return false;
      if (!needle) return true;

      return [row.full_name, row.email]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle));
    });
  }, [rows, search, filter]);

  const columns: Column<AdminIndividualTeacher>[] = [
    {
      key: 'name',
      header: 'Teacher',
      width: '1.8fr',
      render: (row) => <p className="truncate text-[13.5px] font-bold">{row.full_name}</p>,
    },
    {
      key: 'email',
      header: 'Email',
      width: '2fr',
      render: (row) => (
        <p className="truncate text-[12.5px] font-semibold text-ink-base">{row.email}</p>
      ),
    },
    {
      key: 'classes',
      header: 'Classes',
      width: '0.8fr',
      render: (row) => (
        <p className="text-[12.5px] font-bold tabular-nums">{row.class_count ?? 0}</p>
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
      key: 'status',
      header: 'Status',
      width: '1fr',
      render: (row) => (row.status ? <StatusPill status={row.status} /> : '�'),
    },
    {
      key: 'actions',
      header: 'Actions',
      width: '2fr',
      align: 'end',
      render: (row) => (
        <SubscriptionActions
          subscriptionId={row.subscription_id}
          status={row.status}
          plan={row.plan}
          subjectName={row.full_name ?? 'Teacher'}
        />
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Individual Teachers"
        subtitle="Teachers who hold their own subscription rather than belonging to an organization"
        action={
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="Search teachers"
            label="Search teachers by name or email"
          />
        }
      />

      <StatusFilter value={filter} onChange={setFilter} counts={countByStatus(rows)} />

      <DataTable
        rows={visible}
        columns={columns}
        rowKey={(row) => row.id ?? ''}
        loading={teachers.isLoading}
        empty={
          rows.length === 0
            ? {
                title: 'No individual teachers yet',
                body: 'Teachers who sign up without an organization appear here, holding their own subscription.',
              }
            : { title: 'Nothing matches that', body: 'Try a different search or status.' }
        }
      />
    </div>
  );
}
