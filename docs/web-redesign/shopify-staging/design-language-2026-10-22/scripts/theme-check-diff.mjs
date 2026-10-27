// Theme Check against the baseline recorded before this pass (baseline/theme-check-before.json), finding by finding.
//   node theme-check-diff.mjs --out=<absolute folder>
// Writes <out>/theme-check-after.json (raw), <out>/theme-check-diff.json and prints a summary. A finding is keyed by file,
// check, severity and message; positions are ignored so that an inherited finding whose line moved is not counted as new.
// Exit code 0 only when nothing was introduced.
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const evidence = path.resolve(here, '..');
const theme = path.resolve(evidence, '../../../../storefront-theme');
const out = process.argv.find((a) => a.startsWith('--out='))?.slice(6);
if (!out || !path.isAbsolute(out)) throw new Error('--out=<absolute folder> is required');
mkdirSync(out, { recursive: true });

const parse = (text) => JSON.parse(text.split('\n').filter((l) => !/^<claude-code-hint\b/.test(l)).join('\n'));
const flatten = (list) => list.flatMap((e) => e.offenses.map((o) => ({ file: path.relative(theme, e.path), check: o.check, severity: o.severity, message: o.message, row: o.start_row })));
const key = (o) => `${o.file}|${o.check}|${o.severity}|${o.message}`;
const count = (items) => items.reduce((m, o) => m.set(key(o), (m.get(key(o)) || 0) + 1), new Map());

const run = spawnSync('shopify', ['theme', 'check', '--path', theme, '--output', 'json', '--no-color'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
writeFileSync(path.join(out, 'theme-check-after.json'), run.stdout);
const after = flatten(parse(run.stdout));
const before = flatten(parse(readFileSync(path.join(evidence, 'baseline/theme-check-before.json'), 'utf8')));
const a = count(after);
const b = count(before);
const introduced = [];
const resolved = [];
for (const [k, n] of a) if (n > (b.get(k) || 0)) introduced.push({ finding: k, extra: n - (b.get(k) || 0), rows: after.filter((o) => key(o) === k).map((o) => o.row) });
for (const [k, n] of b) if (n > (a.get(k) || 0)) resolved.push({ finding: k, fewer: n - (a.get(k) || 0) });
const sev = (list) => ({ errors: list.filter((o) => o.severity === 'error').length, warnings: list.filter((o) => o.severity === 'warning').length });
const result = { ranAt: new Date().toISOString(), theme, before: sev(before), after: sev(after), introduced, resolvedOrRemoved: resolved };
writeFileSync(path.join(out, 'theme-check-diff.json'), `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify({ before: result.before, after: result.after, introduced: introduced.length, resolvedOrRemoved: resolved.length }, null, 1));
for (const i of introduced) console.log(`NEW  ${i.finding} (rows ${i.rows.join(',')})`);
for (const r of resolved) console.log(`GONE ${r.finding}`);
process.exit(introduced.length ? 1 : 0);
