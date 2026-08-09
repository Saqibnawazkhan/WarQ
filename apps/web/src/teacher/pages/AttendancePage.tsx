import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import {
  ATTENDANCE_MARKS,
  DEFAULT_MARK,
  formatCalendarDate,
  MARK_INITIAL,
  markLabel,
  pluralize,
  today,
  type AttendanceMark,
} from '@warq/core';
import { color } from '@warq/tokens';

import { Button, Card, Chip, EmptyState, useToast } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useAttendance, useMyClasses, useRoster, useSaveAttendance } from '../queries.ts';

/**
 * Taking the register.
 *
 * Everyone starts Present, as the mockups do. A register is mostly presences, so
 * the default that needs the fewest taps is the right one — and "all present
 * unless I say otherwise" is how a teacher actually reads a room.
 *
 * Edits live in local state until saved. The saved register shows through until
 * the first change, so opening yesterday's roll call shows what was recorded
 * rather than a blank slate.
 */
export function AttendancePage() {
  const [params, setParams] = useSearchParams();
  const classes = useMyClasses();
  const toast = useToast();
  const save = useSaveAttendance();

  const rows = useMemo(() => classes.data ?? [], [classes.data]);
  const classId = params.get('class') ?? rows[0]?.id ?? undefined;
  const date = params.get('date') ?? today();

  const roster = useRoster(classId);
  const attendance = useAttendance(classId, date);

  /** Null until the teacher changes something; then it holds the unsaved register. */
  const [edits, setEdits] = useState<Record<string, AttendanceMark> | null>(null);

  const saved = useMemo(() => {
    const map: Record<string, AttendanceMark> = {};
    for (const record of attendance.data?.records ?? []) {
      map[record.student_id] = record.mark;
    }
    return map;
  }, [attendance.data]);

  const students = roster.data ?? [];
  const current = edits ?? saved;
  const dirty = edits !== null;

  function markOf(studentId: string): AttendanceMark {
    return current[studentId] ?? DEFAULT_MARK;
  }

  function set(studentId: string, mark: AttendanceMark) {
    setEdits((existing) => {
      const base = existing ?? { ...saved };
      // Everyone not yet touched is present by default; make that explicit so
      // the saved register matches what is on screen.
      for (const student of students) {
        base[student.id] ??= DEFAULT_MARK;
      }
      return { ...base, [studentId]: mark };
    });
  }

  function allPresent() {
    const next: Record<string, AttendanceMark> = {};
    for (const student of students) next[student.id] = 'present';
    setEdits(next);
  }

  const tally = students.reduce(
    (counts, student) => {
      const mark = markOf(student.id);
      return { ...counts, [mark]: counts[mark] + 1 };
    },
    { present: 0, absent: 0, late: 0 },
  );

  function handleSave() {
    if (!classId) return;

    save.mutate(
      {
        classId,
        date,
        entries: students.map((student) => ({
          studentId: student.id,
          mark: markOf(student.id),
        })),
      },
      {
        onSuccess: (result) => {
          setEdits(null);
          toast(
            result.absent === 0
              ? 'Register saved · everyone present'
              : result.alertable === 0
                ? `Register saved · ${pluralize(result.absent, 'absence')}, no guardian contacts on file`
                : `Register saved · ${pluralize(result.absent, 'absence')} · ${pluralize(result.alertable, 'alert')} queued for guardians`,
            'success',
          );
        },
        onError: (cause) => toast(cause.message, 'danger'),
      },
    );
  }

  if (rows.length === 0 && !classes.isLoading) {
    return (
      <div className="flex flex-col gap-5">
        <PageHeading title="Attendance" />
        <Card padded={false}>
          <EmptyState
            title="No classes yet"
            body="Create a class and add your students before taking a register."
          />
        </Card>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Attendance"
        subtitle={
          attendance.data?.session ? 'Already taken — editing corrects it' : 'Not taken yet'
        }
        action={
          <label className="flex items-center gap-2 rounded-control border border-line bg-raised px-3 py-2 text-[12.5px] font-bold">
            <span className="text-ink-muted">Date</span>
            <input
              type="date"
              value={date}
              max={today()}
              onChange={(event) => {
                setEdits(null);
                setParams((existing) => {
                  existing.set('date', event.target.value);
                  return existing;
                });
              }}
              className="bg-transparent font-bold text-ink"
            />
          </label>
        }
      />

      <div className="flex flex-wrap gap-1.5">
        {rows.map((row) => (
          <Chip
            key={row.id}
            label={`${row.name ?? ''} · ${row.section ?? ''}`}
            selected={row.id === classId}
            onSelect={() => {
              setEdits(null);
              setParams((existing) => {
                existing.set('class', row.id ?? '');
                return existing;
              });
            }}
          />
        ))}
      </div>

      {roster.isLoading ? (
        <Card>
          <p className="py-6 text-center text-[13px] text-ink-muted">Loading…</p>
        </Card>
      ) : students.length === 0 ? (
        <Card padded={false}>
          <EmptyState
            title="No students in this class"
            body="Add students from the class page, then come back to take the register."
          />
        </Card>
      ) : (
        <>
          <div className="flex flex-wrap items-center justify-between gap-3 rounded-tile border border-line bg-raised px-4 py-3">
            <div className="flex gap-4 text-[12.5px] font-bold tabular-nums">
              <span className="text-active">{tally.present} present</span>
              <span className="text-expired">{tally.absent} absent</span>
              <span className="text-pending">{tally.late} late</span>
            </div>

            <button
              type="button"
              onClick={allPresent}
              className="cursor-pointer text-[12px] font-bold text-accent"
            >
              Mark all present
            </button>
          </div>

          <ul className="flex flex-col gap-1.5">
            {students.map((student) => (
              <li
                key={student.id}
                className="flex items-center gap-3 rounded-tile border border-line bg-raised py-2 pr-2.5 pl-4"
              >
                <div className="min-w-0 flex-1">
                  <p className="truncate text-[13.5px] font-semibold">{student.full_name}</p>
                  <p className="text-[11px] text-ink-muted">{student.roll_no}</p>
                </div>

                <div
                  className="flex gap-1.5"
                  role="radiogroup"
                  aria-label={`Attendance for ${student.full_name}`}
                >
                  {ATTENDANCE_MARKS.map((option) => {
                    const selected = markOf(student.id) === option;
                    const hex = color.attendance[option];

                    return (
                      <button
                        key={option}
                        type="button"
                        role="radio"
                        aria-checked={selected}
                        aria-label={markLabel(option)}
                        onClick={() => set(student.id, option)}
                        className="flex h-9 w-10 cursor-pointer items-center justify-center rounded-control border text-[12.5px] font-extrabold transition-colors"
                        style={{
                          backgroundColor: selected ? hex : color.surface.sunken,
                          color: selected ? '#fff' : color.ink.faint,
                          borderColor: selected ? hex : color.border.input,
                        }}
                      >
                        {MARK_INITIAL[option]}
                      </button>
                    );
                  })}
                </div>
              </li>
            ))}
          </ul>

          <div className="sticky bottom-4 flex flex-wrap items-center gap-3">
            <Button
              onClick={handleSave}
              disabled={save.isPending}
              className="h-12 flex-1 shadow-action sm:flex-none sm:px-8"
            >
              {save.isPending
                ? 'Saving…'
                : attendance.data?.session
                  ? 'Update register'
                  : 'Save register'}
            </Button>

            {dirty && (
              <button
                type="button"
                onClick={() => setEdits(null)}
                className="cursor-pointer text-[12.5px] font-bold text-ink-muted hover:text-ink"
              >
                Discard changes
              </button>
            )}

            <p className="text-[12px] text-ink-muted">
              {formatCalendarDate(date)} · absences notify guardians once the worker lands in M7
            </p>
          </div>
        </>
      )}
    </div>
  );
}
