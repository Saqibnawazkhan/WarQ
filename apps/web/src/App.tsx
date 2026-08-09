import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { RequireRole } from './auth/RequireRole.tsx';
import { SessionProvider } from './auth/SessionProvider.tsx';
import { DashboardPage } from './routes/DashboardPage.tsx';
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
        <BrowserRouter>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/design" element={<DesignSystemPage />} />

            <Route path="/login" element={<LoginPage />} />
            <Route path="/signup" element={<SignUpPage />} />
            <Route path="/forgot-password" element={<ForgotPasswordPage />} />

            <Route
              path="/admin/*"
              element={
                <RequireRole role="main_admin">
                  <DashboardPage milestone="M2" title="Platform overview" />
                </RequireRole>
              }
            />
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
      </SessionProvider>
    </QueryClientProvider>
  );
}
