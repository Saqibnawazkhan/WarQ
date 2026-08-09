/**
 * @warq/tokens — the single source for Warq's visual language.
 *
 * Web imports the generated stylesheet (`@warq/tokens/tokens.css`) and maps it
 * into Tailwind. Native imports these objects directly. Neither redefines a value.
 */

export { accents, color, tint, type AccentName } from './color.js';
export { fontFamily, fontSize, fontWeight, letterSpacing, lineHeight } from './typography.js';
export { motion, radius, shadow, size, space } from './layout.js';
export { CSS_VAR_PREFIX, cssVar, cssVariables, renderStylesheet } from './css.js';
