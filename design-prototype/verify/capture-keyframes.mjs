// Keyframe captures for the style-guideline migration: Inicio, Colección, Producto and Cuenta, plus the
// component board, at 390, 834 and 1440 px.
//
//   npm run capture:keyframes -- --out=../docs/style-guideline-migration/2026-10-20/m1/after
//   npm run capture:keyframes -- --out=<dir> --skip-build --only=home,product --full
//
// --out is required: every run replaces the .jpg files of its output folder, and the evidence folders are kept.
import { mkdir, readdir, unlink, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { launch } from './browser.mjs';
import { scrollThrough } from './report.mjs';
import { build, startPreview } from './server.mjs';

const args = Object.fromEntries(process.argv.slice(2).map((arg) => arg.replace(/^--/, '').split('=')).map(([key, value = 'true']) => [key, value]));
if (!args.out) throw new Error('pass --out=<folder>; this script replaces the .jpg files of that folder');
const root = fileURLToPath(new URL('..', import.meta.url));
const outDir = path.resolve(root, args.out);

const SIZES = [
  ['390', { width: 390, height: 844 }, 2],
  ['834', { width: 834, height: 1194 }, 2],
  ['1440', { width: 1440, height: 900 }, 1],
];

const SCREENS = [
  ['inicio', '/'],
  ['coleccion', '/collections/coach'],
  ['producto', '/products/bolso-coach-shoulder-negro-rectangular'],
  ['cuenta', '/design/cuenta'],
  ['board', '/design/board'],
];

const only = args.only ? args.only.split(',') : null;
const screens = SCREENS.filter(([name]) => !only || only.includes(name));

if (!args['skip-build']) await build();
const server = await startPreview(Number(args.port ?? 4175));
const { browser, version } = await launch();
await mkdir(outDir, { recursive: true });
if (!only) for (const file of await readdir(outDir)) if (file.endsWith('.jpg')) await unlink(path.join(outDir, file));

const index = [];
try {
  for (const [screen, route] of screens) {
    for (const [label, viewport, dpr] of SIZES) {
      const context = await browser.newContext({ viewport, deviceScaleFactor: dpr, reducedMotion: 'reduce' });
      const page = await context.newPage();
      const problems = [];
      page.on('pageerror', (error) => problems.push(error.message));
      page.on('console', (message) => message.type() === 'error' && problems.push(message.text()));
      await page.goto(`${server.url}${route}`, { waitUntil: 'networkidle' });
      await page.evaluate(() => document.fonts.ready);
      await scrollThrough(page);
      const top = `${screen}__${label}__top.jpg`;
      await page.screenshot({ path: path.join(outDir, top), type: 'jpeg', quality: 86 });
      let full = null;
      if (args.full !== 'false') {
        full = `${screen}__${label}__full.jpg`;
        await page.screenshot({ path: path.join(outDir, full), type: 'jpeg', quality: 80, fullPage: true });
      }
      const metrics = await page.evaluate(() => ({
        scrollWidth: document.documentElement.scrollWidth,
        clientWidth: document.documentElement.clientWidth,
        height: document.documentElement.scrollHeight,
      }));
      index.push({ screen, viewport: label, route, top, full, ...metrics, problems });
      await context.close();
    }
  }
  await writeFile(path.join(outDir, 'index.json'), `${JSON.stringify({ browser: version, capturedAt: new Date().toISOString(), shots: index }, null, 2)}\n`);
  const horizontal = index.filter((shot) => shot.scrollWidth > shot.clientWidth);
  console.log(`${index.length} viewport captures in ${path.relative(process.cwd(), outDir)}; horizontal page scroll in ${horizontal.length}; problems in ${index.filter((s) => s.problems.length).length}`);
} finally {
  server.stop();
  await browser.close();
}
