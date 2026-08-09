import { useNavigate } from 'react-router-dom';

import { formatCalendarDate, initials, pluralize, today } from '@warq/core';
import { color } from '@warq/tokens';

import { Button, Card, EmptyState, StatCard, useToast } from '../../ui/index.ts';
import { PageHeading } from '../components/PageHeading.tsx';
import { ActivityFeed } from '../components/ActivityFeed.tsx';
import {
  useActivity,
  useExpiringSoon,
  useOverview,
  usePendingRequests,
  useSubscriptionAction,
} from '../queries.ts';

export function OverviewPage() {
  const overview = useOverview();
  const pending = usePendingRequests();
  const expiring = useExpiringSoon();
  const activity = useActivity('all');
  const action = useSubscriptionAction();
  const toast = useToast();
  const navigate = useNavigate();

  const stats = overview.data;

  function run(
    kind: 'approve' | 'reject',
    subscriptionId: string,
    name: string,
    plan: string | null,
  ) {
    action.mutate(
      { kind, subscriptionId },
      {
        onSuccess: () =>
          toast(
            kind === 'approve'
              ? `${name} approved · ${plan ?? 'subscription'} activated`
              : `${name} rejected`,
            kind === 'approve' ? 'success' : 'neutral',
          ),
        onError: (cause) => toast(cause.message, 'danger'),
      },
    );
  }

  return (
    <div className="flex flex-col gap-5">
      <PageHeading eyebrow={formatCalendarDate(today())} title="Platform overview" />

      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          value={String(stats?.organization_count ?? 0)}
          label="Organizations"
          detail={`${stats?.active_organization_count ?? 0} active`}
          tone={color.brand.accent}
        />
        <StatCard
          value={String(stats?.individual_teacher_count ?? 0)}
          label="Individual teachers"
          detail="hold their own subscription"
        />
        <StatCard
          value={String(stats?.organization_teacher_count ?? 0)}
          label="Organization teachers"
          detail={`across ${stats?.organization_count ?? 0} organizations`}
        />
        <StatCard
          value={String(stats?.active_subscription_count ?? 0)}
          label="Active subscriptions"
          detail={`${stats?.expiring_soon_count ?? 0} expiring soon`}
          tone={color.status.active}
        />
      </div>

      <div className="grid items-start gap-3 xl:grid-cols-[1.4fr_1fr]">
        <div className="flex flex-col gap-3">
          <Card
            title="Pending approvals"
            action={
              (pending.data?.length ?? 0) > 0 ? (
                <span className="text-[12px] font-bold text-pending">
                  {pluralize(pending.data?.length ?? 0, 'waiting', 'waiting')}
                </span>
              ) : undefined
            }
          >
            {pending.isLoading ? (
              <p className="py-4 text-[13px] text-ink-muted">Loading…</p>
            ) : (pending.data?.length ?? 0) === 0 ? (
              <p className="py-2 text-[12.5px] text-ink-muted">
                All caught up — no accounts waiting for approval.
              </p>
            ) : (
              <ul className="flex flex-col gap-2.5">
                {pending.data?.map((request) => (
                  <li
                    key={request.subscription_id ?? request.subject_name}
                    className="flex flex-wrap items-center gap-3 rounded-tile border border-line-subtle px-3.5 py-3"
                  >
                    <div className="flex size-9 shrink-0 items-center justify-center rounded-control bg-[#D9770614] font-display text-[12.5px] font-bold text-pending">
                      {initials(request.subject_name ?? '?')}
                    </div>

                    <div className="min-w-0 flex-1">
                      <p className="truncate text-[13.5px] font-bold">{request.subject_name}</p>
                      <p className="truncate text-[11.5px] text-ink-muted">
                        {request.kind === 'organization' ? 'Organization' : 'Individual teacher'}
                        {request.city ? ` · ${request.city}` : ''} · {request.plan} plan
                        {request.kind === 'organization'
                          ? ` · ${pluralize(Number(request.teacher_count ?? 0), 'teacher')}`
                          : ''}
                      </p>
                    </div>

                    <div className="flex gap-1.5">
                      <Button
                        variant="danger"
                        size="sm"
                        disabled={action.isPending}
                        onClick={() =>
                          run(
                            'reject',
                            request.subscription_id ?? '',
                            request.subject_name ?? 'Account',
                            request.plan,
                          )
                        }
                      >
                        Reject
                      </Button>
                      <Button
                        variant="approve"
                        size="sm"
                        disabled={action.isPending}
                        onClick={() =>
                          run(
                            'approve',
                            request.subscription_id ?? '',
                            request.subject_name ?? 'Account',
                            request.plan,
                          )
                        }
                      >
                        Approve
                      </Button>
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </Card>

          <Card
            title="Expiring soon"
            action={
              <button
                type="button"
                onClick={() => void navigate('/admin/expiring')}
                className="cursor-pointer text-[12px] font-bold text-accent"
              >
                View all
              </button>
            }
          >
            {(expiring.data?.length ?? 0) === 0 ? (
              <p className="py-2 text-[12.5px] text-ink-muted">
                Nothing expires in the next fortnight.
              </p>
            ) : (
              <ul className="flex flex-col gap-2.5">
                {expiring.data?.slice(0, 5).map((subscription) => (
                  <li
                    key={subscription.id}
                    className="flex items-center gap-3 rounded-tile border border-line-subtle px-3.5 py-3"
                  >
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-[13.5px] font-bold">
                        {subscription.subject_name}
                      </p>
                      <p className="truncate text-[11.5px] text-ink-muted">
                        {subscription.kind === 'organization'
                          ? 'Organization'
                          : 'Individual teacher'}{' '}
                        · {subscription.plan} · expires {formatCalendarDate(subscription.ends_at)}
                      </p>
                    </div>
                    <span className="shrink-0 text-[12px] font-extrabold text-expiring tabular-nums">
                      {subscription.days_remaining} days
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>

        <div className="flex flex-col gap-3">
          <Card title="Subscriptions by plan">
            <PlanBars
              monthly={Number(stats?.monthly_count ?? 0)}
              yearly={Number(stats?.yearly_count ?? 0)}
              permanent={Number(stats?.permanent_count ?? 0)}
            />
          </Card>

          <Card title="Recent activity">
            {activity.isLoading ? (
              <p className="py-2 text-[13px] text-ink-muted">Loading…</p>
            ) : (activity.data?.length ?? 0) === 0 ? (
              <EmptyState
                title="Nothing has happened yet"
                body="Approvals, suspensions and renewals appear here as they happen."
              />
            ) : (
              <ActivityFeed entries={(activity.data ?? []).slice(0, 6)} />
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}

function PlanBars({
  monthly,
  yearly,
  permanent,
}: {
  monthly: number;
  yearly: number;
  permanent: number;
}) {
  const total = monthly + yearly + permanent;

  const bars = [
    { label: 'Monthly', count: monthly, tone: color.brand.accent },
    { label: 'Yearly', count: yearly, tone: color.status.info },
    { label: 'Permanent', count: permanent, tone: color.status.active },
  ];

  if (total === 0) {
    return (
      <p className="py-2 text-[12.5px] text-ink-muted">
        No subscriptions yet. The mix appears once accounts are approved.
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {bars.map((bar) => (
        <div key={bar.label}>
          <div className="mb-1.5 flex justify-between text-[12px] font-bold">
            <span>{bar.label}</span>
            <span className="text-ink-muted tabular-nums">{bar.count}</span>
          </div>
          <div className="h-2 overflow-hidden rounded-pill bg-meter">
            <div
              className="h-full rounded-pill"
              style={{
                width: `${Math.round((bar.count / total) * 100)}%`,
                backgroundColor: bar.tone,
              }}
            />
          </div>
        </div>
      ))}
    </div>
  );
}
