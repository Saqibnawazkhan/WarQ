import type { ActivityLog } from '@warq/data';
import { color } from '@warq/tokens';

/** Dot colour by activity type — the same mapping the mockups use. */
const TONE: Readonly<Record<string, string>> = {
  attendance: color.status.active,
  marks: color.brand.accent,
  alerts: color.status.expired,
  admin: color.status.info,
  subscription: color.status.pending,
};

interface ActivityFeedProps {
  readonly entries: readonly ActivityLog[];
  readonly showActor?: boolean | undefined;
}

export function ActivityFeed({ entries, showActor = true }: ActivityFeedProps) {
  return (
    <ul className="flex flex-col gap-3">
      {entries.map((entry) => (
        <li key={entry.id} className="flex items-start gap-2.5">
          <span
            aria-hidden="true"
            className="mt-[5px] size-[7px] shrink-0 rounded-pill"
            style={{ backgroundColor: TONE[entry.type] ?? color.ink.faint }}
          />

          <div className="min-w-0 flex-1">
            <p className="text-[12.5px] leading-relaxed text-ink-base">{entry.message}</p>
            {showActor && entry.actor_name && (
              <p className="mt-0.5 text-[11.5px] text-ink-muted">{entry.actor_name}</p>
            )}
          </div>

          <time
            dateTime={entry.created_at}
            className="shrink-0 text-[11px] text-ink-faint tabular-nums"
          >
            {relative(entry.created_at)}
          </time>
        </li>
      ))}
    </ul>
  );
}

/**
 * A feed reads better with "2h" than a full timestamp; the exact value stays in
 * the `datetime` attribute for anyone who needs it.
 */
function relative(iso: string): string {
  const then = new Date(iso).getTime();
  const minutes = Math.round((Date.now() - then) / 60_000);

  if (minutes < 1) return 'now';
  if (minutes < 60) return `${minutes}m`;

  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h`;

  const days = Math.round(hours / 24);
  if (days < 7) return `${days}d`;

  return new Date(iso).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' });
}
