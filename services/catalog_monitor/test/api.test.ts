import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp } from '../src/api/server.js';
import {
  InMemoryCrawlRunRepository,
  InMemoryProductRepository,
} from './support/inMemoryRepositories.js';
import { SOURCE_IDS, type CatalogProductRecord } from '../src/domain/types.js';

const now = new Date('2026-08-10T12:00:00.000Z');

function activeProduct(overrides: Partial<CatalogProductRecord> = {}): CatalogProductRecord {
  return {
    sourceId: 'coach_us',
    externalId: 'C8879',
    canonicalUrl: 'https://www.coach.com/tabby-shoulder-bag-26/C8879.html',
    title: 'Tabby Shoulder Bag 26',
    brand: 'Coach',
    category: 'Handbags',
    imageUrl: 'https://coach.com/images/c8879.jpg',
    priceUsd: 350,
    availability: 'inStock',
    fingerprint: 'abc123',
    firstSeenAt: now,
    lastSeenAt: now,
    lastChangedAt: now,
    isActive: true,
    consecutiveMissingSnapshots: 0,
    ...overrides,
  };
}

describe('GET /v1/external-catalog and /healthz', () => {
  let server: Server;
  let baseUrl: string;
  let products: InMemoryProductRepository;
  let crawlRuns: InMemoryCrawlRunRepository;

  beforeEach(async () => {
    products = new InMemoryProductRepository();
    crawlRuns = new InMemoryCrawlRunRepository();
    for (const sourceId of SOURCE_IDS) {
      crawlRuns.seedRun({
        sourceId,
        startedAt: now,
        endedAt: now,
        status: 'success',
        isFullSnapshot: true,
        urlsDiscovered: 1,
        pagesFetched: 1,
        successfulParses: 1,
        newItems: 1,
        changedItems: 0,
        missingItems: 0,
        inactiveItems: 0,
        errorsByType: {},
      });
    }
    products.seed([activeProduct()]);

    const app = createApp({
      products,
      crawlRuns,
      now: () => now,
      minimumProductsPerSource: 0,
    });
    await new Promise<void>((resolve) => {
      server = app.listen(0, '127.0.0.1', resolve);
    });
    const address = server.address();
    if (address === null || typeof address === 'string') throw new Error('no address');
    baseUrl = `http://127.0.0.1:${address.port}`;
  });

  afterEach(async () => {
    await new Promise<void>((resolve, reject) => {
      server.close((err) => (err ? reject(err) : resolve()));
    });
  });

  it('returns a versioned, schema-shaped catalog with gzip and an ETag', async () => {
    const response = await fetch(`${baseUrl}/v1/external-catalog`, {
      headers: { 'Accept-Encoding': 'gzip' },
    });
    expect(response.status).toBe(200);
    expect(response.headers.get('content-encoding')).toBe('gzip');
    const etag = response.headers.get('etag');
    expect(etag).toBeTruthy();

    const body = await response.json();
    expect(body.schemaVersion).toBe(1);
    expect(body.items).toHaveLength(1);
    expect(body.items[0]).toMatchObject({
      sourceScopedId: 'coach_us:C8879',
      source: 'coach_us',
      merchant: 'Coach',
      price: { amount: 350, currency: 'USD' },
      detailUrl: 'https://www.coach.com/tabby-shoulder-bag-26/C8879.html',
      dataOrigin: 'live_crawl',
      variants: [
        expect.objectContaining({
          variantId: 'C8879:default',
          sku: 'C8879',
          price: { amount: 350, currency: 'USD' },
        }),
      ],
    });
    // Never expose internal fields.
    expect(body.items[0]).not.toHaveProperty('fingerprint');
    expect(body.items[0]).not.toHaveProperty('consecutiveMissingSnapshots');
    expect(body).not.toHaveProperty('databaseUrl');
  });

  it('serves color variants without exposing internal history fields', async () => {
    products.seed([
      activeProduct({
        variants: [
          {
            variantId: 'C8879:B4BK',
            sku: 'C8879 B4/BK',
            colorName: 'Brass/Black',
            colorCode: 'B4BK',
            imageUrl: 'https://coach.com/images/c8879-black.jpg',
            priceUsd: 320,
            availability: 'outOfStock',
            detailUrl: 'https://www.coach.com/products/tabby/C8879-B4%2FBK.html',
          },
        ],
      }),
    ]);
    const response = await fetch(`${baseUrl}/v1/external-catalog`);
    const body = await response.json();
    expect(body.items[0].variants).toEqual([
      expect.objectContaining({
        variantId: 'C8879:B4BK',
        colorName: 'Brass/Black',
        colorCode: 'B4BK',
        price: { amount: 320, currency: 'USD' },
        availability: 'outOfStock',
      }),
    ]);
    expect(body.items[0].variants[0]).not.toHaveProperty('lastChangedAt');
  });

  it('only returns active listings', async () => {
    products.seed([
      activeProduct({ externalId: 'INACTIVE1', isActive: false, title: 'Retired Bag' }),
    ]);
    const response = await fetch(`${baseUrl}/v1/external-catalog`);
    const body = await response.json();
    expect(body.items.map((i: { sourceScopedId: string }) => i.sourceScopedId)).not.toContain(
      'coach_us:INACTIVE1',
    );
  });

  it('returns 304 when If-None-Match matches the current ETag', async () => {
    const first = await fetch(`${baseUrl}/v1/external-catalog`);
    const etag = first.headers.get('etag')!;

    const second = await fetch(`${baseUrl}/v1/external-catalog`, {
      headers: { 'If-None-Match': etag },
    });
    expect(second.status).toBe(304);
  });

  it('changes the ETag once the underlying catalog changes', async () => {
    const first = await fetch(`${baseUrl}/v1/external-catalog`);
    const etag1 = first.headers.get('etag');

    products.seed([activeProduct({ title: 'Tabby Shoulder Bag 26 — Updated' })]);

    const second = await fetch(`${baseUrl}/v1/external-catalog`);
    const etag2 = second.headers.get('etag');
    expect(etag2).not.toBe(etag1);
  });

  it('serves at least ten US snapshot products per source when the database is empty', async () => {
    const emptyProducts = new InMemoryProductRepository();
    const floorApp = createApp({ products: emptyProducts, crawlRuns, now: () => now });
    const floorServer = floorApp.listen(0, '127.0.0.1');
    try {
      await new Promise<void>((resolve) => floorServer.once('listening', resolve));
      const address = floorServer.address();
      if (address === null || typeof address === 'string') throw new Error('no address');

      const response = await fetch(`http://127.0.0.1:${address.port}/v1/external-catalog`);
      const body = await response.json();
      expect(body.items).toHaveLength(40);
      for (const source of SOURCE_IDS) {
        const items = body.items.filter((item: { source: string }) => item.source === source);
        expect(items).toHaveLength(10);
        expect(
          items.every(
            (item: { dataOrigin: string; price: { currency: string } | null }) =>
              item.dataOrigin === 'curated_us_snapshot' && item.price?.currency === 'USD',
          ),
        ).toBe(true);

        expect(body.sources).toContainEqual(
          expect.objectContaining({
            source,
            itemCount: 10,
            liveItemCount: 0,
            snapshotItemCount: 10,
          }),
        );
      }
    } finally {
      await new Promise<void>((resolve, reject) => {
        floorServer.close((error) => (error ? reject(error) : resolve()));
      });
    }
  });

  it('reports healthy status at /healthz for fresh, complete runs', async () => {
    const response = await fetch(`${baseUrl}/healthz`);
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('ok');
    expect(body.sources).toHaveLength(SOURCE_IDS.length);
  });

  it('reports process liveness independently from crawl health', async () => {
    const response = await fetch(`${baseUrl}/livez`);
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ status: 'ok' });
  });

  it('reports degraded status when a source has no recent successful run', async () => {
    const staleRuns = new InMemoryCrawlRunRepository();
    staleRuns.seedRun({
      sourceId: 'coach_us',
      startedAt: new Date(now.getTime() - 48 * 60 * 60 * 1000),
      endedAt: new Date(now.getTime() - 48 * 60 * 60 * 1000),
      status: 'success',
      isFullSnapshot: true,
      urlsDiscovered: 1,
      pagesFetched: 1,
      successfulParses: 1,
      newItems: 0,
      changedItems: 0,
      missingItems: 0,
      inactiveItems: 0,
      errorsByType: {},
    });
    const app = createApp({
      products,
      crawlRuns: staleRuns,
      now: () => now,
      minimumProductsPerSource: 0,
    });
    const s = app.listen(0, '127.0.0.1');
    try {
      await new Promise<void>((resolve) => s.once('listening', resolve));
      const address = s.address();
      if (address === null || typeof address === 'string') throw new Error('no address');
      const response = await fetch(`http://127.0.0.1:${address.port}/healthz`);
      expect(response.status).toBe(503);
      const body = await response.json();
      expect(body.status).toBe('degraded');
    } finally {
      await new Promise<void>((resolve) => s.close(() => resolve()));
    }
  });
});
