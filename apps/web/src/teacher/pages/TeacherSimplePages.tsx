import { DEFAULT_GRADE_SCALE, formatCalendarDate, planLabel, roleLabel } from '@warq/core';

import { color, tint } from '@warq/tokens';

import { useSession } from '../../auth/session-context.ts';
import { Card, EmptyState, StatusPill } from '../../ui/index.ts';
import { PageHeading } from '../../admin/components/PageHeading.tsx';

export function TeacherReportsPage() {
  return (
    <div className="flex flex-col gap-4">
      <PageHeading title="Reports" subtitle="Printable records for a class or a student" />

      <Card padded={false}>
        <EmptyState
          title="Nothing generated yet"
          body="Rendering runs on the worker, which lands in M8. Everything it needs — registers, marks, grades — is already being recorded."
        />
      </Card>

      <div className="grid gap-3 sm:grid-cols-2">
        <Card>
          <h2 className="font-display text-[14px] font-bold">Class report</h2>
          <p className="mt-1.5 text-[13px] leading-relaxed text-ink-base">
            A register and mark sheet for one class, ready to print or hand in.
          </p>
        </Card>
        <Card>
          <h2 className="font-display text-[14px] font-bold">Student report</h2>
          <p className="mt-1.5 text-[13px] leading-relaxed text-ink-base">
            Attendance, every assessment and the overall grade for one student — the thing parents
            actually ask for.
          </p>
        </Card>
      </div>
    </div>
  );
}

export function TeacherSettingsPage() {
  const { session } = useSession();
  if (!session) return null;

  const { profile, organization, subscription } = session;

  return (
    <div className="flex flex-col gap-4">
      <PageHeading title="Settings" />

      <Card title="Your account">
        <dl className="flex flex-col divide-y divide-line-subtle">
          <Row label="Name" value={profile.full_name} />
          <Row label="Email" value={profile.email} />
          <Row label="Role" value={roleLabel('teacher')} />
          <Row
            label="Organization"
            value={organization?.name ?? 'Independent — you hold your own subscription'}
          />
          <Row label="Platforms" value="Web and mobile" />
        </dl>
      </Card>

      {subscription && (
        <Card title="Subscription">
          <dl className="flex flex-col divide-y divide-line-subtle">
            <Row label="Plan" value={subscription.plan ? planLabel(subscription.plan) : '—'} />
            <Row
              label="Status"
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
          </dl>

          <p className="mt-3 text-[12px] leading-relaxed text-ink-muted">
            {organization
              ? 'Your organization holds this subscription. Speak to your organization admin about renewal.'
              : 'Warq manages your plan. Get in touch to renew or change it.'}
          </p>
        </Card>
      )}

      <Card title="Grade scale">
        <p className="text-[12.5px] text-ink-muted">
          What a percentage converts to. Marks entry shows these live as you type.
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
