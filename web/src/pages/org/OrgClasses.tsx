import { BookOpen } from 'lucide-react'
import { useQuery } from '../../lib/useQuery'
import { org } from '../../lib/org'
import { Card, QueryBoundary, formatDate } from '../../components/ui'

/// Every class in the organization, whoever teaches it.
///
/// Classes of a teacher who has since left are still here: removing a teacher
/// detaches the person, not their records, so last term stays readable.
export function OrgClasses() {
  const classes = useQuery(() => org.classes())

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Classes</h1>
          <p className="page-sub">
            {classes.data === null
              ? 'Every class in your organization.'
              : `${classes.data.length} class${classes.data.length === 1 ? '' : 'es'}.`}
          </p>
        </div>
      </div>

      <Card>
        <QueryBoundary
          state={classes}
          what="classes"
          emptyIcon={<BookOpen size={20} />}
          emptyTitle="No classes yet"
          emptyHint="Classes appear here as your teachers create them."
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Class</th>
                    <th>Teacher</th>
                    <th className="num">Students</th>
                    <th className="num">Registers</th>
                    <th className="num">Assessments</th>
                    <th className="num">Attendance</th>
                    <th>Last register</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row) => (
                    <tr key={row.id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>{row.name}</div>
                        <div className="subtle">
                          {[row.section, row.session].filter(Boolean).join(' · ') || '—'}
                        </div>
                      </td>
                      <td className="subtle">{row.teacher_name ?? 'No longer here'}</td>
                      <td className="num">{row.student_count}</td>
                      <td className="num">{row.session_count}</td>
                      <td className="num">{row.assessment_count}</td>
                      <td className="num">
                        {row.attendance_percent === null ? '—' : `${row.attendance_percent}%`}
                      </td>
                      <td className="subtle">{formatDate(row.last_session_date)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </QueryBoundary>
      </Card>
    </>
  )
}
