import { useState } from 'react'
import { UserMinus, Users } from 'lucide-react'
import { useQuery } from '../../lib/useQuery'
import { org } from '../../lib/org'
import { useUser } from '../../lib/session'
import { errorMessage } from '../../lib/supabase'
import type { OrgTeacher } from '../../lib/types'
import {
  Card,
  QueryBoundary,
  Modal,
  ErrorNotice,
  Pill,
  AccountPill,
  formatDate,
} from '../../components/ui'

/// The staff list, and what each of them is actually doing.
///
/// "Idle" is not a stored state: it is nobody having taken a register in a
/// week, which is exactly the thing an administrator opens this page to notice.
export function OrgTeachers() {
  const me = useUser()
  const [removing, setRemoving] = useState<OrgTeacher | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const teachers = useQuery(() => org.teachers())

  async function remove(teacher: OrgTeacher) {
    setBusy(true)
    setError(null)
    try {
      await org.removeTeacher(teacher.id)
      setRemoving(null)
      teachers.reload()
    } catch (caught) {
      setRemoving(null)
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Teachers</h1>
          <p className="page-sub">
            {teachers.data === null
              ? 'Everyone teaching at your organization.'
              : `${teachers.data.length} on staff.`}
          </p>
        </div>
      </div>

      {error !== null && <ErrorNotice message={error} />}

      <Card>
        <QueryBoundary
          state={teachers}
          what="teachers"
          emptyIcon={<Users size={20} />}
          emptyTitle="No teachers yet"
          emptyHint="Invite one, and they join automatically when they register with that email address."
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Teacher</th>
                    <th>Account</th>
                    <th>Activity</th>
                    <th className="num">Classes</th>
                    <th className="num">Students</th>
                    <th className="num">Registers</th>
                    <th>Last register</th>
                    <th>Joined</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((teacher) => (
                    <tr key={teacher.id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>
                          {teacher.full_name}
                          {teacher.id === me.id && (
                            <span className="subtle" style={{ fontWeight: 400 }}> · you</span>
                          )}
                        </div>
                        <div className="subtle">{teacher.email}</div>
                      </td>
                      <td>
                        <AccountPill status={teacher.account_status} />
                      </td>
                      <td>
                        {teacher.activity_state === 'active' ? (
                          <Pill tone="green">Active</Pill>
                        ) : (
                          <Pill tone="amber">Idle</Pill>
                        )}
                      </td>
                      <td className="num">{teacher.class_count}</td>
                      <td className="num">{teacher.student_count}</td>
                      <td className="num">{teacher.session_count}</td>
                      <td className="subtle">{formatDate(teacher.last_attendance_date)}</td>
                      <td className="subtle">{formatDate(teacher.joined_at)}</td>
                      <td>
                        {teacher.id === me.id ? (
                          <span className="subtle">—</span>
                        ) : (
                          <button className="btn-danger" onClick={() => setRemoving(teacher)}>
                            <UserMinus size={16} />
                            Remove
                          </button>
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

      {removing !== null && (
        <Modal
          title={`Remove ${removing.full_name}?`}
          description="Their classes, registers and marks stay with your organization and you keep seeing them. They lose access to WarQ, because with no organization they have no subscription."
          onClose={() => setRemoving(null)}
        >
          <div className="modal-actions">
            <button className="btn-quiet" onClick={() => setRemoving(null)}>
              Cancel
            </button>
            <button className="btn-danger" disabled={busy} onClick={() => void remove(removing)}>
              {busy ? 'Removing…' : 'Remove teacher'}
            </button>
          </div>
        </Modal>
      )}
    </>
  )
}
