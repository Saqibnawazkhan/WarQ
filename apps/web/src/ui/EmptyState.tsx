import type { ReactNode } from 'react';

interface EmptyStateProps {
  readonly title: string;
  readonly body: string;
  readonly action?: ReactNode | undefined;
}

/**
 * What a list shows before it has anything in it.
 *
 * The mockups only draw the populated case, but an empty Organizations table is
 * what the platform actually looks like on day one — so it says what will fill
 * it rather than leaving a blank panel that reads as a failed load.
 */
export function EmptyState({ title, body, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center gap-2 px-6 py-14 text-center">
      <p className="font-display text-[15px] font-bold text-ink">{title}</p>
      <p className="max-w-sm text-[13px] leading-relaxed text-ink-muted">{body}</p>
      {action && <div className="mt-2">{action}</div>}
    </div>
  );
}
