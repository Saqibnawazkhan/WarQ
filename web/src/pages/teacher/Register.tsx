import { useEffect, useMemo, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useQuery } from '../../lib/useQuery'
import { teaching } from '../../lib/teaching'
import { errorMessage } from '../../lib/supabase'
import type { AttendanceMark } from '../../lib/types'
import { Card, QueryBoundary, ErrorNotice, Loading } from '../../components/ui'

const MARKS: { value: AttendanceMark; label: string; tone: string }[] = [
  { value: 'present', label: 'Present', tone: 'green' },
  { value: 'absent', label: 'Absent', tone: 'red' },
  { value: 'late', label: 'Late', tone: 'amber' },
  { value: 'short_leave', label: 'Short leave', tone: 'blue' },
]

/// Taking or correcting a register for one class on one day.
///
/// The whole sheet is saved in one call. Half a class marked because a request
/// failed part-way through is worse than nothing saved at all, and the database
/// function is idempotent on (class, date) so saving again corrects rather than
/// duplicates.
export function Register() {
  const { classId = '' } = useParams()
  const [date, setDate] = useState(today())
  const [marks, setMarks] = useState<Record<string, AttendanceMark>>({})
  const [saved, setSaved] = useState<Record<string, AttendanceMark>>({})
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [result, setResult] = useState<string | null>(null)

  const schoolClass = useQuery(() => teaching.classById(classId), [classId])
  const roster = useQuery(() => teaching.roster(classId), [classId])
  const existing = useQuery(async () => {
    const session = await teaching.sessionOn(classId, date)
    if (session === null) return { session: null, records: [] }
    return { session, records: await teaching.records(session.id) }
  }, [classId, date])

  // Everyone starts present. That is the common case by a wide margin, and it
  // means a teacher marks the exceptions rather than the whole class.
  useEffect(() => {
    if (roster.data === null || existing.data === null) return

    const fromDatabase: Record<string, AttendanceMark> = {}
    for (const record of existing.data.records) {
      fromDatabase[record.student_id] = record.mark
    }

    const next: Record<string, AttendanceMark> = {}
    for (const student of roster.data) {
      next[student.id] = fromDatabase[student.id] ?? 'present'
    }
    setMarks(next)
    setSaved(existing.data.session === null ? {} : next)
    setResult(null)
  }, [roster.data, existing.data])

  const dirty = useMemo(() => {
    const keys = new Set([...Object.keys(marks), ...Object.keys(saved)])
    for (const key of keys) if (marks[key] !== saved[key]) return true
    return false
  }, [marks, saved])

  const counts = useMemo(() => {
    const tally: Record<AttendanceMark, number> = {
      present: 0,
      absent: 0,
      late: 0,
      short_leave: 0,
    }
    for (const mark of Object.values(marks)) tally[mark] += 1
    return tally
  }, [marks])

  const isFuture = date > today()

  async function save() {
    setBusy(true)
    setError(null)
    setResult(null)
    try {
      const outcome = await teaching.saveAttendance(classId, date, marks)
      setSaved({ ...marks })
      setResult(
        outcome.absent === 0
          ? 'Register saved — everyone present.'
          : `Register saved. ${outcome.absent} absent, ${outcome.alertable} with a contactable guardian.`,
      )
      existing.reload()
    } catch (caught) {
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  function setAll(mark: AttendanceMark) {
    if (roster.data === null) return
    const next: Record<string, AttendanceMark> = {}
    for (const student of roster.data) next[student.id] = mark
    setMarks(next)
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>{schoolClass.data?.name ?? 'Register'}</h1>
          <p className="page-sub">
            {existing.data?.session === null || existing.data === null
              ? 'Not taken for this date yet.'
              : 'Already taken — saving again corrects it.'}
          </p>
        </div>
        <Link to={`/classes/${classId}`}>
          <button className="btn-quiet">Back to class</button>
        </Link>
      </div>

      <div className="toolbar">
        <input
          type="date"
          value={date}
          max={today()}
          onChange={(event) => setDate(event.target.value)}
          style={{ width: 'auto' }}
        />
        <button className="btn-quiet" onClick={() => setAll('present')}>
          Mark all present
        </button>
        <button className="btn-quiet" onClick={() => setAll('absent')}>
          Mark all absent
        </button>
        <span className="subtle" style={{ marginLeft: 'auto' }}>
          {counts.present} present · {counts.absent} absent · {counts.late} late ·{' '}
          {counts.short_leave} short leave
        </span>
      </div>

      {error !== null && <ErrorNotice message={error} />}
      {result !== null && <div className="notice notice-ok">{result}</div>}
      {isFuture && (
        <ErrorNotice message="A register cannot be taken for a future date." />
      )}

      <Card>
        <QueryBoundary
          state={roster}
          what="students"
          emptyTitle="Nobody in this class yet"
          emptyHint="Add students to the class before taking a register."
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) =>
            existing.loading && existing.data === null ? (
              <Loading what="the register" />
            ) : (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th style={{ width: 44 }}>#</th>
                      <th>Student</th>
                      <th>Roll no</th>
                      <th>Mark</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((student, index) => (
                      <tr key={student.id}>
                        <td className="subtle num">{index + 1}</td>
                        <td className="wrap" style={{ fontWeight: 600 }}>
                          {student.full_name}
                        </td>
                        <td className="subtle">{student.roll_no ?? '—'}</td>
                        <td>
                          <div className="btn-row">
                            {MARKS.map((option) => {
                              const active = marks[student.id] === option.value
                              return (
                                <button
                                  key={option.value}
                                  className={active ? `mark-on mark-${option.tone}` : 'mark-off'}
                                  onClick={() =>
                                    setMarks({ ...marks, [student.id]: option.value })
                                  }
                                >
                                  {option.label}
                                </button>
                              )
                            })}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )
          }
        </QueryBoundary>
      </Card>

      {(roster.data ?? []).length > 0 && (
        <div className="save-bar">
          <span className="subtle">
            {dirty ? 'Unsaved changes' : result === null ? 'Nothing changed yet' : 'Saved'}
          </span>
          <button
            className="btn-primary"
            disabled={busy || isFuture || !dirty}
            onClick={() => void save()}
          >
            {busy ? 'Saving…' : 'Save register'}
          </button>
        </div>
      )}
    </>
  )
}

/// The device's own day, not UTC: attendance on 11 August is on that date in
/// Lahore whatever the server thinks.
function today(): string {
  const now = new Date()
  const month = `${now.getMonth() + 1}`.padStart(2, '0')
  const day = `${now.getDate()}`.padStart(2, '0')
  return `${now.getFullYear()}-${month}-${day}`
}
