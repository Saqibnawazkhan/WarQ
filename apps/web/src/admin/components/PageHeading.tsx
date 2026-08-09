import type { ReactNode } from 'react';

interface PageHeadingProps {
  readonly title: string;
  readonly eyebrow?: string | undefined;
  readonly subtitle?: string | undefined;
  readonly action?: ReactNode | undefined;
}

export function PageHeading({ title, eyebrow, subtitle, action }: PageHeadingProps) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-3">
      <div>
        {eyebrow && (
          <p className="text-[11px] font-bold tracking-[0.09em] text-ink-muted uppercase">
            {eyebrow}
          </p>
        )}
        <h1 className="mt-0.5 font-display text-2xl font-bold tracking-tight">{title}</h1>
        {subtitle && <p className="mt-1 text-[12.5px] text-ink-muted">{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}
