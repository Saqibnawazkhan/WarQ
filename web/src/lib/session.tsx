import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { supabase, errorMessage } from './supabase'
import type { Me, Profile, Organization } from './types'

interface SessionValue {
  user: Profile | null
  organization: Organization | null
  hasAccess: boolean
  loading: boolean
  error: string | null
  signIn: (email: string, password: string) => Promise<void>
  signOut: () => Promise<void>
  refresh: () => Promise<void>
}

const SessionContext = createContext<SessionValue | null>(null)

/// Holds whoever is signed in, whatever their role.
///
/// One sign-in for all three: a teacher, an organization admin and the platform
/// administrator land in different parts of the app, decided by the role on
/// their profile rather than by which address they typed. Row-level security
/// enforces the same split in the database, so the routing below is about
/// showing people the right thing, not about keeping them out of the rest.
///
/// hasAccess is carried separately from the role because it answers a different
/// question: a teacher in good standing whose organization stopped paying is
/// still a teacher, and still cannot work.
export function SessionProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<Profile | null>(null)
  const [organization, setOrganization] = useState<Organization | null>(null)
  const [hasAccess, setHasAccess] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  async function resolve(): Promise<void> {
    const { data, error: rpcError } = await supabase.rpc('me')
    if (rpcError) throw rpcError

    const me = data as Me | null
    setUser(me?.profile ?? null)
    setOrganization(me?.organization ?? null)
    setHasAccess(me?.has_access ?? false)
  }

  useEffect(() => {
    let cancelled = false

    async function restore() {
      try {
        const { data } = await supabase.auth.getSession()
        if (data.session === null) {
          if (!cancelled) setUser(null)
          return
        }
        if (!cancelled) await resolve()
      } catch {
        // A token that no longer resolves to a profile is worse than no token:
        // it would leave the app looking signed in with nothing behind it.
        await supabase.auth.signOut()
        if (!cancelled) setUser(null)
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
      user,
      organization,
      hasAccess,
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
          await resolve()
        } catch (caught) {
          setUser(null)
          setError(errorMessage(caught))
        } finally {
          setLoading(false)
        }
      },
      async signOut() {
        await supabase.auth.signOut()
        setUser(null)
        setOrganization(null)
        setHasAccess(false)
        setError(null)
      },
      async refresh() {
        setLoading(true)
        try {
          await resolve()
        } catch (caught) {
          setError(errorMessage(caught))
        } finally {
          setLoading(false)
        }
      },
    }),
    [user, organization, hasAccess, loading, error],
  )

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
}

export function useSession(): SessionValue {
  const value = useContext(SessionContext)
  if (value === null) throw new Error('useSession must be used inside a SessionProvider.')
  return value
}

/// The signed-in user, for screens that cannot render without one. Only called
/// from inside an authenticated shell.
export function useUser(): Profile {
  const { user } = useSession()
  if (user === null) throw new Error('This screen requires a signed-in user.')
  return user
}
