import { cx } from '../lib/cx.ts';

interface StatCardProps {
  readonly value: string;
  readonly label: string;
  readonly detail?: string | undefined;
  /** Any CSS colour. Defaults to the ink colour, as the mockups do for neutral figures. */
  readonly tone?: string | undefined;
  readonly className?: string | undefined;
}

/** The figure tile that heads every dashboard. */
export function StatCard({ value, label, detail, tone, className }: StatCardProps) {
  return (
    <div className={cx('rounded-stat border border-line bg-raised p-4', className)}>
      <div
        className="font-display text-[26px] leading-none font-bold tabular-nums"
        style={tone ? { color: tone } : undefined}
      >
        {value}
      </div>
      <div className="mt-1.5 text-xs font-semibold text-ink-muted">{label}</div>
      {detail && <div className="mt-0.5 text-[11px] font-semibold text-ink-faint">{detail}</div>}
    </div>
  );
}
