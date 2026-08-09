import { useState } from 'react';
import { Link } from 'react-router-dom';

import {
  ATTENDANCE_MARKS,
  MARK_INITIAL,
  markLabel,
  SUBSCRIPTION_STATUSES,
  type AttendanceMark,
} from '@warq/core';
import { color, fontSize, radius, tint } from '@warq/tokens';

import { cx } from '../lib/cx.ts';
import { Button, Card, Chip, StatCard, StatusPill } from '../ui/index.ts';

const PALETTE: readonly { group: string; entries: readonly [string, string][] }[] = [
  {
    group: 'Brand',
    entries: [
      ['Accent', color.brand.accent],
      ['Accent hover', color.brand.accentHover],
    ],
  },
  {
    group: 'Ink',
    entries: [
      ['Strong', color.ink.strong],
      ['Base', color.ink.base],
      ['Muted', color.ink.muted],
      ['Faint', color.ink.faint],
    ],
  },
  {
    group: 'Surface',
    entries: [
      ['Canvas', color.surface.canvas],
      ['Raised', color.surface.raised],
      ['Sunken', color.surface.sunken],
      ['Inverse', color.surface.inverse],
    ],
  },
  {
    group: 'Status',
    entries: [
      ['Active', color.status.active],
      ['Pending', color.status.pending],
      ['Expiring soon', color.status.expiringSoon],
      ['Expired', color.status.expired],
      ['Suspended', color.status.suspended],
      ['Info', color.status.info],
    ],
  },
];

const TYPE_SAMPLES: readonly { name: keyof typeof fontSize; use: string }[] = [
  { name: '5xl', use: 'Dashboard statistics' },
  { name: '4xl', use: 'Page titles' },
  { name: '2xl', use: 'Drawer titles' },
  { name: 'xl', use: 'Card titles' },
  { name: 'lg', use: 'List rows and inputs' },
  { name: 'md', use: 'Body copy and buttons' },
  { name: 'base', use: 'Table metadata' },
  { name: 'sm', use: 'Captions' },
  { name: 'xs', use: 'Eyebrows and timestamps' },
];

function Section({
  title,
  note,
  children,
}: {
  title: string;
  note?: string;
  children: React.ReactNode;
}) {
  return (
    <section className="flex flex-col gap-3.5">
      <div>
        <h2 className="font-display text-lg font-bold tracking-tight">{title}</h2>
        {note && <p className="mt-1 text-[13px] text-ink-muted">{note}</p>}
      </div>
      {children}
    </section>
  );
}

