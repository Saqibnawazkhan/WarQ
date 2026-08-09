import { useState } from 'react';

import type { ActivityFilter } from '@warq/data';

import { Card, Chip, EmptyState } from '../../ui/index.ts';
import { ActivityFeed } from '../../admin/components/ActivityFeed.tsx';
import { PageHeading } from '../../admin/components/PageHeading.tsx';
import { useOrgActivity } from '../queries.ts';

/** The four filters drawn in the mockup. */
const FILTERS: readonly { value: ActivityFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'attendance', label: 'Attendance' },
  { value: 'marks', label: 'Marks' },
  { value: 'alerts', label: 'Alerts' },
];

export function OrgActivityPage() {
  const [filter, setFilter] = useState<ActivityFilter>('all');
  const activity = useOrgActivity(filter);
  const entries = activity.data ?? [];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading title="Activity" subtitle="What your teachers have been doing, newest first" />

      <div className="flex flex-wrap gap-1.5" role="group" aria-label="Filter activity">
        {FILTERS.map((option) => (
          <Chip
            key={option.value}
            label={option.label}
            selected={filter === option.value}
            onSelect={() => setFilter(option.value)}
          />
        ))}
      </div>

      <Card padded={entries.length > 0}>
        {activity.isLoading ? (
          <p className="py-6 text-center text-[13px] text-ink-muted">Loading…</p>
        ) : entries.length === 0 ? (
          <EmptyState
            title={filter === 'all' ? 'Nothing yet' : 'Nothing of that kind yet'}
            body="Registers taken, marks entered and absence alerts sent all appear here as they happen."
          />
        ) : (
          <ActivityFeed entries={entries} />
        )}
      </Card>
    </div>
  );
}
