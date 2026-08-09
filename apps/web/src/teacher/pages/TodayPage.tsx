import { Link } from 'react-router-dom';

import { formatCalendarDate, pluralize, today } from '@warq/core';
import { color } from '@warq/tokens';

import { useSession } from '../../auth/session-context.ts';
import { Card, EmptyState, StatCard } from '../../ui/index.ts';
import { ActivityFeed } from '../../admin/components/ActivityFeed.tsx';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useOrgActivity } from '../../org/queries.ts';
import { useToday } from '../queries.ts';

/**
 * The teacher's home screen: which classes still need a register today.
 *
 * Ordered so unmarked classes come first. The point of opening this page in the
 * morning is to find what still needs doing, not to admire what is done.
 */
export function TodayPage() {
  const { session } = useSession();
  const classes = useToday();
  const activity = useOrgActivity('all');

  const rows = classes.data ?? [];
  const pending = rows.filter((row) => !row.taken);
  const done = rows.filter((row) => row.taken);
  const ordered = [...pending, ...done];

  const students = rows.reduce((sum, row) => sum + Number(row.student_count ?? 0), 0);
  const presentToday = done.reduce((sum, row) => sum + Number(row.present ?? 0), 0);
  const markedToday = done.reduce(
    (sum, row) => sum + Number(row.present ?? 0) + Number(row.absent ?? 0) + Number(row.late ?? 0),
    0,
  );

  const firstName = session?.profile.full_name.split(' ')[0] ?? 'there';

  return (
    <div className="flex flex-col gap-5">
      <PageHeading
        eyebrow={formatCalendarDate(today())}
        title={`Good morning, ${firstName}`}
        action={
          <Link
            to="/teacher/classes"
            className="rounded-control bg-accent px-4 py-2.5 text-[13px] font-bold text-on-accent transition-opacity hover:opacity-93"
          >
            + New class
          </Link>
        }
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard value={String(rows.length)} label="Classes" tone={color.brand.accent} />
        <StatCard value={String(students)} label="Students" />
        <StatCard
          value={`${done.length}/${rows.length}`}
          label="Registers taken today"
          detail={pending.length === 0 ? 'All done' : `${pending.length} still to mark`}
          tone={pending.length === 0 ? color.status.active : color.status.pending}
        />
        <StatCard
          value={markedToday === 0 ? '—' : `${Math.round((presentToday / markedToday) * 100)}%`}
          label="Present today"
          detail={markedToday === 0 ? 'No registers yet' : `${presentToday} of ${markedToday}`}
          tone={color.status.active}
        />
      </div>

      <div className="grid items-start gap-3 xl:grid-cols-[1.5fr_1fr]">
        <Card title="Today's register" padded={ordered.length === 0}>
          {classes.isLoading ? (
            <p className="py-4 text-[13px] text-ink-muted">Loading…</p>
          ) : ordered.length === 0 ? (
            <EmptyState
              title="No classes yet"
              body="Create your first class, add your students, and taking the register becomes a thirty-second job each morning."
              action={
                <Link
                  to="/teacher/classes"
                  className="inline-flex rounded-control bg-accent px-4 py-2.5 text-[13px] font-bold text-on-accent"
                >
                  Create a class
                </Link>
              }
            />
          ) : (
            <ul className="flex flex-col gap-2">
              {ordered.map((row) => (
                <li
                  key={row.class_id}
                  className="flex flex-wrap items-center gap-3 rounded-tile border border-line-subtle px-3.5 py-3"
                >
                  <span
                    aria-hidden="true"
                    className="h-7 w-2 shrink-0 rounded-pill"
                    style={{ backgroundColor: color.series[(row.color_index ?? 0) % 6] }}
                  />

                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[14px] font-bold">{row.name}</p>
                    <p className="truncate text-[11.5px] text-ink-muted">
                      Section {row.section} · {pluralize(Number(row.student_count ?? 0), 'student')}
                    </p>
                  </div>

                  {row.taken ? (
                    <span className="flex items-center gap-1.5 text-[12px] font-bold text-active">
                      <svg
                        width="13"
                        height="13"
                        viewBox="0 0 14 14"
                        fill="none"
                        aria-hidden="true"
                      >
                        <path
                          d="M2 7.5L5.5 11L12 3.5"
                          stroke="currentColor"
                          strokeWidth="2"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        />
                      </svg>
                      {row.present}/
                      {Number(row.present ?? 0) + Number(row.absent ?? 0) + Number(row.late ?? 0)}{' '}
                      present
                    </span>
                  ) : (
                    <Link
                      to={`/teacher/attendance?class=${row.class_id ?? ''}`}
                      className="rounded-pill bg-accent px-3.5 py-1.5 text-[12px] font-bold text-on-accent"
                    >
                      Mark
                    </Link>
                  )}
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card title="Recent activity">
          {(activity.data?.length ?? 0) === 0 ? (
            <EmptyState
              title="Nothing yet"
              body="Registers taken and marks entered appear here as you work."
            />
          ) : (
            <ActivityFeed entries={(activity.data ?? []).slice(0, 8)} showActor={false} />
          )}
        </Card>
      </div>
    </div>
  );
}
