import { Link } from 'react-router-dom'
import { supabase } from '../lib/supabase'
import { useQuery } from '../lib/useQuery'
import type { PlatformOverview, PendingRequest, AdminSubscription } from '../lib/types'
import { Card, Stat, QueryBoundary, Empty, formatDate, formatRemaining, capitalise } from '../components/ui'

/// What an administrator wants on opening the dashboard: is anybody waiting on
/// me, and is anything about to lapse. Everything else is a table elsewhere.
export function Overview() {
  const overview = useQuery(async () => {
    const { data, error } = await supabase.from('v_platform_overview').select('*').single()
    if (error) throw error
    return data as PlatformOverview
  })

  const requests = useQuery(async () => {
    const { data, error } = await supabase
      .from('v_pending_requests')
      .select('*')
      .order('requested_at', { ascending: true })
      .limit(5)
    if (error) throw error
    return data as PendingRequest[]
  })

  const expiring = useQuery(async () => {
    const { data, error } = await supabase
      .from('v_admin_subscriptions')
      .select('*')
      .eq('status', 'expiring_soon')
      .order('days_remaining', { ascending: true })
      .limit(5)
    if (error) throw error
    return data as AdminSubscription[]
  })

  const stats = overview.data

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Overview</h1>
          <p className="page-sub">Everything running on WarQ right now.</p>
        </div>
      </div>

      {overview.error !== null && <div className="notice notice-error">{overview.error}</div>}

      <div className="stat-grid">
        <Stat
          label="Organizations"
          value={stats?.organization_count ?? '—'}
          note={stats ? `${stats.active_organization_count} active` : undefined}
        />
        <Stat
          label="Teachers"
          value={
            stats ? stats.organization_teacher_count + stats.individual_teacher_count : '—'
          }
          note={stats ? `${stats.individual_teacher_count} independent` : undefined}
        />
        <Stat
          label="Active subscriptions"
          value={stats?.active_subscription_count ?? '—'}
          note={stats ? `${stats.expiring_soon_count} expiring soon` : undefined}
        />
        <Stat
          label="Awaiting approval"
          value={stats?.pending_count ?? '—'}
          note={stats && stats.expired_count > 0 ? `${stats.expired_count} expired` : undefined}
        />
      </div>

      <div style={{ display: 'grid', gap: 20, gridTemplateColumns: 'repeat(auto-fit, minmax(340px, 1fr))' }}>
        <Card
          title="Waiting for a decision"
          action={<Link to="/requests">See all</Link>}
        >
          <QueryBoundary
            state={requests}
            what="requests"
            emptyTitle="Nobody is waiting"
            emptyHint="New sign-ups are active immediately in Phase 1."
            isEmpty={(rows) => rows.length === 0}
          >
            {(rows) => (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Who</th>
                      <th>Kind</th>
                      <th>Requested</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((row) => (
                      <tr key={row.subscription_id}>
                        <td className="wrap">
                          <div style={{ fontWeight: 600 }}>{row.subject_name ?? 'Unnamed'}</div>
                          <div className="subtle">{row.subject_email ?? '—'}</div>
                        </td>
                        <td>{row.kind === 'organization' ? 'Organization' : 'Teacher'}</td>
                        <td className="subtle">{formatDate(row.requested_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </QueryBoundary>
        </Card>

        <Card title="Expiring soon" action={<Link to="/subscriptions">See all</Link>}>
          <QueryBoundary
            state={expiring}
            what="subscriptions"
            emptyTitle="Nothing expiring"
            emptyHint="No subscription is inside its reminder window."
            isEmpty={(rows) => rows.length === 0}
          >
            {(rows) => (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Who</th>
                      <th>Plan</th>
                      <th>Ends</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((row) => (
                      <tr key={row.id}>
                        <td className="wrap">
                          <div style={{ fontWeight: 600 }}>{row.subject_name ?? 'Unnamed'}</div>
                          <div className="subtle">{formatRemaining(row.days_remaining)}</div>
                        </td>
                        <td>{capitalise(row.plan)}</td>
                        <td className="subtle">{formatDate(row.ends_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </QueryBoundary>
        </Card>
      </div>

      <div style={{ marginTop: 20 }}>
        <Card title="Subscriptions by plan">
          <div className="card-body">
            {stats === null ? (
              <Empty title="No figures yet" />
            ) : (
              <PlanBars
                bars={[
                  { label: 'Monthly', value: stats.monthly_count },
                  { label: 'Yearly', value: stats.yearly_count },
                  { label: 'Permanent', value: stats.permanent_count },
                ]}
              />
            )}
          </div>
        </Card>
      </div>
    </>
  )
}

function PlanBars({ bars }: { bars: { label: string; value: number }[] }) {
  // Scaled against the largest bar rather than the total: with one plan far
  // ahead, proportions of the total would render every other bar invisible.
  const max = Math.max(1, ...bars.map((bar) => bar.value))

  return (
    <>
      {bars.map((bar) => (
        <div className="bar-row" key={bar.label}>
          <span className="bar-label">{bar.label}</span>
          <span className="bar-track">
            <span className="bar-fill" style={{ width: `${(bar.value / max) * 100}%` }} />
          </span>
          <span className="bar-value">{bar.value}</span>
        </div>
      ))}
    </>
  )
}
