import { useState } from 'react'
import { supabase } from '../lib/supabase'
import { useQuery } from '../lib/useQuery'
import type { ActivityRow } from '../lib/types'
import { Card, QueryBoundary, Pill, formatDateTime, capitalise } from '../components/ui'

const PAGE = 100

const TYPES = ['all', 'admin', 'attendance', 'marks', 'alerts', 'subscription'] as const

/// The platform-wide audit trail.
///
/// Append-only by design: there is no update or delete policy on this table
/// anywhere, so nothing here can be edited after the fact, including by an
/// administrator reading it.
export function Activity() {
  const [type, setType] = useState<(typeof TYPES)[number]>('all')
  const [limit, setLimit] = useState(PAGE)

  const activity = useQuery(async () => {
    let query = supabase
      .from('activity_logs')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(limit)

    if (type !== 'all') query = query.eq('type', type)

    const { data, error } = await query
    if (error) throw error
    return data as ActivityRow[]
  }, [type, limit])

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Activity</h1>
          <p className="page-sub">Everything that has happened, newest first.</p>
        </div>
      </div>

      <div className="toolbar">
        <select
          value={type}
          onChange={(event) => {
            setLimit(PAGE)
            setType(event.target.value as (typeof TYPES)[number])
          }}
        >
          {TYPES.map((value) => (
            <option key={value} value={value}>
              {value === 'all' ? 'Everything' : capitalise(value)}
            </option>
          ))}
        </select>
      </div>

      <Card>
        <QueryBoundary
          state={activity}
          what="activity"
          emptyTitle="Nothing recorded yet"
          emptyHint="Entries appear as teachers and administrators use Warq."
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <>
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>When</th>
                      <th>Who</th>
                      <th>Kind</th>
                      <th>What</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map((row) => (
                      <tr key={row.id}>
                        <td className="subtle">{formatDateTime(row.created_at)}</td>
                        <td>{row.actor_name}</td>
                        <td>
                          <Pill tone={toneFor(row.type)}>{capitalise(row.type)}</Pill>
                        </td>
                        <td className="wrap">{row.message}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              {rows.length >= limit && (
                <div className="card-body" style={{ borderTop: '1px solid var(--border)' }}>
                  <button className="btn-quiet" onClick={() => setLimit(limit + PAGE)}>
                    Show more
                  </button>
                </div>
              )}
            </>
          )}
        </QueryBoundary>
      </Card>
    </>
  )
}

function toneFor(type: string): string {
  switch (type) {
    case 'attendance':
      return 'green'
    case 'marks':
      return 'blue'
    case 'alerts':
      return 'amber'
    case 'subscription':
      return 'blue'
    default:
      return 'grey'
  }
}
