import { formatCalendarDate, initials, pluralize } from '@warq/core';

import { Card, EmptyState } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';
import { SubscriptionActions } from '../components/SubscriptionActions.tsx';
import { usePendingRequests } from '../queries.ts';

/**
 * The approvals queue, oldest first.
 *
 * Deliberately a list of cards rather than a table: each row is a decision with
 * context behind it, not a value to scan down a column.
 */
export function PendingPage() {
  const pending = usePendingRequests();
  const rows = pending.data ?? [];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Pending Requests"
        subtitle={
          rows.length === 0
            ? 'Nothing waiting'
            : `${pluralize(rows.length, 'account')} waiting for approval, oldest first`
        }
      />

      {pending.isLoading ? (
        <Card>
          <p className="py-6 text-center text-[13px] text-ink-muted">Loading…</p>
        </Card>
      ) : rows.length === 0 ? (
        <Card padded={false}>
          <EmptyState
            title="All caught up"
            body="New organizations and individual teachers land here the moment they register. Nothing is waiting."
          />
        </Card>
      ) : (
        <ul className="flex flex-col gap-2.5">
          {rows.map((request) => (
            <li key={request.subscription_id}>
              <Card>
                <div className="flex flex-wrap items-start gap-4">
                  <div className="flex size-11 shrink-0 items-center justify-center rounded-tile bg-[#D9770614] font-display text-[14px] font-bold text-pending">
                    {initials(request.subject_name ?? '?')}
                  </div>

                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-baseline gap-2">
                      <h2 className="text-[15px] font-bold">{request.subject_name}</h2>
                      <span className="rounded-xs bg-sunken px-2 py-0.5 text-[11px] font-bold text-ink-muted">
                        {request.kind === 'organization' ? 'Organization' : 'Individual teacher'}
                      </span>
                    </div>

                    <dl className="mt-2 grid gap-x-6 gap-y-1 text-[12.5px] sm:grid-cols-2">
                      <Fact label="Email" value={request.subject_email} />
                      {request.city && <Fact label="City" value={request.city} />}
                      {request.phone && <Fact label="Phone" value={request.phone} />}
                      <Fact label="Plan requested" value={request.plan} />
                      {request.kind === 'organization' && (
                        <Fact label="Teachers" value={String(request.teacher_count ?? 0)} />
                      )}
                      <Fact
                        label="Requested"
                        value={formatCalendarDate(request.requested_at?.slice(0, 10) ?? null)}
                      />
                    </dl>
                  </div>

                  <SubscriptionActions
                    subscriptionId={request.subscription_id}
                    status="pending"
                    plan={request.plan}
                    subjectName={request.subject_name ?? 'Account'}
                    size="md"
                  />
                </div>
              </Card>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function Fact({ label, value }: { label: string; value: string | null }) {
  return (
    <div className="flex gap-2">
      <dt className="text-ink-muted">{label}</dt>
      <dd className="truncate font-semibold text-ink-base">{value ?? '—'}</dd>
    </div>
  );
}
