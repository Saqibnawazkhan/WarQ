import { statusLabel, type SubscriptionStatus } from '@warq/core';
import { color, tint } from '@warq/tokens';

const STATUS_COLOR: Readonly<Record<SubscriptionStatus, string>> = {
  active: color.status.active,
  pending: color.status.pending,
  expiring_soon: color.status.expiringSoon,
  expired: color.status.expired,
  suspended: color.status.suspended,
};

interface StatusPillProps {
  readonly status: SubscriptionStatus;
}

/**
 * The status badge from the mockups: the state's colour at full strength on a
 * 10% wash of itself. State is carried by colour *and* by the word, never colour alone.
 */
export function StatusPill({ status }: StatusPillProps) {
  const hex = STATUS_COLOR[status];

  return (
    <span
      className="inline-flex rounded-xs px-2.5 py-1 text-[11px] font-extrabold whitespace-nowrap"
      style={{ backgroundColor: tint(hex, '1A'), color: hex }}
    >
      {statusLabel(status)}
    </span>
  );
}
