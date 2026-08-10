import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { SessionProvider, useSession } from './lib/session'
import { Shell } from './components/Shell'
import { TeacherShell } from './components/TeacherShell'
import { SignIn } from './pages/SignIn'
import { NoAccess } from './pages/NoAccess'

import { Overview } from './pages/Overview'
import { Requests } from './pages/Requests'
import { Organizations } from './pages/Organizations'
import { Teachers } from './pages/Teachers'
import { Subscriptions } from './pages/Subscriptions'
import { Activity } from './pages/Activity'

import { Today } from './pages/teacher/Today'
import { Classes } from './pages/teacher/Classes'
import { ClassDetail } from './pages/teacher/ClassDetail'
import { Register } from './pages/teacher/Register'
import { MarkEntry } from './pages/teacher/MarkEntry'
import { Students } from './pages/teacher/Students'

export function App() {
  return (
    <SessionProvider>
      <BrowserRouter>
        <Routed />
      </BrowserRouter>
    </SessionProvider>
  )
}

/// One sign-in, three destinations, decided by the role on the profile.
///
/// Row-level security enforces the same split in the database, so this is about
/// showing people the right thing rather than keeping them out of the rest: a
/// teacher who typed an admin URL would reach a page whose every query returns
/// nothing.
function Routed() {
  const { user, hasAccess, loading } = useSession()

  // Nothing renders until the stored session has resolved. Showing the sign-in
  // form first would flash it at someone who is already signed in, every time
  // they open the app.
  if (loading && user === null) {
    return <div className="signin">Loading…</div>
  }

  if (user === null) return <SignIn />

  // The platform administrator holds no subscription of their own, so the
  // access gate does not apply to them.
  if (user.role !== 'main_admin' && !hasAccess) return <NoAccess />

  if (user.role === 'main_admin') {
    return (
      <Routes>
        <Route element={<Shell />}>
          <Route index element={<Overview />} />
          <Route path="requests" element={<Requests />} />
          <Route path="organizations" element={<Organizations />} />
          <Route path="teachers" element={<Teachers />} />
          <Route path="subscriptions" element={<Subscriptions />} />
          <Route path="activity" element={<Activity />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    )
  }

  return (
    <Routes>
      <Route element={<TeacherShell />}>
        <Route index element={<Today />} />
        <Route path="classes" element={<Classes />} />
        <Route path="classes/:classId" element={<ClassDetail />} />
        <Route path="classes/:classId/attendance" element={<Register />} />
        <Route path="classes/:classId/assessments/:assessmentId" element={<MarkEntry />} />
        <Route path="students" element={<Students />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
