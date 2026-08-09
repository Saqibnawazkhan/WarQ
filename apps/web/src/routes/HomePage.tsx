import { Link } from 'react-router-dom';

import { MILESTONES, type MilestoneState } from '../content/milestones.ts';
import { cx } from '../lib/cx.ts';
import { Card, StatCard } from '../ui/index.ts';

const STATE_STYLE: Readonly<Record<MilestoneState, { dot: string; label: string; text: string }>> =
  {
    done: { dot: 'bg-active', label: 'Shipped', text: 'text-active' },
    building: { dot: 'bg-pending', label: 'In progress', text: 'text-pending' },
    planned: { dot: 'bg-line-hover', label: 'Planned', text: 'text-ink-faint' },
  };

const shipped = MILESTONES.filter((m) => m.state === 'done').length;

export function HomePage() {
  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-9 px-6 py-12 sm:px-8">
      <header className="flex flex-col gap-5">
        <div className="flex items-center gap-3">
          <div className="flex size-11 items-center justify-center rounded-field bg-accent font-display text-xl font-extrabold text-on-accent">
            W
          </div>
          <div>
            <h1 className="font-display text-2xl leading-none font-extrabold tracking-tight">
              Warq
            </h1>
            <p className="mt-1 text-[11px] font-bold tracking-[0.09em] text-ink-muted uppercase">
              Education management platform
            </p>
          </div>
        </div>

        <p className="max-w-2xl text-lg text-ink-base">
          Attendance, marks, grades and reports for teachers and institutions — on the web and in
          your pocket, backed by one database.
        </p>
      </header>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          value={`${shipped}/${MILESTONES.length}`}
          label="Milestones shipped"
          tone="#4338CA"
        />
        <StatCard value="3" label="Roles" detail="Main Admin · Org Admin · Teacher" />
        <StatCard value="2" label="Platforms" detail="Web and mobile" />
        <StatCard value="1" label="Source of truth" detail="One database behind both" />
      </div>

      <Card title="Delivery">
        <ol className="flex flex-col">
          {MILESTONES.map((milestone) => {
            const style = STATE_STYLE[milestone.state];
            return (
              <li
                key={milestone.code}
                className="grid grid-cols-[54px_1fr] gap-4 border-t border-line-subtle py-3.5 first:border-t-0 sm:grid-cols-[54px_1fr_92px]"
              >
                <span className="font-mono text-[13px] font-bold text-accent tabular-nums">
                  {milestone.code}
                </span>

                <div className="min-w-0">
                  <h3 className="font-display text-[15px] font-bold">{milestone.title}</h3>
                  <p className="mt-1 text-[13.5px] leading-relaxed text-ink-base">
                    {milestone.summary}
                  </p>
                  <p className="mt-1 text-[11px] font-semibold tracking-wide text-ink-faint uppercase">
                    {milestone.lands}
                  </p>
                </div>

                <div className="flex items-start gap-2 sm:justify-end">
                  <span className={cx('mt-1.5 size-2 shrink-0 rounded-pill', style.dot)} />
                  <span className={cx('text-[11px] font-bold', style.text)}>{style.label}</span>
                </div>
              </li>
            );
          })}
        </ol>
      </Card>

      <Card title="Reference">
        <p className="text-[13.5px] text-ink-base">
          The colours, type scale and components below are compiled from{' '}
          <code className="rounded bg-sunken px-1.5 py-0.5 font-mono text-xs">@warq/tokens</code>,
          the single source every surface reads from.
        </p>
        <Link
          to="/design"
          className="mt-3.5 inline-flex rounded-control bg-accent px-4 py-2.5 text-[13px] font-bold text-on-accent transition-opacity hover:opacity-93"
        >
          Open the design system
        </Link>
      </Card>
    </div>
  );
}
