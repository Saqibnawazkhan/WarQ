import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { formatCalendarDate, pluralize } from '@warq/core';
import { color } from '@warq/tokens';
import type { OrgClass } from '@warq/data';

import { DataTable, SearchField, type Column } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useOrgClasses } from '../queries.ts';

export function OrgClassesPage() {
  const classes = useOrgClasses();
  const navigate = useNavigate();
  const [search, setSearch] = useState('');

  const rows = useMemo(() => classes.data ?? [], [classes.data]);

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return rows;

    return rows.filter((row) =>
      [row.name, row.section, row.teacher_name, row.session]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle)),
    );
  }, [rows, search]);

  const columns: Column<OrgClass>[] = [
    {
      key: 'name',
      header: 'Class',
      width: '2.2fr',
      render: (row) => (
        <div className="flex min-w-0 items-center gap-2.5">
          <span
            aria-hidden="true"
            className="h-7 w-[7px] shrink-0 rounded-pill"
            style={{ backgroundColor: color.series[(row.color_index ?? 0) % 6] }}
          />
          <span className="min-w-0">
            <span className="block truncate text-[13.5px] font-bold">{row.name}</span>
            <span className="block truncate text-[11.5px] text-ink-muted">
              Section {row.section} · Session {row.session}
            </span>
          </span>
        </div>
      ),
    },
    {
      key: 'teacher',
      header: 'Teacher',
      width: '1.6fr',
      render: (row) => (
        <p className="truncate text-[12.5px] font-semibold text-ink-base">
          {row.teacher_name ?? '—'}
        </p>
      ),
    },
    {
      key: 'students',
      header: 'Students',
      width: '0.9fr',
      render: (row) => (
        <p className="text-[12.5px] font-bold tabular-nums">{row.student_count ?? 0}</p>
      ),
    },
    {
      key: 'attendance',
      header: 'Attendance',
      width: '1.1fr',
      render: (row) =>
        (row.session_count ?? 0) === 0 ? (
          // No registers is not zero per cent attendance. Saying so would
          // condemn a class that simply has not started yet.
          <span className="text-[12px] text-ink-faint">No registers</span>
        ) : (
          <span className="text-[12.5px] font-extrabold text-active tabular-nums">
            {row.attendance_percent}%
          </span>
        ),
    },
    {
      key: 'assessments',
      header: 'Assessments',
      width: '1.1fr',
      render: (row) => (
        <p className="text-[12.5px] font-semibold text-ink-base tabular-nums">
          {row.assessment_count ?? 0}
        </p>
      ),
    },
    {
      key: 'last',
      header: 'Last register',
      width: '1.2fr',
      render: (row) => (
        <p className="text-[12.5px] font-semibold text-ink-base">
          {row.last_session_date ? formatCalendarDate(row.last_session_date) : '—'}
        </p>
      ),
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Classes"
        subtitle={`${pluralize(rows.length, 'class', 'classes')} across your organization`}
        action={
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="Search classes"
            label="Search classes by name, section or teacher"
          />
        }
      />

      <DataTable
        rows={visible}
        columns={columns}
        rowKey={(row) => row.id ?? ''}
        onRowClick={(row) => {
          if (row.id) void navigate(`/org/classes/${row.id}`);
        }}
        loading={classes.isLoading}
        empty={
          rows.length === 0
            ? {
                title: 'No classes yet',
                body: 'Classes appear here as your teachers create them. Open one to review its roster, registers and marks.',
              }
            : { title: 'Nothing matches that', body: 'Try a different search.' }
        }
      />
    </div>
  );
}
