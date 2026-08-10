import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { SessionProvider, useSession } from './lib/session'
import { Shell } from './components/Shell'
import { SignIn } from './pages/SignIn'
import { Overview } from './pages/Overview'
import { Requests } from './pages/Requests'
import { Organizations } from './pages/Organizations'
import { Teachers } from './pages/Teachers'
import { Subscriptions } from './pages/Subscriptions'
import { Activity } from './pages/Activity'

export function App() {
  return (
    <SessionProvider>
      <BrowserRouter>
        <Routed />
      </BrowserRouter>
    </SessionProvider>
  )
}

function Routed() {
  const { admin, loading } = useSession()

  // Nothing is rendered until the stored session has been resolved. Showing the
  // sign-in form first would flash it at an administrator who is already signed
  // in, every time they open the dashboard.
  if (loading && admin === null) {
    return <div className="signin">Loading…</div>
  }

  if (admin === null) return <SignIn />

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
