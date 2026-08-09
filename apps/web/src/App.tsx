import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { AdminLayout } from './admin/AdminLayout.tsx';
import { OverviewPage } from './admin/pages/OverviewPage.tsx';
import { PlaceholderPage } from './admin/pages/PlaceholderPage.tsx';
import { RequireRole } from './auth/RequireRole.tsx';
import { SessionProvider } from './auth/SessionProvider.tsx';
import { DashboardPage } from './routes/DashboardPage.tsx';
import { ToastProvider } from './ui/index.ts';
import { DesignSystemPage } from './routes/DesignSystemPage.tsx';
import { ForgotPasswordPage } from './routes/ForgotPasswordPage.tsx';
import { HomePage } from './routes/HomePage.tsx';
import { LoginPage } from './routes/LoginPage.tsx';
import { NotFoundPage } from './routes/NotFoundPage.tsx';
import { SignUpPage } from './routes/SignUpPage.tsx';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Classroom data changes on human timescales; a minute of freshness is
      // plenty, and realtime invalidation takes over from M9.
      staleTime: 60_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

/**
 * Routes.
 *
 * The three dashboard paths match `landingRoute()` in `@warq/core`, so sign-in
 * routes by role without a lookup table of its own. `RequireRole` is a
 * convenience for the user, not a security boundary — the database policies are
 * what actually decide who reads what.
 */
export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <SessionProvider>
        <ToastProvider>
          <BrowserRouter>
            <Routes>
              <Route path="/" element={<HomePage />} />
              <Route path="/design" element={<DesignSystemPage />} />

              <Route path="/login" element={<LoginPage />} />
              <Route path="/signup" element={<SignUpPage />} />
              <Route path="/forgot-password" element={<ForgotPasswordPage />} />

              <Route
                path="/admin"
                element={
                  <RequireRole role="main_admin">
                    <AdminLayout />
                  </RequireRole>
                }
              >
                <Route index element={<OverviewPage />} />
                <Route
                  path="organizations"
                  element={
                    <PlaceholderPage
                      title="Organizations"
                      body="Every institution on the platform, with its subscription, admin and counts. Searchable, filterable by status, with a detail drawer for approving, extending, suspending and renewing."
                    />
                  }
                />
                <Route
                  path="teachers"
                  element={
                    <PlaceholderPage
                      title="Individual Teachers"
                      body="Teachers who hold their own subscription rather than belonging to an organization."
                    />
                  }
                />
                <Route
                  path="org-admins"
                  element={
                    <PlaceholderPage
                      title="Organization Admins"
                      body="The administrators running each organization, and which organization each one owns."
                    />
                  }
                />
                <Route
                  path="subscriptions"
                  element={
                    <PlaceholderPage
                      title="Subscriptions"
                      body="Every subscription on the platform in one list, whoever holds it."
                    />
                  }
                />
                <Route
                  path="pending"
                  element={
                    <PlaceholderPage
                      title="Pending Requests"
                      body="Organizations and individual teachers awaiting approval. The same queue as the dashboard, with the full detail of each request."
                    />
                  }
                />
                <Route
                  path="expiring"
                  element={
                    <PlaceholderPage
                      title="Expiring Soon"
                      body="Subscriptions inside the fourteen-day warning window, soonest first, with the reminders already sent to each."
                    />
                  }
                />
                <Route
                  path="notifications"
                  element={
                    <PlaceholderPage
                      title="Notifications"
                      body="The reminder schedule — 30, 15, 7, 3 and 1 days before expiry — and the log of every notice sent."
                    />
                  }
                />
                <Route
                  path="activity"
                  element={
                    <PlaceholderPage
                      title="Activity Logs"
                      body="Everything that has happened across the platform, filterable by kind."
                    />
                  }
                />
                <Route
                  path="reports"
                  element={
                    <PlaceholderPage
                      title="Reports"
                      body="Platform-wide reports. Generation lands with the worker in M8."
                    />
                  }
                />
                <Route
                  path="settings"
                  element={
                    <PlaceholderPage
                      title="Settings"
                      body="Platform defaults: the grade scale, plan pricing and administrator accounts."
                    />
                  }
                />
              </Route>
              <Route
                path="/org/*"
                element={
                  <RequireRole role="org_admin">
                    <DashboardPage milestone="M3" title="Organization dashboard" />
                  </RequireRole>
                }
              />
              <Route
                path="/teacher/*"
                element={
                  <RequireRole role="teacher">
                    <DashboardPage milestone="M4" title="Teacher dashboard" />
                  </RequireRole>
                }
              />

              <Route path="*" element={<NotFoundPage />} />
            </Routes>
          </BrowserRouter>
        </ToastProvider>
      </SessionProvider>
    </QueryClientProvider>
  );
}
