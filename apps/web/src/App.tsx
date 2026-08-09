import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Route, Routes } from 'react-router-dom';

import { ComingSoonPage } from './routes/ComingSoonPage.tsx';
import { DesignSystemPage } from './routes/DesignSystemPage.tsx';
import { HomePage } from './routes/HomePage.tsx';
import { NotFoundPage } from './routes/NotFoundPage.tsx';

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
 * Route skeleton.
 *
 * The three dashboard paths match `landingRoute()` in `@warq/core`, so sign-in
 * can route by role without a lookup table of its own.
 */
export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/design" element={<DesignSystemPage />} />
          <Route
            path="/admin/*"
            element={<ComingSoonPage milestone="M2" dashboard="Main Admin dashboard" />}
          />
          <Route
            path="/org/*"
            element={<ComingSoonPage milestone="M3" dashboard="Organization Admin dashboard" />}
          />
          <Route
            path="/teacher/*"
            element={<ComingSoonPage milestone="M4" dashboard="Teacher dashboard" />}
          />
          <Route path="*" element={<NotFoundPage />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
