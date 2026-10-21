// Result collection shared by the browser checks.
import { readFileSync } from 'node:fs';

export const catalog = JSON.parse(readFileSync(new URL('../src/data/catalog.json', import.meta.url), 'utf8'));

export function product(handle) {
  const found = catalog.products.find((entry) => entry.handle === handle);
  if (!found) throw new Error(`Unknown product ${handle}`);
  return found;
}

export function createReport() {
  const results = [];
  const problems = [];
  return {
    results,
    problems,
    check(gate, name, passed, details = '') {
      results.push({ gate, name, passed: Boolean(passed), details });
      return Boolean(passed);
    },
    async step(gate, name, fn) {
      try {
        const details = await fn();
        results.push({ gate, name, passed: true, details: details ?? '' });
        return true;
      } catch (error) {
        results.push({ gate, name, passed: false, details: error.message.split('\n')[0] });
        return false;
      }
    },
    trackPage(page, label) {
      page.on('console', (message) => {
        if (message.type() === 'error') problems.push(`${label} console: ${message.text()}`);
      });
      page.on('pageerror', (error) => problems.push(`${label} pageerror: ${error.message}`));
      page.on('requestfailed', (request) => problems.push(`${label} requestfailed: ${request.url()}`));
      page.on('response', (response) => {
        if (response.status() >= 400) problems.push(`${label} http ${response.status()}: ${response.url()}`);
      });
    },
  };
}

export function assert(condition, message) {
  if (!condition) throw new Error(message);
}

/** Puts lines in the demo cart before the first page script runs. */
export async function seedCart(context, lines) {
  await context.addInitScript((value) => {
    if (!sessionStorage.getItem('verify-seeded')) {
      localStorage.setItem('monetta-proto:v1:cart', JSON.stringify(value));
      sessionStorage.setItem('verify-seeded', '1');
    }
  }, lines);
}

/** Scrolls the page once to trigger lazy images and editorial reveals. */
export async function scrollThrough(page) {
  await page.evaluate(async () => {
    const step = Math.max(200, window.innerHeight * 0.75);
    for (let y = 0; y <= document.documentElement.scrollHeight; y += step) {
      window.scrollTo(0, y);
      await new Promise((resolve) => setTimeout(resolve, 60));
    }
    window.scrollTo(0, 0);
  });
  await page.waitForTimeout(250);
}
