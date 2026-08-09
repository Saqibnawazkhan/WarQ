/// <reference types="vite/client" />

/**
 * Only `VITE_`-prefixed variables reach the browser bundle. The secret key has
 * no prefix precisely so that Vite cannot ship it by accident.
 */
interface ImportMetaEnv {
  readonly VITE_SUPABASE_URL: string;
  readonly VITE_SUPABASE_PUBLISHABLE_KEY: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
