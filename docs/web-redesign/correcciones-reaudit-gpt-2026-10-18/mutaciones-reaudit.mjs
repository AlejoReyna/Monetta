// Mutation runs for the corrections of RE-01 and RE-02: in a temporary copy of the corrected tree one piece of the
// fix is taken out at a time, the copy is built and served, and the new checks run against it. A piece that nothing
// notices is not needed, or not covered; a check that fails for a piece it should not care about is too broad.
//
//   node mutaciones-reaudit.mjs --tmp=<folder outside the repository> --out=<results.json> [--only=name,name]
//
// The tree under test is never modified: copies (src, verify, tests, index.html, vite.config.js, package*.json)
// go to --tmp with symlinks to node_modules, public, fixtures and scripts. Ports 4611 and up; the checks are the
// ones of the corrected tree, pointed at each copy with --grep.
import { spawn } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const proto = fileURLToPath(new URL('../../../design-prototype/', import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
if (!args.tmp || !args.out) throw new Error('--tmp=<folder outside the repository> and --out=<results.json> are required');
const tmp = path.resolve(args.tmp);
if (tmp.startsWith(path.resolve(proto, '..'))) throw new Error('--tmp must be outside the repository');
const only = args.only ? new Set(args.only.split(',')) : null;

const replaceOnce = (text, from, to) => {
  if (text.split(from).length !== 2) throw new Error(`mutation anchor not found exactly once: ${from.slice(0, 70)}`);
  return text.replace(from, to);
};

const MUTATIONS = [
  { name: 'control-sin-mutar', grep: 'RE-0', patches: [], note: 'the corrected tree, copied and served like the others' },
  {
    name: 'sin-espacio-al-final-de-la-fila',
    grep: 'RE-02',
    note: 'the row keeps the inset ring but loses its end padding: the last link cannot scroll out of the fade',
    patches: [['src/styles/components.css', (s) => replaceOnce(s, '    padding-right: max(calc(var(--gutter) - 12px), var(--safe-right), calc(12% + 8px));\n', '')]],
  },
  {
    name: 'anillo-fuera-de-la-caja',
    grep: 'RE-02',
    note: 'the row keeps its end padding but the ring goes back outside the 44px link: the row clips its top and bottom',
    patches: [['src/styles/components.css', (s) => replaceOnce(s, '  .site-nav__link:focus-visible {\n    outline-offset: -4px;\n  }\n', '')]],
  },
  {
    name: 'limite-de-ancho-1024',
    grep: 'RE-01',
    note: 'the short-window rule is limited to < 1024px wide again',
    patches: [['src/styles/pages.css', (s) => replaceOnce(s, '@media (max-height: 480px) {', '@media (max-width: 1023.98px) and (max-height: 480px) {')]],
  },
  {
    name: 'sin-columnas-de-escritorio',
    grep: 'RE-01',
    note: 'the rule applies at every width but the sticky columns and the fitted gallery keep their header-sized formulas',
    patches: [
      [
        'src/styles/pages.css',
        (s) =>
          replaceOnce(
            s,
            `  .collection-layout--filters .filter-sidebar {
    position: static;
    max-height: none;
    overflow: visible;
  }

  .gallery__thumbs {
    max-height: none;
  }

  .gallery__main {
    max-width: none;
  }

  .product-panel,
  .cart-layout .summary {
    position: static;
  }
`,
            '',
          ),
      ],
    ],
  },
  {
    name: 'fila-centrada-con-desborde',
    grep: ['RE-01 with 44px', 'desktop row stays centred'],
    note: 'the desktop row is centred with justify-content again (instead of a row as wide as its links): when it overflows, the first link ends up under the inset',
    patches: [
      [
        'src/styles/components.css',
        (s) =>
          replaceOnce(
            s,
            `  .site-nav__list {
    width: fit-content;
    max-width: min(100%, var(--content-max));
    padding: 0 var(--edge-r) 0 var(--edge-l);
    -webkit-mask-image: none;
    mask-image: none;
    scroll-padding-inline: 12px;
  }
}`,
            `  .site-nav__list {
    justify-content: center;
    padding: 0 var(--edge-r) 0 var(--edge-l);
    -webkit-mask-image: none;
    mask-image: none;
    scroll-padding-inline: 12px;
  }
}`,
          ),
      ],
    ],
  },
];

const run = (command, commandArgs, options = {}) =>
  new Promise((resolve) => {
    const child = spawn(command, commandArgs, { ...options, stdio: ['ignore', 'pipe', 'pipe'] });
    let output = '';
    child.stdout.on('data', (chunk) => (output += chunk));
    child.stderr.on('data', (chunk) => (output += chunk));
    child.on('close', (code) => resolve({ code, output }));
  });

const waitFor = async (url) => {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    try {
      if ((await fetch(url)).ok) return;
    } catch {
      // not up yet
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error(`server at ${url} did not come up`);
};

rmSync(tmp, { recursive: true, force: true });
mkdirSync(tmp, { recursive: true });
const results = { ranAt: new Date().toISOString(), mutations: [] };
let port = 4611;
for (const mutation of MUTATIONS) {
  if (only && !only.has(mutation.name)) continue;
  const dir = path.join(tmp, mutation.name);
  mkdirSync(dir, { recursive: true });
  for (const entry of ['src', 'verify', 'tests', 'index.html', 'vite.config.js', 'package.json', 'package-lock.json']) cpSync(path.join(proto, entry), path.join(dir, entry), { recursive: true });
  for (const entry of ['node_modules', 'public', 'fixtures', 'scripts']) if (existsSync(path.join(proto, entry))) symlinkSync(path.join(proto, entry), path.join(dir, entry));
  for (const [file, patch] of mutation.patches) writeFileSync(path.join(dir, file), patch(readFileSync(path.join(dir, file), 'utf8')));
  const built = await run('node', ['node_modules/vite/bin/vite.js', 'build'], { cwd: dir });
  if (built.code !== 0) throw new Error(`build of ${mutation.name} failed:\n${built.output.slice(-600)}`);
  const server = spawn('node', ['node_modules/vite/bin/vite.js', 'preview', '--port', String(port), '--strictPort', '--host', '127.0.0.1'], { cwd: dir, stdio: 'ignore' });
  try {
    await waitFor(`http://127.0.0.1:${port}/`);
    // The checks are those of the corrected tree; only the served build is the mutated copy.
    const lines = [];
    for (const grep of [mutation.grep].flat()) {
      const checked = await run('node', [path.join(proto, 'verify/check-reaudit-fixes.mjs'), `--url=http://127.0.0.1:${port}`, `--grep=${grep}`]);
      lines.push(...checked.output.split('\n').filter((line) => /^(PASS|FAIL) \[D11\]/.test(line)));
    }
    const entries = lines.map((line) => ({ passed: line.startsWith('PASS'), name: line.replace(/^(PASS|FAIL) \[D11\] /, '').split(' — ')[0], detail: line.includes(' — ') ? line.split(' — ').slice(1).join(' — ').slice(0, 260) : '' }));
    results.mutations.push({ name: mutation.name, note: mutation.note, grep: mutation.grep, port, passed: entries.filter((entry) => entry.passed).length, failed: entries.filter((entry) => !entry.passed).length, checks: entries });
    console.log(`${mutation.name.padEnd(36)} ${entries.filter((entry) => entry.passed).length} pass · ${entries.filter((entry) => !entry.passed).length} fail`);
  } finally {
    server.kill();
  }
  port += 1;
}
writeFileSync(path.resolve(args.out), `${JSON.stringify(results, null, 2)}\n`);
console.log(`Saved ${path.resolve(args.out)}`);
