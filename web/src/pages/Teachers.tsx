import { useMemo, useState } from 'react'
import { GraduationCap, Search, SearchX } from 'lucide-react'
import { supabase } from '../lib/supabase'
import { useQuery } from '../lib/useQuery'
import type { AdminIndividualTeacher } from '../lib/types'
import { SubscriptionActions } from '../components/SubscriptionActions'
import {
  Card,
  QueryBoundary,
  SubscriptionPill,
  AccountPill,
  formatDate,
  formatRemaining,
  capitalise,
} from '../components/ui'

/// Teachers who belong to no organization and hold their own subscription.
///
/// A teacher inside an organization is covered by that organization's
/// subscription and is managed by their own admin, so they are deliberately not
/// listed here — they would have no subscription of their own to act on.
export function Teachers() {
  const [search, setSearch] = useState('')

  const teachers = useQuery(async () => {
    const { data, error } = await supabase
      .from('v_admin_individual_teachers')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) throw error
    return data as AdminIndividualTeacher[]
  })

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase()
    if (needle === '') return teachers.data ?? []
    return (teachers.data ?? []).filter((row) =>
      [row.full_name, row.email, row.phone]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle)),
    )
  }, [teachers.data, search])

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Individual teachers</h1>
          <p className="page-sub">
            {teachers.data === null
              ? 'Teachers subscribing directly, without an organization.'
              : `${teachers.data.length} subscribing directly.`}
          </p>
        </div>
      </div>

      <div className="toolbar">
        <Search size={16} className="subtle" aria-hidden="true" />
        <input
          type="search"
          placeholder="Search by name, email or phone"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
      </div>

      <Card>
        <QueryBoundary
          state={{ ...teachers, data: teachers.data === null ? null : visible }}
          what="teachers"
          icon={search === '' ? <GraduationCap size={20} /> : <SearchX size={20} />}
          emptyTitle={search === '' ? 'No independent teachers yet' : 'Nothing matches'}
          emptyHint={
            search === ''
              ? 'Teachers who sign up without an organization appear here.'
              : 'Try a different search.'
          }
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Teacher</th>
                    <th>Account</th>
                    <th>Subscription</th>
                    <th>Ends</th>
                    <th className="num">Classes</th>
                    <th className="num">Students</th>
                    <th>Joined</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row) => (
                    <tr key={row.id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>{row.full_name}</div>
                        <div className="subtle">
                          {[row.email, row.phone].filter(Boolean).join(' · ')}
                        </div>
                      </td>
                      <td>
                        <AccountPill status={row.account_status} />
                      </td>
                      <td>
                        <SubscriptionPill status={row.status} />
                        {row.plan !== null && (
                          <div className="subtle" style={{ fontSize: 12 }}>{capitalise(row.plan)}</div>
                        )}
                      </td>
                      <td className="subtle">
                        {formatDate(row.ends_at)}
                        <div style={{ fontSize: 12 }}>{formatRemaining(row.days_remaining)}</div>
                      </td>
                      <td className="num">{row.class_count}</td>
                      <td className="num">{row.student_count}</td>
                      <td className="subtle">{formatDate(row.created_at)}</td>
                      <td>
                        <SubscriptionActions
                          subscriptionId={row.subscription_id}
                          status={row.status}
                          subjectName={row.full_name}
                          onDone={teachers.reload}
                        />
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
