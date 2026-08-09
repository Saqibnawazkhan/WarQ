import { useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';

import { initials } from '@warq/core';

import { useSession } from '../auth/session-context.ts';
import { cx } from '../lib/cx.ts';

/**
 * The teacher shell.
 *
 * The mockups only cover teachers on a phone, where the surface is five bottom
 * tabs. On a laptop the same work wants a sidebar and wider tables — a phone
 * layout stretched across 1400 pixels is not a desktop app, it is a wasted one.
 */
const NAV = [
  { to: '/teacher', label: 'Today', glyph: '◧', end: true },
  { to: '/teacher/classes', label: 'Classes', glyph: '◫' },
  { to: '/teacher/attendance', label: 'Attendance', glyph: '✓' },
  { to: '/teacher/marks', label: 'Marks', glyph: '◔' },
  { to: '/teacher/reports', label: 'Reports', glyph: '⤓' },
  { to: '/teacher/settings', label: 'Settings', glyph: '◎' },
] as const;

export function TeacherLayout() {
  const { session, signOut } = useSession();
  const [menuOpen, setMenuOpen] = useState(false);

  if (!session) return null;

  return (
    <div className="flex min-h-screen flex-col lg:flex-row">
      <header className="flex items-center justify-between border-b border-line bg-raised px-4 py-3 lg:hidden">
        <Brand />
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
        aria-label="Teacher"
        className={cx(
          'shrink-0 flex-col gap-0.5 border-line bg-raised px-3.5 pb-5 lg:sticky lg:top-0 lg:flex lg:h-screen lg:w-[212px] lg:overflow-y-auto lg:border-r lg:pt-5',
          menuOpen ? 'flex' : 'hidden',
        )}
      >
        <div className="hidden lg:block">
          <Brand />
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

        <div className="mt-auto flex items-center gap-2.5 border-t border-line-subtle pt-3.5">
          <div className="flex size-8 shrink-0 items-center justify-center rounded-sm bg-[color-mix(in_srgb,var(--warq-brand-accent)_8%,transparent)] font-display text-[12px] font-bold text-accent">
            {initials(session.profile.full_name)}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[12px] font-bold">{session.profile.full_name}</p>
            <p className="truncate text-[10.5px] text-ink-muted">
              {session.organization?.name ?? 'Independent'}
            </p>
          </div>
          <button
            type="button"
            onClick={() => void signOut()}
            className="cursor-pointer text-[11px] font-bold text-ink-muted hover:text-ink"
          >
            Exit
          </button>
        </div>
      </nav>

      <main className="min-w-0 flex-1 bg-canvas px-5 py-6 sm:px-8 sm:py-7">
        <div className="mx-auto w-full max-w-[1200px]">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

function Brand() {
  return (
    <div className="flex items-center gap-2.5 px-1">
      <div className="flex size-8.5 items-center justify-center rounded-[11px] bg-accent font-display text-[16px] font-extrabold text-on-accent">
        W
      </div>
      <div>
        <p className="font-display text-[14.5px] font-extrabold">Warq</p>
        <p className="text-[10px] font-bold tracking-[0.08em] text-ink-muted uppercase">Teacher</p>
      </div>
    </div>
  );
}
