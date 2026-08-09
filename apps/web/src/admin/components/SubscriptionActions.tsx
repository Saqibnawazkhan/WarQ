import { planLabel, type SubscriptionPlan, type SubscriptionStatus } from '@warq/core';

import { Button } from '../../ui/index.ts';
import { useSubscriptionAction } from '../queries.ts';
import { useToast } from '../../ui/index.ts';

interface SubscriptionActionsProps {
  readonly subscriptionId: string | null;
  readonly status: SubscriptionStatus | null;
  readonly plan: SubscriptionPlan | null;
  readonly subjectName: string;
  readonly size?: 'sm' | 'md' | undefined;
  readonly onDone?: (() => void) | undefined;
}

/**
 * The actions available on a subscription, chosen by its current state.
 *
 * A pending account offers approve and reject; a lapsed one offers renew; an
 * active one offers extend and suspend. Showing every button always and
 * disabling most would be noisier and no more informative — the mockups make the
 * same choice.
 */
export function SubscriptionActions({
  subscriptionId,
  status,
  plan,
  subjectName,
  size = 'sm',
  onDone,
}: SubscriptionActionsProps) {
  const action = useSubscriptionAction();
  const toast = useToast();

  if (!subscriptionId || !status) {
    return <span className="text-[12px] text-ink-faint">No subscription</span>;
  }

  function run(
    kind: 'approve' | 'reject' | 'suspend' | 'reactivate' | 'renew',
    message: string,
    tone: 'neutral' | 'success' | 'danger' = 'neutral',
  ) {
    action.mutate(
      { kind, subscriptionId: subscriptionId ?? '' },
      {
        onSuccess: () => {
          toast(message, tone);
          onDone?.();
        },
        onError: (cause) => toast(cause.message, 'danger'),
      },
    );
  }

  const busy = action.isPending;
  const planName = plan ? planLabel(plan).toLowerCase() : 'subscription';
  const extendLabel = plan === 'yearly' ? 'Extend +1 year' : 'Extend +1 month';

  if (status === 'pending') {
    return (
      <Row>
        <Button
          variant="approve"
          size={size}
          disabled={busy}
          onClick={() =>
            run('approve', `${subjectName} approved · ${planName} activated`, 'success')
          }
        >
          Approve
        </Button>
        <Button
          variant="danger"
          size={size}
          disabled={busy}
          onClick={() => run('reject', `${subjectName} rejected`)}
        >
          Reject
        </Button>
      </Row>
    );
  }

  if (status === 'suspended') {
    return (
      <Row>
        <Button
          variant="approve"
          size={size}
          disabled={busy}
          onClick={() => run('reactivate', `${subjectName} reactivated`, 'success')}
        >
          Reactivate
        </Button>
      </Row>
    );
  }

  if (status === 'expired') {
    return (
      <Row>
        <Button
          variant="primary"
          size={size}
          disabled={busy}
          onClick={() => run('renew', `${subjectName} renewed`, 'success')}
        >
          Renew {planName}
        </Button>
        <Button
          variant="danger"
          size={size}
          disabled={busy}
          onClick={() => run('suspend', `${subjectName} suspended`)}
        >
          Suspend
        </Button>
      </Row>
    );
  }

  // Active or expiring soon.
  return (
    <Row>
      {plan !== 'permanent' && (
        <Button
          variant="primary"
          size={size}
          disabled={busy}
          onClick={() => run('renew', `${subjectName} extended`, 'success')}
        >
          {extendLabel}
        </Button>
      )}
      <Button
        variant="danger"
        size={size}
        disabled={busy}
        onClick={() => run('suspend', `${subjectName} suspended`)}
      >
        Suspend
      </Button>
    </Row>
  );
}

function Row({ children }: { children: React.ReactNode }) {
  return <div className="flex flex-wrap justify-end gap-1.5">{children}</div>;
}
