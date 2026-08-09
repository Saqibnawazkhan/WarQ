// Supabase needs a URL implementation React Native does not ship.
// Imported first, before the client is constructed.
import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import Constants from 'expo-constants';
import { createBrowserClient } from '@warq/data';

/**
 * Expo exposes only `EXPO_PUBLIC_`-prefixed variables to the bundle, which is
 * why the secret key has no prefix: it cannot reach a phone by accident.
 */
const url = process.env.EXPO_PUBLIC_SUPABASE_URL ?? '';
const publishableKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '';

if (!url || !publishableKey) {
  throw new Error(
    'Missing Supabase configuration. Set EXPO_PUBLIC_SUPABASE_URL and ' +
      'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY in the repository .env, then restart Expo — ' +
      'environment variables are read at bundle time, not at runtime.',
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

/** Shown on the settings screen so a bug report can name the build it came from. */
export const appVersion = Constants.expoConfig?.version ?? '0.0.0';
