import { useMemo, useState } from 'react'
import { GraduationCap, Search, SearchX } from 'lucide-react'
import { useQuery } from '../../lib/useQuery'
import { teaching } from '../../lib/teaching'
import { useUser } from '../../lib/session'
import { Card, QueryBoundary, Pill, capitalise } from '../../components/ui'

/// Every student this teacher has, across all their classes.
///
/// Students belong to the teacher rather than to a class, which is what lets
/// the same person sit in several classes without being entered twice. This is
/// the list that makes that visible.
export function Students() {
  const user = useUser()
  const [search, setSearch] = useState('')

  const students = useQuery(() => teaching.allStudents(user.id), [user.id])

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase()
    if (needle === '') return students.data ?? []
    return (students.data ?? []).filter((student) =>
      [student.full_name, student.roll_no, student.guardian_name, student.email]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle)),
    )
  }, [students.data, search])

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Students</h1>
          <p className="page-sub">
            {students.data === null
              ? 'Everyone you teach.'
              : `${students.data.length} student${students.data.length === 1 ? '' : 's'}, A to Z.`}
          </p>
        </div>
      </div>

      <div className="toolbar">
        {/* The magnifier is decoration for the field beside it; the placeholder
         * is what a screen reader should read out. */}
        <Search size={16} className="subtle" aria-hidden="true" />
        <input
          type="search"
          placeholder="Search by name, roll number or guardian"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
      </div>

      <Card>
        <QueryBoundary
          state={{ ...students, data: students.data === null ? null : visible }}
          what="students"
          emptyTitle={search === '' ? 'No students yet' : 'Nothing matches'}
          emptyHint={
            search === ''
              ? 'Open a class and add your first student.'
              : 'Try a different search.'
          }
          emptyIcon={search === '' ? <GraduationCap size={20} /> : <SearchX size={20} />}
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
