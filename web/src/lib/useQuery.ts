import { useCallback, useEffect, useState } from 'react'
import { errorMessage } from './supabase'

interface QueryState<T> {
  data: T | null
  loading: boolean
  error: string | null
  reload: () => void
}

/// Runs an async read and tracks the three states every screen here needs.
///
/// Deliberately small: this dashboard is read-mostly and each page asks for one
/// or two things, so a caching library would be more machinery than the problem
/// deserves. Writes call reload() to pull fresh rows rather than patching a
/// cache, which keeps what is on screen the same as what is in the database.
export function useQuery<T>(run: () => Promise<T>, deps: unknown[] = []): QueryState<T> {
  const [data, setData] = useState<T | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [nonce, setNonce] = useState(0)

  // eslint-disable-next-line react-hooks/exhaustive-deps
  const callback = useCallback(run, deps)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(null)

    callback()
      .then((result) => {
        if (!cancelled) setData(result)
      })
      .catch((caught: unknown) => {
        if (!cancelled) setError(errorMessage(caught))
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })

    return () => {
      cancelled = true
    }
  }, [callback, nonce])

  return { data, loading, error, reload: () => setNonce((n) => n + 1) }
}
