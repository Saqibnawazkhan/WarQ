import { Link } from 'react-router-dom';

import { formatCalendarDate, initials, today } from '@warq/core';
import { color } from '@warq/tokens';

import { useSession } from '../../auth/session-context.ts';
import { Card, EmptyState, StatCard } from '../../ui/index.ts';
import { ActivityFeed } from '../../admin/components/ActivityFeed.tsx';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { AttendanceBars } from '../components/AttendanceBars.tsx';
import { TeacherStatePill } from '../components/TeacherStatePill.tsx';
import { useDailyAttendance, useOrgActivity, useOrgOverview, useOrgTeachers } from '../queries.ts';

export function OrgOverviewPage() {
  const { session } = useSession();
  const overview = useOrgOverview();
  const teachers = useOrgTeachers();
  const attendance = useDailyAttendance();
  const activity = useOrgActivity('all');

  const stats = overview.data;
  const staff = teachers.data ?? [];
  const activeToday = staff.filter((teacher) => teacher.activity_state === 'active').length;

  return (
    <div className="flex flex-col gap-5">
      <PageHeading
        eyebrow={formatCalendarDate(today())}
        title={session?.organization?.name ?? 'Organization'}
        action={
          <Link
            to="/org/teachers"
            className="rounded-control bg-accent px-4 py-2.5 text-[13px] font-bold text-on-accent transition-opacity hover:opacity-93"
          >
            + Invite teacher
          </Link>
        }
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          value={String(stats?.teacher_count ?? 0)}
          label="Teachers"
          detail={`${activeToday} active this week`}
          tone={color.brand.accent}
        />
        <StatCard value={String(stats?.class_count ?? 0)} label="Classes" detail="not archived" />
        <StatCard
          value={String(stats?.student_count ?? 0)}
          label="Students"
          detail="across all classes"
        />
        <StatCard
          value={`${stats?.attendance_percent ?? 0}%`}
          label="Attendance"
          detail={`${stats?.classes_marked_today ?? 0} of ${stats?.class_count ?? 0} classes marked today`}
          tone={color.status.active}
        />
      </div>

      <div className="grid items-start gap-3 xl:grid-cols-[1.4fr_1fr]">
        <Card
          title="Teachers"
          action={
            <Link to="/org/teachers" className="text-[12px] font-bold text-accent">
              View all
            </Link>
          }
        >
          {teachers.isLoading ? (
            <p className="py-4 text-[13px] text-ink-muted">Loading…</p>
          ) : staff.length === 0 ? (
            <EmptyState
              title="No teachers yet"
              body="Invite your first teacher and they will appear here with their classes and attendance."
            />
          ) : (
            <ul className="flex flex-col gap-2">
              {staff.slice(0, 6).map((teacher) => (
                <li key={teacher.id}>
                  <Link
                    to="/org/teachers"
                    className="flex items-center gap-3 rounded-tile border border-line-subtle px-3.5 py-3 transition-colors hover:border-line-hover"
                  >
                    <span className="flex size-9 shrink-0 items-center justify-center rounded-control bg-[color-mix(in_srgb,var(--warq-brand-accent)_8%,transparent)] font-display text-[12.5px] font-bold text-accent">
                      {initials(teacher.full_name ?? '?')}
                    </span>

                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[13.5px] font-bold">
                        {teacher.full_name}
                      </span>
                      <span className="block truncate text-[11.5px] text-ink-muted">
                        {teacher.class_count} classes · {teacher.student_count} students
                      </span>
                    </span>

                    <span className="hidden shrink-0 text-[12px] font-semibold text-ink-base sm:block">
                      {teacher.last_attendance_date
                        ? formatCalendarDate(teacher.last_attendance_date)
                        : 'No register yet'}
                    </span>

                    <TeacherStatePill state={teacher.activity_state} />
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <div className="flex flex-col gap-3">
          <Card title="Attendance">
            <AttendanceBars days={attendance.data ?? []} loading={attendance.isLoading} />
          </Card>

          <Card title="Recent activity">
            {activity.isLoading ? (
              <p className="py-2 text-[13px] text-ink-muted">Loading…</p>
            ) : (activity.data?.length ?? 0) === 0 ? (
              <EmptyState
                title="Nothing yet"
                body="Registers, marks and invitations appear here as your teachers work."
              />
            ) : (
              <ActivityFeed entries={(activity.data ?? []).slice(0, 6)} />
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}
