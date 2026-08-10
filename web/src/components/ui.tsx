import type { ReactNode } from 'react'
import type { AccountStatus, SubscriptionStatus } from '../lib/types'

/// Small presentational pieces shared by every page.

export function Pill({ tone, children }: { tone: string; children: ReactNode }) {
  return <span className={`pill pill-${tone}`}>{children}</span>
}

/// The colour of a subscription status is the whole point of these tables: an
/// administrator scanning the list should see trouble without reading.
export function SubscriptionPill({ status }: { status: SubscriptionStatus | null }) {
  if (status === null) return <Pill tone="grey">None</Pill>

  const tone =
    status === 'active'
      ? 'green'
      : status === 'expiring_soon'
        ? 'amber'
        : status === 'pending'
          ? 'blue'
          : 'red'

  const label = status === 'expiring_soon' ? 'Expiring soon' : capitalise(status)
  return <Pill tone={tone}>{label}</Pill>
}

export function AccountPill({ status }: { status: AccountStatus }) {
  const tone =
    status === 'active'
      ? 'green'
      : status === 'pending'
        ? 'blue'
        : 'red'
  return <Pill tone={tone}>{capitalise(status)}</Pill>
}

export function Card({
  title,
  action,
  children,
}: {
  title?: string
  action?: ReactNode
  children: ReactNode
}) {
  return (
    <section className="card">
      {(title !== undefined || action !== undefined) && (
        <header className="card-head">
          {title !== undefined ? <h2>{title}</h2> : <span />}
          {action}
        </header>
      )}
      {children}
    </section>
  )
}

export function Stat({
  label,
  value,
  note,
}: {
  label: string
  value: number | string
  // Explicitly `| undefined`: exactOptionalPropertyTypes is on, and callers
  // compute this from data that may not have loaded yet.
  note?: string | undefined
}) {
  return (
    <div className="stat">
      <div className="stat-label">{label}</div>
      <div className="stat-value num">{value}</div>
      {note !== undefined && <div className="stat-note">{note}</div>}
    </div>
  )
}

export function ErrorNotice({ message }: { message: string }) {
  return <div className="notice notice-error">{message}</div>
}

export function Empty({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="empty">
      <div className="empty-title">{title}</div>
      {hint !== undefined && <div>{hint}</div>}
    </div>
  )
}

export function Loading({ what }: { what: string }) {
  return <div className="skeleton">Loading {what}…</div>
}

/// Wraps the three states every table on this dashboard can be in, so no page
/// renders an empty table that is actually a failed request.
export function QueryBoundary<T>({
  state,
  what,
  emptyTitle,
  emptyHint,
  isEmpty,
  children,
}: {
  state: { data: T | null; loading: boolean; error: string | null }
  what: string
  emptyTitle: string
  emptyHint?: string
  isEmpty?: (data: T) => boolean
  children: (data: T) => ReactNode
}) {
  if (state.error !== null) return <ErrorNotice message={state.error} />
  if (state.loading && state.data === null) return <Loading what={what} />
  if (state.data === null) return <Empty title={emptyTitle} {...(emptyHint !== undefined && { hint: emptyHint })} />
  if (isEmpty?.(state.data) === true) {
    return <Empty title={emptyTitle} {...(emptyHint !== undefined && { hint: emptyHint })} />
  }
  return <>{children(state.data)}</>
}

export function Modal({
  title,
  description,
  children,
  onClose,
}: {
  title: string
  description?: string
  children: ReactNode
  onClose: () => void
}) {
  return (
    <div
      className="modal-backdrop"
      onClick={onClose}
      role="presentation"
    >
      <div className="modal" onClick={(event) => event.stopPropagation()} role="dialog" aria-modal="true">
        <h2>{title}</h2>
        {description !== undefined && <p className="subtle">{description}</p>}
        {children}
      </div>
    </div>
  )
}

export function capitalise(value: string): string {
  const spaced = value.replace(/_/g, ' ')
  return spaced.charAt(0).toUpperCase() + spaced.slice(1)
}

/// Dates are shown as a plain day. These are subscription and sign-up dates,
/// where the hour is noise.
export function formatDate(value: string | null): string {
  if (value === null) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return date.toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' })
}

export function formatDateTime(value: string | null): string {
  if (value === null) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return date.toLocaleString(undefined, {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  })
}

/// "in 9 days" is what decides whether an administrator acts today, so it is
/// spelled out rather than left as a date to subtract.
export function formatRemaining(days: number | null): string {
  if (days === null) return 'No end date'
  if (days < 0) return `Expired ${Math.abs(days)} days ago`
  if (days === 0) return 'Expires today'
  if (days === 1) return 'Expires tomorrow'
  return `${days} days left`
}
