// baseline/themes-before.json is the historical "before" list of themes. The Shopify CLI plugin printed a one-line tool diagnostic
// (<claude-code-hint .../>) ahead of the JSON when it was saved, so the file is not valid JSON. The original is never touched: this
// writes a normalised copy next to it (the diagnostic line removed, nothing else) plus a provenance record with both digests, and
// verifies that the copy parses and that its content equals the original's JSON part byte for byte.
//   node docs/web-redesign/shopify-staging/scripts/normalize-themes-before.mjs
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const baseline = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../baseline');
const sha = (buffer) => createHash('sha256').update(buffer).digest('hex');
const original = readFileSync(path.join(baseline, 'themes-before.json'));
const text = original.toString('utf8');
const lines = text.split('\n');
const removed = [];
while (lines.length && /^<claude-code-hint\b[^>]*\/>\s*$/.test(lines[0])) removed.push(lines.shift());
const normalised = lines.join('\n');
const parsed = JSON.parse(normalised); // throws if still not JSON
if (!Array.isArray(parsed) || !parsed.every((t) => Number.isInteger(t.id) && typeof t.name === 'string' && typeof t.role === 'string')) throw new Error('unexpected shape: not a list of themes');
if (text !== `${removed.join('\n')}${removed.length ? '\n' : ''}${normalised}`) throw new Error('the normalised copy differs from the original in more than the removed lines');

writeFileSync(path.join(baseline, 'themes-before.normalized.json'), normalised);
const provenance = {
  note: 'Normalised copy of baseline/themes-before.json (historical list of themes BEFORE the first delivery, 2026-10-19). It is not a new query: the "before" stays the one captured then.',
  source: { file: 'baseline/themes-before.json', sha256: sha(original), bytes: original.length, changed: false },
  transformation: 'removed the leading CLI plugin diagnostic line(s); the rest is byte-identical',
  removedLines: removed,
  result: { file: 'baseline/themes-before.normalized.json', sha256: sha(Buffer.from(normalised)), bytes: Buffer.byteLength(normalised) },
  validation: { jsonParses: true, themes: parsed.length, roles: Object.fromEntries(parsed.map((t) => [t.id, t.role])), restOfFileIdenticalToOriginal: true },
  producedBy: 'docs/web-redesign/shopify-staging/scripts/normalize-themes-before.mjs',
};
writeFileSync(path.join(baseline, 'themes-before.normalized.provenance.json'), `${JSON.stringify(provenance, null, 2)}\n`);
console.log(JSON.stringify(provenance, null, 2));
