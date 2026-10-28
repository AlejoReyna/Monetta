// Runs Theme Check on storefront-theme/ and compares it with the inherited baseline FINDING BY FINDING, not by totals.
//   node docs/web-redesign/shopify-staging/scripts/theme-check-compare.mjs --out=<folder>
// Writes <out>/theme-check.json (the raw tool output, tool diagnostics removed), <out>/theme-check.tool-output.txt (what the tool printed
// besides the JSON) and <out>/theme-check-compare.json (the comparison). Exit code 0 only when no finding is introduced.
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const staging = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const root = path.resolve(staging, '../../..');
const theme = path.join(root, 'storefront-theme');
const out = path.resolve(process.argv.find((a) => a.startsWith('--out='))?.slice(6) || path.join(staging, 'runs'));
mkdirSync(out, { recursive: true });

const rel = (p) => path.relative(theme, p);
const keyOf = (file, o, withPosition) => `${file}|${o.check}|${o.severity}|${withPosition ? `${o.start_row}:${o.start_column}|` : ''}${o.message}`;
const flatten = (list) => list.flatMap((entry) => entry.offenses.map((o) => ({ file: rel(entry.path), ...o })));
const multiset = (items, withPosition) => {
  const map = new Map();
  for (const item of items) map.set(keyOf(item.file, item, withPosition), (map.get(keyOf(item.file, item, withPosition)) || 0) + 1);
  return map;
};
const difference = (a, b) => {
  const out2 = [];
  for (const [key, n] of a) if (n > (b.get(key) || 0)) out2.push({ key, extra: n - (b.get(key) || 0) });
  return out2;
};

const started = new Date().toISOString();
const run = spawnSync('shopify', ['theme', 'check', '--path', theme, '--output', 'json', '--no-color'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const stdout = run.stdout || '';
const toolLines = [];
const jsonText = stdout
  .split('\n')
  .filter((line) => {
    if (/^<claude-code-hint\b/.test(line)) {
      toolLines.push(line);
      return false;
    }
    return true;
  })
  .join('\n');
const current = JSON.parse(jsonText);
const baselineRaw = JSON.parse(readFileSync(path.join(staging, 'baseline/theme-check-baseline.json'), 'utf8'));
writeFileSync(path.join(out, 'theme-check.json'), `${JSON.stringify(current)}\n`);
writeFileSync(path.join(out, 'theme-check.tool-output.txt'), `${toolLines.join('\n')}${toolLines.length ? '\n' : ''}--- stderr ---\n${run.stderr || ''}`);

const now = flatten(current);
const base = flatten(baselineRaw);
const sev = (list) => ({ errors: list.filter((o) => o.severity === 'error').length, warnings: list.filter((o) => o.severity === 'warning').length, info: list.filter((o) => !['error', 'warning'].includes(o.severity)).length });
const strictIntro = difference(multiset(now, true), multiset(base, true));
const relaxedIntro = difference(multiset(now, false), multiset(base, false));
const strictGone = difference(multiset(base, true), multiset(now, true));

// Files of the delivery: everything that is not in the Atelier backup manifest, plus the five JSON templates it modified.
const manifest = new Set(readFileSync(path.join(staging, 'baseline/atelier-3.5.0-staging-live-copy.manifest.sha256'), 'utf8').split('\n').filter(Boolean).map((l) => l.slice(l.indexOf('  ') + 2).replace(/^\.\//, '')));
const files = [];
const walk = (d) => {
  for (const name of readdirSync(d)) {
    const full = path.join(d, name);
    if (statSync(full).isDirectory()) walk(full);
    else if (!name.startsWith('._') && name !== '.DS_Store') files.push(rel(full));
  }
};
walk(theme);
const delivered = files.filter((f) => !manifest.has(f));
const inDelivered = now.filter((o) => delivered.includes(o.file) || ['templates/index.json', 'templates/collection.json', 'templates/product.json', 'templates/cart.json', 'templates/search.json'].includes(o.file));

const result = {
  startedAt: started,
  command: 'shopify theme check --path storefront-theme --output json --no-color',
  exitCode: run.status,
  note: 'exit code 1 is expected: the inherited Atelier base has errors; what must hold is that nothing is introduced',
  totals: { baseline: sev(base), current: sev(now) },
  findings: { baseline: base.length, current: now.length },
  introduced: { strict: strictIntro, relaxedIgnoringPosition: relaxedIntro },
  resolvedOrMoved: strictGone,
  inDeliveredFiles: inDelivered,
  deliveredFiles: delivered.length,
  rawSha256: createHash('sha256').update(jsonText).digest('hex'),
  toolDiagnostics: toolLines,
  verdict: strictIntro.length === 0 && relaxedIntro.length === 0 && inDelivered.length === 0 ? 'no findings introduced' : 'FINDINGS INTRODUCED',
};
writeFileSync(path.join(out, 'theme-check-compare.json'), `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify({ totals: result.totals, findings: result.findings, introducedStrict: strictIntro.length, introducedRelaxed: relaxedIntro.length, resolvedOrMoved: strictGone.length, inDeliveredFiles: inDelivered.length, deliveredFiles: delivered.length, verdict: result.verdict }, null, 2));
process.exit(result.verdict === 'no findings introduced' ? 0 : 1);
