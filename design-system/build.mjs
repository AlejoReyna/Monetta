// Generates the Monetta style tokens for every surface from one manifest.
//
//   node design-system/build.mjs                      write the outputs
//   node design-system/build.mjs --check              fail when an output is stale or a contrast gate fails
//   node design-system/build.mjs --dart-out=<path>    Flutter file (default lib/app/monetta_tokens.g.dart)
//   node design-system/build.mjs --only=css|dart      limit the outputs (the Flutter file lives in another checkout)
//
// Outputs
//  * design-prototype/src/styles/tokens.css   the block between the @generated markers. The Shopify theme
//    receives it through tools/style-guideline-theme/port-css.mjs, never by hand.
//  * lib/app/monetta_tokens.g.dart            constants only; theme.dart and boutique_tokens.dart adapt them.
//
// The contrast gate is part of the build: a manifest whose listed pairs miss their minimum does not generate.
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const args = process.argv.slice(2);
const flag = (name) => args.find((a) => a.startsWith(`--${name}=`))?.slice(name.length + 3);
const check = args.includes('--check');

const manifestText = readFileSync(path.join(here, 'monetta.tokens.json'), 'utf8');
const tokens = JSON.parse(manifestText);
const digest = createHash('sha256').update(manifestText).digest('hex');

