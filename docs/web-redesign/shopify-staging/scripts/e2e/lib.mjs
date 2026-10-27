// Shared harness for the theme's browser checks. Every run identifies store, theme, code state, command, time and
// result, and is written to its own folder under docs/web-redesign/shopify-staging/runs/ (never over an earlier run).
// A run that ends early is saved as result.partial.json with the checks it did reach, never as a complete result.
import { createRequire } from 'node:module';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../../..');
export const staging = path.join(root, 'docs/web-redesign/shopify-staging');
const require = createRequire(path.join(root, 'design-prototype/package.json'));
export const { chromium } = require('playwright-core');

export function parseArgs(argv = process.argv.slice(2)) {
  const out = {};
  for (const a of argv) {
    const text = a.replace(/^--/, '');
    const at = text.indexOf('=');
    if (at < 0) out[text] = 'true';
    else out[text.slice(0, at)] = text.slice(at + 1);
  }
  return out;
}

const env = Object.fromEntries(
  readFileSync(path.join(staging, 'THEME.env'), 'utf8')
    .split('\n')
    .filter((l) => /^[A-Z_]+=/.test(l))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1).replace(/^"|"$/g, '')]),
);
export const target = { store: env.STORE, themeId: env.THEME_ID, themeName: env.THEME_NAME, themeDir: env.THEME_DIR };

/** SHA-256 over the sorted per-file digests of the theme workspace: the "code state" of a run. */
export function treeDigest(dir = target.themeDir) {
  const lines = [];
  const walk = (d) => {
    for (const name of readdirSync(d).sort()) {
      if (name === '.DS_Store') continue;
      const full = path.join(d, name);
      if (statSync(full).isDirectory()) walk(full);
      else lines.push(`${createHash('sha256').update(readFileSync(full)).digest('hex')}  ./${path.relative(dir, full)}`);
    }
  };
  walk(dir);
  return { files: lines.length, sha256: createHash('sha256').update(`${lines.join('\n')}\n`).digest('hex') };
}

function git(...args) {
  try {
    return execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trim();
  } catch {
    return null;
  }
}

export function browserPath() {
  return process.env.BROWSER_PATH || '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser';
}

export class Run {
  constructor(name, { baseUrl, extra = {} } = {}) {
    this.name = name;
    this.startedAt = new Date();
    const stamp = this.startedAt.toISOString().replace(/[:.]/g, '-');
    this.dir = path.join(staging, 'runs', `${stamp}-${name}`);
    mkdirSync(this.dir, { recursive: true });
    this.checks = [];
    this.notes = [];
    this.meta = {
      run: name,
      command: `node ${path.relative(root, process.argv[1])} ${process.argv.slice(2).join(' ')}`.trim(),
      startedAt: this.startedAt.toISOString(),
      store: target.store,
      theme: { id: target.themeId, name: target.themeName },
      baseUrl,
      codeState: { storefrontTheme: treeDigest(), repoHead: git('rev-parse', 'HEAD'), repoBranch: git('rev-parse', '--abbrev-ref', 'HEAD') },
      browser: browserPath(),
      ...extra,
    };
    console.log(`run dir: ${this.dir}`);
  }

  /** `kind` is 'assertion' (the default, not stored) or 'error': a check that failed because the script itself could not run it. */
  check(name, pass, detail = '', kind = 'assertion') {
    this.checks.push({ name, pass: Boolean(pass), detail: typeof detail === 'string' ? detail : JSON.stringify(detail), ...(kind === 'assertion' ? {} : { kind }) });
    console.log(`${pass ? 'PASS' : 'FAIL'}  ${name}${detail ? `  — ${typeof detail === 'string' ? detail : JSON.stringify(detail)}` : ''}`);
    return Boolean(pass);
  }

  note(text) {
    this.notes.push(text);
    console.log(`note  ${text}`);
  }

  file(name) {
    return path.join(this.dir, name);
  }

  finish({ complete = true, error = null } = {}) {
    const failed = this.checks.filter((c) => !c.pass).length;
    const result = {
      ...this.meta,
      finishedAt: new Date().toISOString(),
      status: error ? 'partial-error' : complete ? (failed ? 'complete-with-failures' : 'complete-pass') : 'partial',
      error: error ? String(error.stack || error) : null,
      summary: { checks: this.checks.length, passed: this.checks.length - failed, failed },
      checks: this.checks,
      notes: this.notes,
    };
    const file = this.file(error || !complete ? 'result.partial.json' : 'result.json');
    writeFileSync(file, `${JSON.stringify(result, null, 2)}\n`);
    console.log(`\n${result.status}: ${result.summary.passed}/${result.summary.checks} checks · ${file}`);
    return result;
  }
}

export async function launch({ width, height, insets = null, reducedMotion = 'no-preference', hasTouch = false, deviceScaleFactor = 1, injectCss = null }) {
  const browser = await chromium.launch({ executablePath: browserPath(), headless: true });
  const context = await browser.newContext({ viewport: { width, height }, reducedMotion, hasTouch, isMobile: false, deviceScaleFactor });
  const page = await context.newPage();
  // Negative controls: a stylesheet added to every document of the run, to reintroduce a known defect and see the check fail.
  if (injectCss) {
    await page.addInitScript((css) => {
      document.addEventListener('DOMContentLoaded', () => {
        const style = document.createElement('style');
        style.textContent = css;
        document.head.append(style);
      });
    }, injectCss);
  }
  if (insets) {
    const client = await context.newCDPSession(page);
    await client.send('Emulation.setSafeAreaInsetsOverride', { insets: { top: 0, bottom: 0, left: insets, right: insets } });
  }
  return { browser, context, page };
}

/**
 * Waits for web fonts and for every image to be complete and decoded, so a capture shows what a visitor sees. Lazy
 * images outside the viewport (rails, drawers) never load by themselves, so they are switched to eager first; one that
 * still has not loaded after the time limit is reported instead of blocking the run.
 */
export async function settle(page, { timeoutMs = 20000 } = {}) {
  const pending = await page.evaluate(async (limit) => {
    await document.fonts.ready;
    const imgs = [...document.images].filter((i) => i.currentSrc || i.src || i.getAttribute('src'));
    for (const i of imgs) i.loading = 'eager';
    const deadline = new Promise((r) => setTimeout(() => r('timeout'), limit));
    const loaded = Promise.all(
      imgs.map((i) => (i.complete ? Promise.resolve() : new Promise((r) => { i.addEventListener('load', r, { once: true }); i.addEventListener('error', r, { once: true }); }))),
    ).then(() => Promise.all(imgs.map((i) => i.decode().catch(() => {}))));
    const outcome = await Promise.race([loaded, deadline]);
    return outcome === 'timeout' ? imgs.filter((i) => !i.complete || !i.naturalWidth).map((i) => i.currentSrc || i.src) : [];
  }, timeoutMs);
  await page.waitForTimeout(250);
  return pending;
}

export async function imageReport(page, scopeSelector = 'body') {
  return page.evaluate((scope) => {
    const root = document.querySelector(scope) || document.body;
    const imgs = [...root.querySelectorAll('img')].filter((i) => i.getClientRects().length && getComputedStyle(i).visibility !== 'hidden');
    const broken = imgs.filter((i) => !i.complete || i.naturalWidth === 0).map((i) => i.currentSrc || i.src);
    return { total: imgs.length, broken };
  }, scopeSelector);
}
