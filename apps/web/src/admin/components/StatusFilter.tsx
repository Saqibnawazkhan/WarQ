import { statusLabel, SUBSCRIPTION_STATUSES } from '@warq/core';

import { Chip } from '../../ui/index.ts';
import type { StatusFilterValue } from './status-filter.ts';

interface StatusFilterProps {
  readonly value: StatusFilterValue;
  readonly onChange: (value: StatusFilterValue) => void;
  /** How many rows sit behind each option, so the chips say what they will do. */
  readonly counts?: Partial<Record<StatusFilterValue, number>> | undefined;
}

export function StatusFilter({ value, onChange, counts }: StatusFilterProps) {
  const options: StatusFilterValue[] = ['all', ...SUBSCRIPTION_STATUSES];

  return (
    <div className="flex flex-wrap gap-1.5" role="group" aria-label="Filter by status">
      {options.map((option) => {
        const count = counts?.[option];
        const label = option === 'all' ? 'All' : statusLabel(option);

        return (
          <Chip
            key={option}
            label={count === undefined ? label : `${label} ${count}`}
            selected={value === option}
            onSelect={() => onChange(option)}
          />
        );
      })}
    </div>
  );
}
