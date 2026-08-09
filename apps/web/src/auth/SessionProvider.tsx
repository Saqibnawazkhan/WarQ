import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';

import { getSession, signOut as endSession, type WarqSession } from '@warq/data';

import { supabase } from '../lib/supabase.ts';
import { SessionContext, type SessionState } from './session-context.ts';

/**
 * Holds the signed-in user for the whole app.
 *
 * Everything is driven by `onAuthStateChange`, including the first load:
 * Supabase emits `INITIAL_SESSION` as soon as it has restored (or failed to
 * restore) a session from storage. Reading it from the subscription rather than
 * with a separate `getSession()` call keeps this a subscription to an external
 * system, which is what an effect is for — and it means one code path handles
 * first load, sign-in, sign-out and another tab signing out.
 *
 * `loading` stays true until that first event arrives. Without it a returning
 * user would see the login screen flash before being redirected.
 */
export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<WarqSession | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      setSession(await getSession(supabase));
    } catch {
      // A token that no longer maps to a profile — a deleted account, say.
      // Clear it rather than leaving the app half signed in.
      await endSession(supabase);
      setSession(null);
    }
  }, []);

  useEffect(() => {
    const { data } = supabase.auth.onAuthStateChange((event, authSession) => {
      if (event === 'SIGNED_OUT' || !authSession) {
        setSession(null);
        setLoading(false);
        return;
      }

      if (event === 'INITIAL_SESSION' || event === 'SIGNED_IN' || event === 'USER_UPDATED') {
        void load().finally(() => setLoading(false));
      }
    });

    return () => data.subscription.unsubscribe();
  }, [load]);

  const value = useMemo<SessionState>(
    () => ({
      session,
      loading,
      refresh: load,
      signOut: async () => {
        await endSession(supabase);
        setSession(null);
      },
    }),
    [session, loading, load],
  );

  return <SessionContext value={value}>{children}</SessionContext>;
}
