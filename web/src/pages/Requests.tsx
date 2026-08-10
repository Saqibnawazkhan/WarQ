import { useState } from 'react'
import { supabase, errorMessage } from '../lib/supabase'
import { useQuery } from '../lib/useQuery'
import { subscriptionActions } from '../lib/actions'
import type { PendingRequest } from '../lib/types'
import { Card, QueryBoundary, Modal, ErrorNotice, formatDate, capitalise } from '../components/ui'

/// Organizations and independent teachers waiting to be let in.
///
/// Phase 1 activates a self-service sign-up on the spot, so this queue is
/// normally empty. It fills the day approval is switched back on, and it is
/// what the pending count in the sidebar is counting.
export function Requests() {
  const [busy, setBusy] = useState<string | null>(null)
  const [failure, setFailure] = useState<string | null>(null)
  const [rejecting, setRejecting] = useState<PendingRequest | null>(null)
  const [reason, setReason] = useState('')

  const requests = useQuery(async () => {
    const { data, error } = await supabase
      .from('v_pending_requests')
      .select('*')
      .order('requested_at', { ascending: true })
    if (error) throw error
    return data as PendingRequest[]
  })

  async function run(id: string, action: () => Promise<void>) {
    setBusy(id)
    setFailure(null)
    try {
      await action()
      requests.reload()
    } catch (caught) {
      setFailure(errorMessage(caught))
    } finally {
      setBusy(null)
    }
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Pending requests</h1>
          <p className="page-sub">Accounts waiting to be approved, oldest first.</p>
        </div>
      </div>

      {failure !== null && <ErrorNotice message={failure} />}

      <Card>
        <QueryBoundary
          state={requests}
          what="requests"
          emptyTitle="Nobody is waiting"
          emptyHint="Sign-ups are approved automatically until the approval step is switched on."
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Who</th>
                    <th>Kind</th>
                    <th>City</th>
                    <th>Plan</th>
                    <th className="num">Teachers</th>
                    <th>Requested</th>
                    <th />
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
                      <td className="subtle">{row.city ?? '—'}</td>
                      <td>{capitalise(row.plan)}</td>
                      <td className="num">{row.kind === 'organization' ? row.teacher_count : '—'}</td>
                      <td className="subtle">{formatDate(row.requested_at)}</td>
                      <td>
                        <div className="btn-row">
                          <button
                            className="btn-primary"
                            disabled={busy !== null}
                            onClick={() =>
                              void run(row.subscription_id, () =>
                                subscriptionActions.approve(row.subscription_id),
                              )
                            }
                          >
                            {busy === row.subscription_id ? 'Working…' : 'Approve'}
                          </button>
                          <button
                            className="btn-danger"
                            disabled={busy !== null}
                            onClick={() => {
                              setReason('')
                              setRejecting(row)
                            }}
                          >
                            Reject
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </QueryBoundary>
      </Card>

      {rejecting !== null && (
        <Modal
          title={`Reject ${rejecting.subject_name ?? 'this account'}?`}
          description="They keep their account but cannot use Warq. A reason is optional and is stored on the record."
          onClose={() => setRejecting(null)}
        >
          <div className="field">
            <label htmlFor="reason">Reason</label>
            <textarea
              id="reason"
              rows={3}
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              placeholder="Optional"
            />
          </div>
          <div className="modal-actions">
            <button className="btn-quiet" onClick={() => setRejecting(null)}>
              Cancel
            </button>
            <button
              className="btn-danger"
              disabled={busy !== null}
              onClick={() => {
                const target = rejecting
                setRejecting(null)
                void run(target.subscription_id, () =>
                  subscriptionActions.reject(target.subscription_id, reason),
                )
              }}
            >
              Reject
            </button>
          </div>
        </Modal>
      )}
    </>
  )
}
