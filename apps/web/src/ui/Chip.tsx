import { cx } from '../lib/cx.ts';

interface ChipProps {
  readonly label: string;
  readonly selected?: boolean | undefined;
  readonly onSelect?: (() => void) | undefined;
  readonly className?: string | undefined;
}

/** The pill-shaped filter used above every table and list in the mockups. */
export function Chip({ label, selected = false, onSelect, className }: ChipProps) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      onClick={onSelect}
      className={cx(
        'rounded-pill border px-3.5 py-1.5 text-xs font-bold transition-colors',
        onSelect ? 'cursor-pointer' : 'cursor-default',
        selected
          ? 'border-accent bg-accent text-on-accent'
          : 'border-line bg-raised text-ink-base hover:border-line-hover',
        className,
      )}
    >
      {label}
    </button>
  );
}
