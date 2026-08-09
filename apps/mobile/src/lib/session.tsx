import {
  createContext,
  use,
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';

import { getSession, signOut as endSession, type WarqSession } from '@warq/data';

import { supabase } from './supabase';

interface SessionState {
  readonly session: WarqSession | null;
  readonly loading: boolean;
  readonly refresh: () => Promise<void>;
  readonly signOut: () => Promise<void>;
}

const SessionContext = createContext<SessionState | null>(null);

export function useSession(): SessionState {
  const state = use(SessionContext);
  if (!state) throw new Error('useSession must be called inside <SessionProvider>.');
  return state;
}

/**
 * Holds the signed-in teacher.
 *
 * Driven entirely by `onAuthStateChange`, including first load: Supabase emits
 * `INITIAL_SESSION` once it has read AsyncStorage. One code path then covers
 * cold start, sign-in, sign-out and a token refresh — and `loading` stays true
 * until that first event, so a returning teacher never sees the sign-in screen
 * flash before their classes appear.
 */
export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<WarqSession | null>(null);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      setSession(await getSession(supabase));
    } catch {
      // A stored token that no longer maps to a profile. Clear it rather than
      // leaving the app half signed in.
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
