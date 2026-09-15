import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp } from '../src/api/server.js';
import { createPassphraseVerifier } from '../src/api/auth.js';
import { InMemoryDashboardSessionStore } from '../src/api/session.js';
import {
  InMemorySelectionVersionStore,
  semanticKey,
  type SelectionVersionRecord,
} from '../src/api/admin/selection.js';
import { hashSelectionDocument } from '../src/selection/index.js';
import type { SelectionDocument } from '../src/selection/types.js';
import {
  InMemoryCrawlRunRepository,
  InMemoryProductRepository,
} from './support/inMemoryRepositories.js';
import { SOURCE_IDS, type CatalogProductRecord } from '../src/domain/types.js';

const NOW = new Date('2026-09-03T12:00:00.000Z');
const PASSPHRASE = 'correct-horse-battery-staple-01';
const APPLIED_BY = { 'X-Applied-By': 'owner' };

const SEED_DOC: SelectionDocument = {
  version: 1,
  sources: {
    coach_us: {
      enabled: true,
      include: [{ id: 'all-coach', kind: 'all', placements: ['catalog_browse'] }],
      exclude: [],
    },
  },
};

function seedRecord(version: number, document: SelectionDocument, note: string | null = null): SelectionVersionRecord {
  const stamped = { ...document, version };
  return {
    version,
    hash: hashSelectionDocument(stamped),
    document: stamped,
    appliedBy: 'owner',
    appliedAt: new Date(NOW.getTime() - (10 - version) * 3_600_000).toISOString(),
    note,
  };
}

function product(overrides: Partial<CatalogProductRecord> = {}): CatalogProductRecord {
  return {
    sourceId: 'coach_us',
    externalId: 'C8879',
    canonicalUrl: 'https://www.coach.com/tabby/C8879.html',
    title: 'Tabby Shoulder Bag 26',
    brand: 'Coach',
    category: 'Handbags',
    imageUrl: null,
    priceUsd: 350,
    availability: 'inStock',
    fingerprint: 'test-fingerprint',
    firstSeenAt: NOW,
    lastSeenAt: NOW,
    lastChangedAt: NOW,
    isActive: true,
    consecutiveMissingSnapshots: 0,
    selectionState: 'selected',
    selectionVersion: 1,
    watchTier: 'standard',
    placements: [],
    matchedRuleId: null,
    ...overrides,
  };
}

interface TestContext {
  baseUrl: string;
  token: string;
  selection: InMemorySelectionVersionStore;
  close: () => Promise<void>;
}

