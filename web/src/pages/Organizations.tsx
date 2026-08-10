import { useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useQuery } from '../lib/useQuery'
import type { AdminOrganization, SubscriptionStatus } from '../lib/types'
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

const STATUSES: (SubscriptionStatus | 'all')[] = [
  'all',
  'active',
  'expiring_soon',
  'expired',
  'pending',
  'suspended',
]

/// Every institution on the platform.
export function Organizations() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<SubscriptionStatus | 'all'>('all')

  const organizations = useQuery(async () => {
    const { data, error } = await supabase
      .from('v_admin_organizations')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) throw error
    return data as AdminOrganization[]
  })

  // Filtered here rather than in the query: the whole list is one small read,
  // and typing into the box should not send a request per keystroke.
  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase()
    return (organizations.data ?? []).filter((row) => {
      if (status !== 'all' && row.status !== status) return false
      if (needle === '') return true
      return [row.name, row.city, row.email, row.admin_name, row.admin_email]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle))
    })
  }, [organizations.data, search, status])

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Organizations</h1>
          <p className="page-sub">
            {organizations.data === null
              ? 'Schools, colleges and academies on Warq.'
              : `${organizations.data.length} on the platform.`}
          </p>
        </div>
      </div>

      <div className="toolbar">
        <input
          type="search"
          placeholder="Search by name, city, admin or email"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <select
          value={status}
          onChange={(event) => setStatus(event.target.value as SubscriptionStatus | 'all')}
        >
          {STATUSES.map((value) => (
            <option key={value} value={value}>
              {value === 'all' ? 'Any subscription' : capitalise(value)}
            </option>
          ))}
        </select>
      </div>

      <Card>
        <QueryBoundary
          state={{ ...organizations, data: organizations.data === null ? null : visible }}
          what="organizations"
          emptyTitle={search === '' && status === 'all' ? 'No organizations yet' : 'Nothing matches'}
          emptyHint={
            search === '' && status === 'all'
              ? 'They appear here as soon as someone registers one.'
              : 'Try a different search or filter.'
          }
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Organization</th>
                    <th>Administrator</th>
                    <th>Account</th>
                    <th>Subscription</th>
                    <th>Ends</th>
                    <th className="num">Teachers</th>
                    <th className="num">Students</th>
                    <th className="num">Classes</th>
                    <th>Joined</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row) => (
                    <tr key={row.id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>{row.name}</div>
                        <div className="subtle">
                          {[row.city, row.email].filter(Boolean).join(' · ') || '—'}
                        </div>
                      </td>
                      <td className="wrap">
                        {row.admin_name === null ? (
                          <span className="subtle">No administrator</span>
                        ) : (
                          <>
                            <div>{row.admin_name}</div>
                            <div className="subtle">{row.admin_email}</div>
                          </>
                        )}
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
                      <td className="num">{row.teacher_count}</td>
                      <td className="num">{row.student_count}</td>
                      <td className="num">{row.class_count}</td>
                      <td className="subtle">{formatDate(row.created_at)}</td>
                      <td>
                        <SubscriptionActions
                          subscriptionId={row.subscription_id}
                          status={row.status}
                          subjectName={row.name}
                          onDone={organizations.reload}
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
