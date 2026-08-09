// Supabase needs a URL implementation React Native does not ship.
// Imported first, before the client is constructed.
import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';
import { createBrowserClient } from '@warq/data';

interface WarqExtra {
  readonly supabaseUrl?: string;
  readonly supabasePublishableKey?: string;
}

/**
 * Configuration comes from `app.config.ts`, which loads the repository-root
 * `.env` at build time. Reading it from `extra` rather than `process.env` is
 * what lets one `.env` serve the web app, the worker and this app — Expo would
 * otherwise only look inside `apps/mobile`.
 *
 * The secret key is deliberately absent from every path here: it has no
 * `EXPO_PUBLIC_` prefix and is never placed in `extra`, so it cannot reach a phone.
 */
const extra = (Constants.expoConfig?.extra ?? {}) as WarqExtra;

const url = extra.supabaseUrl ?? '';
const publishableKey = extra.supabasePublishableKey ?? '';

if (!url || !publishableKey) {
  throw new Error(
    'Missing Supabase configuration. Fill EXPO_PUBLIC_SUPABASE_URL and ' +
      'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY in the repository-root .env, then restart Expo — ' +
      'configuration is read when the bundle is built, not at runtime.',
  );
}

/**
 * The one client for the app.
 *
 * The session persists in AsyncStorage so a teacher signs in once rather than
 * every morning, and the platform header lets the database refuse a Main Admin
 * here — the access matrix applied at the edge, not only in the router.
 */
export const supabase = createBrowserClient({ url, publishableKey }, 'mobile', AsyncStorage);

/** Shown on the account screen so a bug report can name the build it came from. */
export const appVersion = Constants.expoConfig?.version ?? '0.0.0';
