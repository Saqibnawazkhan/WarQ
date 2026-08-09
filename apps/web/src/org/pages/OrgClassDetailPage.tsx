import { Link, useParams } from 'react-router-dom';

import { formatCalendarDate, pluralize } from '@warq/core';
import { color, tint } from '@warq/tokens';

import { Card, EmptyState, StatCard } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useClassDetail } from '../queries.ts';

/**
 * One class, reviewed.
 *
 * This is where attendance and marks review live. Both always begin by choosing
 * a class, so a separate page for each would open with a class picker and
 * nothing else — the class is the natural container, not a filter.
 *
 * Everything here is read-only. An Organization Admin reviews their teachers'
 * work; they do not take the register themselves.
 */
export function OrgClassDetailPage() {
  const { classId } = useParams<{ classId: string }>();
  const detail = useClassDetail(classId);

  const cls = detail.data?.details;
  const students = detail.data?.students ?? [];
  const assessments = detail.data?.assessments ?? [];
  const sessions = detail.data?.sessions ?? [];

  if (detail.isLoading) {
    return <p className="text-[13px] text-ink-muted">Loading…</p>;
  }

  if (!cls) {
    return (
      <Card>
        <EmptyState
          title="Class not found"
          body="It may have been archived, or it may belong to another organization."
        />
      </Card>
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <div>
        <Link to="/org/classes" className="text-[13px] font-bold text-accent hover:underline">
          ← Classes
        </Link>
      </div>

      <PageHeading
        title={`${cls.name ?? 'Class'} · ${cls.section ?? ''}`}
        subtitle={`${cls.teacher_name ?? 'No teacher'} · Session ${cls.session ?? '—'} · ${pluralize(
          Number(cls.student_count ?? 0),
          'student',
        )}`}
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          value={String(cls.student_count ?? 0)}
          label="Students"
          tone={color.brand.accent}
        />
        <StatCard
          value={(cls.session_count ?? 0) === 0 ? '—' : `${cls.attendance_percent ?? 0}%`}
          label="Attendance"
          detail={`${cls.session_count ?? 0} registers taken`}
          tone={color.status.active}
        />
        <StatCard value={String(cls.assessment_count ?? 0)} label="Assessments" />
        <StatCard
          value={cls.last_session_date ? formatCalendarDate(cls.last_session_date) : 'Never'}
          label="Last register"
        />
      </div>

      <div className="grid items-start gap-3 xl:grid-cols-[1.5fr_1fr]">
        <Card title="Students" padded={students.length === 0}>
          {students.length === 0 ? (
            <EmptyState
              title="No students yet"
              body="The teacher adds students to their own class. They appear here as soon as they do."
            />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[480px] text-left">
                <thead>
                  <tr className="border-b border-line-subtle">
                    <Th>Student</Th>
                    <Th>Roll</Th>
                    <Th align="right">Attendance</Th>
                    <Th align="right">Marks</Th>
                    <Th align="right">Grade</Th>
                  </tr>
                </thead>
                <tbody>
                  {students.map((student) => (
                    <tr
                      key={student.student_id}
                      className="border-b border-line-faint last:border-0"
                    >
                      <Td>
                        <span className="font-bold">{student.full_name}</span>
                      </Td>
                      <Td>
                        <span className="text-ink-muted">{student.roll_no}</span>
                      </Td>
                      <Td align="right">
                        {student.sessions === 0 ? (
                          <span className="text-ink-faint">—</span>
                        ) : (
                          <span className="font-semibold tabular-nums">
                            {student.attendance_percent}%
                          </span>
                        )}
                      </Td>
                      <Td align="right">
                        {student.assessments_marked === 0 ? (
                          <span className="text-ink-faint">Unmarked</span>
                        ) : (
                          <span className="font-semibold tabular-nums">
                            {student.obtained}/{student.total}
                          </span>
                        )}
                      </Td>
                      <Td align="right">
                        {/* Null grade means nothing marked, which is not an F. */}
                        {student.grade ? (
                          <span
                            className="rounded-xs px-2 py-0.5 text-[11.5px] font-extrabold"
                            style={{
                              backgroundColor: tint(
                                color.grade[student.grade as keyof typeof color.grade] ??
                                  color.grade.none,
                                '1A',
                              ),
                              color:
                                color.grade[student.grade as keyof typeof color.grade] ??
                                color.grade.none,
                            }}
                          >
                            {student.grade}
                          </span>
                        ) : (
                          <span className="text-ink-faint">—</span>
                        )}
                      </Td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>

        <div className="flex flex-col gap-3">
          <Card title="Assessments" padded={assessments.length === 0}>
            {assessments.length === 0 ? (
              <EmptyState
                title="None set yet"
                body="Quizzes, assignments and exams appear here once the teacher creates them."
              />
            ) : (
              <ul className="flex flex-col gap-2">
                {assessments.map((assessment) => (
                  <li
                    key={assessment.id}
                    className="flex items-center justify-between gap-3 rounded-control border border-line-subtle px-3.5 py-2.5"
                  >
                    <div className="min-w-0">
                      <p className="truncate text-[13px] font-bold">{assessment.name}</p>
                      <p className="text-[11.5px] text-ink-muted capitalize">
                        {assessment.type} · {formatCalendarDate(assessment.date)}
                      </p>
                    </div>
                    <span className="shrink-0 text-[12px] font-bold text-ink-base tabular-nums">
                      out of {assessment.total_marks}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card title="Recent registers" padded={sessions.length === 0}>
            {sessions.length === 0 ? (
              <EmptyState
                title="No registers taken"
                body="Attendance appears here the first time this class is marked."
              />
            ) : (
              <ul className="flex flex-col gap-1.5">
                {sessions.slice(0, 10).map((session) => (
                  <li
                    key={session.id}
                    className="flex items-center justify-between gap-3 py-1 text-[12.5px]"
                  >
                    <span className="font-semibold">{formatCalendarDate(session.date)}</span>
                    <span className="text-ink-muted">taken</span>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}

function Th({ children, align }: { children: React.ReactNode; align?: 'right' }) {
  return (
    <th
      className={`pb-2.5 text-[11px] font-bold tracking-[0.06em] text-ink-muted uppercase ${
        align === 'right' ? 'text-right' : ''
      }`}
    >
      {children}
    </th>
  );
}

function Td({ children, align }: { children: React.ReactNode; align?: 'right' }) {
  return (
    <td className={`py-2.5 text-[13px] ${align === 'right' ? 'text-right' : ''}`}>{children}</td>
  );
}
