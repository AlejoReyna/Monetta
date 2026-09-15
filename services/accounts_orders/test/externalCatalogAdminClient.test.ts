import { createHmac } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import {
  HttpExternalCatalogAdminClient,
  type ExternalSourceProjection,
} from '../src/admin/externalCatalogClient.js';

const secret = 'catalog-monitor-internal-test-secret-at-least-32';
const now = 1_756_560_000_000;

const source: ExternalSourceProjection = {
  id: 'coach_us',
  merchant: 'Coach',
  enabled: true,
  itemLimit: 8,
  baseCommissionRate: 0.22,
  highValueCommissionRate: 0.14,
  highValueThreshold: 4000,
  itemCount: 2,
  lastSuccessfulRunAt: null,
  updatedAt: '2026-08-30T12:00:00.000Z',
};

describe('HttpExternalCatalogAdminClient', () => {
  it('signs the canonical request and sends no bearer or service secret in the body', async () => {
    let request: Request | null = null;
    const client = new HttpExternalCatalogAdminClient({
      baseUrl: 'https://catalog.example.test',
      serviceSecret: secret,
      now: () => now,
      fetchFn: async (input, init) => {
        request = new Request(input, init);
        return new Response(JSON.stringify({ sources: [source] }), { status: 200 });
      },
    });

    const result = await client.fetchSources('req_1234567890abcdef-1234');
    expect(result).toEqual([source]);
    expect(request).not.toBeNull();
    expect(request!.url).toBe('https://catalog.example.test/internal/admin/sources');
    expect(request!.headers.get('Authorization')).toBeNull();
    expect(request!.headers.get('X-Monetta-Request-Id')).toBe(
      'req_1234567890abcdef-1234',
    );
    const timestamp = request!.headers.get('X-Monetta-Timestamp')!;
    const expected = createHmac('sha256', secret)
      .update(`${timestamp}.req_1234567890abcdef-1234.GET./internal/admin/sources.`)
      .digest('hex');
    expect(request!.headers.get('X-Monetta-Signature')).toBe(expected);
  });
});
