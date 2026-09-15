import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp } from '../src/api/server.js';
import { createPassphraseVerifier } from '../src/api/auth.js';
import { InMemoryDashboardSessionStore } from '../src/api/session.js';
import {
  InMemoryAdminRunStore,
  type AdminRunSeed,
} from '../src/api/admin/runs.js';
import { InMemoryAdminProductStore } from '../src/api/admin/products.js';
import { InMemoryAdminEventStore } from '../src/api/admin/events.js';
import { InMemoryAdminAlertStore } from '../src/api/admin/alerts.js';
import {
  InMemoryCrawlRunRepository,
  InMemoryProductRepository,
} from './support/inMemoryRepositories.js';
import { SOURCE_IDS, type CatalogProductRecord } from '../src/domain/types.js';

const NOW = new Date('2026-09-02T12:00:00.000Z');
const PASSPHRASE = 'correct-horse-battery-staple-01';
const hoursAgo = (hours: number): Date => new Date(NOW.getTime() - hours * 3_600_000);

function product(overrides: Partial<CatalogProductRecord> = {}): CatalogProductRecord {
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
    fingerprint: 'secret-fingerprint-must-never-leak',
    firstSeenAt: hoursAgo(72),
    lastSeenAt: NOW,
    lastChangedAt: NOW,
    isActive: true,
    consecutiveMissingSnapshots: 0,
    selectionState: 'selected',
    selectionVersion: 7,
    watchTier: 'standard',
    placements: [],
    matchedRuleId: null,
    ...overrides,
  };
}

const NAMED_RUNS: AdminRunSeed[] = [
  {
    id: 'r-dis-1',
    source: 'coach_us',
    kind: 'discovery',
    status: 'success',
    startedAt: hoursAgo(72),
    endedAt: hoursAgo(71),
    selectionVersion: 3,
    urlsDiscovered: 100,
    urlsSelected: 40,
    pagesFetched: 100,
    successfulParses: 98,
    newItems: 5,
    errorsByType: { network: 2 },
  },
  {
    id: 'r-dis-2',
    source: 'coach_us',
    kind: 'discovery',
    status: 'failed',
    startedAt: hoursAgo(48),
    endedAt: hoursAgo(47.5),
    selectionVersion: 4,
    urlsDiscovered: 100,
    pagesFetched: 10,
    successfulParses: 2,
    errorsByType: { timeout: 8 },
  },
  {
    id: 'r-dis-3',
    source: 'coach_us',
    kind: 'discovery',
    status: 'success',
    startedAt: hoursAgo(26),
    endedAt: hoursAgo(25),
    selectionVersion: 4,
    urlsDiscovered: 100,
    urlsSelected: 42,
    pagesFetched: 100,
    successfulParses: 100,
  },
  {
    id: 'r-watch-1',
    source: 'coach_us',
    kind: 'watch',
    status: 'success',
    startedAt: hoursAgo(5),
    endedAt: hoursAgo(4.9),
    selectionVersion: 7,
    pagesFetched: 12,
    successfulParses: 12,
  },
  {
    id: 'r-watch-2',
    source: 'coach_us',
    kind: 'watch',
    status: 'success',
    startedAt: hoursAgo(1),
    endedAt: hoursAgo(0.9),
    selectionVersion: 7,
    pagesFetched: 12,
    successfulParses: 12,
  },
  {
    id: 'r-guess-1',
    source: 'guess_us',
    kind: 'discovery',
    status: 'blocked',
    startedAt: hoursAgo(2),
    endedAt: hoursAgo(1.9),
    urlsDiscovered: 50,
    errorsByType: { captcha_or_block: 40 },
  },
];

const NAMED_PRODUCTS: CatalogProductRecord[] = [
  product({ externalId: 'C8879' }),
  product({
    externalId: 'C9100',
    title: 'Pillow Tabby Shoulder Bag 26',
    watchTier: 'pinned',
    placements: ['home_rail'],
    matchedRuleId: 'coach-tabby',
  }),
  product({ externalId: 'C9200', title: 'Hidden Hobo', placements: ['hidden'] }),
  product({ externalId: 'C9300', title: 'Retired Rogue', selectionState: 'deselected' }),
  product({ externalId: 'C9400', title: 'Missing Maisie', isActive: false }),
  product({
    sourceId: 'guess_us',
    externalId: 'G100',
    canonicalUrl: 'https://www.guess.com/handbag/G100.html',
    title: 'GUESS Tote',
    brand: 'GUESS',
    priceUsd: null,
    placements: ['catalog_browse'],
  }),
];