// ---- colour helpers
const hex = (value) => {
  const m = /^#([0-9a-f]{6})([0-9a-f]{2})?$/i.exec(value);
  if (!m) throw new Error(`bad colour ${value}`);
  return { rgb: m[1].toUpperCase(), alpha: m[2] ? parseInt(m[2], 16) / 255 : 1, a8: (m[2] ?? 'FF').toUpperCase() };
};
const channel = (v) => {
  const s = v / 255;
  return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
};
const luminance = (rgb) => {
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(rgb.slice(i, i + 2), 16));
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b);
};
const ratio = (fg, bg) => {
  const a = luminance(hex(fg).rgb);
  const b = luminance(hex(bg).rgb);
  return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
};
const cssColor = (value) => {
  const c = hex(value);
  if (c.alpha === 1) return `#${c.rgb.toLowerCase()}`;
  const [r, g, b] = [0, 2, 4].map((i) => parseInt(c.rgb.slice(i, i + 2), 16));
  return `rgba(${r}, ${g}, ${b}, ${Number(c.alpha.toFixed(3))})`;
};
const dartColor = (value) => {
  const c = hex(value);
  return `Color(0x${c.a8}${c.rgb})`;
};
const kebab = (s) => s.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`);
const cap = (s) => s[0].toUpperCase() + s.slice(1);

// ---- contrast gate
const light = tokens.color.light;
const failures = [];
const rows = tokens.contrast.map((pair) => {
  const value = ratio(light[pair.fg], light[pair.bg]);
  const ok = value >= pair.min;
  if (!ok) failures.push(`${pair.fg} on ${pair.bg}: ${value.toFixed(2)}:1 < ${pair.min}:1 (${pair.use})`);
  return `${ok ? 'ok  ' : 'FAIL'} ${value.toFixed(2).padStart(5)}:1 (min ${pair.min})  ${pair.fg} on ${pair.bg} — ${pair.use}`;
});
console.log(rows.join('\n'));
if (failures.length) {
  console.error(`\n${failures.length} contrast pair(s) below their minimum:\n- ${failures.join('\n- ')}`);
  process.exit(1);
}

// ---- CSS
const bp = tokens.layout.breakpoint;
const sizes = (name) => tokens.type.role[name].size;
const roleNames = Object.keys(tokens.type.role);
// The web stacks keep the bundled faces first and add system faces, as the earlier hand-written tokens did.
const WEB_STACK = {
  serif: `'Playfair Display', Georgia, 'Times New Roman', serif`,
  sans: `'Inter', system-ui, -apple-system, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif`,
};
const familyCss = (key) => WEB_STACK[key];

const colorLines = Object.entries(light).map(([k, v]) => `  --color-${kebab(k)}: ${cssColor(v)};`);
const legacy = [
  '  /* Names the components already use. They point at the semantic roles above; new work uses the roles. */',
  '  --color-surface-deep: var(--color-surface-tile);',
  '  --color-gold-text: var(--color-accent-text);',
  '  --color-hairline: var(--color-divider);',
  '  --color-hairline-strong: var(--color-border-control);',
  '  --color-on-dark: var(--color-on-photo);',
  '  --color-dock-ink: var(--color-ink);',
  '  --color-ink-on-warm: var(--color-ink);',
];
const base = [
  ...colorLines,
  ...legacy,
  '',
  '  /* Type families and roles (compact values; medium and expanded override below) */',
  `  --font-serif: ${familyCss('serif')};`,
  `  --font-sans: ${familyCss('sans')};`,
  ...roleNames.flatMap((name) => {
    const r = tokens.type.role[name];
    const n = kebab(name);
    return [
      `  --type-${n}-font: var(--font-${r.family});`,
      `  --type-${n}-weight: ${r.weight};`,
      `  --type-${n}-lh: ${r.lineHeight};`,
      `  --type-${n}-track: ${r.tracking}em;`,
      `  --type-${n}-size: ${r.size.compact}px;`,
    ];
  }),
  '',
  '  /* Geometry */',
  `  --radius-card: ${tokens.radius.card}px;`,
  `  --radius-control: ${tokens.radius.control}px;`,
  `  --radius-tile: ${tokens.radius.tile}px;`,
  `  --radius-chip: ${tokens.radius.chip}px;`,
  `  --radius-pill: ${tokens.radius.pill}px;`,
  `  --radius-sheet: ${tokens.radius.sheet}px;`,
  `  --radius-dock: ${tokens.radius.bar}px;`,
  ...tokens.space.map((v, i) => `  --space-${i + 1}: ${v}px;`),
  `  --gutter: ${tokens.layout.gutter.compact}px;`,
  `  --content-max: ${tokens.layout.contentMax}px;`,
  `  --control: ${tokens.size.control}px;`,
  `  --tap: ${tokens.size.tap}px;`,
  `  --header-h: ${tokens.size.headerCompact}px;`,
  `  --logo-h: ${tokens.size.logoHeight}px;`,
  `  --cols-product: ${tokens.layout.columns.product.compact};`,
  `  --cols-category: ${tokens.layout.columns.category.compact};`,
  '',
  '  /* Motion */',
  `  --dur-snap: ${tokens.motion.snap}ms;`,
  `  --dur-swap: ${tokens.motion.swap}ms;`,
  `  --dur-settle: ${tokens.motion.settle}ms;`,
  `  --ease: cubic-bezier(${tokens.motion.easing.join(', ')});`,
  '',
  '  /* Elevation */',
  ...Object.entries(tokens.elevation).map(([k, v]) => `  --shadow-${k}: ${v.replace(/#([0-9a-f]{8})/gi, (m) => cssColor(m))};`),
  '  --shadow-dock: none;',
];
const responsive = (label, query, overrides) => [
  `/* ${label} */`,
  `@media ${query} {`,
  '  :root {',
  ...overrides.map((l) => `  ${l}`),
  '  }',
  '}',
];
const roleOverrides = (key) => roleNames.map((name) => `  --type-${kebab(name)}-size: ${sizes(name)[key]}px;`);
const css = [
  ':root {',
  ...base,
  '}',
  '',
  ...responsive('Narrow phones', '(max-width: 359.98px)', [`  --gutter: ${tokens.layout.gutter.narrow}px;`, `  --cols-product: ${tokens.layout.columns.product.narrow};`]),
  '',
  ...responsive('Medium: tablets and large phones in landscape', `(min-width: ${bp.medium}px)`, [
    `  --gutter: ${tokens.layout.gutter.medium}px;`,
    `  --header-h: ${tokens.size.headerMedium}px;`,
    `  --cols-product: ${tokens.layout.columns.product.medium};`,
    `  --cols-category: ${tokens.layout.columns.category.medium};`,
    ...roleOverrides('medium'),
  ]),
  '',
  ...responsive('Expanded: desktop', `(min-width: ${bp.expanded}px)`, [
    `  --gutter: ${tokens.layout.gutter.expanded}px;`,
    `  --header-h: ${tokens.size.headerExpanded}px;`,
    `  --cols-product: ${tokens.layout.columns.product.expanded};`,
    `  --cols-category: ${tokens.layout.columns.category.expanded};`,
    ...roleOverrides('expanded'),
  ]),
  '',
  ...responsive('Wide desktop', `(min-width: ${bp.wide}px)`, [`  --gutter: ${tokens.layout.gutter.wide}px;`]),
].join('\n');

const START = '/* @generated:tokens:start — design-system/build.mjs from design-system/monetta.tokens.json; edit the manifest, not this block */';
const END = '/* @generated:tokens:end */';
const generatedBlock = `${START}\n${css}\n${END}`;

const cssPath = path.join(root, 'design-prototype/src/styles/tokens.css');
const currentCss = readFileSync(cssPath, 'utf8');
const startAt = currentCss.indexOf('/* @generated:tokens:start');
const endAt = currentCss.indexOf(END);
if (startAt < 0 || endAt < 0) throw new Error('tokens.css has no @generated:tokens markers; add them once by hand');
const nextCss = currentCss.slice(0, startAt) + generatedBlock + currentCss.slice(endAt + END.length);

// ---- Dart
const dartRoleLines = roleNames.map((name) => {
  const r = tokens.type.role[name];
  return `  static const MonettaTypeRole ${name} = MonettaTypeRole(\n    serif: ${r.family === 'serif'},\n    weight: ${r.weight},\n    lineHeight: ${r.lineHeight},\n    tracking: ${r.tracking},\n    compact: ${r.size.compact},\n    medium: ${r.size.medium},\n    expanded: ${r.size.expanded},\n  );`;
});
const dartColors = Object.entries(light).map(([k, v]) => `  static const Color ${k} = ${dartColor(v)};`);
const dartDark = Object.entries(tokens.color.darkRolesOnly)
  .filter(([k]) => !k.startsWith('$'))
  .map(([k, v]) => `  static const Color dark${cap(k)} = ${dartColor(v)};`);
const dart = `// GENERATED by design-system/build.mjs from design-system/monetta.tokens.json
// (sha256 ${digest}). Do not edit: change the manifest and regenerate.
//
// Constants only, so lib/domain-style purity holds. app/theme.dart (MonettaColors) and
// features/boutique/boutique_tokens.dart adapt these values to widgets.
//
// Kept byte-for-byte as generated, so dart format must leave it alone.
// dart format off
library;

import 'dart:ui' show Color;

/// One typographic role at the three width classes. The sizes are logical pixels before the user's
/// text scale; widgets pick one with [MonettaTypeRole.sizeFor].
final class MonettaTypeRole {
  const MonettaTypeRole({
    required this.serif,
    required this.weight,
    required this.lineHeight,
    required this.tracking,
    required this.compact,
    required this.medium,
    required this.expanded,
  });

  final bool serif;
  final int weight;
  final double lineHeight;

  /// Letter spacing in em.
  final double tracking;
  final double compact;
  final double medium;
  final double expanded;

  double sizeFor(double width) {
    if (width >= MonettaTokens.breakpointExpanded) return expanded;
    if (width >= MonettaTokens.breakpointMedium) return medium;
    return compact;
  }
}

abstract final class MonettaTokens {
  static const String version = '${tokens.version}';
  static const String manifestSha256 =
      '${digest}';

  // Light palette (semantic roles).
${dartColors.join('\n')}

  // Roles that dark mode did not have before; the rest of dark stays in MonettaColors.dark.
${dartDark.join('\n')}

  // Geometry.
  static const double radiusCard = ${tokens.radius.card};
  static const double radiusControl = ${tokens.radius.control};
  static const double radiusTile = ${tokens.radius.tile};
  static const double radiusPill = ${tokens.radius.pill};
  static const double radiusSheet = ${tokens.radius.sheet};
  static const List<double> space = <double>[${tokens.space.join(', ')}];
  static const double controlHeight = ${tokens.size.control};
  static const double tapTarget = ${tokens.size.tap};
  static const double logoHeight = ${tokens.size.logoHeight};

  // Layout.
  static const double breakpointMedium = ${bp.medium};
  static const double breakpointExpanded = ${bp.expanded};
  static const double breakpointWide = ${bp.wide};
  static const double contentMax = ${tokens.layout.contentMax};
  static const double gutterNarrow = ${tokens.layout.gutter.narrow};
  static const double gutterCompact = ${tokens.layout.gutter.compact};
  static const double gutterMedium = ${tokens.layout.gutter.medium};
  static const double gutterExpanded = ${tokens.layout.gutter.expanded};
  static const double gutterWide = ${tokens.layout.gutter.wide};
  static const int productColumnsNarrow = ${tokens.layout.columns.product.narrow};
  static const int productColumnsCompact = ${tokens.layout.columns.product.compact};
  static const int productColumnsMedium = ${tokens.layout.columns.product.medium};
  static const int productColumnsExpanded = ${tokens.layout.columns.product.expanded};
  static const int categoryColumnsCompact = ${tokens.layout.columns.category.compact};
  static const int categoryColumnsMedium = ${tokens.layout.columns.category.medium};
  static const int categoryColumnsExpanded = ${tokens.layout.columns.category.expanded};

  /// Gutter for an available width, following the manifest's bands.
  static double gutterFor(double width) {
    if (width >= breakpointWide) return gutterWide;
    if (width >= breakpointExpanded) return gutterExpanded;
    if (width >= breakpointMedium) return gutterMedium;
    if (width < 360) return gutterNarrow;
    return gutterCompact;
  }

  // Type roles.
${dartRoleLines.join('\n')}
}
`;

const dartPath = path.resolve(root, flag('dart-out') ?? 'lib/app/monetta_tokens.g.dart');

// ---- write or check
const only = flag('only');
const outputs = [
  ...(!only || only === 'css' ? [[cssPath, nextCss]] : []),
  ...(!only || only === 'dart' ? [[dartPath, dart]] : []),
];
let stale = 0;
for (const [file, content] of outputs) {
  const current = existsSync(file) ? readFileSync(file, 'utf8') : null;
  if (check) {
    if (current !== content) {
      stale += 1;
      console.error(`stale: ${path.relative(root, file)}`);
    }
  } else if (current !== content) {
    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, content);
    console.log(`wrote ${path.relative(root, file)}`);
  } else {
    console.log(`unchanged ${path.relative(root, file)}`);
  }
}
if (check && stale) process.exit(1);
if (check) console.log('tokens: outputs are current and every contrast pair passes');
