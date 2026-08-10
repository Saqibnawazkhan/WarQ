import { NavLink, Outlet } from 'react-router-dom'
import { useSession } from '../lib/session'
import { useQuery } from '../lib/useQuery'
import { supabase } from '../lib/supabase'

/// The dashboard frame: navigation on the left, the routed page on the right.
///
/// The queue count sits next to Pending requests because it is the only number
/// that means somebody is waiting on a decision.
export function Shell() {
  const { user, signOut } = useSession()

  const pending = useQuery(async () => {
    const { count, error } = await supabase
      .from('v_pending_requests')
      .select('subscription_id', { count: 'exact', head: true })
    if (error) throw error
    return count ?? 0
  })

  const waiting = pending.data ?? 0

  return (
    <div className="shell">
      <nav className="sidebar">
        <div className="brand">
          <span className="brand-mark">W</span>
          <span>
            <div className="brand-name">Warq</div>
            <div className="brand-sub">Platform admin</div>
          </span>
        </div>

        <NavLink to="/" end className={navClass}>
          Overview
        </NavLink>
        <NavLink to="/requests" className={navClass}>
          <span>Pending requests</span>
          {waiting > 0 && <span className="pill pill-blue">{waiting}</span>}
        </NavLink>
        <NavLink to="/organizations" className={navClass}>
          Organizations
        </NavLink>
        <NavLink to="/teachers" className={navClass}>
          Individual teachers
        </NavLink>
        <NavLink to="/subscriptions" className={navClass}>
          Subscriptions
        </NavLink>
        <NavLink to="/activity" className={navClass}>
          Activity
        </NavLink>

        <span className="nav-spacer" />

        <div className="sidebar-footer">
          <div style={{ fontWeight: 600, color: 'var(--text)' }}>{user?.full_name}</div>
          <div style={{ marginBottom: 10 }}>{user?.email}</div>
          <button className="btn-quiet" onClick={() => void signOut()}>
            Sign out
          </button>
        </div>
      </nav>

      <main className="main">
        <Outlet />
      </main>
    </div>
  )
}

function navClass({ isActive }: { isActive: boolean }): string {
  return isActive ? 'nav-link active' : 'nav-link'
}
