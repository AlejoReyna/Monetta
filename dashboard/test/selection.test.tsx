import { describe, expect, it, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ApiClient } from '../src/api/client.js';
import { SelectionScreen } from '../src/screens/Selection.js';

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const CURRENT = {
  version: 3,
  hash: 'abc123def456',
  appliedBy: 'owner',
  appliedAt: '2026-09-03T10:00:00.000Z',
  note: 'tighten coach',
  document: {
    version: 3,
    sources: {
      coach_us: {
        enabled: true,
        include: [{ id: 'all-coach', kind: 'all', placements: ['catalog_browse'] }],
        exclude: [],
      },
    },
  },
};

const PREVIEW = {
  perRule: [
    { ruleId: 'all-coach', kind: 'all', stage: 'A', matchedUrls: 0, fetchCosting: false },
    { ruleId: 'price-filter', kind: 'priceUsdRange', stage: 'B', matchedUrls: 0, fetchCosting: true },
  ],
  perSource: [{ source: 'coach_us', candidates: 0, selected: 0, maxSelectedUrls: null, overBudget: false }],
  note: 'No candidate URLs supplied.',
};

interface SeenCall {
  readonly url: string;
  readonly method: string;
  readonly headers: Record<string, string>;
  readonly body: unknown;
}

function selectionClient(overrides?: { current?: unknown }): { client: ApiClient; seen: SeenCall[] } {
  const seen: SeenCall[] = [];
  const fetchImpl = (async (url: unknown, init?: RequestInit) => {
    const href = String(url);
    const path = href.replace('https://api.example', '');
    const headers: Record<string, string> = {};
    new Headers(init?.headers).forEach((value, key) => { headers[key] = value; });
    let body: unknown = null;
    try {
      body = init?.body !== undefined ? JSON.parse(String(init.body)) : null;
    } catch {
      body = null;
    }
    seen.push({ url: path, method: init?.method ?? 'GET', headers, body });
    if (path === '/admin/selection' && (init?.method ?? 'GET') === 'GET') {
      return new Response(JSON.stringify(overrides?.current ?? CURRENT), {
        status: 200,
        headers: { 'Content-Type': 'application/json', ETag: '"sel-3"' },
      });
    }
    if (path === '/admin/selection/versions') {
      return new Response(
        JSON.stringify({ versions: [{ version: 3, hash: 'abc', appliedBy: 'owner', appliedAt: CURRENT.appliedAt, note: 'tighten coach' }] }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }
    if (path === '/admin/selection/preview') {
      return new Response(JSON.stringify(PREVIEW), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    if (path === '/admin/selection' && init?.method === 'PUT') {
      return new Response(JSON.stringify({ applied: true, version: 4 }), {
        status: 201,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    if (path === '/admin/selection/rollback') {
      return new Response(JSON.stringify({ applied: true, version: 4 }), {
        status: 201,
        headers: { 'Content-Type': 'application/json' },
      });
    }
    return new Response('{}', { status: 404 });
  }) as typeof fetch;
  return {
    client: new ApiClient({ baseUrl: 'https://api.example', getToken: () => 'tok', onUnauthorized: () => {}, fetchImpl }),
    seen,
  };
}

function stubSession(): Map<string, string> {
  const store = new Map<string, string>();
  vi.stubGlobal('sessionStorage', {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => { store.set(key, value); },
    removeItem: (key: string) => { store.delete(key); },
  });
  return store;
}

describe('SelectionScreen (WP-65)', () => {
  it('an invalid document cannot be applied and names the failing rule', async () => {
    const { client } = selectionClient();
    stubSession();
    render(
      <MemoryRouter>
        <SelectionScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByLabelText('Selection document')).toBeTruthy());
    fireEvent.change(screen.getByLabelText('Selection document'), {
      target: {
        value: JSON.stringify({
          version: 4,
          sources: {
            coach_us: {
              enabled: true,
              include: [
                { id: 'dup', kind: 'all' },
                { id: 'dup', kind: 'urlExact', value: '/products/x' },
              ],
            },
          },
        }),
      },
    });
    await waitFor(() => expect(screen.getByRole('alert').textContent).toContain('dup'));
    // No apply section while invalid.
    expect(screen.queryByLabelText('apply note')).toBeNull();
  });

  it('preview shows per-rule counts and flags Stage-B fetch cost', async () => {
    const { client } = selectionClient();
    stubSession();
    render(
      <MemoryRouter>
        <SelectionScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText('Preview')).toBeTruthy());
    fireEvent.click(screen.getByText('Preview'));
    await waitFor(() => expect(screen.getByLabelText('preview')).toBeTruthy());
    expect(screen.getByLabelText('preview').textContent).toContain('costs a fetch per candidate');
  });

  it('apply shows a diff first and requires a note plus X-Applied-By', async () => {
    const { client, seen } = selectionClient();
    stubSession();
    render(
      <MemoryRouter>
        <SelectionScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByLabelText('Selection document')).toBeTruthy());
    // Make a change: add an exclude rule.
    fireEvent.change(screen.getByLabelText('Selection document'), {
      target: {
        value: JSON.stringify({
          version: 3,
          sources: {
            coach_us: {
              enabled: true,
              include: [{ id: 'all-coach', kind: 'all', placements: ['catalog_browse'] }],
              exclude: [{ id: 'no-mens', kind: 'urlPattern', value: '/products/*mens*' }],
            },
          },
        }),
      },
    });
    await waitFor(() => expect(screen.getByLabelText('diff')).toBeTruthy());
    expect(screen.getByText(/Affected sources: coach_us/)).toBeTruthy();

    fireEvent.change(screen.getByLabelText('apply note'), { target: { value: 'exclude mens' } });
    fireEvent.change(screen.getByLabelText('applied by'), { target: { value: 'owner' } });
    fireEvent.click(screen.getByText('Review and confirm…'));
    fireEvent.click(await screen.findByText('Confirm apply to 1 source(s)'));
    await waitFor(() => expect(screen.getByRole('status').textContent).toContain('Applied as v4.'));
    const put = seen.find((call) => call.method === 'PUT');
    expect(put?.headers['x-applied-by']).toBe('owner');
    expect((put?.body as { note: string }).note).toBe('exclude mens');
  });

  it('a zero-selection apply requires a second worded confirmation', async () => {
    const { client } = selectionClient();
    stubSession();
    render(
      <MemoryRouter>
        <SelectionScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByLabelText('Selection document')).toBeTruthy());
    fireEvent.change(screen.getByLabelText('Selection document'), {
      target: {
        value: JSON.stringify({
          version: 4,
          sources: { coach_us: { enabled: true, include: [], exclude: [] } },
        }),
      },
    });
    await waitFor(() => expect(screen.getByLabelText('second confirmation')).toBeTruthy());
    expect(screen.getByText(/selects zero products/)).toBeTruthy();
    fireEvent.change(screen.getByLabelText('apply note'), { target: { value: 'empty it' } });
    fireEvent.change(screen.getByLabelText('applied by'), { target: { value: 'owner' } });
    fireEvent.click(screen.getByText('Review and confirm…'));
    // Confirm stays disabled until the second checkbox is checked.
    expect((screen.getByText(/Confirm apply/) as HTMLButtonElement).disabled).toBe(true);
    fireEvent.click(screen.getByLabelText('second confirmation'));
    expect((screen.getByText(/Confirm apply/) as HTMLButtonElement).disabled).toBe(false);
  });

  it('a Stage-B-only document trips the zero-selection guard too', async () => {
    const { client } = selectionClient();
    stubSession();
    render(
      <MemoryRouter>
        <SelectionScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByLabelText('Selection document')).toBeTruthy());
    fireEvent.change(screen.getByLabelText('Selection document'), {
      target: {
        value: JSON.stringify({
          version: 4,
          sources: {
            coach_us: {
              enabled: true,
              include: [{ id: 'price-only', kind: 'priceUsdRange', value: [100, 500] }],
              exclude: [],
            },
          },
        }),
      },
    });
    // One include rule, zero Stage-A candidates — the engine would fetch
    // nothing, so the second confirmation is still required.
    await waitFor(() => expect(screen.getByLabelText('second confirmation')).toBeTruthy());
    expect(screen.getByText(/selects zero products/)).toBeTruthy();
  });

  it('editing the document discards a stale preview', async () => {
    const { client } = selectionClient();
    stubSession();
    render(
      <MemoryRouter>
        <SelectionScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText('Preview')).toBeTruthy());
    fireEvent.click(screen.getByText('Preview'));
    await waitFor(() => expect(screen.getByLabelText('preview')).toBeTruthy());
    fireEvent.change(screen.getByLabelText('Selection document'), {
      target: { value: JSON.stringify(CURRENT.document) },
    });
    await waitFor(() => expect(screen.queryByLabelText('preview')).toBeNull());
  });

  it('rollback appends from history', async () => {
    const { client, seen } = selectionClient();
    stubSession();
    render(
      <MemoryRouter>
        <SelectionScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText('Roll back to v3')).toBeTruthy());
    fireEvent.click(screen.getByText('Roll back to v3'));
    await waitFor(() =>
      expect(seen.some((call) => call.url === '/admin/selection/rollback')).toBe(true),
    );
  });
});
