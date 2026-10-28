// Helpers shared by regressions.mjs: network interception with a request log, bounded navigation that records proxy incidents instead
// of hiding them, and the "old assets" switch used to replay the audited (pre-fix) scripts as a negative control.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { root, staging } from './lib.mjs';
import { classifyIncident } from './proxy-health.mjs';

export const previous = path.join(staging, 'correcciones-auditoria-codex-2026-10-19/codigo-previo');
export const theme = path.join(root, 'storefront-theme');
export const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
export const esc = (text) => String(text).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** A promise whose resolution is controlled from outside: how a request is held "pending" and then released. */
export function gate() {
  let release;
  const promise = new Promise((resolve) => {
    release = resolve;
  });
  return { promise, release };
}

/**
 * Rules are tried in order for every request of a page; the first whose `match(url, request)` is true handles it, otherwise the request
 * goes on to the proxy untouched. `log` keeps every request that matched a rule or that `watch` selects.
 */
export class Intercept {
  constructor(page) {
    this.page = page;
    this.rules = [];
    this.log = [];
  }

  async start() {
    await this.page.route('**/*', async (route) => {
      const request = route.request();
      const url = new URL(request.url());
      for (const rule of this.rules) {
        if (rule.match(url, request)) {
          const entry = { rule: rule.name, method: request.method(), url: url.pathname + url.search, body: request.postData() || null, at: Date.now() };
          this.log.push(entry);
          rule.hits = (rule.hits || 0) + 1;
          if (rule.times && rule.hits > rule.times) continue;
          return rule.handle(route, request, entry, rule.hits);
        }
      }
      return route.fallback();
    });
    return this;
  }

  add(name, match, handle, { times = 0 } = {}) {
    const rule = { name, match, handle, times, hits: 0 };
    this.rules.unshift(rule);
    return rule;
  }

  remove(rule) {
    this.rules = this.rules.filter((candidate) => candidate !== rule);
  }

  count(name) {
    return this.log.filter((entry) => entry.rule === name).length;
  }

  reset() {
    this.log.length = 0;
  }
}

/** Replays the audited scripts instead of the current ones: the same defects come back, so each regression must fail on them. */
export async function useOldAssets(page, names) {
  for (const name of names) {
    const body = readFileSync(path.join(previous, 'assets', name), 'utf8');
    await page.route(new RegExp(`/assets/${esc(name)}(\\?.*)?$`), (route) => route.fulfill({ status: 200, contentType: 'text/javascript; charset=utf-8', body }));
  }
}

/** Navigation with a bounded wait. A failed attempt is kept as a proxy incident (kind + detail), then retried once for pure GET navigations. */
export async function goto(page, url, { incidents, attempts = 2, waitUntil = 'load', timeout = 30000 } = {}) {
  let last;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      const response = await page.goto(url, { waitUntil, timeout });
      if (response && response.ok() && (await page.locator('body.mw').count())) return response;
      const text = response ? (await response.text().catch(() => '')).slice(0, 200) : '';
      const data = { status: response?.status() ?? null, text };
      incidents?.push({ at: new Date().toISOString(), url, kind: classifyIncident(data), detail: `HTTP ${data.status} ${text.slice(0, 100)}`, attempt });
      last = new Error(`unexpected document (HTTP ${data.status})`);
    } catch (error) {
      incidents?.push({ at: new Date().toISOString(), url, kind: classifyIncident({ error: String(error.message) }), detail: String(error.message).split('\n')[0], attempt });
      last = error;
    }
  }
  throw last;
}

export const money = (text) => Number(String(text).replace(/[^0-9.]/g, ''));
