import { useState } from 'react';

import type { ActivityFilter } from '@warq/data';

import { Card, Chip, EmptyState } from '../../ui/index.ts';
import { ActivityFeed } from '../components/ActivityFeed.tsx';
import { PageHeading } from '../components/PageHeading.tsx';
import { useActivity } from '../queries.ts';

const FILTERS: readonly { value: ActivityFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'subscription', label: 'Subscriptions' },
  { value: 'admin', label: 'Admin' },
  { value: 'attendance', label: 'Attendance' },
  { value: 'marks', label: 'Marks' },
  { value: 'alerts', label: 'Alerts' },
];

export function ActivityPage() {
  const [filter, setFilter] = useState<ActivityFilter>('all');
  const activity = useActivity(filter);

  const entries = activity.data ?? [];

  return (
    <div className="flex flex-col gap-4">
      <PageHeading
        title="Activity Logs"
        subtitle="Everything that has happened across the platform, newest first"
      />

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
            title={filter === 'all' ? 'Nothing has happened yet' : 'Nothing of that kind yet'}
            body="Approvals, suspensions, renewals and reminders are all recorded here as they happen."
          />
        ) : (
          <ActivityFeed entries={entries} />
        )}
      </Card>
    </div>
  );
}
