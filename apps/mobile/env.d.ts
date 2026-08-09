/**
 * Expo inlines only `EXPO_PUBLIC_`-prefixed variables into the bundle. Declaring
 * them keeps `process.env` typed rather than `any` — which matters here, because
 * an untyped read of a missing key produces `undefined` and a confusing runtime
 * failure instead of a compile error.
 *
 * The Supabase secret key is deliberately absent: it has no `EXPO_PUBLIC_`
 * prefix precisely so it can never reach a phone.
 */
declare namespace NodeJS {
  interface ProcessEnv {
    readonly EXPO_PUBLIC_SUPABASE_URL?: string;
    readonly EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY?: string;
  }
}
