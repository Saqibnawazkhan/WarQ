import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import {
  CalendarCheck,
  ClipboardList,
  Pencil,
  Plus,
  Trash2,
  TrendingUp,
  Users,
} from 'lucide-react'
import { useQuery } from '../../lib/useQuery'
import { teaching } from '../../lib/teaching'
import type { StudentFields } from '../../lib/teaching'
import { useSession, useUser } from '../../lib/session'
import { errorMessage } from '../../lib/supabase'
import type { Student } from '../../lib/types'
import { ClassForm } from './Classes'
import {
  Card,
  QueryBoundary,
  Modal,
  ErrorNotice,
  Pill,
  formatDate,
  capitalise,
} from '../../components/ui'

type Tab = 'students' | 'attendance' | 'assessments' | 'results'

/// One class, with everything about it on a single page.
export function ClassDetail() {
  const { classId = '' } = useParams()
  const navigate = useNavigate()
  const [tab, setTab] = useState<Tab>('students')
  const [editing, setEditing] = useState(false)
  const [confirmDelete, setConfirmDelete] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const schoolClass = useQuery(() => teaching.classById(classId), [classId])

  async function remove() {
    try {
      await teaching.deleteClass(classId)
      navigate('/classes')
    } catch (caught) {
      setConfirmDelete(false)
      setError(errorMessage(caught))
    }
  }

  const current = schoolClass.data

  return (
    <>
      <div className="page-head">
        <div>
          <h1>{current?.name ?? 'Class'}</h1>
          <p className="page-sub">
            {current === null || current === undefined
              ? ''
              : [current.subject, current.section, current.session]
                  .filter(Boolean)
                  .join(' · ') || 'No subject or section set'}
          </p>
        </div>
        <div className="btn-row">
          <Link to={`/classes/${classId}/attendance`}>
            <button className="btn-primary">
              <CalendarCheck size={18} />
              Take register
            </button>
          </Link>
          <button className="btn-quiet" onClick={() => setEditing(true)}>
            <Pencil size={18} />
            Edit
          </button>
          <button className="btn-danger" onClick={() => setConfirmDelete(true)}>
            <Trash2 size={18} />
            Delete
          </button>
        </div>
      </div>

      {error !== null && <ErrorNotice message={error} />}

      <div className="tabs">
        <TabButton current={tab} value="students" onSelect={setTab}>
          Students
        </TabButton>
        <TabButton current={tab} value="attendance" onSelect={setTab}>
          Attendance
        </TabButton>
        <TabButton current={tab} value="assessments" onSelect={setTab}>
          Assessments
        </TabButton>
        <TabButton current={tab} value="results" onSelect={setTab}>
          Results
        </TabButton>
      </div>

      {tab === 'students' && <StudentsTab classId={classId} />}
      {tab === 'attendance' && <AttendanceTab classId={classId} />}
      {tab === 'assessments' && <AssessmentsTab classId={classId} />}
      {tab === 'results' && <ResultsTab classId={classId} />}

      {editing && current !== null && current !== undefined && (
        <ClassForm
          classId={classId}
          initial={{
            name: current.name,
            subject: current.subject,
            section: current.section,
            session: current.session,
            description: current.description,
          }}
          onClose={() => setEditing(false)}
          onSaved={() => {
            setEditing(false)
            schoolClass.reload()
          }}
        />
      )}

      {confirmDelete && (
        <Modal
          title={`Delete ${current?.name ?? 'this class'}?`}
          description="Its registers, assessments and marks go with it. The students themselves are kept — they belong to you, not to the class."
          onClose={() => setConfirmDelete(false)}
        >
          <div className="modal-actions">
            <button className="btn-quiet" onClick={() => setConfirmDelete(false)}>
              Cancel
            </button>
            <button className="btn-danger" onClick={() => void remove()}>
              Delete class
            </button>
          </div>
        </Modal>
      )}
    </>
  )
}

function TabButton({
  current,
  value,
  onSelect,
  children,
}: {
  current: Tab
  value: Tab
  onSelect: (tab: Tab) => void
  children: React.ReactNode
}) {
  return (
    <button
      className={current === value ? 'tab active' : 'tab'}
      onClick={() => onSelect(value)}
    >
      {children}
    </button>
  )
}

