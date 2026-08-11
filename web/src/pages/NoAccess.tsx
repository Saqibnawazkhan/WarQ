import { Hourglass, PauseCircle, RefreshCw } from 'lucide-react'
import { useSession } from '../lib/session'

/// Shown to a signed-in account that is not allowed to work yet.
///
/// The same four situations the mobile app distinguishes, worded the same way.
/// The alternative is dropping someone on a dashboard where every panel fails
/// with "your subscription is not active", which reads as a broken app rather
/// than a decision somebody made.
export function NoAccess() {
  const { user, organization, loading, refresh, signOut } = useSession()

  const explanation = explain(user?.status ?? 'pending', organization !== null)

  return (
    <div className="signin">
      <div className="signin-card" style={{ textAlign: 'center' }}>
        <div
          style={{
            width: 64,
            height: 64,
            borderRadius: '50%',
            display: 'grid',
            placeItems: 'center',
            margin: '0 auto 18px',
            background: explanation.waiting ? 'var(--primary-tint)' : 'var(--red-tint)',
            color: explanation.waiting ? 'var(--primary)' : 'var(--red)',
          }}
        >
          {explanation.waiting ? <Hourglass size={26} /> : <PauseCircle size={26} />}
        </div>

        <h1 style={{ fontSize: 19 }}>{explanation.title}</h1>
        <p className="page-sub" style={{ marginBottom: 20 }}>
          {explanation.body}
        </p>

        <div
          style={{
            background: 'var(--grey-tint)',
            borderRadius: 10,
            padding: 14,
            marginBottom: 20,
          }}
        >
          <div style={{ fontWeight: 600 }}>{user?.full_name}</div>
          <div className="subtle">{user?.email}</div>
        </div>

        {/* Approval happens elsewhere and nothing pushes it here, so asking the
            server again is the only honest thing to offer. */}
        <button
          className="btn-primary"
          style={{ width: '100%' }}
          disabled={loading}
          onClick={() => void refresh()}
        >
          <RefreshCw size={18} />
          {loading ? 'Checking…' : 'Check again'}
        </button>
        <button
          className="btn-quiet"
          style={{ width: '100%', marginTop: 8, border: 'none' }}
          onClick={() => void signOut()}
        >
          Sign out
        </button>
      </div>
    </div>
  )
}

function explain(status: string, inOrganization: boolean) {
  switch (status) {
    case 'pending':
      return {
        waiting: true,
        title: 'Waiting for approval',
        body: 'Your account has been created and is with the WarQ team for review. You will be able to start creating classes as soon as it is approved.',
      }
    case 'suspended':
      return {
        waiting: false,
        title: 'Account paused',
        body: 'This account has been switched off. Your classes, registers and marks are all safe and come back exactly as they were once it is switched on again.',
      }
    default:
      // In good standing, but still gated: the subscription covering them has
      // lapsed or been suspended. Whose subscription it is changes who they
      // need to speak to.
      return inOrganization
        ? {
            waiting: false,
            title: 'Your organization’s subscription has stopped',
            body: 'Nothing is wrong with your account. Your organization administrator can restore access, and everything you have recorded is waiting for you.',
          }
        : {
            waiting: false,
            title: 'Your subscription has ended',
            body: 'Renew to pick up exactly where you left off. Your classes, registers and marks are all still here.',
          }
  }
}
