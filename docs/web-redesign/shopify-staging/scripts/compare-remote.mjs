// Downloads the draft theme into a NEW empty temporary folder (read-only against the store) and compares it with storefront-theme/,
// file by file. Differences are split: identical bytes, JSON files that differ only in formatting (equal after parsing), and real
// content differences, plus files present on one side only.
//   node docs/web-redesign/shopify-staging/scripts/compare-remote.mjs --out=<folder>
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const staging = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = Object.fromEntries(readFileSync(path.join(staging, 'THEME.env'), 'utf8').split('\n').filter((l) => /^[A-Z_]+=/.test(l)).map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')]));
const out = path.resolve(process.argv.find((a) => a.startsWith('--out='))?.slice(6) || staging);
mkdirSync(out, { recursive: true });
const local = env.THEME_DIR;
const remote = mkdtempSync(path.join(process.env.TMPDIR || tmpdir(), 'monetta-remote-'));

const list = (dir) => {
  const files = [];
  const walk = (d) => {
    for (const name of readdirSync(d)) {
      if (name === '.DS_Store' || name.startsWith('._')) continue;
      const full = path.join(d, name);
      if (statSync(full).isDirectory()) walk(full);
      else files.push(path.relative(dir, full));
    }
  };
  walk(dir);
  return files.sort();
};
const sha = (buffer) => createHash('sha256').update(buffer).digest('hex');
const digest = (dir, files) => sha(`${files.map((f) => `${sha(readFileSync(path.join(dir, f)))}  ./${f}`).join('\n')}\n`);
// Shopify stores its JSON templates with a leading /* ... */ comment block and its own formatting: comments outside strings are dropped
// before parsing.
function withoutComments(text) {
  let out2 = '';
  let inString = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inString) {
      out2 += c;
      if (c === '\\') out2 += text[++i];
      else if (c === '"') inString = false;
    } else if (c === '"') {
      inString = true;
      out2 += c;
    } else if (c === '/' && text[i + 1] === '*') {
      i = text.indexOf('*/', i + 2) + 1;
    } else if (c === '/' && text[i + 1] === '/') {
      while (i < text.length && text[i] !== '\n') i++;
    } else {
      out2 += c;
    }
  }
  return out2;
}
// Same canonical form for JSON: parsed and re-serialised with sorted keys, so key order and whitespace do not count.
const canonical = (value) => JSON.stringify(value, (key, v) => (v && typeof v === 'object' && !Array.isArray(v) ? Object.fromEntries(Object.entries(v).sort(([a], [b]) => a.localeCompare(b))) : v));

// Guard: only the authorised draft is read.
const info = spawnSync('shopify', ['theme', 'list', '--store', env.STORE, '--id', env.THEME_ID, '--json', '--no-color'], { encoding: 'utf8' });
const listed = JSON.parse(info.stdout.split('\n').filter((l) => !l.startsWith('<claude-code-hint')).join('\n'));
if (listed.length !== 1 || listed[0].role !== 'unpublished' || listed[0].name !== env.THEME_NAME) throw new Error(`unexpected target: ${info.stdout}`);

const startedAt = new Date().toISOString();
const pull = spawnSync('shopify', ['theme', 'pull', '--store', env.STORE, '--theme', env.THEME_ID, '--path', remote, '--no-color', '--force'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const localFiles = list(local);
const remoteFiles = list(remote);
const remoteOnly = remoteFiles.filter((f) => !localFiles.includes(f));
const localOnly = localFiles.filter((f) => !remoteFiles.includes(f));
const contentDifferences = [];
const formatOnlyDifferences = [];
let identical = 0;
for (const file of localFiles.filter((f) => remoteFiles.includes(f))) {
  const a = readFileSync(path.join(local, file));
  const b = readFileSync(path.join(remote, file));
  if (a.equals(b)) {
    identical += 1;
    continue;
  }
  if (file.endsWith('.json')) {
    try {
      if (canonical(JSON.parse(withoutComments(a.toString('utf8')))) === canonical(JSON.parse(withoutComments(b.toString('utf8'))))) {
        formatOnlyDifferences.push(file);
        continue;
      }
    } catch {
      /* a JSON file that does not parse on one side is a real difference */
    }
  }
  contentDifferences.push({ file, localSha256: sha(a), remoteSha256: sha(b) });
}
const result = {
  checkedAt: new Date().toISOString(),
  startedAt,
  command: `shopify theme pull --store ${env.STORE} --theme ${env.THEME_ID} --path <new temporary folder> --no-color --force`,
  store: env.STORE,
  theme: { id: env.THEME_ID, name: listed[0].name, role: listed[0].role },
  pullExitCode: pull.status,
  temporaryPath: remote,
  localFiles: localFiles.length,
  remoteFiles: remoteFiles.length,
  localTreeSha256: digest(local, localFiles),
  remoteTreeSha256: digest(remote, remoteFiles),
  identicalBytes: identical,
  remoteOnly,
  localOnly,
  contentDifferences,
  formatOnlyDifferences,
  equivalent: pull.status === 0 && remoteOnly.length === 0 && localOnly.length === 0 && contentDifferences.length === 0,
};
writeFileSync(path.join(out, 'remote-comparison.json'), `${JSON.stringify(result, null, 2)}\n`);
console.log(JSON.stringify({ ...result, remoteOnly: remoteOnly.length, localOnly: localOnly.length, contentDifferences: contentDifferences.length }, null, 2));
process.exit(result.equivalent ? 0 : 1);
