import { describe, expect, it, vi } from 'vitest';
import { ApiClient } from '../src/api/client.js';
import { createPoller } from '../src/api/poll.js';

function jsonResponse(status: number, body: unknown, headers: Record<string, string> = {}): Response {
  return new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

describe('ApiClient (WP-63)', () => {
  it('round-trips ETags: second poll sends If-None-Match and surfaces 304', async () => {
    const seen: string[] = [];
    const fetchImpl = vi.fn(async (_url: unknown, init?: RequestInit) => {
      const headers = new Headers(init?.headers);
      seen.push(headers.get('If-None-Match') ?? '(none)');
      if (headers.get('If-None-Match') === '"v1"') {
        return new Response(null, { status: 304, headers: { ETag: '"v1"' } });
      }
      return jsonResponse(200, { ok: true }, { ETag: '"v1"' });
    });
    const client = new ApiClient({
      baseUrl: 'https://api.example',
      getToken: () => 'tok',
      onUnauthorized: () => {},
      fetchImpl: fetchImpl as typeof fetch,
    });
    const first = await client.get('/admin/overview');
    expect(first.status).toBe(200);
    expect(first.etag).toBe('"v1"');
    const second = await client.get('/admin/overview');
    expect(second.status).toBe(304);
    expect(second.notModified).toBe(true);
    // The cached copy comes back with the 304 — a revisited screen
    // repopulates instead of sitting on "Loading…".
    expect(second.data).toEqual({ ok: true });
    expect(seen).toEqual(['(none)', '"v1"']);
  });

  it('calls onUnauthorized on 401 so the caller can clear the session', async () => {
    const onUnauthorized = vi.fn();
    const client = new ApiClient({
      baseUrl: 'https://api.example',
      getToken: () => 'stale',
      onUnauthorized,
      fetchImpl: (async () => new Response(null, { status: 401 })) as typeof fetch,
    });
    const result = await client.get('/admin/overview');
    expect(result.status).toBe(401);
    expect(onUnauthorized).toHaveBeenCalledTimes(1);
  });
});

describe('createPoller (WP-63)', () => {
  it('keeps last data on failure with backoff to the 2-minute ceiling', async () => {
    const delays: number[] = [];
    let calls = 0;
    const client = {
      get: async () => {
        calls += 1;
        if (calls <= 3) throw new Error('down');
        return { status: 200, data: { ok: calls }, etag: '"v4"', notModified: false };
      },
    } as unknown as ApiClient;
    const statuses: string[] = [];
    const seen: unknown[] = [];
    const poller = createPoller({
      client,
      path: '/admin/overview',
      intervalMs: 15_000,
      isHidden: () => false,
      schedule: (fn, ms) => {
        delays.push(ms);
        if (delays.length < 4) fn();
        return { cancel: () => {} };
      },
      onData: (data) => { seen.push(data); },
      onStatus: (status) => { statuses.push(status); },
    });
    poller.start();
    await vi.waitFor(() => expect(calls).toBe(4));
    poller.stop();
    // 15s base, then backoff 15s / 30s / 60s, then healthy again on base.
    expect(delays.slice(0, 3)).toEqual([15_000, 30_000, 60_000]);
    expect(statuses).toEqual(['degraded', 'unreachable', 'unreachable', 'ok']);
    expect(seen).toEqual([{ ok: 4 }]);
  });

  it('pauses while the document is hidden', async () => {
    let calls = 0;
    let hidden = true;
    const scheduled: number[] = [];
    const client = {
      get: async () => {
        calls += 1;
        return { status: 200, data: { ok: true }, etag: null, notModified: false };
      },
    } as unknown as ApiClient;
    const poller = createPoller({
      client,
      path: '/admin/overview',
      intervalMs: 15_000,
      isHidden: () => hidden,
      schedule: (_fn, ms) => {
        scheduled.push(ms);
        return { cancel: () => {} };
      },
      onData: () => {},
      onStatus: () => {},
    });
    poller.start();
    await vi.waitFor(() => expect(scheduled.length).toBe(1));
    expect(calls).toBe(0);
    hidden = false;
    poller.refreshNow();
    await vi.waitFor(() => expect(calls).toBe(1));
    poller.stop();
  });
});
