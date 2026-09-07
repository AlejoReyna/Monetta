import { createHmac } from 'node:crypto';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { Server } from 'node:http';
import { createApp } from '../src/api/server.js';
import type { SourcePolicy, SourcePolicyRepository } from '../src/admin/sourcePolicy.js';
import type { SourceId } from '../src/domain/types.js';
import {
  InMemoryCrawlRunRepository,
  InMemoryProductRepository,
} from './support/inMemoryRepositories.js';

const now = new Date('2026-08-30T12:00:00.000Z');
const secret = 'catalog-monitor-internal-test-secret-at-least-32';
let requestSequence = 0;

class InMemorySourcePolicyRepository implements SourcePolicyRepository {
  readonly rows = new Map<SourceId, SourcePolicy>();

  async list(): Promise<SourcePolicy[]> {
    return [...this.rows.values()];
  }

  async find(sourceId: SourceId): Promise<SourcePolicy | null> {
    return this.rows.get(sourceId) ?? null;
  }

  async upsert(input: {
    readonly sourceId: SourceId;
    readonly enabled: boolean;
    readonly itemLimit: number;
    readonly baseCommissionBps: number;
    readonly highValueCommissionBps: number;
    readonly highValueThresholdMxn: number;
  }): Promise<SourcePolicy> {
    const policy: SourcePolicy = { ...input, updatedAt: now };
    this.rows.set(input.sourceId, policy);
    return policy;
  }
}

describe('signed catalog-monitor admin adapter', () => {
  let server: Server;
  let baseUrl: string;
  let policies: InMemorySourcePolicyRepository;

  beforeEach(async () => {
    policies = new InMemorySourcePolicyRepository();
    const products = new InMemoryProductRepository();
    products.seed([{
      sourceId: 'coach_us',
      externalId: 'bag-1',
      canonicalUrl: 'https://www.coach.com/bag-1',
      title: 'Bag',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      priceUsd: 100,
      availability: 'inStock',
      fingerprint: 'fingerprint',
      firstSeenAt: now,
      lastSeenAt: now,
      lastChangedAt: now,
      isActive: true,
      consecutiveMissingSnapshots: 0,
      selectionState: 'selected',
      selectionVersion: 1,
      watchTier: 'standard',
      placements: [],
      matchedRuleId: null,
    }]);
    const crawlRuns = new InMemoryCrawlRunRepository();
    crawlRuns.seedRun({
      sourceId: 'coach_us',
      startedAt: now,
      endedAt: now,
      status: 'success',
      isFullSnapshot: true,
      selectionVersion: 1,
      urlsDiscovered: 1,
      urlsSelected: 1,
      pagesFetched: 1,
      successfulParses: 1,
      newItems: 1,
      changedItems: 0,
      missingItems: 0,
      inactiveItems: 0,
      deselectedItems: 0,
      errorsByType: {},
    });
    const app = createApp({
      products,
      crawlRuns,
      now: () => now,
      enabledSourceIds: ['coach_us'],
      policies,
      internalServiceSecret: secret,
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
      server.close((error) => error ? reject(error) : resolve());
    });
  });

  it('rejects missing and stale internal signatures', async () => {
    const missing = await fetch(`${baseUrl}/internal/admin/sources`);
    expect(missing.status).toBe(401);

    const stale = signedRequest('GET', '/internal/admin/sources', '', now.getTime() - 10 * 60 * 1_000);
    const response = await fetch(`${baseUrl}/internal/admin/sources`, { headers: stale });
    expect(response.status).toBe(401);
  });

  it('returns source health and persists bounded policies through the signed boundary', async () => {
    const read = await fetch(`${baseUrl}/internal/admin/sources`, {
      headers: signedRequest('GET', '/internal/admin/sources'),
    });
    expect(read.status).toBe(200);
    expect(await read.json()).toMatchObject({
      schemaVersion: 1,
      sources: [{
        id: 'coach_us',
        itemCount: 1,
        health: { status: 'ready' },
      }],
    });

    const body = {
      enabled: false,
      itemLimit: 3,
      baseCommissionBps: 1800,
      highValueCommissionBps: 1200,
      highValueThresholdMxn: 5000,
    };
    const path = '/internal/admin/sources/coach_us';
    const response = await fetch(`${baseUrl}${path}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        ...signedRequest('PUT', path, stableJson(body)),
      },
      body: JSON.stringify(body),
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      source: {
        id: 'coach_us',
        enabled: false,
        itemLimit: 3,
        baseCommissionRate: 0.18,
      },
    });
    expect(policies.rows.get('coach_us')).toMatchObject({ enabled: false, itemLimit: 3 });
  });

  function signedRequest(
    method: string,
    path: string,
    body = '',
    timestamp = now.getTime(),
  ): Record<string, string> {
    const timestampText = String(timestamp);
    const requestId = `req_${(++requestSequence).toString(16).padStart(16, '0')}-1234567890abcdef`;
    const signature = createHmac('sha256', secret)
      .update(`${timestampText}.${requestId}.${method}.${path}.${body}`)
      .digest('hex');
    return {
      'X-Monetta-Timestamp': timestampText,
      'X-Monetta-Signature': signature,
      'X-Monetta-Request-Id': requestId,
    };
  }
});

function stableJson(value: Record<string, unknown>): string {
  return `{${Object.entries(value)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, item]) => `${JSON.stringify(key)}:${JSON.stringify(item)}`)
    .join(',')}}`;
}
