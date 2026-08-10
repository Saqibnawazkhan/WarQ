import { Link } from 'react-router-dom'
import { useQuery } from '../../lib/useQuery'
import { teaching } from '../../lib/teaching'
import { useUser } from '../../lib/session'
import { Card, Stat, QueryBoundary, Pill } from '../../components/ui'

/// The question a teacher opens the app to answer: which of my classes still
/// needs a register today, and how did the ones already taken go.
export function Today() {
  const user = useUser()

  const today = useQuery(() => teaching.today())
  const stats = useQuery(() => teaching.classStats())

  const rows = today.data ?? []
  const taken = rows.filter((row) => row.taken)
  const outstanding = rows.filter((row) => !row.taken)

  const studentTotal = (stats.data ?? []).reduce((sum, row) => sum + row.student_count, 0)
  const presentToday = taken.reduce((sum, row) => sum + row.present + row.late, 0)
  const absentToday = taken.reduce((sum, row) => sum + row.absent, 0)

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Good day, {user.full_name.split(' ')[0]}</h1>
          <p className="page-sub">
            {rows.length === 0
              ? 'Create a class to start taking attendance.'
              : `${taken.length} of ${rows.length} classes marked today.`}
          </p>
        </div>
        <Link to="/classes">
          <button className="btn-primary">Go to classes</button>
        </Link>
      </div>

      <div className="stat-grid">
        <Stat label="Classes" value={rows.length} />
        <Stat label="Students" value={studentTotal} />
        <Stat label="Present today" value={presentToday} note="Includes late arrivals" />
        <Stat label="Absent today" value={absentToday} />
      </div>

      <Card title="Still to mark today">
        <QueryBoundary
          state={{ ...today, data: today.data === null ? null : outstanding }}
          what="classes"
          emptyTitle={rows.length === 0 ? 'No classes yet' : 'Every class is marked'}
          emptyHint={
            rows.length === 0
              ? 'Create your first class and add students to it.'
              : 'Nothing left to do today.'
          }
          isEmpty={(list) => list.length === 0}
        >
          {(list) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Class</th>
                    <th className="num">Students</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {list.map((row) => (
                    <tr key={row.class_id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>{row.name}</div>
                        {row.section !== null && <div className="subtle">{row.section}</div>}
                      </td>
                      <td className="num">{row.student_count}</td>
                      <td>
                        <Link to={`/classes/${row.class_id}/attendance`}>
                          <button
                            className="btn-primary"
                            disabled={row.student_count === 0}
                            title={
                              row.student_count === 0
                                ? 'Add a student to this class first'
                                : undefined
                            }
                          >
                            Take register
                          </button>
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

      {taken.length > 0 && (
        <div style={{ marginTop: 20 }}>
          <Card title="Marked today">
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Class</th>
                    <th className="num">Present</th>
                    <th className="num">Absent</th>
                    <th className="num">Late</th>
                    <th className="num">Short leave</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {taken.map((row) => (
                    <tr key={row.class_id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>{row.name}</div>
                        {row.section !== null && <div className="subtle">{row.section}</div>}
                      </td>
                      <td className="num">{row.present}</td>
                      <td className="num">
                        {row.absent > 0 ? <Pill tone="red">{row.absent}</Pill> : 0}
                      </td>
                      <td className="num">{row.late}</td>
                      <td className="num">{row.short_leave}</td>
                      <td>
                        <Link to={`/classes/${row.class_id}/attendance`}>
                          <button className="btn-quiet">Edit</button>
                        </Link>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        </div>
      )}
    </>
  )
}
