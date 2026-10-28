// Health and identity check of the single `shopify theme dev` proxy the browser checks read through. Every wait is bounded.
// It answers three questions before a run may report results:
//   1. is exactly one HEALTHY proxy for the authorised draft theme answering (a leftover whose storefront session expired and now
//      redirects to /password is reported as `expired`, not counted as healthy, and never used)?
//   2. is the document it serves the expected theme (Shopify.theme.id / role / name from THEME.env, layout class "mw")?
//   3. are the theme scripts it serves byte-identical to the local files (so edits made after the last sync are not tested)?
// Anything that fails is classified as a proxy incident and kept with its time, URL and detail; none is retried silently.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { target } from './lib.mjs';

const sha = (buffer) => createHash('sha256').update(buffer).digest('hex');

/** Incident classes, from the symptom only: the cause behind a symptom is not asserted. */
export function classifyIncident({ status = null, error = null, text = '' }) {
  if (error) {
    if (/abort|timeout|timed out/i.test(error)) return 'timeout';
    if (/ECONNREFUSED|ECONNRESET|fetch failed|connect/i.test(error)) return 'connection';
    return 'network-error';
  }
  if (status === 401 || /"error"\s*:\s*"unauthorized"/.test(text)) return 'proxy-session-unauthorized';
  if (status === 502 || status === 503 || status === 504) return `http-${status}`;
  if (status && status >= 400) return `http-${status}`;
  return 'unexpected-document';
}

export function listProxies() {
  try {
    const out = execFileSync('ps', ['-axo', 'pid,etime,command'], { encoding: 'utf8' });
    return out
      .split('\n')
      .filter((line) => /shopify theme dev/.test(line) && !/grep/.test(line))
      .map((line) => line.trim().replace(/\s+/g, ' '));
  } catch {
    return [];
  }
}

async function get(url, timeoutMs) {
  const started = Date.now();
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(timeoutMs), redirect: 'manual' });
    const buffer = Buffer.from(await response.arrayBuffer());
    return { ok: true, status: response.status, ms: Date.now() - started, buffer };
  } catch (error) {
    return { ok: false, error: String(error?.cause?.code || error?.message || error), ms: Date.now() - started };
  }
}

/**
 * @param {string} baseUrl e.g. http://127.0.0.1:9292
 * @param {object} [options]
 * @param {number} [options.timeoutMs] per request
 * @param {string} [options.probePath] a themed page that loads the scripts
 * @param {string[]} [options.scripts] assets whose served bytes must equal the local files
 */
