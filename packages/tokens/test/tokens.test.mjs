import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { accents, color, cssVar, cssVariables, renderStylesheet, tint } from '../dist/index.js';

const HEX = /^#[0-9A-F]{6}$/;

describe('palette', () => {
  it('exposes the four accents the mockups offer as a theme switch', () => {
    assert.deepEqual(Object.keys(accents), ['indigo', 'teal', 'amber', 'navy']);
    for (const [name, hex] of Object.entries(accents)) {
      assert.match(hex, HEX, `${name} must be a six-digit uppercase hex`);
    }
  });

  it('defaults to the indigo accent from the mockups', () => {
    assert.equal(color.brand.accent, '#4338CA');
    assert.equal(color.brand.accent, accents.indigo);
  });

  it('colours every subscription status', () => {
    assert.deepEqual(Object.keys(color.status), [
      'active',
      'pending',
      'expiringSoon',
      'expired',
      'suspended',
      'idle',
      'info',
    ]);
  });

  it('colours every letter grade the scale can produce', () => {
    for (const band of ['A+', 'A', 'B', 'C', 'D', 'F']) {
      assert.match(color.grade[band], HEX, `grade ${band} needs a colour`);
    }
  });

  it('gives each attendance mark a distinct colour', () => {
    const marks = Object.values(color.attendance);
    assert.equal(new Set(marks).size, marks.length);
  });

  it('rotates six series colours for class bars', () => {
    assert.equal(color.series.length, 6);
    assert.equal(new Set(color.series).size, 6);
  });
});

describe('tint', () => {
  it('appends the alpha channel the mockups use for status pills', () => {
    assert.equal(tint('#16A34A', '1A'), '#16A34A1A');
    assert.equal(tint(color.brand.accent, '14'), '#4338CA14');
  });
});

describe('css generation', () => {
  const vars = cssVariables();

  it('namespaces every variable under --warq-', () => {
    const keys = Object.keys(vars);
    assert.ok(keys.length > 60, `expected a full token set, got ${keys.length}`);
    assert.ok(keys.every((key) => key.startsWith('--warq-')));
  });

  it('slugs awkward token names into valid custom properties', () => {
    assert.equal(vars['--warq-grade-a-plus'], '#16A34A');
    assert.equal(vars['--warq-status-expiring-soon'], '#EA580C');
    assert.equal(vars['--warq-space-0-5'], '2px');
    assert.equal(vars['--warq-series-0'], '#4338CA');
  });

  it('attaches units only where a unit belongs', () => {
    assert.equal(vars['--warq-radius-full'], '999px');
    assert.equal(vars['--warq-text-lg'], '14px');
    assert.equal(vars['--warq-motion-duration-slow'], '220ms');
    assert.equal(vars['--warq-weight-heavy'], '800');
    assert.equal(vars['--warq-leading-base'], '1.45');
  });

  it('builds a reference with an optional fallback', () => {
    assert.equal(cssVar('brand-accent'), 'var(--warq-brand-accent)');
    assert.equal(cssVar('brand-accent', '#4338CA'), 'var(--warq-brand-accent, #4338CA)');
  });

  it('renders a stylesheet with a root block and the accent overrides', () => {
    const css = renderStylesheet();
    assert.match(css, /^\/\*\n \* Warq design tokens — GENERATED FILE/);
    assert.match(css, /:root \{/);
    assert.match(css, /color-scheme: light;/);
    assert.match(css, /\[data-accent='teal'\] \{/);
    assert.match(css, /--warq-brand-accent: #0F766E;/);
    assert.ok(!css.includes("[data-accent='indigo']"), 'indigo is the default, not an override');
  });

  it('emits every variable it reports', () => {
    const css = renderStylesheet();
    for (const [name, value] of Object.entries(vars)) {
      assert.ok(css.includes(`${name}: ${value};`), `stylesheet is missing ${name}`);
    }
  });
});
