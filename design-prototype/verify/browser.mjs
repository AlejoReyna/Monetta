// Launches an already-installed Chromium-based browser through playwright-core
// (which never downloads a browser). Set BROWSER_PATH to choose one explicitly.
import { existsSync } from 'node:fs';
import { chromium } from 'playwright-core';

const CANDIDATES = [
  process.env.BROWSER_PATH,
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/Applications/Brave Browser.app/Contents/MacOS/Brave Browser',
  '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
  '/usr/bin/microsoft-edge',
].filter(Boolean);

export function findBrowser() {
  const found = CANDIDATES.find((candidate) => existsSync(candidate));
  if (!found) {
    throw new Error(
      `No Chromium-based browser found. Install one you already use or set BROWSER_PATH. Tried:\n${CANDIDATES.join('\n')}`,
    );
  }
  return found;
}

export async function launch() {
  const executablePath = findBrowser();
  const browser = await chromium.launch({ executablePath, headless: true, timeout: 45000 });
  return { browser, executablePath, version: browser.version() };
}

export const BASE_URL = process.env.PROTOTYPE_URL ?? 'http://127.0.0.1:4173';

/** Collects console errors, page errors and failed requests for a page. */
export function watch(page) {
  const problems = [];
  page.on('console', (message) => {
    if (message.type() === 'error') problems.push(`console: ${message.text()}`);
  });
  page.on('pageerror', (error) => problems.push(`pageerror: ${error.message}`));
  page.on('requestfailed', (request) => problems.push(`requestfailed: ${request.url()} ${request.failure()?.errorText ?? ''}`));
  page.on('response', (response) => {
    if (response.status() >= 400) problems.push(`http ${response.status()}: ${response.url()}`);
  });
  return problems;
}