interface TestContext {
  baseUrl: string;
  token: string;
  close: () => Promise<void>;
}

async function startApp(setup?: (stores: {
  runs: InMemoryAdminRunStore;
  products: InMemoryAdminProductStore;
  events: InMemoryAdminEventStore;
  alerts: InMemoryAdminAlertStore;
}) => void): Promise<TestContext> {
  const products = new InMemoryProductRepository();
  const crawlRuns = new InMemoryCrawlRunRepository();
  for (const sourceId of SOURCE_IDS) {
    crawlRuns.seedRun({
      sourceId,
      startedAt: NOW,
      endedAt: NOW,
      status: 'success',
      isFullSnapshot: true,
      selectionVersion: 7,
      urlsDiscovered: 10,
      urlsSelected: 10,
      pagesFetched: 10,
      successfulParses: 10,
      newItems: 0,
      changedItems: 0,
      missingItems: 0,
      inactiveItems: 0,
      deselectedItems: 0,
      errorsByType: {},
    });
  }
  products.seed(NAMED_PRODUCTS);

  const runs = new InMemoryAdminRunStore();
  const adminProducts = new InMemoryAdminProductStore();
  const events = new InMemoryAdminEventStore();
  const alerts = new InMemoryAdminAlertStore();
  runs.seed(NAMED_RUNS);
  adminProducts.seed(NAMED_PRODUCTS);
  events.seed([
    {
      kind: 'price_drop',
      source: 'coach_us',
      externalId: 'C8879',
      observedAt: hoursAgo(2),
      previous: { price: 350, fingerprint: 'must-be-stripped' },
      current: { price: 300 },
    },
    {
      kind: 'back_in_stock',
      source: 'coach_us',
      externalId: 'C9100',
      observedAt: hoursAgo(25),
      current: { availability: 'inStock' },
    },
    {
      kind: 'new_match',
      source: 'guess_us',
      externalId: 'G100',
      observedAt: hoursAgo(1),
      current: { title: 'GUESS Tote' },
    },
  ]);
  alerts.seed([
    { key: 'source.blocked:guess_us', lastSentAt: hoursAgo(1) },
    { key: 'coverage:coach_us', lastSentAt: hoursAgo(10) },
  ]);
  setup?.({ runs, products: adminProducts, events, alerts });

  const app = createApp({
    products,
    crawlRuns,
    now: () => NOW,
    minimumProductsPerSource: 0,
    dashboardPassphraseVerifier: await createPassphraseVerifier(PASSPHRASE),
    dashboardSessions: new InMemoryDashboardSessionStore(),
    adminStores: {
      runs,
      products: adminProducts,
      events,
      alerts,
      listAllProducts: async () => products.all(),
      getSelection: async () => ({
        version: 7,
        hash: 'sel-hash-7',
        appliedBy: 'owner',
        appliedAt: hoursAgo(3).toISOString(),
        note: 'tighten coach selection',
      }),
      getPageBudget: async () => ({ limit: 3000, usedToday: 120 }),
    },
  });
  const server: Server = await new Promise((resolve) => {
    const listening = app.listen(0, '127.0.0.1', () => resolve(listening));
  });
  const address = server.address();
  if (address === null || typeof address === 'string') throw new Error('no address');
  const baseUrl = `http://127.0.0.1:${address.port}`;

  const login = await fetch(`${baseUrl}/admin/session`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ passphrase: PASSPHRASE }),
  });
  if (login.status !== 200) throw new Error('setup login failed');
  const { token } = (await login.json()) as { token: string };

  return {
    baseUrl,
    token,
    close: () =>
      new Promise<void>((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      }),
  };
}

