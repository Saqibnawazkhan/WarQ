import { NavLink, Outlet } from 'react-router-dom'
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
            <div className="brand-name">{organization?.name ?? 'Warq'}</div>
            <div className="brand-sub">Organization admin</div>
          </span>
        </div>

        <NavLink to="/" end className={navClass}>
          Overview
        </NavLink>
        <NavLink to="/teachers" className={navClass}>
          Teachers
        </NavLink>
        <NavLink to="/invitations" className={navClass}>
          Invitations
        </NavLink>
        <NavLink to="/classes" className={navClass}>
          Classes
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
