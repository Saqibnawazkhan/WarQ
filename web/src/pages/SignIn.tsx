import { useState } from 'react'
import { useSession } from '../lib/session'
import { ErrorNotice } from '../components/ui'

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
          <input
            id="email"
            type="email"
            autoComplete="username"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </div>

        <div className="field">
          <label htmlFor="password">Password</label>
          <input
            id="password"
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
        </div>

        <button className="btn-primary" style={{ width: '100%' }} disabled={loading}>
          {loading ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </div>
  )
}
