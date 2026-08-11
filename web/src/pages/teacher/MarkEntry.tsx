import { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { CircleCheck, Save, Users } from 'lucide-react'
import { useQuery } from '../../lib/useQuery'
import { teaching } from '../../lib/teaching'
import { errorMessage } from '../../lib/supabase'
import { Card, QueryBoundary, ErrorNotice, Pill } from '../../components/ui'

interface Entry {
  score: string
  absent: boolean
  remarks: string
}

/// Entering marks for one assessment.
///
/// Three states a box can be in, and they are not the same thing: a score, a
/// recorded absence, and nothing yet. An empty box leaves the assessment out of
/// the student's total rather than scoring it zero, so nobody is failed for
/// work their teacher has not marked.
export function MarkEntry() {
  const { classId = '', assessmentId = '' } = useParams()
  const [entries, setEntries] = useState<Record<string, Entry>>({})
  const [saved, setSaved] = useState<Record<string, Entry>>({})
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [result, setResult] = useState<string | null>(null)

  const assessment = useQuery(() => teaching.assessmentById(assessmentId), [assessmentId])
  const roster = useQuery(() => teaching.roster(classId), [classId])
  const marks = useQuery(() => teaching.marks(assessmentId), [assessmentId])

  useEffect(() => {
    if (roster.data === null || marks.data === null) return

    const stored = new Map(marks.data.map((mark) => [mark.student_id, mark]))
    const next: Record<string, Entry> = {}
    for (const student of roster.data) {
      const mark = stored.get(student.id)
      next[student.id] = {
        score: mark?.score === null || mark === undefined ? '' : String(mark.score),
        absent: mark?.absent ?? false,
        remarks: mark?.remarks ?? '',
      }
    }
    setEntries(next)
    setSaved(structuredClone(next))
    setResult(null)
  }, [roster.data, marks.data])

  const total = assessment.data?.total_marks ?? 0

  const dirty = useMemo(
    () => JSON.stringify(entries) !== JSON.stringify(saved),
    [entries, saved],
  )

  const invalid = useMemo(() => {
    for (const entry of Object.values(entries)) {
      if (entry.absent || entry.score.trim() === '') continue
      const value = Number(entry.score)
      if (!Number.isFinite(value) || value < 0 || value > total) return true
    }
    return false
  }, [entries, total])

  function set(studentId: string, patch: Partial<Entry>) {
    setEntries((current) => ({
      ...current,
      [studentId]: { ...(current[studentId] ?? blank()), ...patch },
    }))
  }

  async function save() {
    setBusy(true)
    setError(null)
    setResult(null)
    try {
      const outcome = await teaching.saveMarks(
        assessmentId,
        Object.entries(entries).map(([student_id, entry]) => ({
          student_id,
          // An absent student carries no score by construction, so the two are
          // never sent together.
          score: entry.absent || entry.score.trim() === '' ? null : Number(entry.score),
          absent: entry.absent,
          remarks: entry.remarks.trim() === '' ? null : entry.remarks.trim(),
        })),
      )
      setSaved(structuredClone(entries))
      setResult(`Saved. ${outcome.marked} of ${Object.keys(entries).length} marked.`)
      marks.reload()
    } catch (caught) {
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>{assessment.data?.name ?? 'Marks'}</h1>
          <p className="page-sub">
            Out of {total}. Leave a box empty for work not marked yet.
          </p>
        </div>
        <Link to={`/classes/${classId}`}>
          <button className="btn-quiet">Back to class</button>
        </Link>
      </div>

      {error !== null && <ErrorNotice message={error} />}
      {result !== null && (
        <div className="notice notice-ok">
          <CircleCheck size={18} />
          <span>{result}</span>
        </div>
      )}
      {invalid && (
        <ErrorNotice message={`A score must be between 0 and ${total}.`} />
      )}

      <Card>
        <QueryBoundary
          state={roster}
          what="students"
          emptyTitle="Nobody in this class yet"
          emptyHint="Add students before recording marks."
          emptyIcon={Users}
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th style={{ width: 44 }}>#</th>
                    <th>Student</th>
                    <th style={{ width: 130 }}>Score</th>
                    <th style={{ width: 110 }}>Absent</th>
                    <th>Remarks</th>
                    <th style={{ width: 90 }}>Grade</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((student, index) => {
                    const entry = entries[student.id] ?? blank()
                    const percent =
                      entry.absent || entry.score.trim() === '' || total === 0
                        ? null
                        : (Number(entry.score) / total) * 100

                    return (
                      <tr key={student.id}>
                        <td className="subtle num">{index + 1}</td>
                        <td className="wrap" style={{ fontWeight: 600 }}>
                          {student.full_name}
                        </td>
                        <td>
                          <input
                            value={entry.score}
                            disabled={entry.absent}
                            inputMode="decimal"
                            placeholder="—"
                            onChange={(e) => set(student.id, { score: e.target.value })}
                          />
                        </td>
                        <td>
                          <label style={{ display: 'flex', gap: 6, alignItems: 'center', margin: 0 }}>
                            <input
                              type="checkbox"
                              style={{ width: 'auto' }}
                              checked={entry.absent}
                              onChange={(e) =>
                                set(student.id, {
                                  absent: e.target.checked,
                                  ...(e.target.checked ? { score: '' } : {}),
                                })
                              }
                            />
                            <span className="subtle">Missed it</span>
                          </label>
                        </td>
                        <td>
                          <input
                            value={entry.remarks}
                            placeholder="Optional"
                            onChange={(e) => set(student.id, { remarks: e.target.value })}
                          />
                        </td>
                        <td>
                          {percent === null ? (
                            <span className="subtle">—</span>
                          ) : (
                            <Pill tone={toneFor(percent)}>{gradeFor(percent)}</Pill>
                          )}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          )}
        </QueryBoundary>
      </Card>

      {(roster.data ?? []).length > 0 && (
        <div className="save-bar">
          <span className="subtle">{dirty ? 'Unsaved changes' : 'Nothing changed yet'}</span>
          <button
            className="btn-primary"
            disabled={busy || invalid || !dirty}
            onClick={() => void save()}
          >
            <Save size={18} />
            {busy ? 'Saving…' : 'Save marks'}
          </button>
        </div>
      )}
    </>
  )
}

function blank(): Entry {
  return { score: '', absent: false, remarks: '' }
}

/// Mirrors fn_grade_for in the database. Shown live as a teacher types, so they
/// see the grade before saving; the database remains the authority once saved.
function gradeFor(percent: number): string {
  if (percent >= 90) return 'A+'
  if (percent >= 80) return 'A'
  if (percent >= 70) return 'B'
  if (percent >= 60) return 'C'
  if (percent >= 50) return 'D'
  return 'F'
}

function toneFor(percent: number): string {
  if (percent >= 80) return 'green'
  if (percent >= 60) return 'blue'
  if (percent >= 50) return 'amber'
  return 'red'
}
