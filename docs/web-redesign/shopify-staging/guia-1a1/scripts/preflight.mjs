// Theme Check on a staged change before it reaches storefront-theme/. The `shopify theme dev` proxy uploads every
// saved file at once, and one that Shopify rejects (a Liquid syntax error) turns every page of the preview into an
// upload-error page, so a change is checked on a scratch copy of the theme first.
//
//   node preflight.mjs --overlay=<absolute folder laid out like storefront-theme/>
//
// Prints every error and warning in the overlaid files; exit 1 when any of them is an error.
import { cpSync, mkdtempSync, readdirSync, rmSync, statSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const theme = path.resolve(here, '../../../../../storefront-theme');
const overlay = process.argv.find((a) => a.startsWith('--overlay='))?.slice(10);
if (!overlay || !path.isAbsolute(overlay)) throw new Error('--overlay=<absolute folder> is required');

const files = [];
const walk = (dir) => {
  for (const name of readdirSync(dir)) {
    const full = path.join(dir, name);
    if (statSync(full).isDirectory()) walk(full);
    else files.push(path.relative(overlay, full));
  }
};
walk(overlay);

const scratch = mkdtempSync(path.join(process.env.TMPDIR || tmpdir(), 'monetta-preflight-'));
try {
  cpSync(theme, scratch, { recursive: true });
  cpSync(overlay, scratch, { recursive: true });
  const run = spawnSync('shopify', ['theme', 'check', '--path', scratch, '--output', 'json', '--no-color'], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  const report = JSON.parse(run.stdout.split('\n').filter((l) => !/^<claude-code-hint\b/.test(l)).join('\n'));
  let errors = 0;
  for (const entry of report) {
    const rel = path.relative(scratch, entry.path);
    if (!files.includes(rel)) continue;
    for (const o of entry.offenses) {
      if (o.check === 'OrphanedSnippet') continue;
      if (o.severity === 'error') errors += 1;
      console.log(`${o.severity.padEnd(7)} ${rel}:${o.start_row + 1}  ${o.check}  ${o.message}`);
    }
  }
  console.log(`preflight: ${files.length} file(s), ${errors} error(s)`);
  process.exitCode = errors ? 1 : 0;
} finally {
  rmSync(scratch, { recursive: true, force: true });
}
