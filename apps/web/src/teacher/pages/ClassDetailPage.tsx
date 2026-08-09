import { useState, type FormEvent } from 'react';
import { Link, useParams } from 'react-router-dom';

import { formatCalendarDate, pluralize, today } from '@warq/core';
import { color, tint } from '@warq/tokens';

import { Button, Card, EmptyState, Field, Modal, useToast } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import {
  useAddStudent,
  useAssessments,
  useCreateAssessment,
  useMyClasses,
  useRoster,
} from '../queries.ts';

const ASSESSMENT_TYPES = ['quiz', 'assignment', 'midterm', 'final', 'project', 'lab'] as const;

export function ClassDetailPage() {
  const { classId } = useParams<{ classId: string }>();
  const classes = useMyClasses();
  const roster = useRoster(classId);
  const assessments = useAssessments(classId);

  const [tab, setTab] = useState<'students' | 'assessments'>('students');
  const [addingStudent, setAddingStudent] = useState(false);
  const [addingAssessment, setAddingAssessment] = useState(false);

  const cls = classes.data?.find((row) => row.id === classId);
  const students = roster.data ?? [];
  const papers = assessments.data ?? [];
  const classColor = color.series[(cls?.color_index ?? 0) % color.series.length] ?? color.series[0];

  if (classes.isLoading) return <p className="text-[13px] text-ink-muted">Loading…</p>;

  if (!cls) {
    return (
      <Card padded={false}>
        <EmptyState title="Class not found" body="It may have been archived or removed." />
      </Card>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <Link to="/teacher/classes" className="text-[13px] font-bold text-accent hover:underline">
        ← Classes
      </Link>

      <PageHeading
        title={`${cls.name ?? ''} · ${cls.section ?? ''}`}
        subtitle={`Session ${cls.session ?? ''} · ${pluralize(students.length, 'student')}`}
        action={
          <Link
            to={`/teacher/attendance?class=${classId ?? ''}`}
            className="rounded-control bg-accent px-4 py-2.5 text-[13px] font-bold text-on-accent"
          >
            Take register
          </Link>
        }
      />

      <div className="flex gap-5 border-b border-line" role="tablist" aria-label="Class sections">
        {(
          [
            ['students', `Students (${students.length})`],
            ['assessments', `Assessments (${papers.length})`],
          ] as const
        ).map(([value, label]) => (
          <button
            key={value}
            type="button"
            role="tab"
            aria-selected={tab === value}
            onClick={() => setTab(value)}
            className={`cursor-pointer border-b-2 px-0.5 pb-2.5 text-[13.5px] font-bold transition-colors ${
              tab === value
                ? 'border-accent text-ink'
                : 'border-transparent text-ink-muted hover:text-ink-base'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === 'students' ? (
        <>
          <div className="flex justify-end">
            <Button onClick={() => setAddingStudent(true)}>+ Add student</Button>
          </div>

          {students.length === 0 ? (
            <Card padded={false}>
              <EmptyState
                title="No students yet"
                body="Add your students once and every register, mark and report follows from that list."
                action={
                  <Button onClick={() => setAddingStudent(true)}>Add the first student</Button>
                }
              />
            </Card>
          ) : (
            <ul className="flex flex-col gap-1.5">
              {students.map((student) => (
                <li key={student.id}>
                  <Link
                    to={`/teacher/students/${student.id}`}
                    className="flex items-center gap-3 rounded-tile border border-line bg-raised px-4 py-3 transition-colors hover:border-line-hover"
                  >
                    <span
                      className="flex size-9 shrink-0 items-center justify-center rounded-control font-display text-[12.5px] font-bold"
                      style={{
                        backgroundColor: tint(classColor, '14'),
                        color: classColor,
                      }}
                    >
                      {student.full_name.slice(0, 2).toUpperCase()}
                    </span>

                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[14px] font-semibold">
                        {student.full_name}
                      </span>
                      <span className="block text-[11.5px] text-ink-muted">{student.roll_no}</span>
                    </span>

                    <span className="text-[12px] font-bold text-ink-faint">View →</span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </>
      ) : (
        <>
          <div className="flex justify-end">
            <Button onClick={() => setAddingAssessment(true)}>+ New assessment</Button>
          </div>

          {papers.length === 0 ? (
            <Card padded={false}>
              <EmptyState
                title="No assessments yet"
                body="Create a quiz, assignment or exam, then enter marks against it."
                action={
                  <Button onClick={() => setAddingAssessment(true)}>Create an assessment</Button>
                }
              />
            </Card>
          ) : (
            <ul className="flex flex-col gap-1.5">
              {papers.map((paper) => (
                <li key={paper.id}>
                  <Link
                    to={`/teacher/marks?assessment=${paper.id}&class=${classId ?? ''}`}
                    className="flex items-center gap-3 rounded-tile border border-line bg-raised px-4 py-3 transition-colors hover:border-line-hover"
                  >
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-[14px] font-bold">{paper.name}</span>
                      <span className="block text-[11.5px] text-ink-muted capitalize">
                        {paper.type} · {formatCalendarDate(paper.date)} · out of {paper.total_marks}
                      </span>
                    </span>
                    <span className="text-[12px] font-bold text-accent">Enter marks →</span>
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </>
      )}

      <AddStudentModal
        classId={classId ?? ''}
        open={addingStudent}
        onClose={() => setAddingStudent(false)}
      />
      <AddAssessmentModal
        classId={classId ?? ''}
        open={addingAssessment}
        onClose={() => setAddingAssessment(false)}
      />
    </div>
  );
}

function AddStudentModal({
  classId,
  open,
  onClose,
}: {
  classId: string;
  open: boolean;
  onClose: () => void;
}) {
  const add = useAddStudent();
  const toast = useToast();

  const [fullName, setFullName] = useState('');
  const [rollNo, setRollNo] = useState('');
  const [phone, setPhone] = useState('');
  const [label, setLabel] = useState<'father' | 'mother' | 'guardian' | 'student'>('father');

  function reset() {
    setFullName('');
    setRollNo('');
    setPhone('');
    onClose();
  }

  function submit(event: FormEvent) {
    event.preventDefault();

    add.mutate(
      {
        classId,
        fullName,
        rollNo,
        ...(phone.trim() ? { contacts: [{ label, phone: phone.trim() }] } : {}),
      },
      {
        onSuccess: () => {
          toast(`${fullName} added`, 'success');
          // Keep the dialog open: adding a roster is one sitting, not one student.
          setFullName('');
          setRollNo('');
          setPhone('');
        },
        onError: (cause) => toast(cause.message, 'danger'),
      },
    );
  }

  return (
    <Modal
      open={open}
      onClose={reset}
      title="Add a student"
      description="The dialog stays open so you can add the whole class in one go."
    >
      <form onSubmit={submit} className="flex flex-col gap-3" noValidate>
        <Field
          label="Full name"
          required
          value={fullName}
          onChange={(event) => setFullName(event.target.value)}
        />
        <Field
          label="Roll number"
          required
          value={rollNo}
          onChange={(event) => setRollNo(event.target.value)}
          placeholder="SE-01"
        />

        <div className="flex gap-2.5">
          <label className="flex flex-col gap-1.5">
            <span className="text-[12.5px] font-bold text-ink-base">Contact</span>
            <select
              value={label}
              onChange={(event) =>
                setLabel(event.target.value as 'father' | 'mother' | 'guardian' | 'student')
              }
              className="h-12 rounded-field border border-line-input bg-sunken px-3 text-[14px] font-semibold text-ink"
            >
              <option value="father">Father</option>
              <option value="mother">Mother</option>
              <option value="guardian">Guardian</option>
              <option value="student">Student</option>
            </select>
          </label>

          <Field
            label="Phone"
            type="tel"
            className="flex-1"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            placeholder="0300 1234567"
            hint="Optional. Absence alerts go here."
          />
        </div>

        <div className="mt-1 flex gap-2.5">
          <Button type="submit" disabled={add.isPending} className="flex-1">
            {add.isPending ? 'Adding…' : 'Add student'}
          </Button>
          <Button variant="ghost" onClick={reset}>
            Done
          </Button>
        </div>
      </form>
    </Modal>
  );
}

function AddAssessmentModal({
  classId,
  open,
  onClose,
}: {
  classId: string;
  open: boolean;
  onClose: () => void;
}) {
  const create = useCreateAssessment();
  const toast = useToast();

  const [name, setName] = useState('');
  const [type, setType] = useState<(typeof ASSESSMENT_TYPES)[number]>('quiz');
  const [date, setDate] = useState(today());
  const [totalMarks, setTotalMarks] = useState('20');

  function reset() {
    setName('');
    setTotalMarks('20');
    onClose();
  }

  function submit(event: FormEvent) {
    event.preventDefault();

    const total = Number(totalMarks);

    if (!Number.isFinite(total) || total <= 0) {
      toast('Total marks must be more than zero.', 'danger');
      return;
    }

    create.mutate(
      { classId, name, type, date, totalMarks: total },
      {
        onSuccess: () => {
          toast(`${name} created`, 'success');
          reset();
        },
        onError: (cause) => toast(cause.message, 'danger'),
      },
    );
  }

  return (
    <Modal open={open} onClose={reset} title="New assessment">
      <form onSubmit={submit} className="flex flex-col gap-3" noValidate>
        <Field
          label="Name"
          required
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="Quiz 1"
        />

        <label className="flex flex-col gap-1.5">
          <span className="text-[12.5px] font-bold text-ink-base">Type</span>
          <select
            value={type}
            onChange={(event) => setType(event.target.value as (typeof ASSESSMENT_TYPES)[number])}
            className="h-12 rounded-field border border-line-input bg-sunken px-3 text-[14px] font-semibold text-ink capitalize"
          >
            {ASSESSMENT_TYPES.map((option) => (
              <option key={option} value={option} className="capitalize">
                {option}
              </option>
            ))}
          </select>
        </label>

        <Field
          label="Date"
          type="date"
          required
          value={date}
          onChange={(event) => setDate(event.target.value)}
        />
        <Field
          label="Out of"
          type="number"
          min={1}
          required
          value={totalMarks}
          onChange={(event) => setTotalMarks(event.target.value)}
          hint="The denominator for every mark and every grade."
        />

        <div className="mt-1 flex gap-2.5">
          <Button type="submit" disabled={create.isPending} className="flex-1">
            {create.isPending ? 'Creating…' : 'Create assessment'}
          </Button>
          <Button variant="ghost" onClick={reset}>
            Cancel
          </Button>
        </div>
      </form>
    </Modal>
  );
}
