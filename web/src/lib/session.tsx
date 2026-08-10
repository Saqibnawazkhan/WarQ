import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { supabase, errorMessage } from './supabase'
import type { Me } from './types'

interface SessionValue {
  admin: Me['profile']
  loading: boolean
  error: string | null
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
}

const SessionContext = createContext<SessionValue | null>(null)

/// Holds the signed-in platform administrator.
///
/// This dashboard is for one role. A teacher or an organization admin has a
/// perfectly valid account and would authenticate happily, then see nothing but
/// empty tables, because every view here is behind is_main_admin(). Refusing
/// them at the door and saying why is kinder than an empty dashboard, so the
/// role is checked after sign-in and a non-admin is signed straight back out.
export function SessionProvider({ children }: { children: ReactNode }) {
  const [admin, setAdmin] = useState<Me['profile']>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  async function resolveAdmin(): Promise<Me['profile']> {
    const { data, error: rpcError } = await supabase.rpc('me')
    if (rpcError) throw rpcError

    const profile = (data as Me | null)?.profile ?? null
    if (profile === null) return null

    if (profile.role !== 'main_admin') {
      await supabase.auth.signOut()
      throw new Error(
        'That account is not a platform administrator. Teachers and organization admins use the mobile app.',
      )
    }
    return profile
  }

  useEffect(() => {
    let cancelled = false

    async function restore() {
      try {
        const { data } = await supabase.auth.getSession()
        if (data.session === null) {
          if (!cancelled) setAdmin(null)
          return
        }
        const profile = await resolveAdmin()
        if (!cancelled) setAdmin(profile)
      } catch {
        // A token that no longer resolves to an administrator is worse than no
        // token: it would leave the dashboard looking signed in with nothing
        // behind it.
        await supabase.auth.signOut()
        if (!cancelled) setAdmin(null)
      } finally {
        if (!cancelled) setLoading(false)
      }
    }

    void restore()
    return () => {
      cancelled = true
    }
  }, [])

  const value = useMemo<SessionValue>(
    () => ({
      admin,
      loading,
      error,
      async signIn(email, password) {
        setError(null)
        setLoading(true)
        try {
          const { error: authError } = await supabase.auth.signInWithPassword({
            email: email.trim().toLowerCase(),
            password,
          })
          if (authError) throw new Error('Incorrect email or password.')
          setAdmin(await resolveAdmin())
        } catch (caught) {
          setAdmin(null)
          setError(errorMessage(caught))
        } finally {
          setLoading(false)
        }
      },
      async signOut() {
        await supabase.auth.signOut()
        setAdmin(null)
        setError(null)
      },
    }),
    [admin, loading, error],
  )

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
}

export function useSession(): SessionValue {
  const value = useContext(SessionContext)
  if (value === null) throw new Error('useSession must be used inside a SessionProvider.')
  return value
}
