// Check only an isolated copy of this delivery, never the shared theme/suites.
import { mkdir, readdir, copyFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { theme, evidence } from './fixture.mjs';

const fixture = fileURLToPath(new URL('./theme-check-fixture/', import.meta.url));
for (const directory of ['assets', 'snippets', 'sections', 'layout', 'config', 'locales', 'templates']) {
  await mkdir(path.join(fixture, directory), { recursive: true });
  if (['assets', 'snippets', 'sections'].includes(directory)) {
    for (const name of await readdir(path.join(theme, directory))) {
      if (name.startsWith('monetta-predictive-')) await copyFile(path.join(theme, directory, name), path.join(fixture, directory, name));
    }
  }
}
await writeFile(path.join(fixture, 'layout/theme.liquid'), '<!doctype html><html lang="{{ request.locale.iso_code }}"><head><title>{{ page_title }}</title>{{ content_for_header }}</head><body>{{ content_for_layout }}</body></html>\n');
await writeFile(path.join(fixture, 'config/settings_schema.json'), '[]\n');
await writeFile(path.join(fixture, 'locales/en.default.json'), '{}\n');
await writeFile(path.join(fixture, '.theme-check.yml'), 'extends: theme-check:recommended\n');
const result = spawnSync('shopify', ['theme', 'check', '--path', fixture, '--no-color', '--no-input', '--output', 'json'], {
  encoding: 'utf8',
  env: { ...process.env, SHOPIFY_CLI_NO_ANALYTICS: '1' },
  maxBuffer: 4 * 1024 * 1024,
});
await mkdir(evidence, { recursive: true });
await writeFile(path.join(evidence, 'theme-check.json'), result.stdout || '[]');
await writeFile(path.join(evidence, 'theme-check.stderr.txt'), result.stderr || '');
if (result.stdout) console.log(result.stdout.trim());
if (result.stderr) console.error(result.stderr.trim());
if (result.error) throw result.error;
process.exitCode = result.status || (/Error:/.test(result.stderr) ? 1 : 0);
