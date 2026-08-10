import { createClient } from '@supabase/supabase-js'

/// Connection details for the shared Warq database.
///
/// The publishable (anon) key is designed to be public: it identifies the
/// project, not the caller. Every table is behind row-level security that
/// resolves the real user from their signed-in session, and this dashboard's
/// data is additionally gated on is_main_admin(). It ships in the JavaScript
/// bundle whatever we do.
///
/// The service-role key bypasses row-level security entirely and must never
/// appear here.
const url = import.meta.env.VITE_SUPABASE_URL ?? 'https://befjsognpcqxuhqfmlpe.supabase.co'

const publishableKey =
  import.meta.env.VITE_SUPABASE_ANON_KEY ??
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlZmpzb2ducGNxeHVocWZtbHBlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzMDA3NDMsImV4cCI6MjEwMTg3Njc0M30.NKVIpWtSaKUb5kSS9FHKyhvm9-rPpCXwjXRJxCUeYEU'

export const supabase = createClient(url, publishableKey)

/// Turns whatever the client threw into a sentence worth showing someone.
///
/// The database functions raise messages written to be read
/// ("A platform administrator already exists."), so those are passed through
/// rather than replaced.
export function errorMessage(error: unknown): string {
  if (error === null || error === undefined) return 'Something went wrong.'

  if (typeof error === 'object' && 'code' in error && 'message' in error) {
    const code = String((error as { code: unknown }).code ?? '')
    const message = String((error as { message: unknown }).message ?? '')

    switch (code) {
      case 'P0001':
        return message
      case '42501':
        return 'You are not allowed to do that.'
      case 'PGRST116':
        return 'That record could not be found.'
      case 'PGRST202':
      case 'PGRST204':
        return 'This dashboard is out of step with the database. Reload the page.'
      default:
        return message || 'Something went wrong.'
    }
  }

  if (error instanceof Error) return error.message
  return String(error)
}
