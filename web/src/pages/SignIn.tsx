import { useState } from 'react'
import type { CSSProperties } from 'react'
import { LogIn, Lock, Mail } from 'lucide-react'
import { useSession } from '../lib/session'
import { ErrorNotice } from '../components/ui'

/// An icon sitting inside an input needs two things the stylesheet does not
/// offer: somewhere to sit, and room made for it on the input. Both are local
/// to this one screen, so they stay here rather than becoming a shared class.
const fieldIcon: CSSProperties = {
  position: 'absolute',
  left: 12,
  top: '50%',
  translate: '0 -50%',
  color: 'var(--muted)',
  // Otherwise the icon swallows the click that should land in the field.
  pointerEvents: 'none',
}

const withIcon: CSSProperties = { paddingLeft: 36 }

export function SignIn() {
  const { signIn, loading, error } = useSession()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    await signIn(email, password)
  }

  return (
    <div className="signin">
      <form className="signin-card" onSubmit={submit}>
        <div className="brand" style={{ padding: 0, marginBottom: 18 }}>
          <span className="brand-mark">W</span>
          <span>
            <div className="brand-name">WarQ</div>
            <div className="brand-sub">Platform administration</div>
          </span>
        </div>

        <div className="signin-head">
          <h1>Sign in</h1>
          <p className="page-sub">
            For platform administrators. Teachers and organizations use the mobile app.
          </p>
        </div>

        {error !== null && <ErrorNotice message={error} />}

        <div className="field">
          <label htmlFor="email">Email</label>
          <div style={{ position: 'relative' }}>
            <Mail size={16} style={fieldIcon} />
            <input
              id="email"
              type="email"
              autoComplete="username"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
              style={withIcon}
            />
          </div>
        </div>

        <div className="field">
          <label htmlFor="password">Password</label>
          <div style={{ position: 'relative' }}>
            <Lock size={16} style={fieldIcon} />
            <input
              id="password"
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              required
              style={withIcon}
            />
          </div>
        </div>

        <button className="btn-primary" style={{ width: '100%' }} disabled={loading}>
          <LogIn size={18} />
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  )
}
