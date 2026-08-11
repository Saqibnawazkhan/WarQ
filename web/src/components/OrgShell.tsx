import { NavLink, Outlet } from 'react-router-dom'
import { Activity, BookOpen, LayoutDashboard, LogOut, Mail, Users } from 'lucide-react'
import { useSession } from '../lib/session'

/// The frame an organization administrator works inside.
///
/// They do not teach, so there is no register or mark entry here: what they
/// need is who is on staff, what those teachers are doing, and who is waiting
/// on an invitation.
export function OrgShell() {
  const { user, organization, signOut } = useSession()

  return (
    <div className="shell">
      <nav className="sidebar">
        <div className="brand">
          <span className="brand-mark">W</span>
          <span>
            <div className="brand-name">{organization?.name ?? 'WarQ'}</div>
            <div className="brand-sub">Organization admin</div>
          </span>
        </div>

        <NavLink to="/" end className={navClass}>
          <LayoutDashboard size={18} />
          <span>Overview</span>
        </NavLink>
        <NavLink to="/teachers" className={navClass}>
          <Users size={18} />
          <span>Teachers</span>
        </NavLink>
        <NavLink to="/invitations" className={navClass}>
          <Mail size={18} />
          <span>Invitations</span>
        </NavLink>
        <NavLink to="/classes" className={navClass}>
          <BookOpen size={18} />
          <span>Classes</span>
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
