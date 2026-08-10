import { useState } from 'react'
import { subscriptionActions } from '../lib/actions'
import { errorMessage } from '../lib/supabase'
import type { SubscriptionStatus } from '../lib/types'
import { Modal } from './ui'

/// The buttons that act on one subscription, wherever it is listed.
///
/// Which buttons appear is decided by the status, so an administrator is never
/// offered an action the database would refuse: there is nothing to reactivate
/// on a live subscription, and nothing to suspend on one already suspended.
export function SubscriptionActions({
  subscriptionId,
  status,
  subjectName,
  onDone,
}: {
  subscriptionId: string | null
  status: SubscriptionStatus | null
  subjectName: string
  onDone: () => void
  }) {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [confirming, setConfirming] = useState<'suspend' | null>(null)
  const [reason, setReason] = useState('')

  if (subscriptionId === null || status === null) {
    return <span className="subtle">No subscription</span>
  }

  async function run(action: () => Promise<void>) {
    setBusy(true)
    setError(null)
    try {
      await action()
      onDone()
    } catch (caught) {
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  const id = subscriptionId
  const canApprove = status === 'pending'
  const canSuspend = status === 'active' || status === 'expiring_soon'
  const canReactivate = status === 'suspended'
  const canRenew = status === 'active' || status === 'expiring_soon' || status === 'expired'

  return (
    <>
      <div className="btn-row">
        {canApprove && (
          <button className="btn-primary" disabled={busy} onClick={() => void run(() => subscriptionActions.approve(id))}>
            Approve
          </button>
        )}
        {canRenew && (
          <button className="btn-quiet" disabled={busy} onClick={() => void run(() => subscriptionActions.renew(id))}>
            Renew
          </button>
        )}
        {canReactivate && (
          <button
            className="btn-primary"
            disabled={busy}
            onClick={() => void run(() => subscriptionActions.reactivate(id))}
          >
            Reactivate
          </button>
        )}
        {canSuspend && (
          <button
            className="btn-danger"
            disabled={busy}
            onClick={() => {
              setReason('')
              setConfirming('suspend')
            }}
          >
            Suspend
          </button>
        )}
      </div>

      {error !== null && (
        <div className="subtle" style={{ color: 'var(--red)', marginTop: 4, whiteSpace: 'normal' }}>
          {error}
        </div>
      )}

      {confirming === 'suspend' && (
        <Modal
          title={`Suspend ${subjectName}?`}
          description="Everyone on this subscription loses access immediately. Their classes, registers and marks are untouched, and reactivating restores everything."
          onClose={() => setConfirming(null)}
        >
          <div className="field">
            <label htmlFor="suspend-reason">Reason</label>
            <textarea
              id="suspend-reason"
              rows={3}
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              placeholder="Optional. Stored on the record."
            />
          </div>
          <div className="modal-actions">
            <button className="btn-quiet" onClick={() => setConfirming(null)}>
              Cancel
            </button>
            <button
              className="btn-danger"
              disabled={busy}
              onClick={() => {
                const note = reason
                setConfirming(null)
                void run(() => subscriptionActions.suspend(id, note))
              }}
            >
              Suspend
            </button>
          </div>
        </Modal>
      )}
    </>
  )
}
