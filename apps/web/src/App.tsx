import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { AdminLayout } from './admin/AdminLayout.tsx';
import { ActivityPage } from './admin/pages/ActivityPage.tsx';
import { NotificationsPage } from './admin/pages/NotificationsPage.tsx';
import { OrgAdminsPage } from './admin/pages/OrgAdminsPage.tsx';
import { OrganizationsPage } from './admin/pages/OrganizationsPage.tsx';
import { OverviewPage } from './admin/pages/OverviewPage.tsx';
import { PendingPage } from './admin/pages/PendingPage.tsx';
import { ReportsPage } from './admin/pages/ReportsPage.tsx';
import { SettingsPage } from './admin/pages/SettingsPage.tsx';
import { ExpiringPage, SubscriptionsPage } from './admin/pages/SubscriptionsPage.tsx';
import { TeachersPage } from './admin/pages/TeachersPage.tsx';
import { OrgLayout } from './org/OrgLayout.tsx';
import { OrgActivityPage } from './org/pages/OrgActivityPage.tsx';
import { OrgClassDetailPage } from './org/pages/OrgClassDetailPage.tsx';
import { OrgClassesPage } from './org/pages/OrgClassesPage.tsx';
import { OrgOverviewPage } from './org/pages/OrgOverviewPage.tsx';
import { OrgReportsPage } from './org/pages/OrgReportsPage.tsx';
import { OrgSettingsPage } from './org/pages/OrgSettingsPage.tsx';
import { OrgStudentsPage } from './org/pages/OrgStudentsPage.tsx';
import { OrgTeachersPage } from './org/pages/OrgTeachersPage.tsx';
import { RequireRole } from './auth/RequireRole.tsx';
import { SessionProvider } from './auth/SessionProvider.tsx';
import { DashboardPage } from './routes/DashboardPage.tsx';
import { JoinPage } from './routes/JoinPage.tsx';
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
              <Route path="/join/:token" element={<JoinPage />} />

              <Route
                path="/admin"
                element={
                  <RequireRole role="main_admin">
                    <AdminLayout />
                  </RequireRole>
                }
              >
                <Route index element={<OverviewPage />} />
                <Route path="organizations" element={<OrganizationsPage />} />
                <Route path="teachers" element={<TeachersPage />} />
                <Route path="org-admins" element={<OrgAdminsPage />} />
                <Route path="subscriptions" element={<SubscriptionsPage />} />
                <Route path="pending" element={<PendingPage />} />
                <Route path="expiring" element={<ExpiringPage />} />
                <Route path="notifications" element={<NotificationsPage />} />
                <Route path="activity" element={<ActivityPage />} />
                <Route path="reports" element={<ReportsPage />} />
                <Route path="settings" element={<SettingsPage />} />
                <Route path="*" element={<NotFoundPage />} />
              </Route>
              <Route
                path="/org"
                element={
                  <RequireRole role="org_admin">
                    <OrgLayout />
                  </RequireRole>
                }
              >
                <Route index element={<OrgOverviewPage />} />
                <Route path="teachers" element={<OrgTeachersPage />} />
                <Route path="classes" element={<OrgClassesPage />} />
                <Route path="classes/:classId" element={<OrgClassDetailPage />} />
                <Route path="students" element={<OrgStudentsPage />} />
                <Route path="activity" element={<OrgActivityPage />} />
                <Route path="reports" element={<OrgReportsPage />} />
                <Route path="settings" element={<OrgSettingsPage />} />
                <Route path="*" element={<NotFoundPage />} />
              </Route>
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
