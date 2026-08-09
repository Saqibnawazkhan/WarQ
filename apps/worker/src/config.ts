/**
 * Worker configuration.
 *
 * Read once at start-up and validated immediately: a missing key should stop
 * the process with a clear message, not surface as a confusing failure at
 * three in the morning when the reminder job runs.
 */

export interface WorkerConfig {
  readonly port: number;
  readonly host: string;
  readonly environment: 'development' | 'production' | 'test';
  /** Set from M7, when the worker starts writing to Supabase. */
  readonly supabaseUrl: string | null;
  /**
   * The `sb_secret_…` key. Bypasses row-level security, so it lives here and
   * nowhere else — never in the web app, never in the mobile app.
   */
  readonly supabaseSecretKey: string | null;
}

function readPort(raw: string | undefined, fallback: number): number {
  if (raw === undefined || raw === '') return fallback;
  const port = Number(raw);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`PORT must be a number between 1 and 65535, got "${raw}".`);
  }
  return port;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): WorkerConfig {
  const environment =
    env.NODE_ENV === 'production' ? 'production' : env.NODE_ENV === 'test' ? 'test' : 'development';

  return {
    // Railway injects PORT; 8080 is the local default.
    port: readPort(env.PORT, 8080),
    host: env.HOST ?? '0.0.0.0',
    environment,
    supabaseUrl: env.SUPABASE_URL ?? null,
    supabaseSecretKey: env.SUPABASE_SECRET_KEY ?? null,
  };
}
