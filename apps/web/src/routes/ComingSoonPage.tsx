import { Link } from 'react-router-dom';

import { MILESTONES } from '../content/milestones.ts';

interface ComingSoonPageProps {
  /** Which milestone builds this surface, e.g. `M2`. */
  readonly milestone: string;
  readonly dashboard: string;
}

/**
 * A placeholder for a dashboard route that is reserved but not yet built.
 * It names the milestone rather than pretending the feature is loading.
 */
export function ComingSoonPage({ milestone, dashboard }: ComingSoonPageProps) {
  const detail = MILESTONES.find((entry) => entry.code === milestone);

  return (
    <div className="mx-auto flex max-w-xl flex-col gap-4 px-6 py-24">
      <p className="font-mono text-[11px] font-bold tracking-[0.12em] text-accent uppercase">
        {milestone} · not built yet
      </p>
      <h1 className="font-display text-3xl font-extrabold tracking-tight">{dashboard}</h1>
      <p className="text-ink-base">{detail?.summary ?? 'This dashboard is planned.'}</p>
      <p className="text-[13px] text-ink-muted">
        The route is reserved so sign-in can route to it the moment authentication lands.
      </p>
      <Link to="/" className="mt-2 text-[13px] font-bold text-accent hover:underline">
        ← Back to Warq
      </Link>
    </div>
  );
}
