// Mobile LCP and CLS on fixed routes under one repeatable setup: 390x844 at DPR 3, CPU throttled 4x and a "slow 4G" network
// (150 ms RTT, 1.6 Mbps down, 750 kbps up) through CDP, cache disabled, three loads per route, median reported. The pages come
// through the local `shopify theme dev` proxy, which adds its own latency, so the numbers compare states of this theme measured
// the same way; they are not field data and say nothing about INP.
//
//   node perf.mjs --base-url=http://127.0.0.1:9292 --out=<absolute file.json> [--label=after] [--runs=3]
import { writeFileSync } from 'node:fs';
import path from 'node:path';
import { chromium, browserPath, parseArgs } from '../../scripts/e2e/lib.mjs';

const args = parseArgs();
const baseUrl = args['base-url'] || 'http://127.0.0.1:9292';
if (!args.out || !path.isAbsolute(args.out)) throw new Error('--out=<absolute file.json> is required');
const runs = Number(args.runs || 3);
const routes = { home: '/', collection: '/collections/all', product: '/products/reloj-coach-talia-saddle', bag: '/cart' };
const median = (values) => {
  const v = [...values].sort((a, b) => a - b);
  return v[Math.floor(v.length / 2)];
};

const browser = await chromium.launch({ executablePath: browserPath(), headless: true });
const results = {};
for (const [name, route] of Object.entries(routes)) {
  const samples = [];
  for (let i = 0; i < runs; i += 1) {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true });
    const page = await context.newPage();
    const cdp = await context.newCDPSession(page);
    await cdp.send('Network.enable');
    await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
    await cdp.send('Network.emulateNetworkConditions', { offline: false, latency: 150, downloadThroughput: (1.6 * 1024 * 1024) / 8, uploadThroughput: (750 * 1024) / 8 });
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });
    await page.addInitScript(() => {
      window.__perf = { lcp: 0, lcpElement: '', cls: 0 };
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          window.__perf.lcp = entry.startTime;
          const el = entry.element;
          window.__perf.lcpElement = el ? `${el.tagName.toLowerCase()}.${[...el.classList].join('.')}` : '';
        }
      }).observe({ type: 'largest-contentful-paint', buffered: true });
      new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) if (!entry.hadRecentInput) window.__perf.cls += entry.value;
      }).observe({ type: 'layout-shift', buffered: true });
    });
    await page.goto(`${baseUrl}${route}`, { waitUntil: 'load', timeout: 120000 });
    await page.waitForTimeout(3000);
    // LCP is final once the user interacts; a scroll-free settle of 3 s after load is the fixed end of a sample.
    const perf = await page.evaluate(() => window.__perf);
    const nav = await page.evaluate(() => {
      const n = performance.getEntriesByType('navigation')[0];
      return { ttfb: n.responseStart, domContentLoaded: n.domContentLoadedEventEnd, load: n.loadEventEnd, transferKB: Math.round(performance.getEntriesByType('resource').reduce((s, r) => s + (r.transferSize || 0), n.transferSize || 0) / 1024) };
    });
    samples.push({ ...perf, ...nav });
    await context.close();
  }
  results[name] = {
    route,
    lcpMs: Math.round(median(samples.map((s) => s.lcp))),
    cls: Number(median(samples.map((s) => s.cls)).toFixed(3)),
    ttfbMs: Math.round(median(samples.map((s) => s.ttfb))),
    transferKB: median(samples.map((s) => s.transferKB)),
    lcpElements: [...new Set(samples.map((s) => s.lcpElement))],
    samples,
  };
  console.log(name, JSON.stringify({ lcpMs: results[name].lcpMs, cls: results[name].cls, ttfbMs: results[name].ttfbMs, transferKB: results[name].transferKB, lcp: results[name].lcpElements }));
}
await browser.close();
writeFileSync(args.out, `${JSON.stringify({ label: args.label || '', baseUrl, measuredAt: new Date().toISOString(), setup: '390x844 DPR3 mobile, CPU 4x, 150ms RTT, 1.6Mbps/750kbps, cache disabled, median of runs', runs, results }, null, 2)}\n`);
