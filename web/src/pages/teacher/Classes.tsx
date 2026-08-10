import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useQuery } from '../../lib/useQuery'
import { teaching } from '../../lib/teaching'
import { useUser } from '../../lib/session'
import { errorMessage } from '../../lib/supabase'
import { Card, QueryBoundary, Modal, ErrorNotice, formatDate } from '../../components/ui'

/// Every class this teacher runs.
export function Classes() {
  const user = useUser()
  const [creating, setCreating] = useState(false)

  const classes = useQuery(() => teaching.classes(user.id), [user.id])
  const stats = useQuery(() => teaching.classStats())

  const byClass = new Map((stats.data ?? []).map((row) => [row.class_id, row]))

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Classes</h1>
          <p className="page-sub">
            {classes.data === null ? 'Your classes.' : `${classes.data.length} class${classes.data.length === 1 ? '' : 'es'}.`}
          </p>
        </div>
        <button className="btn-primary" onClick={() => setCreating(true)}>
          New class
        </button>
      </div>

      <Card>
        <QueryBoundary
          state={classes}
          what="classes"
          emptyTitle="No classes yet"
          emptyHint="Create your first class to start adding students and taking attendance."
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Class</th>
                    <th>Subject</th>
                    <th className="num">Students</th>
                    <th className="num">Attendance</th>
                    <th className="num">Assessments</th>
                    <th>Last register</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row) => {
                    const stat = byClass.get(row.id)
                    return (
                      <tr key={row.id}>
                        <td className="wrap">
                          <div style={{ fontWeight: 600 }}>{row.name}</div>
                          <div className="subtle">
                            {[row.section, row.session].filter(Boolean).join(' · ') || '—'}
                          </div>
                        </td>
                        <td className="subtle">{row.subject ?? '—'}</td>
                        <td className="num">{stat?.student_count ?? 0}</td>
                        <td className="num">
                          {stat?.attendance_percent === null || stat === undefined
                            ? '—'
                            : `${stat.attendance_percent}%`}
                        </td>
                        <td className="num">{stat?.assessment_count ?? 0}</td>
                        <td className="subtle">{formatDate(stat?.last_session_date ?? null)}</td>
                        <td>
                          <div className="btn-row">
                            <Link to={`/classes/${row.id}`}>
                              <button className="btn-quiet">Open</button>
                            </Link>
                            <Link to={`/classes/${row.id}/attendance`}>
                              <button className="btn-primary">Register</button>
                            </Link>
                          </div>
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

      {creating && (
        <ClassForm
          onClose={() => setCreating(false)}
          onSaved={() => {
            setCreating(false)
            classes.reload()
            stats.reload()
          }}
        />
      )}
    </>
  )
}

/// Only the name is required, which is the whole point of the form: a teacher
/// mid-term should be able to add a class in one field and fill in the rest
/// later, or never.
export function ClassForm({
  initial,
  classId,
  onClose,
  onSaved,
}: {
  initial?: {
    name: string
    subject: string | null
    section: string | null
    session: string | null
    description: string | null
  }
  classId?: string
  onClose: () => void
  onSaved: () => void
}) {
  const [name, setName] = useState(initial?.name ?? '')
  const [subject, setSubject] = useState(initial?.subject ?? '')
  const [section, setSection] = useState(initial?.section ?? '')
  const [session, setSession] = useState(initial?.session ?? '')
  const [description, setDescription] = useState(initial?.description ?? '')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (name.trim() === '') {
      setError('A class needs a name.')
      return
    }

    setBusy(true)
    setError(null)
    try {
      const fields = { name, subject, section, session, description }
      if (classId === undefined) await teaching.createClass(fields)
      else await teaching.updateClass(classId, fields)
      onSaved()
    } catch (caught) {
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      title={classId === undefined ? 'New class' : 'Edit class'}
      description="Only the name is required."
      onClose={onClose}
    >
      <form onSubmit={submit}>
        {error !== null && <ErrorNotice message={error} />}

        <div className="field">
          <label htmlFor="name">Class name</label>
          <input id="name" value={name} onChange={(e) => setName(e.target.value)} autoFocus />
        </div>
        <div className="field">
          <label htmlFor="subject">Subject</label>
          <input id="subject" value={subject} onChange={(e) => setSubject(e.target.value)} />
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div className="field">
            <label htmlFor="section">Section</label>
            <input id="section" value={section} onChange={(e) => setSection(e.target.value)} />
          </div>
          <div className="field">
            <label htmlFor="session">Session</label>
            <input id="session" value={session} onChange={(e) => setSession(e.target.value)} />
          </div>
        </div>
        <div className="field">
          <label htmlFor="description">Description</label>
          <textarea
            id="description"
            rows={2}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </div>

        <div className="modal-actions">
          <button type="button" className="btn-quiet" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-primary" disabled={busy}>
            {busy ? 'Saving…' : classId === undefined ? 'Create class' : 'Save'}
          </button>
        </div>
      </form>
    </Modal>
  )
}
