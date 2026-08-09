import { config as loadEnv } from 'dotenv';
import path from 'node:path';
import type { ExpoConfig } from 'expo/config';

/**
 * Expo reads `.env` from the app directory, but Warq keeps one `.env` at the
 * repository root so the web app, the worker and this app cannot drift on to
 * different Supabase projects.
 *
 * This config runs in Node before the bundle is built, so it can reach up and
 * load that file, then pass the values through `extra`. Without it the app
 * launches and immediately throws about missing configuration — which is what
 * happened the first time.
 */
loadEnv({ path: path.resolve(__dirname, '../../.env') });

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL ?? '';
const supabasePublishableKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '';

if (!supabaseUrl || !supabasePublishableKey) {
  // Fail while a developer is watching, rather than on a teacher's phone.
  throw new Error(
    'Missing Supabase configuration. Fill EXPO_PUBLIC_SUPABASE_URL and ' +
      'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY in the repository-root .env, then restart Expo.',
  );
}

const config: ExpoConfig = {
  name: 'Warq',
  slug: 'warq',
  version: '0.1.0',
  orientation: 'portrait',
  icon: './assets/images/icon.png',
  scheme: 'warq',
  userInterfaceStyle: 'light',
  // The new architecture is the default in SDK 57 and is no longer a config
  // field, so there is nothing to declare here.
  ios: {
    supportsTablet: true,
    bundleIdentifier: 'pk.warq.app',
  },
  android: {
    package: 'pk.warq.app',
    adaptiveIcon: {
      backgroundColor: '#4338CA',
      foregroundImage: './assets/images/android-icon-foreground.png',
      monochromeImage: './assets/images/android-icon-monochrome.png',
    },
    predictiveBackGestureEnabled: false,
  },
  web: {
    output: 'static',
    favicon: './assets/images/favicon.png',
  },
  plugins: [
    'expo-router',
    [
      'expo-splash-screen',
      {
        backgroundColor: '#4338CA',
        image: './assets/images/splash-icon.png',
        imageWidth: 76,
      },
    ],
  ],
  experiments: {
    typedRoutes: true,
    reactCompiler: true,
  },
  extra: {
    supabaseUrl,
    supabasePublishableKey,
  },
};

export default config;
