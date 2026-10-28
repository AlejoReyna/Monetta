// Fixes the state of the prototype's code tree by hash, so every run can say which state it covers.
//
//   node estado-del-arbol.mjs --root=<design-prototype or a copy> --out=<manifest.sha256>
//
// The set is the one the archive of the previous corrections carried: src/, verify/, tests/,
// index.html, vite.config.js, package.json, package-lock.json and README.md (verify/output and
// OS litter excluded). The manifest has one `sha256  path` line per file, sorted, and a last
// `# tree <digest>` line: the sha256 of those lines. Two trees with the same digest are the same code.
import { createHash } from 'node:crypto';
import { readdir, readFile, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';

const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
if (!args.root) throw new Error('--root=<prototype folder> is required');
const root = path.resolve(args.root);
const INCLUDE = ['src', 'verify', 'tests', 'index.html', 'vite.config.js', 'package.json', 'package-lock.json', 'README.md'];
const SKIP = (relative) => relative.startsWith('verify/output') || relative.endsWith('.DS_Store');

async function walk(relative) {
  const full = path.join(root, relative);
  const info = await stat(full).catch(() => null);
  if (!info) return [];
  if (info.isFile()) return SKIP(relative) ? [] : [relative];
  const entries = await readdir(full);
  const nested = await Promise.all(entries.map((entry) => walk(path.posix.join(relative, entry))));
  return nested.flat();
}

const files = (await Promise.all(INCLUDE.map((entry) => walk(entry)))).flat().sort();
const lines = [];
for (const file of files) lines.push(`${createHash('sha256').update(await readFile(path.join(root, file))).digest('hex')}  ${file}`);
const digest = createHash('sha256').update(`${lines.join('\n')}\n`).digest('hex');
const manifest = `${lines.join('\n')}\n# tree ${digest}\n`;
if (args.out) await writeFile(path.resolve(args.out), manifest);
console.log(`${files.length} files, tree ${digest}`);
