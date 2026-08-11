import { isValidElement, type ReactNode } from 'react'
import { AlertCircle, Inbox, X, type LucideIcon } from 'lucide-react'
import type { AccountStatus, SubscriptionStatus } from '../lib/types'

/// Small presentational pieces shared by every page.

/// An icon may arrive either as the lucide component (`icon={Users}`) or
/// already rendered (`icon={<Users size={20} />}`). Accepting both means a
/// screen cannot get it wrong, and passing the bare component lets this file
/// keep every tile on the same size.
type IconLike = LucideIcon | ReactNode

function drawIcon(icon: IconLike, size: number): ReactNode {
  if (isValidElement(icon)) return icon
  // Lucide icons are forwardRef objects rather than plain functions, so the
  // component form is anything else React can use as an element type. The
  // `$$typeof` test keeps a stray array or string from being called as one.
  if (
    typeof icon === 'function' ||
    (typeof icon === 'object' && icon !== null && '$$typeof' in icon)
  ) {
    const Icon = icon as LucideIcon
    return <Icon size={size} />
  }
  return null
}

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
  icon,
}: {
  label: string
  value: number | string
  // Explicitly `| undefined`: exactOptionalPropertyTypes is on, and callers
  // compute this from data that may not have loaded yet.
  note?: string | undefined
  icon?: IconLike | undefined
}) {
  const tile = drawIcon(icon, 20)
  return (
    <div className="stat">
      {tile !== null && <div className="stat-icon">{tile}</div>}
      <div className="stat-label">{label}</div>
      <div className="stat-value num">{value}</div>
      {note !== undefined && <div className="stat-note">{note}</div>}
    </div>
  )
}

export function ErrorNotice({ message }: { message: string }) {
  return (
    <div className="notice notice-error">
      <AlertCircle size={18} />
      <span>{message}</span>
    </div>
  )
}

export function Empty({
  title,
  hint,
  icon,
}: {
  title: string
  hint?: string
  icon?: IconLike | undefined
}) {
  // The tile is always drawn, so it falls back rather than showing an empty
  // box when a screen passes a condition that came out false.
  const tile = drawIcon(icon, 20) ?? <Inbox size={20} />
  return (
    <div className="empty">
      <div className="empty-icon">{tile}</div>
      <div className="empty-title">{title}</div>
      {hint !== undefined && <div>{hint}</div>}
    </div>
  )
}

/// Bars in the shape of the rows that are coming, so the card keeps its size
/// and nothing on the page jumps when the data lands.
export function SkeletonTable({
  rows = 5,
  label = 'Loading…',
}: {
  rows?: number | undefined
  label?: string | undefined
}) {
  return (
    <div className="card-body" role="status" aria-label={label} style={{ display: 'grid', gap: 14 }}>
      {Array.from({ length: rows }, (_unused, index) => (
        <div key={index} className="skeleton-row" />
      ))}
    </div>
  )
}

export function Loading({ what }: { what: string }) {
  return <SkeletonTable label={`Loading ${what}…`} />
}

/// Wraps the three states every table on this dashboard can be in, so no page
/// renders an empty table that is actually a failed request.
export function QueryBoundary<T>({
  state,
  what,
  emptyTitle,
  emptyHint,
  emptyIcon,
  icon,
  isEmpty,
  children,
}: {
  state: { data: T | null; loading: boolean; error: string | null }
  what: string
  emptyTitle: string
  emptyHint?: string
  // The icon for the empty state. `icon` is the same thing under the shorter
  // name some screens reach for; both spell one prop so no page has to know.
  emptyIcon?: IconLike | undefined
  icon?: IconLike | undefined
  isEmpty?: (data: T) => boolean
  children: (data: T) => ReactNode
}) {
  const empty = (
    <Empty
      title={emptyTitle}
      {...(emptyHint !== undefined && { hint: emptyHint })}
      icon={emptyIcon ?? icon}
    />
  )

  if (state.error !== null) return <ErrorNotice message={state.error} />
  if (state.loading && state.data === null) return <SkeletonTable label={`Loading ${what}…`} />
  if (state.data === null) return empty
  if (isEmpty?.(state.data) === true) return empty
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
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
          <h2 style={{ flex: 1 }}>{title}</h2>
          {/* The corner button is the way out people look for first; the
              backdrop already closes, so it does exactly the same thing. */}
          <button
            type="button"
            className="btn-quiet"
            onClick={onClose}
            aria-label="Close"
            style={{ flex: 'none', padding: 6, borderRadius: 999 }}
          >
            <X size={16} />
          </button>
        </div>
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
