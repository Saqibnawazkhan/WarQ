import type { ReactNode } from 'react';

import { cx } from '../lib/cx.ts';
import { EmptyState } from './EmptyState.tsx';

export interface Column<T> {
  readonly key: string;
  readonly header: string;
  readonly render: (row: T) => ReactNode;
  /** Grid track for this column, e.g. `2fr` or `120px`. */
  readonly width: string;
  readonly align?: 'start' | 'end' | undefined;
}

interface DataTableProps<T> {
  readonly rows: readonly T[];
  readonly columns: readonly Column<T>[];
  readonly rowKey: (row: T) => string;
  readonly onRowClick?: ((row: T) => void) | undefined;
  readonly loading?: boolean | undefined;
  readonly empty: { title: string; body: string };
}

/**
 * The card-wrapped table used across the admin dashboard.
 *
 * Laid out with a CSS grid rather than a `<table>` so a row can be one focusable
 * control when it opens a drawer, while still exposing table semantics to a
 * screen reader through roles.
 *
 * Scrolls inside its own container: the page body never scrolls sideways.
 */
export function DataTable<T>({
  rows,
  columns,
  rowKey,
  onRowClick,
  loading,
  empty,
}: DataTableProps<T>) {
  const template = columns.map((column) => column.width).join(' ');

  return (
    <div className="overflow-hidden rounded-card border border-line bg-raised">
      <div className="overflow-x-auto">
        <div role="table" className="min-w-[720px]">
          <div
            role="row"
            className="grid gap-3 border-b border-line-subtle px-[18px] py-3"
            style={{ gridTemplateColumns: template }}
          >
            {columns.map((column) => (
              <div
                key={column.key}
                role="columnheader"
                className={cx(
                  'text-[11px] font-bold tracking-[0.06em] text-ink-muted uppercase',
                  column.align === 'end' && 'text-right',
                )}
              >
                {column.header}
              </div>
            ))}
          </div>

          {loading ? (
            <div className="px-[18px] py-10 text-center text-[13px] text-ink-muted" role="status">
              Loading…
            </div>
          ) : rows.length === 0 ? (
            <EmptyState title={empty.title} body={empty.body} />
          ) : (
            rows.map((row) => {
              const cells = columns.map((column) => (
                <div
                  key={column.key}
                  role="cell"
                  className={cx('min-w-0', column.align === 'end' && 'text-right')}
                >
                  {column.render(row)}
                </div>
              ));

              const shared =
                'grid w-full items-center gap-3 border-b border-line-faint px-[18px] py-3 text-left last:border-b-0';

              return onRowClick ? (
                <button
                  key={rowKey(row)}
                  type="button"
                  role="row"
                  onClick={() => onRowClick(row)}
                  className={cx(shared, 'cursor-pointer hover:bg-hover')}
                  style={{ gridTemplateColumns: template }}
                >
                  {cells}
                </button>
              ) : (
                <div
                  key={rowKey(row)}
                  role="row"
                  className={shared}
                  style={{ gridTemplateColumns: template }}
                >
                  {cells}
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
}
