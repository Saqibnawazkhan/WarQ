/**
 * Warq typography.
 *
 * Two families, as set in the mockups: Sora carries headings and figures,
 * Public Sans carries everything else. Both are self-hosted from M2 onward so
 * the apps never depend on a font CDN at runtime.
 */

export const fontFamily = {
  /** Headings, statistics, initials. Weights 400 / 600 / 700 / 800. */
  display: "Sora, 'Segoe UI', -apple-system, BlinkMacSystemFont, system-ui, sans-serif",
  /** Body copy, labels, table cells. Weights 400 / 500 / 600 / 700. */
  body: "'Public Sans', 'Segoe UI', -apple-system, BlinkMacSystemFont, system-ui, sans-serif",
  /** Roll numbers, IDs, marks — anything that should line up in a column. */
  mono: "ui-monospace, 'Cascadia Code', 'SF Mono', Consolas, 'Liberation Mono', monospace",
} as const;

/**
 * The type scale, in pixels, exactly as used in the mockups.
 * Half-pixel sizes are intentional — they are what the designs specify.
 */
export const fontSize = {
  /** Tab-bar labels, badge counts. */
  '2xs': 10,
  /** Uppercase eyebrows, timestamps. */
  xs: 11,
  /** Captions, secondary metadata. */
  sm: 11.5,
  /** Table metadata, chips. */
  base: 12.5,
  /** Body copy, buttons. */
  md: 13.5,
  /** List rows, inputs. */
  lg: 14,
  /** Card titles. */
  xl: 15,
  /** Drawer titles. */
  '2xl': 18,
  /** Screen titles on mobile. */
  '3xl': 22,
  /** Page titles. */
  '4xl': 24,
  /** Dashboard statistics. */
  '5xl': 26,
} as const;

export const fontWeight = {
  regular: 400,
  medium: 500,
  semibold: 600,
  bold: 700,
  heavy: 800,
} as const;

export const lineHeight = {
  tight: 1.1,
  snug: 1.25,
  base: 1.45,
  relaxed: 1.5,
  loose: 1.55,
} as const;

/** Letter-spacing for the uppercase eyebrow labels that head each section. */
export const letterSpacing = {
  tight: '-0.02em',
  normal: '0',
  wide: '0.06em',
  wider: '0.08em',
  widest: '0.09em',
} as const;
