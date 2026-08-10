import { NavLink, Outlet } from 'react-router-dom'
import { useSession } from '../lib/session'

/// The frame a teacher works inside.
///
/// Deliberately fewer places than the phone has tabs. A laptop screen can show
/// a class and its register at once, so the class page holds students,
/// attendance, assessments and results together rather than splitting them
/// across a navigation bar the way a phone must.
export function TeacherShell() {
  const { user, organization, signOut } = useSession()

  return (
    <div className="shell">
      <nav className="sidebar">
        <div className="brand">
          <span className="brand-mark">W</span>
          <span>
            <div className="brand-name">Warq</div>
            <div className="brand-sub">{organization?.name ?? 'Teacher'}</div>
          </span>
        </div>

        <NavLink to="/" end className={navClass}>
          Today
        </NavLink>
        <NavLink to="/classes" className={navClass}>
          Classes
        </NavLink>
        <NavLink to="/students" className={navClass}>
          Students
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
