import { createBrowserClient } from '@warq/data';

/**
 * The one Supabase client for the web app.
 *
 * Built at module load so a missing environment variable fails immediately and
 * loudly, rather than as a confusing error on the first query.
 */
export const supabase = createBrowserClient(
  {
    url: import.meta.env.VITE_SUPABASE_URL,
    publishableKey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY,
  },
  'web',
);
