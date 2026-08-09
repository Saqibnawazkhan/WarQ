import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import { pluralize } from '@warq/core';
import { color, tint } from '@warq/tokens';
import type { StudentPerformanceRow } from '@warq/data';

import { DataTable, SearchField, type Column } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useOrgStudents } from '../queries.ts';

export function OrgStudentsPage() {
  const students = useOrgStudents();
  const navigate = useNavigate();
  const [search, setSearch] = useState('');

  const rows = useMemo(() => students.data ?? [], [students.data]);

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase();
    if (!needle) return rows;

    return rows.filter((row) =>
      [row.full_name, row.roll_no]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle)),
    );
  }, [rows, search]);

  const columns: Column<StudentPerformanceRow>[] = [
    {
      key: 'name',
      header: 'Student',
      width: '2fr',
      render: (row) => (
        <>
          <p className="truncate text-[13.5px] font-bold">{row.full_name}</p>
          <p className="truncate text-[11.5px] text-ink-muted">{row.roll_no}</p>
        </>
      ),
    },
    {
      key: 'attendance',
      header: 'Attendance',
      width: '1.2fr',
      render: (row) =>
        row.sessions === 0 ? (
          <span className="text-[12px] text-ink-faint">No registers</span>
        ) : (
          <div className="flex items-center gap-2">
            <span className="w-9 shrink-0 text-[12.5px] font-bold tabular-nums">
              {row.attendance_percent}%
            </span>
            <span className="h-1.5 min-w-0 flex-1 overflow-hidden rounded-pill bg-meter">
              <span
                className="block h-full rounded-pill bg-active"
                style={{ width: `${row.attendance_percent ?? 0}%` }}
              />
            </span>
          </div>
        ),
    },
    {
      key: 'present',
      header: 'P · A · L',
      width: '1fr',
      render: (row) => (
        <p className="text-[12px] font-semibold tabular-nums">
          <span className="text-active">{row.present ?? 0}</span>
          <span className="text-ink-faint"> · </span>
          <span className="text-expired">{row.absent ?? 0}</span>
          <span className="text-ink-faint"> · </span>
          <span className="text-pending">{row.late ?? 0}</span>
        </p>
      ),
    },
    {
      key: 'marks',
      header: 'Marks',
      width: '1fr',
      render: (row) =>
        row.assessments_marked === 0 ? (
          <span className="text-[12px] text-ink-faint">Unmarked</span>
        ) : (
          <span className="text-[12.5px] font-semibold tabular-nums">
            {row.obtained}/{row.total}
          </span>
        ),
    },
    {
      key: 'grade',
      header: 'Grade',
      width: '0.8fr',
      render: (row) =>
        row.grade ? (
          <span
            className="rounded-xs px-2.5 py-1 text-[11.5px] font-extrabold"
            style={{
              backgroundColor: tint(
                color.grade[row.grade as keyof typeof color.grade] ?? color.grade.none,
                '1A',
              ),
              color: color.grade[row.grade as keyof typeof color.grade] ?? color.grade.none,
            }}
          >
            {row.grade}
          </span>
        ) : (
          <span className="text-[12px] text-ink-faint">—</span>
        ),
    },
  ];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Students"
        subtitle={`${pluralize(rows.length, 'student')} across every class`}
        action={
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="Search students"
            label="Search students by name or roll number"
          />
        }
      />

      <DataTable
        rows={visible}
        columns={columns}
        rowKey={(row) => row.student_id ?? ''}
        onRowClick={(row) => {
          if (row.class_id) void navigate(`/org/classes/${row.class_id}`);
        }}
        loading={students.isLoading}
        empty={
          rows.length === 0
            ? {
                title: 'No students yet',
                body: 'Teachers add students to their own classes. Everyone in your organization appears here once they do.',
              }
            : { title: 'Nothing matches that', body: 'Try a different name or roll number.' }
        }
      />
    </div>
  );
}
