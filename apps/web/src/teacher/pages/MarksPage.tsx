import { useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import { classAverage, formatCalendarDate, gradeFor, percentage } from '@warq/core';
import { color, tint } from '@warq/tokens';

import { Button, Card, Chip, EmptyState, useToast } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useAssessments, useMarks, useMyClasses, useRoster, useSaveMarks } from '../queries.ts';

/**
 * Entering marks.
 *
 * The grade beside each box updates as you type, so a mistyped mark shows itself
 * before it is saved rather than at the end of term.
 *
 * An empty box means not yet marked and is stored as nothing at all — different
 * from a zero, which means the student sat it and scored none. Only the second
 * one counts against their total.
 */
export function MarksPage() {
  const [params, setParams] = useSearchParams();
  const classes = useMyClasses();
  const toast = useToast();
  const save = useSaveMarks();

  const classRows = useMemo(() => classes.data ?? [], [classes.data]);
  const classId = params.get('class') ?? classRows[0]?.id ?? undefined;

  const assessments = useAssessments(classId);
  const papers = useMemo(() => assessments.data ?? [], [assessments.data]);
  const assessmentId = params.get('assessment') ?? papers[0]?.id;

  const paper = papers.find((row) => row.id === assessmentId);
  const roster = useRoster(classId);
  const marks = useMarks(assessmentId);

  /** Null until a box is touched; then it holds the unsaved sheet. */
  const [edits, setEdits] = useState<Record<string, string> | null>(null);

  const saved = useMemo(() => {
    const map: Record<string, string> = {};
    for (const mark of marks.data ?? []) {
      map[mark.student_id] = mark.score === null ? '' : String(mark.score);
    }
    return map;
  }, [marks.data]);

  const students = roster.data ?? [];
  const current = edits ?? saved;
  const total = Number(paper?.total_marks ?? 0);

  function valueOf(studentId: string): string {
    return current[studentId] ?? '';
  }

  function set(studentId: string, value: string) {
    setEdits((existing) => ({ ...(existing ?? saved), [studentId]: value }));
  }

  // One pass, keyed to the student rather than to a position, so a row and its
  // score cannot drift apart.
  const sheet = students.map((student) => {
    const raw = valueOf(student.id).trim();
    const score = raw === '' ? null : Number(raw);
    const pct = score === null ? null : percentage(score, total);

    return {
      student,
      score,
      grade: pct === null ? null : gradeFor(pct),
      over: score !== null && score > total,
    };
  });

  const average = classAverage(
    sheet.map((row) => row.score),
    total,
  );

  function handleSave() {
    if (!assessmentId) return;

    const entries = sheet.map((row) => ({
      studentId: row.student.id,
      score: row.score,
    }));

    const invalid = entries.find(
      (entry) => entry.score !== null && (!Number.isFinite(entry.score) || entry.score > total),
    );

    if (invalid) {
      toast(`A mark is above the total of ${total}. Check it before saving.`, 'danger');
      return;
    }

    save.mutate(
      { assessmentId, entries },
      {
        onSuccess: (result) => {
          setEdits(null);
          toast(
            `${paper?.name ?? 'Marks'} saved · ${result.marked} of ${students.length} marked`,
            'success',
          );
        },
        onError: (cause) => toast(cause.message, 'danger'),
      },
    );
  }

  if (classRows.length === 0 && !classes.isLoading) {
    return (
      <div className="flex flex-col gap-5">
        <PageHeading title="Marks" />
        <Card padded={false}>
          <EmptyState title="No classes yet" body="Create a class and add students first." />
        </Card>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Marks"
        subtitle={
          paper
            ? `${paper.type} · ${formatCalendarDate(paper.date)} · out of ${paper.total_marks} · class average ${average === null ? '—' : `${average}%`}`
            : 'Choose a class and an assessment'
        }
      />

      <div className="flex flex-wrap gap-1.5">
        {classRows.map((row) => (
          <Chip
            key={row.id}
            label={`${row.name ?? ''} · ${row.section ?? ''}`}
            selected={row.id === classId}
            onSelect={() => {
              setEdits(null);
              setParams({ class: row.id ?? '' });
            }}
          />
        ))}
      </div>

      {papers.length === 0 ? (
        <Card padded={false}>
          <EmptyState
            title="No assessments in this class"
            body="Create one from the class page, then enter marks against it here."
          />
        </Card>
      ) : (
        <>
          <div className="flex flex-wrap gap-1.5 border-t border-line-subtle pt-3">
            {papers.map((row) => (
              <Chip
                key={row.id}
                label={row.name}
                selected={row.id === assessmentId}
                onSelect={() => {
                  setEdits(null);
                  setParams({ class: classId ?? '', assessment: row.id });
                }}
              />
            ))}
          </div>

          {students.length === 0 ? (
            <Card padded={false}>
              <EmptyState
                title="No students in this class"
                body="Add students from the class page before entering marks."
              />
            </Card>
          ) : (
            <>
              <ul className="flex flex-col gap-1.5">
                {sheet.map(({ student, grade, over }) => {
                  return (
                    <li
                      key={student.id}
                      className="flex items-center gap-3 rounded-tile border border-line bg-raised py-2 pr-3 pl-4"
                    >
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-[13.5px] font-semibold">{student.full_name}</p>
                        <p className="text-[11px] text-ink-muted">{student.roll_no}</p>
                      </div>

                      <label className="sr-only" htmlFor={`mark-${student.id}`}>
                        Mark for {student.full_name}, out of {total}
                      </label>
                      <input
                        id={`mark-${student.id}`}
                        type="number"
                        min={0}
                        max={total}
                        step="0.5"
                        value={valueOf(student.id)}
                        onChange={(event) => set(student.id, event.target.value)}
                        placeholder="—"
                        aria-invalid={over || undefined}
                        className={`h-10 w-16 rounded-control border bg-sunken text-center text-[14px] font-bold tabular-nums ${
                          over ? 'border-expired text-expired' : 'border-line-input text-ink'
                        }`}
                      />

                      <span
                        className="w-11 shrink-0 rounded-xs py-1 text-center text-[11.5px] font-extrabold"
                        style={{
                          backgroundColor: tint(
                            grade ? color.grade[grade] : color.grade.none,
                            '1A',
                          ),
                          color: grade ? color.grade[grade] : color.grade.none,
                        }}
                      >
                        {grade ?? '—'}
                      </span>
                    </li>
                  );
                })}
              </ul>

              <div className="sticky bottom-4 flex flex-wrap items-center gap-3">
                <Button
                  onClick={handleSave}
                  disabled={save.isPending}
                  className="h-12 flex-1 shadow-action sm:flex-none sm:px-8"
                >
                  {save.isPending ? 'Saving…' : 'Save marks'}
                </Button>

                {edits !== null && (
                  <button
                    type="button"
                    onClick={() => setEdits(null)}
                    className="cursor-pointer text-[12.5px] font-bold text-ink-muted hover:text-ink"
                  >
                    Discard changes
                  </button>
                )}

                <p className="text-[12px] text-ink-muted">
                  An empty box means not marked — different from a zero, and left out of the total.
                </p>
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
}
