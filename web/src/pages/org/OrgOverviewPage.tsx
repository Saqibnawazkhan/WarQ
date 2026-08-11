import { Link } from 'react-router-dom'
import {
  BookOpen,
  CalendarCheck,
  CheckCircle2,
  GraduationCap,
  Mail,
  Users,
} from 'lucide-react'
import { useQuery } from '../../lib/useQuery'
import { org } from '../../lib/org'
import { useSession } from '../../lib/session'
import { Card, Stat, QueryBoundary, Pill, formatDate } from '../../components/ui'

/// What an organization administrator opens the page to find out: is teaching
/// actually happening today, and is anybody drifting.
export function OrgOverviewPage() {
  const { organization } = useSession()
  const organizationId = organization?.id ?? ''

  const overview = useQuery(() => org.overview(organizationId), [organizationId])
  const teachers = useQuery(() => org.teachers())

  const idle = (teachers.data ?? []).filter((t) => t.activity_state === 'idle')
  const stats = overview.data

  return (
    <>
      <div className="page-head">
        <div>
          <h1>{organization?.name ?? 'Overview'}</h1>
          <p className="page-sub">
            {organization?.city ?? 'Your organization at a glance.'}
          </p>
        </div>
        <Link to="/invitations">
          <button className="btn-primary">
            <Mail size={18} />
            Invite a teacher
          </button>
        </Link>
      </div>

      <div className="stat-grid">
        <Stat icon={<Users size={20} />} label="Teachers" value={stats?.teacher_count ?? '—'} />
        <Stat
          icon={<GraduationCap size={20} />}
          label="Students"
          value={stats?.student_count ?? '—'}
        />
        <Stat icon={<BookOpen size={20} />} label="Classes" value={stats?.class_count ?? '—'} />
        <Stat
          icon={<CalendarCheck size={20} />}
          label="Marked today"
          value={stats?.classes_marked_today ?? '—'}
          note={
            stats === null || stats === undefined
              ? undefined
              : `of ${stats.class_count} classes`
          }
        />
      </div>

      <Card title="Nobody has taken a register this week">
        <QueryBoundary
          state={{ ...teachers, data: teachers.data === null ? null : idle }}
          what="teachers"
          emptyIcon={
            (teachers.data ?? []).length === 0 ? (
              <Users size={20} />
            ) : (
              <CheckCircle2 size={20} />
            )
          }
          emptyTitle={
            (teachers.data ?? []).length === 0
              ? 'No teachers yet'
              : 'Everyone is up to date'
          }
          emptyHint={
            (teachers.data ?? []).length === 0
              ? 'Invite a teacher and they will appear here once they register.'
              : 'Every teacher has taken a register in the last week.'
          }
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Teacher</th>
                    <th className="num">Classes</th>
                    <th className="num">Students</th>
                    <th>Last register</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((teacher) => (
                    <tr key={teacher.id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>{teacher.full_name}</div>
                        <div className="subtle">{teacher.email}</div>
                      </td>
                      <td className="num">{teacher.class_count}</td>
                      <td className="num">{teacher.student_count}</td>
                      <td className="subtle">
                        {teacher.last_attendance_date === null ? (
                          <Pill tone="grey">Never</Pill>
                        ) : (
                          formatDate(teacher.last_attendance_date)
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
    </>
  )
}
