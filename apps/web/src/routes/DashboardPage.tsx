import { formatCalendarDate, planLabel, roleLabel, statusLabel } from '@warq/core';

import { useSession } from '../auth/session-context.ts';
import { MILESTONES } from '../content/milestones.ts';
import { Button, Card, StatusPill } from '../ui/index.ts';

interface DashboardPageProps {
  /** The milestone that replaces this placeholder with the real dashboard. */
  readonly milestone: string;
  readonly title: string;
}

/**
 * The signed-in placeholder.
 *
 * It is not the dashboard — that is M2 to M4 — but it is not a blank page
 * either. It shows exactly what the database returned for this account, which
 * is what proves authentication, tenant scoping and the subscription gate are
 * all working before a single chart is drawn.
 */
export function DashboardPage({ milestone, title }: DashboardPageProps) {
  const { session, signOut } = useSession();
  const detail = MILESTONES.find((entry) => entry.code === milestone);

  if (!session) return null;

  const { profile, organization, subscription, hasAccess } = session;

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6 px-6 py-12">
      <header className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="font-mono text-[11px] font-bold tracking-[0.1em] text-ink-muted uppercase">
            {roleLabel(profile.role)}
          </p>
          <h1 className="mt-1 font-display text-2xl font-bold tracking-tight">{title}</h1>
          <p className="mt-1 text-[13.5px] text-ink-muted">
            {profile.full_name} · {profile.email}
          </p>
        </div>

        <Button variant="secondary" size="sm" onClick={() => void signOut()}>
          Sign out
        </Button>
      </header>

      <Card title="Your account">
        <dl className="flex flex-col divide-y divide-line-subtle">
          <Row label="Role" value={roleLabel(profile.role)} />
          <Row label="Account status" value={capitalise(profile.status)} />
          <Row label="Organization" value={organization?.name ?? 'None — independent'} />
          {organization && <Row label="City" value={organization.city} />}

          {subscription ? (
            <>
              <Row label="Plan" value={subscription.plan ? planLabel(subscription.plan) : '—'} />
              <Row
                label="Subscription"
                value={subscription.status ? <StatusPill status={subscription.status} /> : '—'}
              />
              <Row
                label="Expires"
                value={
                  subscription.plan === 'permanent'
                    ? 'No expiry'
                    : formatCalendarDate(subscription.ends_at)
                }
              />
              {subscription.days_remaining !== null && (
                <Row label="Days remaining" value={String(subscription.days_remaining)} />
              )}
            </>
          ) : (
            <Row label="Subscription" value="None" />
          )}

          <Row
            label="Access"
            value={
              <span className={hasAccess ? 'font-bold text-active' : 'font-bold text-expired'}>
                {hasAccess ? 'Granted' : 'Blocked'}
              </span>
            }
          />
        </dl>
      </Card>

      {!hasAccess && (
        <Card>
          <h2 className="font-display text-[15px] font-bold">Waiting for approval</h2>
          <p className="mt-2 text-[13.5px] leading-relaxed text-ink-base">
            {statusLabel(subscription?.status ?? 'pending')} — Warq reviews every new account before
            activating it. You will get an email once yours is approved.
          </p>
          <p className="mt-2 text-[13px] text-ink-muted">
            Until then the database will refuse any classes, students, attendance or marks. That is
            the subscription gate working, not an error.
          </p>
        </Card>
      )}

      <Card>
        <h2 className="font-display text-[15px] font-bold">
          {milestone} · dashboard not built yet
        </h2>
        <p className="mt-2 text-[13.5px] leading-relaxed text-ink-base">
          {detail?.summary ?? 'This dashboard is planned.'}
        </p>
        <p className="mt-2 text-[13px] text-ink-muted">
          Everything above came from the database through row-level security, so sign-in, tenant
          scoping and the subscription gate are already working.
        </p>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-4 py-2.5">
      <dt className="text-[13px] font-semibold text-ink-muted">{label}</dt>
      <dd className="text-right text-[13.5px] font-bold text-ink">{value}</dd>
    </div>
  );
}

function capitalise(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