export async function proxyHealth(baseUrl, { timeoutMs = 20000, probePath = '/products/reloj-coach-talia-saddle', scripts = ['monetta-product.js', 'monetta-cart.js', 'monetta-core.js'] } = {}) {
  const report = { checkedAt: new Date().toISOString(), baseUrl, store: target.store, expectedTheme: { id: target.themeId, name: target.themeName }, timeoutMs, checks: [], incidents: [], processes: listProxies() };
  const add = (name, pass, detail) => report.checks.push({ name, pass: Boolean(pass), detail });
  const incident = (url, data) => report.incidents.push({ at: new Date().toISOString(), url, kind: classifyIncident(data), detail: data.error || `HTTP ${data.status}${data.text ? ` ${data.text.slice(0, 120)}` : ''}` });

  // Every `theme dev` process is probed on its own port: a proxy whose storefront session expired answers 302 /password, so a process
  // being alive says nothing about it being usable. Exactly one must be healthy and it must be the one under test.
  const basePort = Number(new URL(baseUrl).port);
  report.proxies = [];
  for (const command of report.processes) {
    const port = Number(/--port (\d+)/.exec(command)?.[1] || 9292);
    const theme = /--theme (\d+)/.exec(command)?.[1] || null;
    const probe = await get(`http://127.0.0.1:${port}/`, 8000);
    const text = probe.buffer ? probe.buffer.toString('utf8') : '';
    const state = !probe.ok ? 'unreachable' : probe.status === 200 && /Shopify\.theme/.test(text) ? 'healthy' : probe.status === 302 ? 'expired' : `http-${probe.status}`;
    report.proxies.push({ port, theme, state, process: command.slice(0, 120) });
    if (state !== 'healthy') report.incidents.push({ at: new Date().toISOString(), url: `http://127.0.0.1:${port}/`, kind: state === 'expired' ? 'proxy-session-expired (302 /password)' : state, detail: command.slice(0, 120) });
  }
  const healthy = report.proxies.filter((p) => p.state === 'healthy');
  add('exactly one healthy theme dev proxy exists, it serves the authorised draft theme and it is the one under test', healthy.length === 1 && healthy[0].port === basePort && healthy[0].theme === target.themeId, JSON.stringify(report.proxies.map((p) => [p.port, p.theme, p.state])));

  const page = await get(`${baseUrl}${probePath}`, timeoutMs);
  if (!page.ok || page.status !== 200) {
    const text = page.buffer ? page.buffer.toString('utf8', 0, 300) : '';
    incident(`${baseUrl}${probePath}`, { ...page, text });
    add('the probe page answers 200 within the time limit', false, page.ok ? `HTTP ${page.status}` : page.error);
    report.ok = false;
    return report;
  }
  add('the probe page answers 200 within the time limit', true, `${page.ms} ms`);
  const html = page.buffer.toString('utf8');
  const themeJson = /Shopify\.theme = (\{[^}]*\})/.exec(html)?.[1];
  let theme = null;
  try {
    theme = themeJson ? JSON.parse(themeJson) : null;
  } catch {
    /* handled below */
  }
  add('the document is the expected theme (Shopify.theme id, role unpublished, name)', theme && String(theme.id) === target.themeId && theme.role === 'unpublished' && theme.name === target.themeName, themeJson || 'Shopify.theme not found');
  add('the document uses the Monetta layout (body.mw)', /<body[^>]*class="[^"]*\bmw\b/.test(html), '');

  for (const name of scripts) {
    const src = new RegExp(`src="([^"]*${name.replace('.', '\\.')}[^"]*)"`).exec(html)?.[1];
    if (!src) {
      add(`served ${name} equals the local file`, false, 'script tag not found in the document');
      continue;
    }
    const served = await get(new URL(src, baseUrl).href, timeoutMs);
    if (!served.ok || served.status !== 200) {
      incident(src, { ...served, text: served.buffer ? served.buffer.toString('utf8', 0, 200) : '' });
      add(`served ${name} equals the local file`, false, served.ok ? `HTTP ${served.status}` : served.error);
      continue;
    }
    const local = readFileSync(path.join(target.themeDir, 'assets', name));
    add(`served ${name} equals the local file`, sha(served.buffer) === sha(local), `served ${sha(served.buffer).slice(0, 12)} · local ${sha(local).slice(0, 12)}`);
  }
  report.ok = report.checks.every((c) => c.pass);
  return report;
}

/** Runs the health check, writes it next to the run's result and returns it. Throws when the proxy is not the expected, healthy one. */
export async function requireHealthyProxy(baseUrl, file, options) {
  const report = await proxyHealth(baseUrl, options);
  if (file) writeFileSync(file, `${JSON.stringify(report, null, 2)}\n`);
  if (!report.ok) {
    const failed = report.checks.filter((c) => !c.pass).map((c) => `${c.name}: ${c.detail}`);
    throw new Error(`proxy not healthy / not the expected theme — ${failed.join('; ')}`);
  }
  return report;
}

if (process.argv[1] && import.meta.url === `file://${process.argv[1]}`) {
  const base = process.argv[2] || 'http://127.0.0.1:9292';
  const report = await proxyHealth(base);
  console.log(JSON.stringify(report, null, 2));
  process.exit(report.ok ? 0 : 1);
}
