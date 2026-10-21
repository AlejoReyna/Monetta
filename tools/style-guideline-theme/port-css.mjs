// Ports the approved prototype stylesheets (design-prototype/src/styles) to the Shopify theme.
//
//   node tools/style-guideline-theme/port-css.mjs
//
// What it changes, and nothing else:
//  * tokens.css  -> assets/monetta-tokens.css   @font-face moves to snippets/monetta-fonts.liquid
//                                               (asset URLs need Liquid); --strip-h becomes 0 because the
//                                               theme has no prototype strip.
//  * base.css    -> assets/monetta-base.css     bare element selectors are scoped with :where(.mw), a
//                                               zero-specificity ancestor, so app widgets and payment buttons
//                                               keep winning with their own class rules.
//  * components.css, pages.css                  prototype-only rules are dropped (see DROP); everything else is
//                                               copied byte for byte so the verified measurements travel intact.
// Run it again after editing the prototype; the output is deterministic.
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const require = createRequire(path.join(root, 'design-prototype/package.json'));
const postcss = require('postcss');

const src = (name) => readFileSync(path.join(root, 'design-prototype/src/styles', name), 'utf8');
const out = (name, css) => writeFileSync(path.join(root, 'storefront-theme/assets', name), css);

// Prototype scaffolding or surfaces that are not part of this delivery's theme.
const DROP = [
  /^\.proto-strip/,
  /^\.demo-/,
  /^\.img-fallback/,
  /^\.handoff-list/,
  /^\.message-preview/,
  /^\.sample-note/,
  /^\.search-panel/,
  /^\.search-option/,
  /^\.search-footer/,
  /^\.search-status/,
  /^\.search-skeleton/,
  /^\.search-predict/,
  /^\.search-error/,
  /^\.review-card/,
  /^\.reviews-/,
  /^\.quick-view/,
  /^\.account-/,
  /^\.policy-body/,
  /^\.unavailable-row/,
  /^\.editorial-hero/,
  /^\.panel/,
  /^\.steps?\b/,
  /^\.terms?\b/,
  /^\.catalog-/,
  /^\.timeline/,
  /^\.trust-list/,
  /^\.two-col/,
  /^\.about-card/,
  /^\.social-/,
  /^\.brand-/,
  /^\.beauty-panel/,
  /^\.search-discovery/,
  /^\.search-row/,
  // Design-review surfaces of the style-guideline migration (/design/cuenta, /design/board).
  /^\.board/,
  /^\.dock--static/,
];

const keep = (selector) => !DROP.some((re) => re.test(selector.trim()));

function filterRules(root_) {
  root_.walkRules((rule) => {
    if (rule.parent?.type === 'atrule' && /keyframes$/.test(rule.parent.name)) return;
    const kept = rule.selectors.filter(keep);
    if (kept.length === 0) rule.remove();
    else if (kept.length !== rule.selectors.length) rule.selectors = kept;
  });
  root_.walkAtRules((atRule) => {
    if (atRule.nodes && atRule.nodes.length === 0) atRule.remove();
  });
}

// ---- tokens
{
  const tree = postcss.parse(src('tokens.css'));
  tree.walkAtRules('font-face', (atRule) => atRule.remove());
  tree.walkDecls('--strip-h', (decl) => {
    decl.value = '0px';
  });
  tree.first.raws.before = '';
  const header = `/* Monetta tokens, ported from design-prototype/src/styles/tokens.css by tools/style-guideline-theme/port-css.mjs.\n   @font-face lives in snippets/monetta-fonts.liquid (asset URLs need Liquid). --strip-h is 0: the theme has no prototype strip. */\n`;
  out('monetta-tokens.css', header + tree.toString().replace(/^\s*\/\*[\s\S]*?\*\/\s*/, ''));
}

// ---- base: scope bare element selectors
{
  const tree = postcss.parse(src('base.css'));
  const scope = (selector) => {
    const s = selector.trim();
    if (s === 'html' || s === ':root') return s;
    if (s === 'body') return 'body.mw';
    if (s.startsWith('html.')) return s;
    // Only selectors that start with a class or id are already specific enough.
    if (/^[.#]/.test(s)) return s;
    if (s.startsWith('::selection')) return s;
    return `:where(.mw) ${s}`;
  };
  tree.walkRules((rule) => {
    if (rule.parent?.type === 'atrule' && /keyframes$/.test(rule.parent.name)) return;
    rule.selectors = rule.selectors.map(scope);
  });
  filterRules(tree);
  out('monetta-base.css', `/* Ported from design-prototype/src/styles/base.css; bare element selectors are scoped with :where(.mw). */\n${tree.toString()}`);
}

// ---- components + pages
for (const [file, dest] of [
  ['components.css', 'monetta-components.css'],
  ['pages.css', 'monetta-pages.css'],
]) {
  const tree = postcss.parse(src(file));
  filterRules(tree);
  tree.walkRules((rule) => {
    if (rule.parent?.type === 'atrule' && /keyframes$/.test(rule.parent.name)) return;
    // main is the one bare element in these files.
    rule.selectors = rule.selectors.map((s) => (/^main\b/.test(s.trim()) ? `:where(.mw) ${s.trim()}` : s));
  });
  out(dest, `/* Ported from design-prototype/src/styles/${file}; prototype-only surfaces dropped (tools/style-guideline-theme/port-css.mjs). */\n${tree.toString()}`);
}
console.log('ported: monetta-tokens.css monetta-base.css monetta-components.css monetta-pages.css');
