import { createContext, use } from 'react';

import type { WarqSession } from '@warq/data';

export interface SessionState {
  /** Null once loading has finished and nobody is signed in. */
  readonly session: WarqSession | null;
  /** True until the first session check completes. Guards against a login-screen flash. */
  readonly loading: boolean;
  readonly refresh: () => Promise<void>;
  readonly signOut: () => Promise<void>;
}

export const SessionContext = createContext<SessionState | null>(null);

export function useSession(): SessionState {
  const state = use(SessionContext);

  if (!state) {
    throw new Error('useSession must be called inside <SessionProvider>.');
  }

  return state;
}
