import { useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useQuery } from '../lib/useQuery'
import type { AdminSubscription, SubscriptionStatus, SubjectKind } from '../lib/types'
import { SubscriptionActions } from '../components/SubscriptionActions'
import {
  Card,
  QueryBoundary,
  SubscriptionPill,
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
  'rejected',
]

const KINDS: (SubjectKind | 'all')[] = ['all', 'organization', 'individual_teacher']

/// Every subscription on the platform, whoever holds it.
///
/// Sorted by how little time is left, so whatever needs attention first is at
/// the top without anybody choosing a filter. Rows with no end date sort last.
export function Subscriptions() {
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<SubscriptionStatus | 'all'>('all')
  const [kind, setKind] = useState<SubjectKind | 'all'>('all')

  const subscriptions = useQuery(async () => {
    const { data, error } = await supabase.from('v_admin_subscriptions').select('*')
    if (error) throw error
    return data as AdminSubscription[]
  })

  const visible = useMemo(() => {
    const needle = search.trim().toLowerCase()
    const rows = (subscriptions.data ?? []).filter((row) => {
      if (status !== 'all' && row.status !== status) return false
      if (kind !== 'all' && row.kind !== kind) return false
      if (needle === '') return true
      return [row.subject_name, row.subject_email, row.city]
        .filter((value): value is string => typeof value === 'string')
        .some((value) => value.toLowerCase().includes(needle))
    })

    return [...rows].sort((a, b) => {
      const left = a.days_remaining ?? Number.MAX_SAFE_INTEGER
      const right = b.days_remaining ?? Number.MAX_SAFE_INTEGER
      return left - right
    })
  }, [subscriptions.data, search, status, kind])

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Subscriptions</h1>
          <p className="page-sub">Soonest to expire first.</p>
        </div>
      </div>

      <div className="toolbar">
        <input
          type="search"
          placeholder="Search by name, email or city"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <select
          value={status}
          onChange={(event) => setStatus(event.target.value as SubscriptionStatus | 'all')}
        >
          {STATUSES.map((value) => (
            <option key={value} value={value}>
              {value === 'all' ? 'Any status' : capitalise(value)}
            </option>
          ))}
        </select>
        <select value={kind} onChange={(event) => setKind(event.target.value as SubjectKind | 'all')}>
          {KINDS.map((value) => (
            <option key={value} value={value}>
              {value === 'all'
                ? 'Anyone'
                : value === 'organization'
                  ? 'Organizations'
                  : 'Individual teachers'}
            </option>
          ))}
        </select>
      </div>

      <Card>
        <QueryBoundary
          state={{ ...subscriptions, data: subscriptions.data === null ? null : visible }}
          what="subscriptions"
          emptyTitle="Nothing matches"
          emptyHint="Try a different search or filter."
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Held by</th>
                    <th>Kind</th>
                    <th>Plan</th>
                    <th>Status</th>
                    <th>Started</th>
                    <th>Ends</th>
                    <th>Access</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row) => (
                    <tr key={row.id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>{row.subject_name ?? 'Unnamed'}</div>
                        <div className="subtle">
                          {[row.subject_email, row.city].filter(Boolean).join(' · ') || '—'}
                        </div>
                      </td>
                      <td>{row.kind === 'organization' ? 'Organization' : 'Teacher'}</td>
                      <td>{capitalise(row.plan)}</td>
                      <td>
                        <SubscriptionPill status={row.status} />
                      </td>
                      <td className="subtle">{formatDate(row.starts_at)}</td>
                      <td className="subtle">
                        {formatDate(row.ends_at)}
                        <div style={{ fontSize: 12 }}>{formatRemaining(row.days_remaining)}</div>
                      </td>
                      <td>
                        {row.grants_access ? (
                          <span className="pill pill-green">Yes</span>
                        ) : (
                          <span className="pill pill-red">No</span>
                        )}
                      </td>
                      <td>
                        <SubscriptionActions
                          subscriptionId={row.id}
                          status={row.status}
                          subjectName={row.subject_name ?? 'this subscription'}
                          onDone={subscriptions.reload}
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
