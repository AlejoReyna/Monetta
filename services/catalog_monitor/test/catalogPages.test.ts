import { describe, expect, it } from 'vitest';
import { gpMcallenAdapter } from '../src/adapters/gpMcallen.js';
import { discoverProductUrlsFromCatalogPages } from '../src/discovery/catalogPages.js';

describe('discoverProductUrlsFromCatalogPages', () => {
  it('follows same-category pagination and ignores navigation/outside hosts', async () => {
    const first = 'https://www.gpmcallen.com/ladies-perfumes.html';
    const second = `${first}?p=2`;
    const pages: Record<string, string> = {
      [first]: `
        <a href="/212-vip-rose-28oz-edp-by-carolina-herrera.html">Perfume</a>
        <a href="${second}">Next</a>
        <a href="/blog.html">Blog</a>
        <a href="https://evil.example/perfume.html">Outside</a>`,
      [second]: `
        <a href="/lattafa-petra-viola-34oz-eau-de-parfum.html">Perfume 2</a>
        <a href="${first}?p=1">Previous</a>`,
    };

    const result = await discoverProductUrlsFromCatalogPages(
      [first],
      async (url) => ({ status: 200, body: pages[url]! }),
      (url) => gpMcallenAdapter.isProductUrl(url),
    );

    expect(result.errors).toEqual([]);
    expect(result.sitemapUrlsVisited).toEqual([first, second]);
    expect(result.productUrls).toEqual([
      'https://www.gpmcallen.com/212-vip-rose-28oz-edp-by-carolina-herrera.html',
      'https://www.gpmcallen.com/lattafa-petra-viola-34oz-eau-de-parfum.html',
    ]);
  });

  it('marks discovery truncated when the page cap leaves pagination queued', async () => {
    const first = 'https://www.gpmcallen.com/ladies-perfumes.html';
    const result = await discoverProductUrlsFromCatalogPages(
      [first],
      async () => ({ status: 200, body: `<a href="${first}?p=2">Next</a>` }),
      (url) => gpMcallenAdapter.isProductUrl(url),
      { maxPages: 1 },
    );
    expect(result.truncated).toBe(true);
  });
});
