import { useState } from 'react'
import { Info, Mail } from 'lucide-react'
import { useQuery } from '../../lib/useQuery'
import { org } from '../../lib/org'
import { errorMessage } from '../../lib/supabase'
import { Card, QueryBoundary, Modal, ErrorNotice, Pill, formatDate } from '../../components/ui'

/// Teachers invited to join, and what became of each invitation.
export function OrgInvitations() {
  const [inviting, setInviting] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const invitations = useQuery(() => org.invitations())

  async function revoke(id: string) {
    setBusy(true)
    setError(null)
    try {
      await org.revoke(id)
      invitations.reload()
    } catch (caught) {
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <div className="page-head">
        <div>
          <h1>Invitations</h1>
          <p className="page-sub">
            A teacher joins automatically when they register with the address you invited.
          </p>
        </div>
        <button className="btn-primary" onClick={() => setInviting(true)}>
          <Mail size={18} />
          Invite a teacher
        </button>
      </div>

      {error !== null && <ErrorNotice message={error} />}

      <div className="notice notice-info">
        <Info size={18} />
        <div>
          WarQ does not send the email yet. Tell the teacher to download the app and register with
          exactly the address you invite here, and they will land inside your organization.
        </div>
      </div>

      <Card>
        <QueryBoundary
          state={invitations}
          what="invitations"
          emptyIcon={<Mail size={20} />}
          emptyTitle="No invitations yet"
          emptyHint="Invite a teacher by email address."
          isEmpty={(rows) => rows.length === 0}
        >
          {(rows) => (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Invited</th>
                    <th>Status</th>
                    <th>Sent</th>
                    <th>Expires</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((invitation) => (
                    <tr key={invitation.id}>
                      <td className="wrap">
                        <div style={{ fontWeight: 600 }}>{invitation.full_name}</div>
                        <div className="subtle">{invitation.email}</div>
                      </td>
                      <td>
                        <Pill tone={toneFor(invitation.status)}>
                          {invitation.status === 'pending' ? 'Waiting' : capital(invitation.status)}
                        </Pill>
                      </td>
                      <td className="subtle">{formatDate(invitation.created_at)}</td>
                      <td className="subtle">
                        {invitation.status === 'accepted'
                          ? formatDate(invitation.accepted_at)
                          : formatDate(invitation.expires_at)}
                      </td>
                      <td>
                        {invitation.status === 'pending' ? (
                          <button
                            className="btn-danger"
                            disabled={busy}
                            onClick={() => void revoke(invitation.id)}
                          >
                            Revoke
                          </button>
                        ) : (
                          <span className="subtle">—</span>
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

      {inviting && (
        <InviteForm
          onClose={() => setInviting(false)}
          onSent={() => {
            setInviting(false)
            invitations.reload()
          }}
        />
      )}
    </>
  )
}

function InviteForm({ onClose, onSent }: { onClose: () => void; onSent: () => void }) {
  const [email, setEmail] = useState('')
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (email.trim() === '') return setError('An email address is required.')

    setBusy(true)
    setError(null)
    try {
      await org.invite(email, name)
      onSent()
    } catch (caught) {
      setError(errorMessage(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      title="Invite a teacher"
      description="They join your organization the moment they register with this address."
      onClose={onClose}
    >
      <form onSubmit={submit}>
        {error !== null && <ErrorNotice message={error} />}

        <div className="field">
          <label htmlFor="i-email">Email address</label>
          <input
            id="i-email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoFocus
          />
        </div>
        <div className="field">
          <label htmlFor="i-name">Their name</label>
          <input id="i-name" value={name} onChange={(e) => setName(e.target.value)} />
        </div>

        <div className="modal-actions">
          <button type="button" className="btn-quiet" onClick={onClose}>
            Cancel
          </button>
          <button className="btn-primary" disabled={busy}>
            {busy ? 'Inviting…' : 'Send invitation'}
          </button>
        </div>
      </form>
    </Modal>
  )
}

function toneFor(status: string): string {
  switch (status) {
    case 'accepted':
      return 'green'
    case 'pending':
      return 'blue'
    case 'revoked':
      return 'red'
    default:
      return 'grey'
  }
}

function capital(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1)
}
