/**
 * Warq colour system.
 *
 * Every value here is lifted verbatim from the approved mockups in `design/`.
 * Nothing is invented: if a colour is not in this file, it is not in the product.
 *
 * Groups are semantic rather than literal — components ask for `border.subtle`,
 * never for `#F0F0F6`, so a repaint is one edit here.
 */

/** The four accents the mockups expose as a theme switch. `indigo` is the default. */
export const accents = {
  indigo: '#4338CA',
  teal: '#0F766E',
  amber: '#B45309',
  navy: '#1E3A5F',
} as const;

export type AccentName = keyof typeof accents;

export const color = {
  /** Brand accent and its supporting shades. */
  brand: {
    accent: accents.indigo,
    /** Hover state for accent-coloured links. */
    accentHover: '#3730A3',
    /** 8% accent wash used behind avatars and icon tiles. */
    accentWash: '#4338CA14',
    /** Foreground on top of a solid accent fill. */
    onAccent: '#FFFFFF',
  },

  /** Text, in descending emphasis. */
  ink: {
    /** Headings, primary values, the Main Admin sidebar ground. */
    strong: '#17173A',
    /** Body copy and table cells. */
    base: '#43436B',
    /** Labels, captions, secondary metadata. */
    muted: '#8A8AA3',
    /** Timestamps and other tertiary detail. */
    faint: '#B0B0C3',
    /** Inactive tab-bar icons and labels. */
    disabled: '#9C9CB2',
    /** Chevrons and other decorative marks. */
    hint: '#C2C2D4',
    onDark: '#FFFFFF',
    onDarkMuted: 'rgba(255,255,255,0.68)',
    onDarkFaint: 'rgba(255,255,255,0.45)',
  },

  /** Backgrounds, from the page ground upward. */
  surface: {
    /** The application canvas. */
    canvas: '#F6F6F9',
    /** The ground the phone frame sits on in the mobile mockups. */
    canvasDeep: '#E9E9F0',
    /** Cards, tables, sheets. */
    raised: '#FFFFFF',
    /** Inputs and inset wells. */
    sunken: '#FAFAFC',
    /** Table row hover. */
    hover: '#FAFAFD',
    /** Segmented-control track. */
    track: '#ECECF2',
    /** Progress-bar track. */
    meter: '#EFEFF5',
    /** The Main Admin sidebar. */
    inverse: '#17173A',
    inverseHover: 'rgba(255,255,255,0.08)',
    inverseWash: 'rgba(255,255,255,0.12)',
  },

  /** Hairlines, in descending weight. */
  border: {
    /** Card and control outlines. */
    base: '#E7E7EF',
    /** Input outlines. */
    input: '#E3E3EC',
    /** Nested panels inside a card. */
    subtle: '#F0F0F6',
    /** Table row separators. */
    faint: '#F6F6FA',
    /** Activity-feed separators. */
    ghost: '#F3F3F8',
    /** Border on hover. */
    hover: '#C9C9DB',
    /** Destructive-action outline. */
    danger: '#F3C4C4',
    onDark: 'rgba(255,255,255,0.1)',
  },

  /**
   * Subscription and account state.
   * These map one-to-one onto the statuses in `@warq/core`.
   */
  status: {
    active: '#16A34A',
    pending: '#D97706',
    expiringSoon: '#EA580C',
    expired: '#DC2626',
    suspended: '#8A8AA3',
    idle: '#D97706',
    info: '#0E7490',
  },

  /** Attendance marks — the P · A · L toggle. */
  attendance: {
    present: '#16A34A',
    absent: '#DC2626',
    late: '#D97706',
  },

  /** Letter grades. Bands themselves live in `@warq/core`. */
  grade: {
    'A+': '#16A34A',
    A: '#16A34A',
    B: '#0E7490',
    C: '#D97706',
    D: '#EA580C',
    F: '#DC2626',
    /** Not yet marked. */
    none: '#B0B0C3',
  },

  /**
   * Rotating palette for class colour bars. Assigned by index so a class keeps
   * the same colour on web and mobile.
   */
  series: ['#4338CA', '#0E7490', '#B45309', '#16A34A', '#BE185D', '#7C3AED'] as const,

  /** Modal and drawer scrims. */
  overlay: {
    light: 'rgba(23,23,58,0.35)',
    base: 'rgba(23,23,58,0.4)',
    heavy: 'rgba(23,23,58,0.45)',
  },
} as const;

/**
 * Composes an eight-digit hex from a six-digit one.
 * The mockups tint status pills by appending `1A` (10%) or `14` (8%) to a hex.
 */
export function tint(hex: string, alpha: '0A' | '14' | '18' | '1A'): string {
  return `${hex}${alpha}`;
}
