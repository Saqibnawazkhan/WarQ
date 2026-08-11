import { NavLink, Outlet } from 'react-router-dom'
import {
  Activity,
  Building2,
  CreditCard,
  Inbox,
  LayoutDashboard,
  LogOut,
  Users,
} from 'lucide-react'
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
            <div className="brand-name">WarQ</div>
            <div className="brand-sub">Platform admin</div>
          </span>
        </div>

        <NavLink to="/" end className={navClass}>
          <LayoutDashboard size={18} />
          <span>Overview</span>
        </NavLink>
        <NavLink to="/requests" className={navClass}>
          <Inbox size={18} />
          <span>Pending requests</span>
          {waiting > 0 && <span className="pill pill-blue nav-count">{waiting}</span>}
        </NavLink>
        <NavLink to="/organizations" className={navClass}>
          <Building2 size={18} />
          <span>Organizations</span>
        </NavLink>
        <NavLink to="/teachers" className={navClass}>
          <Users size={18} />
          <span>Individual teachers</span>
        </NavLink>
        <NavLink to="/subscriptions" className={navClass}>
          <CreditCard size={18} />
          <span>Subscriptions</span>
        </NavLink>
        <NavLink to="/activity" className={navClass}>
          <Activity size={18} />
          <span>Activity</span>
        </NavLink>

        <span className="nav-spacer" />

        <div className="sidebar-footer">
          <div style={{ fontWeight: 600, color: 'var(--text)' }}>{user?.full_name}</div>
          <div style={{ marginBottom: 10 }}>{user?.email}</div>
          <button className="btn-quiet" onClick={() => void signOut()}>
            <LogOut size={18} />
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
