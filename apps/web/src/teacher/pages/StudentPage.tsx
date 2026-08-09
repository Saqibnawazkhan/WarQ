import { Link, useParams } from 'react-router-dom';

import { aggregate, attendancePercent, percentage, pluralize, possessive } from '@warq/core';
import { color, tint } from '@warq/tokens';

import { Card, EmptyState, StatCard } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useOrgStudents } from '../../org/queries.ts';
import { useAssessments, useMarks, useStudentContacts } from '../queries.ts';

/**
 * One student's record: attendance, every assessment, and the resulting grade.
 *
 * The performance bars show each assessment separately rather than only the
 * total, because a total hides whether a student is slipping or recovering.
 */
export function StudentPage() {
  const { studentId } = useParams<{ studentId: string }>();
  const students = useOrgStudents();

  const student = students.data?.find((row) => row.student_id === studentId);
  const assessments = useAssessments(student?.class_id ?? undefined);
  const contacts = useStudentContacts(studentId);

  if (students.isLoading) return <p className="text-[13px] text-ink-muted">Loading…</p>;

  if (!student) {
    return (
      <Card padded={false}>
        <EmptyState
          title="Student not found"
          body="They may have been removed, or belong to a class that is no longer yours."
        />
      </Card>
    );
  }

  const attendance = {
    present: Number(student.present ?? 0),
    absent: Number(student.absent ?? 0),
    late: Number(student.late ?? 0),
  };

  const sessions = Number(student.sessions ?? 0);
  const grade = student.grade;

  return (
    <div className="flex flex-col gap-4">
      <Link
        to={`/teacher/classes/${student.class_id ?? ''}`}
        className="text-[13px] font-bold text-accent hover:underline"
      >
        ← Class
      </Link>

      <PageHeading
        title={student.full_name ?? 'Student'}
        subtitle={`${student.roll_no ?? ''} · ${pluralize(sessions, 'session')} recorded`}
      />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          value={sessions === 0 ? '—' : `${attendancePercent(attendance)}%`}
          label="Attendance"
          detail={
            sessions === 0
              ? 'No registers yet'
              : `${attendance.present} present · ${attendance.absent} absent · ${attendance.late} late`
          }
          tone={color.status.active}
        />
        <StatCard
          value={
            student.assessments_marked === 0
              ? '—'
              : `${student.obtained ?? 0}/${student.total ?? 0}`
          }
          label="Marks"
          detail={`${student.assessments_marked ?? 0} marked · ${student.assessments_pending ?? 0} pending`}
        />
        <StatCard
          value={student.assessments_marked === 0 ? '—' : `${student.marks_percent ?? 0}%`}
          label="Percentage"
        />
        <StatCard
          value={grade ?? '—'}
          label="Grade"
          detail={grade ? undefined : 'Nothing marked yet'}
          tone={grade ? color.grade[grade as keyof typeof color.grade] : undefined}
        />
      </div>

      <div className="grid items-start gap-3 xl:grid-cols-[1.4fr_1fr]">
        <Card title="Assessment performance">
          <PerformanceBars
            studentId={studentId ?? ''}
            classId={student.class_id ?? ''}
            assessmentCount={assessments.data?.length ?? 0}
          />
        </Card>

        <div className="flex flex-col gap-3">
          <Card title="Attendance">
            {sessions === 0 ? (
              <p className="py-2 text-[12.5px] text-ink-muted">
                No registers taken for this class yet.
              </p>
            ) : (
              <>
                <div className="mb-3 h-2 overflow-hidden rounded-pill bg-meter">
                  <div
                    className="h-full rounded-pill bg-active"
                    style={{ width: `${attendancePercent(attendance)}%` }}
                  />
                </div>
                <dl className="flex flex-wrap gap-x-5 gap-y-1 text-[12px] font-semibold">
                  <Pair label="Present" value={attendance.present} tone={color.status.active} />
                  <Pair label="Absent" value={attendance.absent} tone={color.status.expired} />
                  <Pair label="Late" value={attendance.late} tone={color.status.pending} />
                </dl>
              </>
            )}
          </Card>

          <Card title="Contacts">
            {(contacts.data?.length ?? 0) === 0 ? (
              <p className="py-1 text-[12.5px] leading-relaxed text-ink-muted">
                No contacts on file, so no absence alert can be sent for{' '}
                {possessive(student.full_name ?? 'this student')} absences. Add one from the class
                page.
              </p>
            ) : (
              <ul className="flex flex-col gap-2">
                {contacts.data?.map((contact) => (
                  <li key={contact.id} className="flex items-center justify-between gap-3">
                    <span className="text-[12.5px] font-semibold text-ink-muted capitalize">
                      {contact.label}
                      {contact.receives_alerts ? '' : ' · alerts off'}
                    </span>
                    <span className="text-[13px] font-bold tabular-nums">{contact.phone}</span>
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

function PerformanceBars({
  studentId,
  classId,
  assessmentCount,
}: {
  studentId: string;
  classId: string;
  assessmentCount: number;
}) {
  const assessments = useAssessments(classId);

  if (assessmentCount === 0) {
    return (
      <p className="py-2 text-[12.5px] text-ink-muted">
        No assessments in this class yet. Create one and marks appear here.
      </p>
    );
  }

  return (
    <ul className="flex flex-col gap-2.5">
      {assessments.data?.map((paper) => (
        <AssessmentBar
          key={paper.id}
          assessmentId={paper.id}
          name={paper.name}
          total={Number(paper.total_marks)}
          studentId={studentId}
        />
      ))}
    </ul>
  );
}

function AssessmentBar({
  assessmentId,
  name,
  total,
  studentId,
}: {
  assessmentId: string;
  name: string;
  total: number;
  studentId: string;
}) {
  const marks = useMarks(assessmentId);
  const mark = marks.data?.find((row) => row.student_id === studentId);
  const score = mark?.score ?? null;
  const pct = score === null ? null : percentage(Number(score), total);

  const summary = aggregate([{ score: score === null ? null : Number(score), total }]);

  return (
    <li className="flex items-center gap-3">
      <span className="w-28 shrink-0 truncate text-[11.5px] font-semibold text-ink-base">
        {name}
      </span>

      <span className="h-2 min-w-0 flex-1 overflow-hidden rounded-pill bg-meter">
        <span className="block h-full rounded-pill bg-accent" style={{ width: `${pct ?? 0}%` }} />
      </span>

      <span className="w-14 shrink-0 text-right text-[11.5px] font-bold tabular-nums">
        {score === null ? '—' : `${score}/${total}`}
      </span>

      <span
        className="w-9 shrink-0 rounded-xs py-0.5 text-center text-[11px] font-extrabold"
        style={{
          backgroundColor: tint(
            score === null ? color.grade.none : color.grade[summary.grade],
            '1A',
          ),
          color: score === null ? color.grade.none : color.grade[summary.grade],
        }}
      >
        {score === null ? '—' : summary.grade}
      </span>
    </li>
  );
}

function Pair({ label, value, tone }: { label: string; value: number; tone: string }) {
  return (
    <div className="flex gap-1.5">
      <dt className="text-ink-muted">{label}</dt>
      <dd className="tabular-nums" style={{ color: tone }}>
        {value}
      </dd>
    </div>
  );
}