// ── Students ────────────────────────────────────────────────

function StudentsTab({ classId }: { classId: string }) {
  const [adding, setAdding] = useState(false)
  const [editing, setEditing] = useState<Student | null>(null)
  const [error, setError] = useState<string | null>(null)

  const roster = useQuery(() => teaching.roster(classId), [classId])

  async function unenrol(student: Student) {
    try {
      await teaching.unenrol(classId, student.id)
      roster.reload()
    } catch (caught) {
      setError(errorMessage(caught))
    }
  }

  return (
    <>
      <div className="toolbar">
        <button className="btn-primary" onClick={() => setAdding(true)}>
          <Plus size={18} />
          Add student
        </button>
        <span className="subtle">
          {roster.data === null ? '' : `${roster.data.length} enrolled, listed A to Z`}
        </span>
      </div>

      {error !== null && <ErrorNotice message={error} />}

      <Card>
        <QueryBoundary
          state={roster}
          what="students"
          emptyTitle="Nobody in this class yet"
          emptyHint="Add a student — only their name is required."
          emptyIcon={Users}
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Student</th>
                    <th>Roll no</th>
                    <th>Guardian</th>
                    <th>Contact numbers</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((student) => (
                    <tr key={student.id}>
                      <td className="wrap" style={{ fontWeight: 600 }}>
                        {student.full_name}
                      </td>
                      <td className="subtle">{student.roll_no ?? '—'}</td>
                      <td className="subtle">{student.guardian_name ?? '—'}</td>
                      <td className="subtle">
                        {(student.student_contacts ?? []).length === 0 ? (
                          <Pill tone="grey">Nobody to call</Pill>
                        ) : (
                          (student.student_contacts ?? [])
                            .map((c) => `${capitalise(c.label)} ${c.phone}`)
                            .join(' · ')
                        )}
                      </td>
                      <td>
                        <div className="btn-row">
                          <button className="btn-quiet" onClick={() => setEditing(student)}>
                            <Pencil size={16} />
                            Edit
                          </button>
                          <button className="btn-danger" onClick={() => void unenrol(student)}>
                            <Trash2 size={16} />
                            Remove
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </QueryBoundary>
      </Card>

      {(adding || editing !== null) && (
        <StudentForm
          classId={classId}
          student={editing}
          onClose={() => {
            setAdding(false)
            setEditing(null)
          }}
          onSaved={() => {
            setAdding(false)
            setEditing(null)
            roster.reload()
          }}
        />
      )}
    </>
  )
}

/// Only the name is mandatory. Roll numbers are optional and not unique, and
/// every phone number is optional — a student with nobody to call simply
/// generates no absence alert.
function StudentForm({
  classId,
  student,
  onClose,
  onSaved,
}: {
  classId: string
  student: Student | null
  onClose: () => void
  onSaved: () => void
}) {
  const user = useUser()
  const { organization } = useSession()

  const contacts = student?.student_contacts ?? []
  const phoneFor = (label: string) => contacts.find((c) => c.label === label)?.phone ?? ''

  const [fields, setFields] = useState<StudentFields>({
    full_name: student?.full_name ?? '',
    roll_no: student?.roll_no ?? '',
    guardian_name: student?.guardian_name ?? '',
    email: student?.email ?? '',
    address: student?.address ?? '',
    notes: student?.notes ?? '',
    father_phone: phoneFor('father'),
    mother_phone: phoneFor('mother'),
    student_phone: phoneFor('student'),
  })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function set(key: keyof StudentFields, value: string) {
    setFields((current) => ({ ...current, [key]: value }))
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (fields.full_name.trim() === '') {
      setError('A student needs a name.')
      return
    }

    setBusy(true)
    setError(null)
    try {
      if (student === null) {
        await teaching.createStudent(user.id, organization?.id ?? null, fields, classId)
      } else {
        await teaching.updateStudent(student.id, fields)
      }
      onSaved()
    } catch (caught) {
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      title={student === null ? 'Add student' : 'Edit student'}
      description="Only the name is required."
      onClose={onClose}
    >
      <form onSubmit={submit}>
        {error !== null && <ErrorNotice message={error} />}

        <div className="field">
          <label htmlFor="full_name">Full name</label>
          <input
            id="full_name"
            value={fields.full_name}
            onChange={(e) => set('full_name', e.target.value)}
            autoFocus
          />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div className="field">
            <label htmlFor="roll_no">Roll number</label>
            <input
              id="roll_no"
              value={fields.roll_no}
              onChange={(e) => set('roll_no', e.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor="guardian_name">Guardian name</label>
            <input
              id="guardian_name"
              value={fields.guardian_name}
              onChange={(e) => set('guardian_name', e.target.value)}
            />
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
          <div className="field">
            <label htmlFor="father_phone">Father’s phone</label>
            <input
              id="father_phone"
              value={fields.father_phone}
              onChange={(e) => set('father_phone', e.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor="mother_phone">Mother’s phone</label>
            <input
              id="mother_phone"
              value={fields.mother_phone}
              onChange={(e) => set('mother_phone', e.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor="student_phone">Student’s phone</label>
            <input
              id="student_phone"
              value={fields.student_phone}
              onChange={(e) => set('student_phone', e.target.value)}
            />
          </div>
        </div>

        <div className="modal-actions">
          <button type="button" className="btn-quiet" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-primary" disabled={busy}>
            {busy ? 'Saving…' : student === null ? 'Add student' : 'Save'}
          </button>
        </div>
      </form>
    </Modal>
  )
}

// ── Attendance history ──────────────────────────────────────

function AttendanceTab({ classId }: { classId: string }) {
  const sessions = useQuery(() => teaching.sessions(classId), [classId])

  return (
    <Card>
      <QueryBoundary
        state={sessions}
        what="registers"
        emptyTitle="No registers yet"
        emptyHint="Take one and it will appear here."
        emptyIcon={CalendarCheck}
        isEmpty={(rows) => rows.length === 0}
      >
        {(rows) => (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Note</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {rows.map((session) => (
                  <tr key={session.id}>
                    <td style={{ fontWeight: 600 }}>{formatDate(session.date)}</td>
                    <td className="wrap subtle">{session.note ?? '—'}</td>
                    <td>
                      <Link to={`/classes/${classId}/attendance?date=${session.date}`}>
                        <button className="btn-quiet">Open</button>
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </QueryBoundary>
    </Card>
  )
}

// ── Assessments ─────────────────────────────────────────────

function AssessmentsTab({ classId }: { classId: string }) {
  const [creating, setCreating] = useState(false)
  const assessments = useQuery(() => teaching.assessments(classId), [classId])

  return (
    <>
      <div className="toolbar">
        <button className="btn-primary" onClick={() => setCreating(true)}>
          <Plus size={18} />
          New assessment
        </button>
      </div>

      <Card>
        <QueryBoundary
          state={assessments}
          what="assessments"
          emptyTitle="No assessments yet"
          emptyHint="Create a quiz, assignment or exam to start recording marks."
          emptyIcon={ClipboardList}
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Assessment</th>
                    <th>Type</th>
                    <th>Date</th>
                    <th className="num">Out of</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((assessment) => (
                    <tr key={assessment.id}>
                      <td className="wrap" style={{ fontWeight: 600 }}>
                        {assessment.name}
                      </td>
                      <td>
                        {assessment.type === 'custom'
                          ? (assessment.custom_type_label ?? 'Custom')
                          : capitalise(assessment.type)}
                      </td>
                      <td className="subtle">{formatDate(assessment.date)}</td>
                      <td className="num">{assessment.total_marks}</td>
                      <td>
                        <Link to={`/classes/${classId}/assessments/${assessment.id}`}>
                          <button className="btn-primary">Enter marks</button>
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </QueryBoundary>
      </Card>

      {creating && (
        <AssessmentForm
          classId={classId}
          onClose={() => setCreating(false)}
          onSaved={() => {
            setCreating(false)
            assessments.reload()
          }}
        />
      )}
    </>
  )
}

const TYPES = [
  'quiz',
  'assignment',
  'midterm',
  'final',
  'presentation',
  'project',
  'lab',
  'custom',
] as const

function AssessmentForm({
  classId,
  onClose,
  onSaved,
}: {
  classId: string
  onClose: () => void
  onSaved: () => void
}) {
  const [name, setName] = useState('')
  const [type, setType] = useState<(typeof TYPES)[number]>('quiz')
  const [customLabel, setCustomLabel] = useState('')
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [total, setTotal] = useState('100')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    const totalMarks = Number(total)
    if (name.trim() === '') return setError('An assessment needs a name.')
    if (!Number.isFinite(totalMarks) || totalMarks <= 0) {
      return setError('Total marks must be a number greater than zero.')
    }

    setBusy(true)
    setError(null)
    try {
      await teaching.createAssessment({
        class_id: classId,
        name,
        type,
        date,
        total_marks: totalMarks,
        custom_type_label: type === 'custom' ? customLabel : undefined,
      })
      onSaved()
    } catch (caught) {
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal title="New assessment" onClose={onClose}>
      <form onSubmit={submit}>
        {error !== null && <ErrorNotice message={error} />}

        <div className="field">
          <label htmlFor="a-name">Name</label>
          <input id="a-name" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div className="field">
            <label htmlFor="a-type">Type</label>
            <select
              id="a-type"
              value={type}
              onChange={(e) => setType(e.target.value as (typeof TYPES)[number])}
              style={{ width: '100%' }}
            >
              {TYPES.map((value) => (
                <option key={value} value={value}>
                  {value === 'final' ? 'Final exam' : capitalise(value)}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor="a-total">Total marks</label>
            <input id="a-total" value={total} onChange={(e) => setTotal(e.target.value)} />
          </div>
        </div>

        {type === 'custom' && (
          <div className="field">
            <label htmlFor="a-label">What to call this type</label>
            <input
              id="a-label"
              value={customLabel}
              onChange={(e) => setCustomLabel(e.target.value)}
              placeholder="e.g. Viva"
            />
          </div>
        )}

        <div className="field">
          <label htmlFor="a-date">Date</label>
          <input id="a-date" type="date" value={date} onChange={(e) => setDate(e.target.value)} />
        </div>

        <div className="modal-actions">
          <button type="button" className="btn-quiet" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-primary" disabled={busy}>
            {busy ? 'Creating…' : 'Create'}
          </button>
        </div>
      </form>
    </Modal>
  )
}

// ── Results ─────────────────────────────────────────────────

function ResultsTab({ classId }: { classId: string }) {
  const performance = useQuery(() => teaching.performance(classId), [classId])

  return (
    <Card>
      <QueryBoundary
        state={performance}
        what="results"
        emptyTitle="Nothing to report yet"
        emptyHint="Results appear once there are students with attendance or marks."
        emptyIcon={TrendingUp}
        isEmpty={(rows) => rows.length === 0}
      >
        {(rows) => (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Student</th>
                  <th className="num">Attendance</th>
                  <th className="num">Present</th>
                  <th className="num">Absent</th>
                  <th className="num">Late</th>
                  <th className="num">Short leave</th>
                  <th className="num">Marks</th>
                  <th>Grade</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((row) => (
                  <tr key={row.student_id}>
                    <td className="wrap" style={{ fontWeight: 600 }}>
                      {row.full_name}
                    </td>
                    <td className="num">
                      {row.attendance_percent === null ? '—' : `${row.attendance_percent}%`}
                    </td>
                    <td className="num">{row.present}</td>
                    <td className="num">{row.absent}</td>
                    <td className="num">{row.late}</td>
                    <td className="num">{row.short_leave}</td>
                    <td className="num">
                      {/* total 0 means nothing has been marked, which is not
                          the same as scoring nothing. */}
                      {row.total === 0 ? '—' : `${row.obtained} / ${row.total}`}
                    </td>
                    <td>
                      {row.grade === null ? (
                        <span className="subtle">—</span>
                      ) : (
                        <Pill tone={gradeTone(row.grade)}>{row.grade}</Pill>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </QueryBoundary>
    </Card>
  )
}

function gradeTone(grade: string): string {
  if (grade.startsWith('A')) return 'green'
  if (grade.startsWith('B') || grade.startsWith('C')) return 'blue'
  if (grade.startsWith('D')) return 'amber'
  return 'red'
}
