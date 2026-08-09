/**
 * Warq spatial and motion tokens.
 *
 * The mockups use a consistent shape language: pill-shaped chips, soft 10–14px
 * controls, and generously rounded 16–22px cards. These names encode the role,
 * not the number.
 */

/** Corner radii, in pixels. */
export const radius = {
  /** Status pills and small badges. */
  xs: 8,
  /** Row-level action buttons. */
  sm: 10,
  /** Inputs, buttons, filter chips. */
  md: 12,
  /** Search fields, icon tiles. */
  lg: 14,
  /** List cards on mobile. */
  xl: 16,
  /** Statistic cards. */
  '2xl': 18,
  /** Content cards and tables. */
  '3xl': 20,
  /** Modals and bottom sheets. */
  '4xl': 24,
  /** Fully round — chips, avatars, the floating action button. */
  full: 999,
} as const;

/** Spacing scale, in pixels. */
export const space = {
  px: 1,
  0.5: 2,
  1: 4,
  1.5: 6,
  2: 8,
  2.5: 10,
  3: 12,
  3.5: 14,
  4: 16,
  5: 18,
  6: 20,
  7: 22,
  8: 26,
  9: 32,
  10: 40,
} as const;

/** Elevation. Every shadow is tinted with the ink colour, never neutral black. */
export const shadow = {
  /** Resting card. */
  card: '0 1px 2px rgba(23,23,58,0.04), 0 8px 24px rgba(23,23,58,0.05)',
  /** Segmented-control thumb. */
  thumb: '0 1px 4px rgba(23,23,58,0.12)',
  /** Sticky primary action, e.g. Save attendance. */
  action: '0 10px 24px rgba(23,23,58,0.22)',
  /** Floating action button — tinted with the accent, not the ink. */
  fab: '0 10px 22px rgba(67,56,202,0.38)',
  /** Right-hand detail drawer. */
  drawer: '-20px 0 50px rgba(23,23,58,0.15)',
  /** Toast. */
  toast: '0 12px 28px rgba(23,23,58,0.35)',
} as const;

/** Motion, matching the keyframes declared in the mockups. */
export const motion = {
  duration: {
    /** Scrim fade. */
    fast: 180,
    /** Modal and sheet entrance. */
    base: 200,
    /** Drawer and toast entrance. */
    slow: 220,
  },
  easing: {
    standard: 'ease',
    emphasized: 'cubic-bezier(0.2, 0, 0, 1)',
  },
} as const;

/** Fixed dimensions the layouts depend on. */
export const size = {
  /** Web sidebar width. */
  sidebar: 232,
  /** Right-hand detail drawer width. */
  drawer: 430,
  /** Centred dialog width. */
  dialog: 420,
  /** Reference device viewport from the mobile mockups. */
  deviceWidth: 402,
  deviceHeight: 874,
} as const;
