import type { ReactNode } from 'react';

import { cx } from '../lib/cx.ts';

interface CardProps {
  readonly children: ReactNode;
  readonly title?: string | undefined;
  readonly action?: ReactNode | undefined;
  readonly className?: string | undefined;
  readonly padded?: boolean | undefined;
}

/** The white panel every dashboard surface is built from. */
export function Card({ children, title, action, className, padded = true }: CardProps) {
  return (
    <section
      className={cx(
        'rounded-card border border-line bg-raised shadow-card',
        padded && 'p-[18px]',
        className,
      )}
    >
      {(title ?? action) && (
        <header className="mb-3 flex items-baseline justify-between gap-3">
          {title && <h2 className="font-display text-[15px] font-bold text-ink">{title}</h2>}
          {action}
        </header>
      )}
      {children}
    </section>
  );
}
