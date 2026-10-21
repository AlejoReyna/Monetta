// Every custom property the stylesheets read must be defined by the stylesheets or set by the shell.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import test from 'node:test';

const dir = new URL('../../src/styles/', import.meta.url);
const css = readdirSync(dir)
  .filter((name) => name.endsWith('.css'))
  .map((name) => readFileSync(new URL(name, dir), 'utf8'))
  .join('\n');
const sources = ['../../src/lib/chrome.js', '../../src/main.js', '../../src/components/shell.js', '../../src/components/ui.js', '../../src/pages/design.js', '../../src/pages/product.js', '../../src/pages/collection.js']
  .map((file) => readFileSync(new URL(file, import.meta.url), 'utf8'))
  .join('\n');

const defined = new Set([...css.matchAll(/(--[a-z0-9-]+)\s*:/gi)].map((m) => m[1]));
// Properties written from script (setProperty) or inline styles count as defined.
for (const m of sources.matchAll(/(--[a-z0-9-]+)\s*[:,'"]/gi)) defined.add(m[1]);

test('every var(--x) with no fallback is defined somewhere', () => {
  const missing = new Set();
  for (const m of css.matchAll(/var\((--[a-z0-9-]+)\s*([,)])/gi)) {
    if (m[2] === ',') continue; // has a fallback
    if (!defined.has(m[1])) missing.add(m[1]);
  }
  assert.deepEqual([...missing], []);
});

test('the generated block defines the semantic roles the components rely on', () => {
  for (const name of ['--color-action-primary', '--color-on-action-primary', '--color-surface-warm', '--color-surface-tile', '--color-border-control', '--color-navigation-active', '--color-navigation-inactive', '--color-sale-surface', '--type-product-name-size', '--type-section-title-size']) {
    assert.ok(defined.has(name), `${name} missing`);
  }
});