describe('WP-61 admin reads', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await startApp();
  });

  afterEach(async () => {
    await ctx.close();
  });

  const auth = (): { Authorization: string } => ({ Authorization: `Bearer ${ctx.token}` });

  it('rejects every read route without a valid Bearer token', async () => {
    const paths = [
      '/admin/overview',
      '/admin/runs',
      '/admin/runs/r-watch-2',
      '/admin/products',
      '/admin/events',
      '/admin/alerts',
    ];
    for (const path of paths) {
      const missing = await fetch(`${ctx.baseUrl}${path}`);
      expect(missing.status).toBe(401);
      const wrong = await fetch(`${ctx.baseUrl}${path}`, {
        headers: { Authorization: 'Bearer wrong-token' },
      });
      expect(wrong.status).toBe(401);
    }
  });

  it('serves the whole Overview screen in one request', async () => {
    const response = await fetch(`${ctx.baseUrl}/admin/overview`, { headers: auth() });
    expect(response.status).toBe(200);
    expect(response.headers.get('etag')).toBeTruthy();
    const body = await response.json();

    expect(body.status).toBe('degraded');
    expect(body.generatedAt).toBe(NOW.toISOString());
    expect(body.sources).toHaveLength(SOURCE_IDS.length);

    const coach = body.sources.find((s: { source: string }) => s.source === 'coach_us');
    expect(coach.status).toBe('healthy');
    expect(coach.reasons).toEqual([]);
    expect(coach.freshness.discoveryHours).toBe(0);
    expect(coach.freshness.watchHours).toBeCloseTo(1, 5);
    expect(coach.lastDiscoveryRun).toMatchObject({ id: 'r-dis-3', kind: 'discovery' });
    expect(coach.lastWatchRun).toMatchObject({ id: 'r-watch-2', kind: 'watch' });
    expect(coach.counts).toEqual({ selected: 4, served: 2, deselected: 1, inactive: 1 });
    expect(coach.coverage).toBe(1);

    const guess = body.sources.find((s: { source: string }) => s.source === 'guess_us');
    expect(guess.status).toBe('unhealthy');
    expect(guess.reasons).toContain('watch_stale');
    expect(guess.lastWatchRun).toBeNull();

    expect(body.pageBudget).toEqual({ limit: 3000, usedToday: 120, remaining: 2880 });
    expect(body.selection).toMatchObject({ version: 7, appliedBy: 'owner' });
    expect(body.alerts).toHaveLength(2);
    expect(body.alerts[0]).toMatchObject({ key: 'source.blocked:guess_us', suppressed: true });
  });

  it('lists runs newest-first with filters and cursor paging', async () => {
    const all = await (
      await fetch(`${ctx.baseUrl}/admin/runs?limit=10`, { headers: auth() })
    ).json();
    const ids = all.runs.map((r: { id: string }) => r.id);
    expect(ids).toEqual(['r-watch-2', 'r-guess-1', 'r-watch-1', 'r-dis-3', 'r-dis-2', 'r-dis-1']);

    const discovery = await (
      await fetch(`${ctx.baseUrl}/admin/runs?kind=discovery`, { headers: auth() })
    ).json();
    expect(discovery.runs.every((r: { kind: string }) => r.kind === 'discovery')).toBe(true);

    const blocked = await (
      await fetch(`${ctx.baseUrl}/admin/runs?status=blocked`, { headers: auth() })
    ).json();
    expect(blocked.runs.map((r: { id: string }) => r.id)).toEqual(['r-guess-1']);

    const coachWatch = await (
      await fetch(`${ctx.baseUrl}/admin/runs?source=coach_us&kind=watch&limit=1`, { headers: auth() })
    ).json();
    expect(coachWatch.runs.map((r: { id: string }) => r.id)).toEqual(['r-watch-2']);
    expect(coachWatch.nextCursor).toBe('r-watch-2');

    const second = await (
      await fetch(`${ctx.baseUrl}/admin/runs?source=coach_us&kind=watch&limit=1&before=${coachWatch.nextCursor}`, {
        headers: auth(),
      })
    ).json();
    expect(second.runs.map((r: { id: string }) => r.id)).toEqual(['r-watch-1']);
    expect(second.nextCursor).toBeNull();

    const badSource = await fetch(`${ctx.baseUrl}/admin/runs?source=bogus`, { headers: auth() });
    expect(badSource.status).toBe(400);
    const badKind = await fetch(`${ctx.baseUrl}/admin/runs?kind=bogus`, { headers: auth() });
    expect(badKind.status).toBe(400);
  });

  it('returns full run detail with errors, duration and selection version', async () => {
    const response = await fetch(`${ctx.baseUrl}/admin/runs/r-dis-1`, { headers: auth() });
    expect(response.status).toBe(200);
    const { run } = await response.json();
    expect(run).toMatchObject({
      id: 'r-dis-1',
      source: 'coach_us',
      kind: 'discovery',
      status: 'success',
      selectionVersion: 3,
      urlsDiscovered: 100,
      urlsSelected: 40,
      pagesFetched: 100,
      successfulParses: 100 - 2,
      errorsByType: { network: 2 },
    });
    expect(run.durationMs).toBe(3_600_000);
    expect(run.coverage).toBeCloseTo(0.98, 5);

    const missing = await fetch(`${ctx.baseUrl}/admin/runs/does-not-exist`, { headers: auth() });
    expect(missing.status).toBe(404);
  });

  it('serves a server-filtered, paged product table', async () => {
    const all = await (
      await fetch(`${ctx.baseUrl}/admin/products?limit=50`, { headers: auth() })
    ).json();
    expect(all.products).toHaveLength(6);
    expect(all.nextCursor).toBeNull();

    const coach = await (
      await fetch(`${ctx.baseUrl}/admin/products?source=coach_us&limit=50`, { headers: auth() })
    ).json();
    expect(coach.products).toHaveLength(5);

    const search = await (
      await fetch(`${ctx.baseUrl}/admin/products?q=tabby`, { headers: auth() })
    ).json();
    expect(search.products.map((p: { sourceScopedId: string }) => p.sourceScopedId).sort()).toEqual([
      'coach_us:C8879',
      'coach_us:C9100',
    ]);

    const deselected = await (
      await fetch(`${ctx.baseUrl}/admin/products?state=deselected`, { headers: auth() })
    ).json();
    expect(deselected.products.map((p: { sourceScopedId: string }) => p.sourceScopedId)).toEqual([
      'coach_us:C9300',
    ]);

    const inactive = await (
      await fetch(`${ctx.baseUrl}/admin/products?state=inactive`, { headers: auth() })
    ).json();
    expect(inactive.products.map((p: { sourceScopedId: string }) => p.sourceScopedId)).toEqual([
      'coach_us:C9400',
    ]);

    const pinned = await (
      await fetch(`${ctx.baseUrl}/admin/products?tier=pinned`, { headers: auth() })
    ).json();
    expect(pinned.products.map((p: { sourceScopedId: string }) => p.sourceScopedId)).toEqual([
      'coach_us:C9100',
    ]);

    const hidden = await (
      await fetch(`${ctx.baseUrl}/admin/products?placement=hidden`, { headers: auth() })
    ).json();
    expect(hidden.products.map((p: { sourceScopedId: string }) => p.sourceScopedId)).toEqual([
      'coach_us:C9200',
    ]);

    const first = await (
      await fetch(`${ctx.baseUrl}/admin/products?source=coach_us&limit=2`, { headers: auth() })
    ).json();
    expect(first.products).toHaveLength(2);
    expect(first.nextCursor).toBeTruthy();
    const second = await (
      await fetch(`${ctx.baseUrl}/admin/products?source=coach_us&limit=2&cursor=${first.nextCursor}`, {
        headers: auth(),
      })
    ).json();
    expect(second.products).toHaveLength(2);
    expect(
      second.products.every(
        (p: { sourceScopedId: string }) =>
          !first.products.some(
            (q: { sourceScopedId: string }) => q.sourceScopedId === p.sourceScopedId,
          ),
      ),
    ).toBe(true);

    const nullPrice = all.products.find(
      (p: { sourceScopedId: string }) => p.sourceScopedId === 'guess_us:G100',
    );
    expect(nullPrice.priceUsd).toBeNull();

    const badState = await fetch(`${ctx.baseUrl}/admin/products?state=bogus`, { headers: auth() });
    expect(badState.status).toBe(400);
  });

  it('serves events since a timestamp with a paging cursor', async () => {
    const recent = await (
      await fetch(`${ctx.baseUrl}/admin/events`, { headers: auth() })
    ).json();
    expect(recent.events.map((e: { kind: string }) => e.kind).sort()).toEqual([
      'new_match',
      'price_drop',
    ]);
    expect(typeof recent.nextSince).toBe('string');

    const all = await (
      await fetch(`${ctx.baseUrl}/admin/events?since=${hoursAgo(26).toISOString()}`, { headers: auth() })
    ).json();
    expect(all.events).toHaveLength(3);

    const invalidSince = await (
      await fetch(`${ctx.baseUrl}/admin/events?since=not-a-date`, { headers: auth() })
    ).json();
    expect(invalidSince.events).toHaveLength(2);
  });

  it('serves alerts with dedupe state', async () => {
    const body = await (
      await fetch(`${ctx.baseUrl}/admin/alerts?limit=10`, { headers: auth() })
    ).json();
    expect(body.alerts).toEqual([
      { key: 'source.blocked:guess_us', lastSentAt: hoursAgo(1).toISOString(), suppressed: true },
      { key: 'coverage:coach_us', lastSentAt: hoursAgo(10).toISOString(), suppressed: false },
    ]);
  });

  it('supports conditional polling with ETags', async () => {
    for (const path of ['/admin/overview', '/admin/runs', '/admin/products', '/admin/events', '/admin/alerts']) {
      const first = await fetch(`${ctx.baseUrl}${path}`, { headers: auth() });
      expect(first.status).toBe(200);
      const etag = first.headers.get('etag');
      expect(etag).toBeTruthy();
      const second = await fetch(`${ctx.baseUrl}${path}`, {
        headers: { ...auth(), 'If-None-Match': etag! },
      });
      expect(second.status).toBe(304);
    }
  });

  it('never leaks fingerprints, raw HTML, stacks or connection details', async () => {
    const bodies: unknown[] = [];
    for (const path of [
      '/admin/overview',
      '/admin/runs',
      '/admin/runs/r-dis-1',
      '/admin/products?limit=50',
      '/admin/events',
      '/admin/alerts',
    ]) {
      const response = await fetch(`${ctx.baseUrl}${path}`, { headers: auth() });
      expect(response.status).toBe(200);
      bodies.push(await response.json());
    }
    const dumped = JSON.stringify(bodies);
    for (const leak of [
      'secret-fingerprint-must-never-leak',
      'fingerprint',
      'consecutiveMissingSnapshots',
      'stackTrace',
      'rawHtml',
      'raw_html',
      'connectionDetails',
      'connection_details',
    ]) {
      expect(dumped).not.toContain(leak);
    }
    const productsBody = bodies[3] as {
      products: Array<Record<string, unknown>>;
    };
    for (const item of productsBody.products) {
      expect(item).not.toHaveProperty('fingerprint');
      expect(item).not.toHaveProperty('variants');
    }
    const eventsBody = bodies[4] as {
      events: Array<{ previous: Record<string, unknown> | null }>;
    };
    for (const event of eventsBody.events) {
      expect(event.previous === null || !('fingerprint' in event.previous)).toBe(true);
    }
  });
});

