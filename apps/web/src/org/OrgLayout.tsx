import { useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';

import { formatCalendarDate, initials, planLabel } from '@warq/core';

import { useSession } from '../auth/session-context.ts';
import { cx } from '../lib/cx.ts';

/**
 * The Organization Admin shell.
 *
 * Light rather than dark, as the mockup draws it — a deliberate contrast with
 * the Main Admin dashboard, so it is obvious at a glance which one you are
 * looking at.
 *
 * The mockup carries four sections; the specification asks for students,
 * attendance review, marks review, performance and reports too. Attendance and
 * marks live inside a class rather than as their own pages: reviewing either one
 * always begins by choosing a class, so a separate page would open with a class
 * picker and nothing else.
 */
const NAV = [
  { to: '/org', label: 'Dashboard', glyph: '◧', end: true },
  { to: '/org/teachers', label: 'Teachers', glyph: '◔' },
  { to: '/org/classes', label: 'Classes', glyph: '◫' },
  { to: '/org/students', label: 'Students', glyph: '◍' },
  { to: '/org/activity', label: 'Activity', glyph: '◭' },
  { to: '/org/reports', label: 'Reports', glyph: '⤓' },
  { to: '/org/settings', label: 'Settings', glyph: '◎' },
] as const;

export function OrgLayout() {
  const { session, signOut } = useSession();
  const [menuOpen, setMenuOpen] = useState(false);

  if (!session) return null;

  const { organization, subscription } = session;

  return (
    <div className="flex min-h-screen flex-col lg:flex-row">
      <header className="flex items-center justify-between border-b border-line bg-raised px-4 py-3 lg:hidden">
        <Brand name={organization?.name ?? 'Organization'} />
        <button
          type="button"
          onClick={() => setMenuOpen((open) => !open)}
          aria-expanded={menuOpen}
          className="cursor-pointer rounded-control border border-line px-3 py-1.5 text-[12px] font-bold text-ink-base"
        >
          {menuOpen ? 'Close' : 'Menu'}
        </button>
      </header>

      <nav
        aria-label="Organization"
        className={cx(
          'shrink-0 flex-col gap-0.5 border-line bg-raised px-3.5 pb-5 lg:sticky lg:top-0 lg:flex lg:h-screen lg:w-[232px] lg:overflow-y-auto lg:border-r lg:pt-5',
          menuOpen ? 'flex' : 'hidden',
        )}
      >
        <div className="hidden lg:block">
          <Brand name={organization?.name ?? 'Organization'} />
        </div>

        <div className="mt-5 flex flex-col gap-0.5">
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={'end' in item ? item.end : false}
              onClick={() => setMenuOpen(false)}
              className={({ isActive }) =>
                cx(
                  'flex items-center gap-2.5 rounded-[11px] px-3 py-2.5 text-[13px] font-bold transition-colors',
                  isActive ? 'bg-accent text-on-accent' : 'text-ink-base hover:bg-canvas',
                )
              }
            >
              <span className="w-4 text-center font-display text-[13px]">{item.glyph}</span>
              {item.label}
            </NavLink>
          ))}
        </div>

        <div className="mt-auto border-t border-line-subtle pt-3.5">
          <p className="text-[11px] font-bold tracking-[0.07em] text-ink-muted uppercase">
            {organization?.name}
          </p>

          <div className="mt-2.5 flex items-center gap-2.5">
            <div className="flex size-8 shrink-0 items-center justify-center rounded-sm bg-[color-mix(in_srgb,var(--warq-brand-accent)_8%,transparent)] font-display text-[12px] font-bold text-accent">
              {initials(session.profile.full_name)}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[12px] font-bold">{session.profile.full_name}</p>
              <p className="text-[10.5px] text-ink-muted">Org Admin</p>
            </div>
            <button
              type="button"
              onClick={() => void signOut()}
              className="cursor-pointer text-[11px] font-bold text-ink-muted hover:text-ink"
            >
              Exit
            </button>
          </div>

          {subscription && (
            <p className="mt-2.5 text-[11px] text-ink-muted">
              {subscription.plan ? planLabel(subscription.plan) : ''} plan
              {subscription.plan === 'permanent'
                ? ' · no expiry'
                : subscription.ends_at
                  ? ` · until ${formatCalendarDate(subscription.ends_at)}`
                  : ''}
            </p>
          )}
        </div>
      </nav>

      <main className="min-w-0 flex-1 bg-canvas px-5 py-6 sm:px-8 sm:py-7">
        <div className="mx-auto w-full max-w-[1440px]">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

function Brand({ name }: { name: string }) {
  return (
    <div className="flex items-center gap-2.5 px-1">
      <div className="flex size-8.5 items-center justify-center rounded-[11px] bg-accent font-display text-[16px] font-extrabold text-on-accent">
        W
      </div>
      <div className="min-w-0">
        <p className="font-display text-[14.5px] font-extrabold">Warq</p>
        <p className="truncate text-[10px] font-bold tracking-[0.08em] text-ink-muted uppercase">
          {name}
        </p>
      </div>
    </div>
  );
}
