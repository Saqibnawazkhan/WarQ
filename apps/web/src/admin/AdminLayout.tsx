import { useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';

import { initials } from '@warq/core';

import { useSession } from '../auth/session-context.ts';
import { cx } from '../lib/cx.ts';
import { NAV } from './nav.ts';
import { useAdminBadges } from './queries.ts';

/**
 * The Main Admin shell: a dark sidebar and a light content area, as drawn.
 *
 * The sidebar collapses to a top bar below `lg`. The dashboard is web-only by
 * design, but "web-only" includes a laptop at 1280 and a tablet in a meeting —
 * it should not fall apart at either.
 */
export function AdminLayout() {
  const { session, signOut } = useSession();
  const badges = useAdminBadges();
  const [menuOpen, setMenuOpen] = useState(false);

  if (!session) return null;

  const counts = { pending: badges.data?.pending ?? 0, expiring: badges.data?.expiring ?? 0 };

  return (
    <div className="flex min-h-screen flex-col lg:flex-row">
      <header className="flex items-center justify-between bg-inverse px-4 py-3 lg:hidden">
        <Brand />
        <button
          type="button"
          onClick={() => setMenuOpen((open) => !open)}
          aria-expanded={menuOpen}
          className="cursor-pointer rounded-control border border-white/15 px-3 py-1.5 text-[12px] font-bold text-white/80"
        >
          {menuOpen ? 'Close' : 'Menu'}
        </button>
      </header>

      <nav
        aria-label="Main admin"
        className={cx(
          'shrink-0 flex-col gap-0.5 bg-inverse px-3.5 pb-5 lg:sticky lg:top-0 lg:flex lg:h-screen lg:w-[232px] lg:overflow-y-auto lg:pt-5',
          menuOpen ? 'flex' : 'hidden',
        )}
      >
        <div className="hidden lg:block">
          <Brand />
        </div>

        <div className="mt-5 flex flex-col gap-4">
          {NAV.map((group) => (
            <div key={group.heading ?? 'top'} className="flex flex-col gap-0.5">
              {group.heading && (
                <p className="px-3 pt-1 pb-1.5 text-[10px] font-bold tracking-[0.1em] text-white/35 uppercase">
                  {group.heading}
                </p>
              )}

              {group.items.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.to === '/admin'}
                  onClick={() => setMenuOpen(false)}
                  className={({ isActive }) =>
                    cx(
                      'flex items-center gap-2.5 rounded-[11px] px-3 py-2.5 text-[13px] font-bold transition-colors',
                      isActive ? 'bg-accent text-white' : 'text-white/65 hover:bg-white/8',
                    )
                  }
                >
                  <span className="w-4 text-center font-display text-[13px]">{item.glyph}</span>
                  <span className="flex-1">{item.label}</span>

                  {item.badge && counts[item.badge] > 0 && (
                    <span
                      className={cx(
                        'rounded-pill px-[7px] py-0.5 text-[10.5px] font-extrabold text-white tabular-nums',
                        item.badge === 'pending' ? 'bg-pending' : 'bg-expiring',
                      )}
                    >
                      {counts[item.badge]}
                    </span>
                  )}
                </NavLink>
              ))}
            </div>
          ))}
        </div>

        <div className="mt-auto flex items-center gap-2.5 border-t border-white/10 pt-3.5">
          <div className="flex size-8 shrink-0 items-center justify-center rounded-sm bg-white/12 font-display text-[12px] font-bold text-white">
            {initials(session.profile.full_name)}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-[12px] font-bold text-white">{session.profile.full_name}</p>
            <p className="truncate text-[10.5px] text-white/45">{session.profile.email}</p>
          </div>
          <button
            type="button"
            onClick={() => void signOut()}
            className="cursor-pointer text-[11px] font-bold text-white/50 hover:text-white"
          >
            Exit
          </button>
        </div>
      </nav>

      {/*
        Capped and centred. Without a maximum the tables stretch the full width
        of a large monitor, which pushes a row's first and last cell so far apart
        that scanning across one becomes work. 1440 keeps a six-column table
        readable while still using a laptop screen fully.
      */}
      <main className="min-w-0 flex-1 px-5 py-6 sm:px-8 sm:py-7">
        <div className="mx-auto w-full max-w-[1440px]">
          <Outlet />
        </div>
      </main>
    </div>
  );
}

function Brand() {
  return (
    <div className="flex items-center gap-2.5 px-1">
      <div className="flex size-8.5 items-center justify-center rounded-[11px] bg-accent font-display text-[16px] font-extrabold text-white">
        W
      </div>
      <div>
        <p className="font-display text-[14.5px] font-extrabold text-white">Warq</p>
        <p className="text-[10px] font-bold tracking-[0.08em] text-white/45 uppercase">
          Main Admin
        </p>
      </div>
    </div>
  );
}