async function startApp(options?: {
  seedSelection?: boolean;
  failingStore?: boolean;
}): Promise<TestContext> {
  const products = new InMemoryProductRepository();
  const crawlRuns = new InMemoryCrawlRunRepository();
  products.seed([product(), product({ externalId: 'C9100', title: 'Pillow Tabby' })]);
  for (const sourceId of SOURCE_IDS) {
    crawlRuns.seedRun({
      sourceId,
      startedAt: NOW,
      endedAt: NOW,
      status: 'success',
      isFullSnapshot: true,
      selectionVersion: 1,
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
  const selection = new InMemorySelectionVersionStore();
  if (options?.seedSelection !== false) {
    selection.seed([seedRecord(1, SEED_DOC, 'initial')]);
  }
  const stores = options?.failingStore === true
    ? {
      selectionVersions: {
        current: async () => { throw new Error('boom'); },
        history: async () => { throw new Error('boom'); },
        getByVersion: async () => { throw new Error('boom'); },
        append: async () => { throw new Error('boom'); },
        nextVersion: async () => { throw new Error('boom'); },
      },
    }
    : { selectionVersions: selection };
  const app = createApp({
    products,
    crawlRuns,
    now: () => NOW,
    minimumProductsPerSource: 0,
    dashboardPassphraseVerifier: await createPassphraseVerifier(PASSPHRASE),
    dashboardSessions: new InMemoryDashboardSessionStore(),
    adminStores: stores,
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
    selection,
    close: () =>
      new Promise<void>((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      }),
  };
}

describe('WP-62 selection console', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await startApp();
  });

  afterEach(async () => {
    await ctx.close();
  });

  const auth = (extra: Record<string, string> = {}): Record<string, string> => ({
    Authorization: `Bearer ${ctx.token}`,
    ...extra,
  });

  it('rejects every selection route without a valid Bearer token', async () => {
    const authed: Array<[string, RequestInit]> = [
      ['/admin/selection', { headers: auth() }],
      ['/admin/selection/versions', { headers: auth() }],
      ['/admin/feed-preview', { headers: auth() }],
    ];
    for (const [path, init] of authed) {
      const missing = await fetch(`${ctx.baseUrl}${path}`);
      expect(missing.status).toBe(401);
      const wrong = await fetch(`${ctx.baseUrl}${path}`, {
        headers: { Authorization: 'Bearer wrong-token' },
      });
      expect(wrong.status).toBe(401);
      void init;
    }
    for (const [method, path, body] of [
      ['PUT', '/admin/selection', { document: SEED_DOC }],
      ['POST', '/admin/selection/rollback', { version: 1 }],
      ['POST', '/admin/selection/preview', { document: SEED_DOC }],
      ['POST', '/admin/products/coach_us:CU1/pin', {}],
      ['POST', '/admin/products/coach_us:CU1/hide', {}],
    ] as const) {
      const missing = await fetch(`${ctx.baseUrl}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json', ...APPLIED_BY },
        body: JSON.stringify(body),
      });
      expect(missing.status).toBe(401);
    }
  });

  it('serves the current document with an ETag', async () => {
    const response = await fetch(`${ctx.baseUrl}/admin/selection`, { headers: auth() });
    expect(response.status).toBe(200);
    const etag = response.headers.get('etag');
    expect(etag).toBeTruthy();
    const body = await response.json();
    expect(body).toMatchObject({ version: 1, appliedBy: 'owner', note: 'initial' });
    expect(body.document.sources.coach_us.include).toHaveLength(1);

    const cached = await fetch(`${ctx.baseUrl}/admin/selection`, {
      headers: { ...auth(), 'If-None-Match': etag! },
    });
    expect(cached.status).toBe(304);
  });

  it('applies a new version, then treats an identical document as a no-op', async () => {
    const v2 = {
      version: 99, // caller stamp is overwritten by the store sequence
      sources: {
        coach_us: {
          enabled: true,
          include: [
            { id: 'all-coach', kind: 'all', placements: ['catalog_browse'] },
            { id: 'tabby', kind: 'urlPattern', value: '/products/tabby/**' },
          ],
          exclude: [],
        },
      },
    };
    const applied = await fetch(`${ctx.baseUrl}/admin/selection`, {
      method: 'PUT',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({ document: v2, note: 'add tabby' }),
    });
    expect(applied.status).toBe(201);
    const appliedBody = await applied.json();
    expect(appliedBody).toMatchObject({ applied: true, version: 2, appliedBy: 'owner' });

    const current = await (await fetch(`${ctx.baseUrl}/admin/selection`, { headers: auth() })).json();
    expect(current.version).toBe(2);
    expect(current.document.version).toBe(2);
    expect(current.document.sources.coach_us.include).toHaveLength(2);

    const noop = await fetch(`${ctx.baseUrl}/admin/selection`, {
      method: 'PUT',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({ document: { ...v2, version: 42, note: 'other note' } }),
    });
    expect(noop.status).toBe(200);
    expect(await noop.json()).toMatchObject({ applied: false, version: 2 });
  });

  it('rejects an invalid document naming the failing rule, leaving the version in force', async () => {
    const bad = {
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: [
            { id: 'dup-rule', kind: 'all' },
            { id: 'dup-rule', kind: 'urlExact', value: '/products/x' },
          ],
        },
      },
    };
    const response = await fetch(`${ctx.baseUrl}/admin/selection`, {
      method: 'PUT',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({ document: bad }),
    });
    expect(response.status).toBe(400);
    const body = await response.json();
    expect(body.code).toBe('duplicate_rule_id');
    expect(body.message).toContain('dup-rule');

    const current = await (await fetch(`${ctx.baseUrl}/admin/selection`, { headers: auth() })).json();
    expect(current.version).toBe(1);
  });

  it('requires X-Applied-By on every write', async () => {
    for (const [method, path, body] of [
      ['PUT', '/admin/selection', { document: SEED_DOC }],
      ['POST', '/admin/selection/rollback', { version: 1 }],
      ['POST', '/admin/products/coach_us:CU1/pin', {}],
      ['POST', '/admin/products/coach_us:CU1/hide', {}],
    ] as const) {
      const response = await fetch(`${ctx.baseUrl}${path}`, {
        method,
        headers: { ...auth(), 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      expect(response.status).toBe(400);
      expect(await response.json()).toEqual({ error: 'missing_applied_by' });
    }
  });

  it('lists append-only history and rolls back as a new version', async () => {
    const v2doc = {
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: [{ id: 'narrow', kind: 'urlPattern', value: '/products/tabby/**' }],
          exclude: [],
        },
      },
    };
    await fetch(`${ctx.baseUrl}/admin/selection`, {
      method: 'PUT',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({ document: v2doc, note: 'narrow' }),
    });

    const history = await (
      await fetch(`${ctx.baseUrl}/admin/selection/versions`, { headers: auth() })
    ).json();
    expect(history.versions.map((v: { version: number }) => v.version)).toEqual([2, 1]);

    const rollback = await fetch(`${ctx.baseUrl}/admin/selection/rollback`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({ version: 1 }),
    });
    expect(rollback.status).toBe(201);
    const rolled = await rollback.json();
    expect(rolled).toMatchObject({ applied: true, version: 3 });

    // History is append-only: all three rows intact, newest first.
    const after = await (
      await fetch(`${ctx.baseUrl}/admin/selection/versions?limit=10`, { headers: auth() })
    ).json();
    expect(after.versions.map((v: { version: number }) => v.version)).toEqual([3, 2, 1]);

    // The new version's document equals the old one (modulo the stamp).
    const current = await (await fetch(`${ctx.baseUrl}/admin/selection`, { headers: auth() })).json();
    expect(semanticKey(current.document)).toBe(semanticKey({ ...SEED_DOC, version: 3 }));

    // Rolling back to the current version is a no-op.
    const noop = await fetch(`${ctx.baseUrl}/admin/selection/rollback`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({ version: 3 }),
    });
    expect(noop.status).toBe(200);
    expect(await noop.json()).toMatchObject({ applied: false, version: 3 });

    const missing = await fetch(`${ctx.baseUrl}/admin/selection/rollback`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({ version: 99 }),
    });
    expect(missing.status).toBe(404);
  });

  it('previews Stage-A matching with per-rule counts and Stage-B cost flags', async () => {
    const candidate = {
      version: 9,
      sources: {
        coach_us: {
          enabled: true,
          maxSelectedUrls: 2,
          include: [
            { id: 'tabby-urls', kind: 'urlPattern', value: '/products/tabby/**', placements: ['catalog_browse'] },
            { id: 'price-filter', kind: 'priceUsdRange', value: [100, 500] },
          ],
          exclude: [],
        },
      },
    };
    const response = await fetch(`${ctx.baseUrl}/admin/selection/preview`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        document: candidate,
        candidates: [
          { source: 'coach_us', url: 'https://www.coach.com/products/tabby/a.html' },
          { source: 'coach_us', url: 'https://www.coach.com/products/tabby/b.html' },
          { source: 'coach_us', url: 'https://www.coach.com/products/other/c.html' },
        ],
      }),
    });
    expect(response.status).toBe(200);
    const body = await response.json();
    expect(body.valid).toBe(true);
    const tabby = body.perRule.find((r: { ruleId: string }) => r.ruleId === 'tabby-urls');
    expect(tabby).toMatchObject({ stage: 'A', matchedUrls: 2, fetchCosting: false });
    const price = body.perRule.find((r: { ruleId: string }) => r.ruleId === 'price-filter');
    expect(price).toMatchObject({ stage: 'B', fetchCosting: true });
    const coach = body.perSource.find((s: { source: string }) => s.source === 'coach_us');
    expect(coach).toMatchObject({ candidates: 3, selected: 2, maxSelectedUrls: 2, overBudget: false });

    // Over budget when the cap is tighter than the match count.
    const tight = await (
      await fetch(`${ctx.baseUrl}/admin/selection/preview`, {
        method: 'POST',
        headers: { ...auth(), 'Content-Type': 'application/json' },
        body: JSON.stringify({
          document: {
            ...candidate,
            sources: { coach_us: { ...candidate.sources.coach_us, maxSelectedUrls: 1 } },
          },
          candidates: [
            { source: 'coach_us', url: 'https://www.coach.com/products/tabby/a.html' },
            { source: 'coach_us', url: 'https://www.coach.com/products/tabby/b.html' },
          ],
        }),
      })
    ).json();
    expect(tight.perSource[0]).toMatchObject({ selected: 2, overBudget: true });

    const invalid = await fetch(`${ctx.baseUrl}/admin/selection/preview`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ document: { version: 1 } }),
    });
    expect(invalid.status).toBe(400);

    const badSource = await fetch(`${ctx.baseUrl}/admin/selection/preview`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json' },
      body: JSON.stringify({
        document: candidate,
        candidates: [{ source: 'nope', url: 'https://example.com/x' }],
      }),
    });
    expect(badSource.status).toBe(400);
  });

  it('pins and hides via scoped rules, idempotently and as inverses', async () => {
    const pin = await fetch(`${ctx.baseUrl}/admin/products/coach_us:CU999/pin`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({}),
    });
    expect(pin.status).toBe(201);
    expect(await pin.json()).toMatchObject({ applied: true, version: 2 });

    let current = await (await fetch(`${ctx.baseUrl}/admin/selection`, { headers: auth() })).json();
    const pinRule = current.document.sources.coach_us.include.find(
      (r: { id: string }) => r.id === 'pin-cu999',
    );
    expect(pinRule).toMatchObject({ kind: 'externalId', value: 'CU999', tier: 'pinned' });

    const repin = await fetch(`${ctx.baseUrl}/admin/products/coach_us:CU999/pin`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({}),
    });
    expect(repin.status).toBe(200);
    expect(await repin.json()).toMatchObject({ applied: false, version: 2 });

    const hide = await fetch(`${ctx.baseUrl}/admin/products/coach_us:CU999/hide`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({}),
    });
    expect(hide.status).toBe(201);
    current = await (await fetch(`${ctx.baseUrl}/admin/selection`, { headers: auth() })).json();
    expect(
      current.document.sources.coach_us.include.some((r: { id: string }) => r.id === 'pin-cu999'),
    ).toBe(false);
    expect(
      current.document.sources.coach_us.exclude.some((r: { id: string }) => r.id === 'hide-cu999'),
    ).toBe(true);

    const rehide = await fetch(`${ctx.baseUrl}/admin/products/coach_us:CU999/hide`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({}),
    });
    expect(await rehide.json()).toMatchObject({ applied: false });

    const badSource = await fetch(`${ctx.baseUrl}/admin/products/bogus:X1/pin`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY },
      body: JSON.stringify({}),
    });
    expect(badSource.status).toBe(400);
  });

  it('serves a feed preview byte-identical to the public feed', async () => {
    const preview = await fetch(`${ctx.baseUrl}/admin/feed-preview`, { headers: auth() });
    expect(preview.status).toBe(200);
    expect(preview.headers.get('etag')).toBeTruthy();
    expect(preview.headers.get('cache-control')).toContain('private');
    const previewText = await preview.text();

    const publicFeed = await fetch(`${ctx.baseUrl}/v1/external-catalog`);
    expect(publicFeed.status).toBe(200);
    expect(await publicFeed.text()).toBe(previewText);
    expect(publicFeed.headers.get('etag')).toBe(preview.headers.get('etag'));

    const cached = await fetch(`${ctx.baseUrl}/admin/feed-preview`, {
      headers: { ...auth(), 'If-None-Match': preview.headers.get('etag')! },
    });
    expect(cached.status).toBe(304);
  });

  it('rejects stale writes with 412 instead of overwriting', async () => {
    const v2 = {
      version: 2,
      sources: {
        coach_us: {
          enabled: true,
          include: [{ id: 'narrow', kind: 'urlPattern', value: '/products/tabby/**' }],
          exclude: [],
        },
      },
    };
    const put = (document: unknown, ifMatch?: string) =>
      fetch(`${ctx.baseUrl}/admin/selection`, {
        method: 'PUT',
        headers: {
          ...auth(),
          'Content-Type': 'application/json',
          ...APPLIED_BY,
          ...(ifMatch !== undefined ? { 'If-Match': ifMatch } : {}),
        },
        body: JSON.stringify({ document }),
      });
    expect((await put(v2)).status).toBe(201);

    const stale = await put({ ...SEED_DOC, version: 9 }, '"1"');
    expect(stale.status).toBe(412);
    expect(await stale.json()).toMatchObject({ error: 'version_conflict', currentVersion: 2 });

    const fresh = await put({ ...SEED_DOC, version: 9 }, '"2"');
    expect(fresh.status).toBe(201);

    const staleRollback = await fetch(`${ctx.baseUrl}/admin/selection/rollback`, {
      method: 'POST',
      headers: { ...auth(), 'Content-Type': 'application/json', ...APPLIED_BY, 'If-Match': '"2"' },
      body: JSON.stringify({ version: 1 }),
    });
    expect(staleRollback.status).toBe(412);
  });

  it('answers 404 when no selection was ever applied', async () => {
    const fresh = await startApp({ seedSelection: false });
    try {
      const get = await fetch(`${fresh.baseUrl}/admin/selection`, {
        headers: { Authorization: `Bearer ${fresh.token}` },
      });
      expect(get.status).toBe(404);
      const pin = await fetch(`${fresh.baseUrl}/admin/products/coach_us:CU1/pin`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${fresh.token}`, 'Content-Type': 'application/json', ...APPLIED_BY },
        body: JSON.stringify({}),
      });
      expect(pin.status).toBe(404);
    } finally {
      await fresh.close();
    }
  });
});

describe('WP-62 failure mode', () => {
  it('returns the generic catch-all on store failure', async () => {
    const ctx = await startApp({ failingStore: true });
    try {
      const response = await fetch(`${ctx.baseUrl}/admin/selection`, {
        headers: { Authorization: `Bearer ${ctx.token}` },
      });
      expect(response.status).toBe(500);
      expect(await response.json()).toEqual({ error: 'internal_error' });
    } finally {
      await ctx.close();
    }
  });

  it('clamps over-cap version history limits', async () => {
    const ctx = await startApp();
    try {
      const response = await fetch(`${ctx.baseUrl}/admin/selection/versions?limit=9999`, {
        headers: { Authorization: `Bearer ${ctx.token}` },
      });
      expect(response.status).toBe(200);
      expect((await response.json()).versions).toHaveLength(1);
    } finally {
      await ctx.close();
    }
  });
});
