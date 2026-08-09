/**
 * Supabase client factories.
 *
 * Two of them, deliberately. A browser or phone gets the publishable key and is
 * subject to every row-level security policy. The worker gets the secret key and
 * is subject to none — which is exactly why the two are separate functions with
 * separate names, rather than one function with a key argument that could be
 * passed the wrong thing.
 */

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

import type { Database } from './database.types.js';

export type WarqClient = SupabaseClient<Database>;

export interface ClientConfig {
  readonly url: string;
  readonly publishableKey: string;
}

/**
 * The client for a browser or a phone.
 *
 * `platform` is sent on every request so the session guard can refuse a Main
 * Admin signing in on mobile — the rule from the access matrix, applied at the
 * edge rather than only in the router.
 */
export function createBrowserClient(
  config: ClientConfig,
  platform: 'web' | 'mobile',
  storage?: unknown,
): WarqClient {
  assertConfig(config);

  return createClient<Database>(config.url, config.publishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      // Web reads the session back from the URL after a password reset or an
      // invitation link; native handles that itself through a deep link.
      detectSessionInUrl: platform === 'web',
      ...(storage ? { storage: storage as never } : {}),
    },
    global: {
      headers: {
        'x-client-platform': platform,
      },
    },
    db: { schema: 'public' },
  });
}

/**
 * The worker's client. Bypasses row-level security entirely.
 *
 * Only ever constructed in `apps/worker`. If this function is imported anywhere
 * a user's browser can reach, the secret key has already leaked.
 */
export function createServiceClient(url: string, secretKey: string): WarqClient {
  if (!url || !secretKey) {
    throw new Error(
      'The worker needs SUPABASE_URL and SUPABASE_SECRET_KEY. Copy .env.example to .env and fill them in.',
    );
  }

  return createClient<Database>(url, secretKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
    global: {
      headers: { 'x-client-platform': 'worker' },
    },
  });
}

function assertConfig(config: ClientConfig): void {
  if (!config.url) {
    throw new Error(
      'Missing Supabase URL. Set VITE_SUPABASE_URL (web) or EXPO_PUBLIC_SUPABASE_URL (mobile).',
    );
  }

  if (!config.publishableKey) {
    throw new Error(
      'Missing Supabase publishable key. Set VITE_SUPABASE_PUBLISHABLE_KEY (web) or EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY (mobile).',
    );
  }

  if (config.publishableKey.startsWith('sb_secret_')) {
    // Worth failing loudly: a secret key in a client bundle is a full data breach,
    // and it would otherwise work perfectly and silently.
    throw new Error(
      'A secret key was passed to the browser client. Use the sb_publishable_ key; the secret key belongs only in the worker.',
    );
  }
}