export function DesignSystemPage() {
  const [filter, setFilter] = useState('All');
  const [mark, setMark] = useState<AttendanceMark>('present');

  const markColor: Readonly<Record<AttendanceMark, string>> = {
    present: color.attendance.present,
    absent: color.attendance.absent,
    late: color.attendance.late,
  };

  return (
    <div className="mx-auto flex max-w-5xl flex-col gap-10 px-6 py-12 sm:px-8">
      <header className="flex flex-col gap-2">
        <Link to="/" className="text-[13px] font-bold text-accent hover:underline">
          ← Warq
        </Link>
        <h1 className="font-display text-3xl font-extrabold tracking-tight">Design system</h1>
        <p className="max-w-2xl text-ink-base">
          Every value here is generated from <code className="font-mono text-sm">@warq/tokens</code>{' '}
          at build time. Nothing on this page is typed in by hand, so it cannot drift from what the
          product uses.
        </p>
      </header>

      <Section title="Palette" note="Lifted verbatim from the approved mockups.">
        <div className="flex flex-col gap-5">
          {PALETTE.map(({ group, entries }) => (
            <div key={group}>
              <h3 className="mb-2.5 font-mono text-[11px] font-bold tracking-[0.1em] text-ink-muted uppercase">
                {group}
              </h3>
              <div className="grid grid-cols-2 gap-2.5 sm:grid-cols-3 lg:grid-cols-6">
                {entries.map(([name, hex]) => (
                  <div key={name} className="flex flex-col gap-1.5">
                    <div
                      className="h-14 rounded-tile border border-line"
                      style={{ backgroundColor: hex }}
                    />
                    <div>
                      <div className="text-xs font-bold">{name}</div>
                      <div className="font-mono text-[11px] text-ink-muted">{hex}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </Section>

      <Section
        title="Type scale"
        note="Sora carries headings and figures; Public Sans carries the rest."
      >
        <Card>
          <div className="flex flex-col divide-y divide-line-subtle">
            {TYPE_SAMPLES.map(({ name, use }) => (
              <div key={name} className="flex items-baseline gap-4 py-2.5">
                <span className="w-14 shrink-0 font-mono text-[11px] text-ink-muted tabular-nums">
                  {fontSize[name]}px
                </span>
                <span
                  className="min-w-0 flex-1 truncate font-display font-bold"
                  style={{ fontSize: fontSize[name] }}
                >
                  Software Engineering · A
                </span>
                <span className="hidden shrink-0 text-[12px] text-ink-faint sm:block">{use}</span>
              </div>
            ))}
          </div>
        </Card>
      </Section>

      <Section title="Statistics">
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard
            value="7"
            label="Organizations"
            detail="4 active · 1 expired"
            tone={color.brand.accent}
          />
          <StatCard value="6" label="Individual teachers" detail="3 active" />
          <StatCard value="72" label="Organization teachers" detail="across 7 organizations" />
          <StatCard
            value="91%"
            label="Attendance today"
            detail="7 of 9 classes marked"
            tone={color.status.active}
          />
        </div>
      </Section>

      <Section title="Subscription status" note="Colour and word together — never colour alone.">
        <Card>
          <div className="flex flex-wrap gap-2.5">
            {SUBSCRIPTION_STATUSES.map((status) => (
              <StatusPill key={status} status={status} />
            ))}
          </div>
        </Card>
      </Section>

      <Section title="Buttons">
        <Card>
          <div className="flex flex-wrap items-center gap-2.5">
            <Button variant="primary">Invite teacher</Button>
            <Button variant="approve">Approve</Button>
            <Button variant="secondary">Notify expiry</Button>
            <Button variant="danger">Suspend</Button>
            <Button variant="ghost">Cancel</Button>
            <Button variant="primary" disabled>
              Saving…
            </Button>
          </div>
        </Card>
      </Section>

      <Section title="Filters">
        <Card>
          <div className="flex flex-wrap gap-2">
            {['All', 'Pending', 'Active', 'Expiring Soon', 'Expired', 'Suspended'].map((label) => (
              <Chip
                key={label}
                label={label}
                selected={filter === label}
                onSelect={() => setFilter(label)}
              />
            ))}
          </div>
        </Card>
      </Section>

      <Section title="Attendance" note="The P · A · L toggle from the mobile roll call.">
        <Card>
          <div className="flex items-center gap-3">
            <span className="flex-1 text-[13.5px] font-semibold">Sara Malik</span>
            <div className="flex gap-1.5">
              {ATTENDANCE_MARKS.map((option) => {
                const selected = mark === option;
                const hex = markColor[option];
                return (
                  <button
                    key={option}
                    type="button"
                    aria-pressed={selected}
                    aria-label={markLabel(option)}
                    onClick={() => setMark(option)}
                    className="flex h-9 w-10 cursor-pointer items-center justify-center rounded-control border text-[12.5px] font-extrabold"
                    style={{
                      backgroundColor: selected ? hex : color.surface.sunken,
                      color: selected ? '#fff' : color.ink.faint,
                      borderColor: selected ? hex : color.border.input,
                    }}
                  >
                    {MARK_INITIAL[option]}
                  </button>
                );
              })}
            </div>
          </div>
          <p className="mt-3 text-[13px] text-ink-muted">
            Marked <strong className="text-ink">{markLabel(mark)}</strong>.
          </p>
        </Card>
      </Section>

      <Section title="Grades" note="Default bands. Organizations may set their own.">
        <Card>
          <div className="flex flex-wrap gap-2.5">
            {(['A+', 'A', 'B', 'C', 'D', 'F'] as const).map((grade) => (
              <span
                key={grade}
                className="rounded-xs px-3 py-1.5 text-[13px] font-extrabold"
                style={{
                  backgroundColor: tint(color.grade[grade], '1A'),
                  color: color.grade[grade],
                }}
              >
                {grade}
              </span>
            ))}
          </div>
        </Card>
      </Section>

      <Section title="Corner radii">
        <Card>
          <div className="flex flex-wrap gap-4">
            {(Object.entries(radius) as [string, number][]).map(([name, value]) => (
              <div key={name} className="flex flex-col items-center gap-2">
                <div
                  className={cx('size-16 border border-line bg-sunken')}
                  style={{ borderRadius: value }}
                />
                <div className="text-center">
                  <div className="text-[11px] font-bold">{name}</div>
                  <div className="font-mono text-[10px] text-ink-muted tabular-nums">{value}px</div>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </Section>
    </div>
  );
}
