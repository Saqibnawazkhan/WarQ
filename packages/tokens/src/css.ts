/**
 * Compiles the token objects into CSS custom properties.
 *
 * The web app consumes the generated stylesheet and maps it into Tailwind's
 * theme; the native app consumes the same TypeScript objects directly. One
 * source, two targets — a colour changes in `color.ts` and nowhere else.
 */

import { accents, color } from './color.js';
import { fontFamily, fontSize, fontWeight, letterSpacing, lineHeight } from './typography.js';
import { motion, radius, shadow, size, space } from './layout.js';

export const CSS_VAR_PREFIX = 'warq';

type Primitive = string | number;

interface TokenTree {
  readonly [key: string]: Primitive | readonly Primitive[] | TokenTree;
}

/** `accentHover` → `accent-hover`, `A+` → `a-plus`, `0.5` → `0-5`. */
function slug(key: string): string {
  return key
    .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
    .toLowerCase()
    .replace(/\+/g, '-plus')
    .replace(/\./g, '-');
}

type TokenValue = Primitive | readonly Primitive[] | TokenTree;

function isPrimitive(value: TokenValue): value is Primitive {
  return typeof value === 'string' || typeof value === 'number';
}

/**
 * Narrows to a nested group.
 *
 * Written as an explicit predicate rather than a bare `Array.isArray` check:
 * `Array.isArray` narrows to a mutable `any[]`, which leaves a `readonly` array
 * sitting in the false branch and forces an assertion downstream.
 */
function isTree(value: Exclude<TokenValue, Primitive>): value is TokenTree {
  return !Array.isArray(value);
}

/** Walks a token object depth-first, emitting `[cssName, rawValue]` pairs. */
function flatten(tree: TokenTree, path: readonly string[] = []): [string, Primitive][] {
  const out: [string, Primitive][] = [];

  for (const [key, value] of Object.entries(tree)) {
    const next = [...path, slug(key)];

    if (isPrimitive(value)) {
      out.push([next.join('-'), value]);
    } else if (isTree(value)) {
      out.push(...flatten(value, next));
    } else {
      // A rotating palette, e.g. the six class-bar colours.
      value.forEach((item, index) => {
        out.push([[...next, String(index)].join('-'), item]);
      });
    }
  }

  return out;
}

type Unit = 'px' | 'ms' | 'none';

function withUnit(value: Primitive, unit: Unit): string {
  if (typeof value === 'string' || unit === 'none') return String(value);
  return `${value}${unit}`;
}

interface Group {
  readonly name: string;
  readonly prefix: string;
  readonly tokens: TokenTree;
  readonly unit: Unit;
}

const GROUPS: readonly Group[] = [
  { name: 'Colour', prefix: '', tokens: color, unit: 'none' },
  { name: 'Type family', prefix: 'font', tokens: fontFamily, unit: 'none' },
  { name: 'Type scale', prefix: 'text', tokens: fontSize, unit: 'px' },
  { name: 'Type weight', prefix: 'weight', tokens: fontWeight, unit: 'none' },
  { name: 'Line height', prefix: 'leading', tokens: lineHeight, unit: 'none' },
  { name: 'Letter spacing', prefix: 'tracking', tokens: letterSpacing, unit: 'none' },
  { name: 'Radius', prefix: 'radius', tokens: radius, unit: 'px' },
  { name: 'Space', prefix: 'space', tokens: space, unit: 'px' },
  { name: 'Shadow', prefix: 'shadow', tokens: shadow, unit: 'none' },
  { name: 'Motion', prefix: 'motion', tokens: motion, unit: 'ms' },
  { name: 'Size', prefix: 'size', tokens: size, unit: 'px' },
];

/** Every token as a flat `{ '--warq-…': value }` map. Useful for tests and inline styles. */
export function cssVariables(): Record<string, string> {
  const vars: Record<string, string> = {};

  for (const group of GROUPS) {
    for (const [name, value] of flatten(group.tokens)) {
      const key = group.prefix ? `${group.prefix}-${name}` : name;
      vars[`--${CSS_VAR_PREFIX}-${key}`] = withUnit(value, group.unit);
    }
  }

  return vars;
}

/** Reference a token from a stylesheet or an inline style: `cssVar('brand-accent')`. */
export function cssVar(name: string, fallback?: string): string {
  const variable = `--${CSS_VAR_PREFIX}-${name}`;
  return fallback ? `var(${variable}, ${fallback})` : `var(${variable})`;
}

/**
 * Renders the complete stylesheet, including the accent overrides that back the
 * theme switch exposed in the mockups (`<html data-accent="teal">`).
 */
export function renderStylesheet(): string {
  const lines: string[] = [
    '/*',
    ' * Warq design tokens — GENERATED FILE, DO NOT EDIT.',
    ' * Source: packages/tokens/src/*.ts   Regenerate: npm run build -w @warq/tokens',
    ' */',
    '',
    ':root {',
    '  color-scheme: light;',
  ];

  for (const group of GROUPS) {
    lines.push('', `  /* ${group.name} */`);
    for (const [name, value] of flatten(group.tokens)) {
      const key = group.prefix ? `${group.prefix}-${name}` : name;
      lines.push(`  --${CSS_VAR_PREFIX}-${key}: ${withUnit(value, group.unit)};`);
    }
  }

  lines.push('}', '');
  lines.push('/* Accent themes. Default is indigo, declared above. */');

  for (const [name, hex] of Object.entries(accents)) {
    if (name === 'indigo') continue;
    lines.push(
      `[data-accent='${name}'] {`,
      `  --${CSS_VAR_PREFIX}-brand-accent: ${hex};`,
      `  --${CSS_VAR_PREFIX}-brand-accent-wash: ${hex}14;`,
      '}',
    );
  }

  lines.push('');
  return lines.join('\n');
}
