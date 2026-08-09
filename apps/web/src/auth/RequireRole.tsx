import { Navigate, useLocation } from 'react-router-dom';

import { landingRoute, type UserRole } from '@warq/core';

import { useSession } from './session-context.ts';

interface RequireRoleProps {
  readonly role: UserRole;
  readonly children: React.ReactNode;
}

/**
 * Guards a dashboard route.
 *
 * This is convenience, not security — the database policies are what actually
 * stop a request. Its job is to send people somewhere sensible rather than to
 * show them an empty screen full of failed queries.
 */
export function RequireRole({ role, children }: RequireRoleProps) {
  const { session, loading } = useSession();
  const location = useLocation();

  if (loading) {
    return <FullPageWait />;
  }

  if (!session) {
    // Remember where they were headed, so signing in resumes rather than restarts.
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  if (session.profile.role !== role) {
    return <Navigate to={landingRoute(session.profile.role)} replace />;
  }

  return children;
}

export function FullPageWait() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-canvas">
      <p className="text-[13px] font-semibold text-ink-muted" role="status">
        Loading…
      </p>
    </div>
  );
}
