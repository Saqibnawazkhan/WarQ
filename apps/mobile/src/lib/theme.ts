/**
 * The Warq design system, as React Native values.
 *
 * Same source as the web app — `@warq/tokens` — so a colour or a radius cannot
 * drift between the two. What differs is only the shape: React Native wants
 * numbers where CSS wants strings with units.
 */

import { color, fontSize, radius, space } from '@warq/tokens';

export const theme = {
  color,
  radius,
  space,
  text: fontSize,

  /**
   * Font families.
   *
   * Sora and Public Sans are loaded at start-up. Until they are ready the
   * platform default stands in, which is why the splash screen is held rather
   * than showing a frame of the wrong typeface.
   */
  font: {
    display: 'Sora_700Bold',
    displayHeavy: 'Sora_800ExtraBold',
    body: 'PublicSans_400Regular',
    bodyMedium: 'PublicSans_500Medium',
    bodySemibold: 'PublicSans_600SemiBold',
    bodyBold: 'PublicSans_700Bold',
  },
} as const;

/** Shadows, expressed the way each platform expects. */
export const elevation = {
  card: {
    shadowColor: '#17173A',
    shadowOpacity: 0.05,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 2,
  },
  action: {
    shadowColor: '#17173A',
    shadowOpacity: 0.22,
    shadowRadius: 16,
    shadowOffset: { width: 0, height: 8 },
    elevation: 8,
  },
} as const;

/**
 * A hit target big enough to use.
 *
 * Attendance is taken standing in front of a class, often quickly. 44 points is
 * the smallest square a thumb hits reliably, and every tappable control here
 * meets it whatever its visual size.
 */
export const MIN_TOUCH = 44;
