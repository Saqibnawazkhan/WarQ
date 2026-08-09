/**
 * The Main Admin navigation.
 *
 * The mockup draws four sections; the specification asks for eleven. These are
 * the eleven, grouped so the sidebar reads as three jobs rather than one long
 * list: who is on the platform, what needs attention, and how it is running.
 */

export interface NavItem {
  readonly to: string;
  readonly label: string;
  readonly glyph: string;
  /** Which count, if any, appears as a badge. */
  readonly badge?: 'pending' | 'expiring';
}

export interface NavGroup {
  readonly heading: string | null;
  readonly items: readonly NavItem[];
}

export const NAV: readonly NavGroup[] = [
  {
    heading: null,
    items: [{ to: '/admin', label: 'Dashboard', glyph: '◧' }],
  },
  {
    heading: 'Accounts',
    items: [
      { to: '/admin/organizations', label: 'Organizations', glyph: '◫' },
      { to: '/admin/teachers', label: 'Individual Teachers', glyph: '◔' },
      { to: '/admin/org-admins', label: 'Organization Admins', glyph: '◍' },
    ],
  },
  {
    heading: 'Billing',
    items: [
      { to: '/admin/subscriptions', label: 'Subscriptions', glyph: '◈' },
      { to: '/admin/pending', label: 'Pending Requests', glyph: '◒', badge: 'pending' },
      { to: '/admin/expiring', label: 'Expiring Soon', glyph: '◓', badge: 'expiring' },
    ],
  },
  {
    heading: 'Platform',
    items: [
      { to: '/admin/notifications', label: 'Notifications', glyph: '◭' },
      { to: '/admin/activity', label: 'Activity Logs', glyph: '◊' },
      { to: '/admin/reports', label: 'Reports', glyph: '⤓' },
      { to: '/admin/settings', label: 'Settings', glyph: '◎' },
    ],
  },
];
