import { DEFAULT_GRADE_SCALE, formatCalendarDate, planLabel, statusLabel } from '@warq/core';
import { color, tint } from '@warq/tokens';

import { useSession } from '../../auth/session-context.ts';
import { Card, EmptyState, StatusPill } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';

export function OrgSettingsPage() {
  const { session } = useSession();
  if (!session) return null;

  const { organization, subscription, profile } = session;

  return (
    <div className="flex flex-col gap-4">
      <PageHeading title="Settings" subtitle="Your organization and its subscription" />

      <Card title="Organization">
        <dl className="flex flex-col divide-y divide-line-subtle">
          <Row label="Name" value={organization?.name ?? '—'} />
          <Row label="City" value={organization?.city ?? '—'} />
          <Row label="Email" value={organization?.email ?? '—'} />
          <Row label="Phone" value={organization?.phone ?? '—'} />
          <Row
            label="Status"
            value={organization?.status ? capitalise(organization.status) : '—'}
          />
        </dl>
      </Card>

      <Card title="Subscription">
        {subscription ? (
          <dl className="flex flex-col divide-y divide-line-subtle">
            <Row label="Plan" value={subscription.plan ? planLabel(subscription.plan) : '—'} />
            <Row
              label="Status"
              value={subscription.status ? <StatusPill status={subscription.status} /> : '—'}
            />
            <Row label="Started" value={formatCalendarDate(subscription.starts_at)} />
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
          </dl>
        ) : (
          <EmptyState
            title="No subscription"
            body="Contact Warq to set your organization up with a plan."
          />
        )}

        <p className="mt-3 text-[12px] leading-relaxed text-ink-muted">
          {subscription?.status === 'expiring_soon'
            ? `${statusLabel('expiring_soon')} — Warq will be in touch about renewal. Access continues until the end date.`
            : 'Plans are changed by Warq, not from here. Get in touch to upgrade, renew or switch plan.'}
        </p>
      </Card>

      <Card title="Grade scale">
        <p className="text-[12.5px] text-ink-muted">
          What your teachers&rsquo; marks convert to. This is the platform default; a custom scale
          for your institution is a change we can make for you.
        </p>

        <div className="mt-3.5 flex flex-wrap gap-2">
          {DEFAULT_GRADE_SCALE.map((band) => (
            <span
              key={band.grade}
              className="rounded-xs px-3 py-1.5 text-[13px] font-extrabold"
              style={{
                backgroundColor: tint(color.grade[band.grade], '1A'),
                color: color.grade[band.grade],
              }}
            >
              {band.grade} · {band.min}%+
            </span>
          ))}
        </div>
      </Card>

      <Card title="Your account">
        <dl className="flex flex-col divide-y divide-line-subtle">
          <Row label="Name" value={profile.full_name} />
          <Row label="Email" value={profile.email} />
          <Row label="Role" value="Organization Admin" />
          <Row label="Platforms" value="Web and mobile" />
        </dl>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between gap-6 py-2.5">
      <dt className="shrink-0 text-[13px] font-semibold text-ink-muted">{label}</dt>
      <dd className="text-right text-[13px] font-bold text-ink">{value}</dd>
    </div>
  );
}

function capitalise(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
