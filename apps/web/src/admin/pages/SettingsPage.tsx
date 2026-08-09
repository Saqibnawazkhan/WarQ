import { DEFAULT_GRADE_SCALE, EXPIRING_SOON_DAYS, SUBSCRIPTION_PLANS, planLabel } from '@warq/core';
import { color, tint } from '@warq/tokens';

import { useSession } from '../../auth/session-context.ts';
import { Card } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';

/**
 * Platform defaults, shown as facts rather than as forms.
 *
 * Everything here is currently set in code and enforced by the database, which
 * is the honest thing to display. Making them editable is a real change with
 * real consequences — an editable grade scale needs revalidation of every
 * existing grade — so it waits until it is actually wanted.
 */
export function SettingsPage() {
  const { session } = useSession();

  return (
    <div className="flex flex-col gap-4">
      <PageHeading title="Settings" subtitle="Platform defaults and your own account" />

      <Card title="Your account">
        <dl className="flex flex-col divide-y divide-line-subtle">
          <Row label="Name" value={session?.profile.full_name ?? '—'} />
          <Row label="Email" value={session?.profile.email ?? '—'} />
          <Row label="Role" value="Main Admin" />
          <Row label="Platforms" value="Web only — the mobile app has no administrator surface" />
        </dl>
      </Card>

      <Card title="Grade scale">
        <p className="text-[12.5px] text-ink-muted">
          The platform default. An organization that grades differently can set its own; this is
          what applies until they do.
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

      <Card title="Plans">
        <dl className="flex flex-col divide-y divide-line-subtle">
          {SUBSCRIPTION_PLANS.map((plan) => (
            <Row
              key={plan}
              label={planLabel(plan)}
              value={
                plan === 'permanent'
                  ? 'No expiry'
                  : plan === 'yearly'
                    ? 'Renews one year from the current end date'
                    : 'Renews one month from the current end date'
              }
            />
          ))}
        </dl>
        <p className="mt-3 text-[12px] text-ink-muted">
          Pricing is stored per subscription but no payment gateway is connected. Accounts are
          activated by hand, as designed.
        </p>
      </Card>

      <Card title="Expiry">
        <dl className="flex flex-col divide-y divide-line-subtle">
          <Row label="Expiring soon window" value={`${EXPIRING_SOON_DAYS} days`} />
          <Row
            label="How status is decided"
            value="Derived from the end date on every read, never stored"
          />
        </dl>
        <p className="mt-3 text-[12px] leading-relaxed text-ink-muted">
          Because status is computed rather than saved, a missed scheduled job can delay a reminder
          but can never leave an expired account with access it should have lost.
        </p>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-6 py-2.5">
      <dt className="shrink-0 text-[13px] font-semibold text-ink-muted">{label}</dt>
      <dd className="text-right text-[13px] font-bold text-ink">{value}</dd>
    </div>
  );
}