describe('WP-61 limits and failure mode', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await startApp(({ runs, products }) => {
      const bulkRuns: AdminRunSeed[] = [];
      for (let i = 1; i <= 205; i++) {
        bulkRuns.push({
          id: `run-bulk-${String(i).padStart(4, '0')}`,
          source: 'coach_us',
          kind: 'discovery',
          status: 'success',
          startedAt: new Date(NOW.getTime() - i * 60_000),
          endedAt: new Date(NOW.getTime() - i * 60_000 + 30_000),
          pagesFetched: 10,
          successfulParses: 10,
        });
      }
      runs.seed(bulkRuns);
      products.seed(
        Array.from({ length: 205 }, (_, i) =>
          product({ externalId: `BULK-${String(i).padStart(4, '0')}`, title: `Bulk Bag ${i}` }),
        ),
      );
    });
  });

  afterEach(async () => {
    await ctx.close();
  });

  const auth = (): { Authorization: string } => ({ Authorization: `Bearer ${ctx.token}` });

  it('clamps over-cap limits instead of erroring', async () => {
    const runs = await (
      await fetch(`${ctx.baseUrl}/admin/runs?limit=999`, { headers: auth() })
    ).json();
    expect(runs.runs).toHaveLength(200);

    const products = await (
      await fetch(`${ctx.baseUrl}/admin/products?limit=500`, { headers: auth() })
    ).json();
    expect(products.products).toHaveLength(200);

    const events = await (
      await fetch(`${ctx.baseUrl}/admin/events?limit=9999`, { headers: auth() })
    ).json();
    expect(events.events.length).toBeLessThanOrEqual(200);

    const alerts = await (
      await fetch(`${ctx.baseUrl}/admin/alerts?limit=9999`, { headers: auth() })
    ).json();
    expect(alerts.alerts.length).toBeLessThanOrEqual(200);
  });

  it('returns the generic catch-all on store failure', async () => {
    const failingApp = createApp({
      products: new InMemoryProductRepository(),
      crawlRuns: new InMemoryCrawlRunRepository(),
      now: () => NOW,
      dashboardPassphraseVerifier: await createPassphraseVerifier(PASSPHRASE),
      dashboardSessions: new InMemoryDashboardSessionStore(),
      adminStores: {
        runs: {
          list: async () => {
            throw new Error('boom');
          },
          getById: async () => {
            throw new Error('boom');
          },
        },
      },
    });
    const server: Server = await new Promise((resolve) => {
      const listening = failingApp.listen(0, '127.0.0.1', () => resolve(listening));
    });
    try {
      const address = server.address();
      if (address === null || typeof address === 'string') throw new Error('no address');
      const base = `http://127.0.0.1:${address.port}`;
      const login = await fetch(`${base}/admin/session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ passphrase: PASSPHRASE }),
      });
      const { token } = (await login.json()) as { token: string };
      const response = await fetch(`${base}/admin/runs`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: 'internal_error' });
    } finally {
      await new Promise<void>((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      });
    }
  });
});
