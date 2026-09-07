import { describe, expect, it, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ApiClient } from '../src/api/client.js';
import { ProductsScreen } from '../src/screens/Products.js';
import { EventsScreen } from '../src/screens/Events.js';
import { FeedPreviewScreen } from '../src/screens/FeedPreview.js';
import { formatUsdPrice, formatMxnPrice } from '../src/catalog/money.js';
import { groupByPlacement } from '../src/screens/FeedPreview.js';

afterEach(() => cleanup());

const PRODUCT_A = {
  sourceScopedId: 'coach_us:C8879',
  source: 'coach_us',
  title: 'Tabby Shoulder Bag 26',
  brand: 'Coach',
  category: 'Handbags',
  imageUrl: null,
  priceUsd: 350,
  availability: 'inStock',
  selectionState: 'selected',
  isActive: true,
  served: true,
  watchTier: 'standard',
  placements: ['catalog_browse'],
  matchedRuleId: 'all-coach',
  detailUrl: 'https://www.coach.com/tabby/C8879.html',
  firstSeenAt: '2026-09-01T00:00:00.000Z',
  lastSeenAt: '2026-09-03T12:00:00.000Z',
  lastChangedAt: '2026-09-03T12:00:00.000Z',
};

const PRODUCT_B = { ...PRODUCT_A, sourceScopedId: 'guess_us:G100', source: 'guess_us', title: 'GUESS Tote', priceUsd: null };

function productsClient(seen: string[]): ApiClient {
  const fetchImpl = (async (url: unknown, init?: RequestInit) => {
    const href = String(url);
    seen.push(`${init?.method ?? 'GET'} ${href.replace('https://api.example', '')}`);
    if (href.includes('/admin/products/coach_us')) {
      return new Response(JSON.stringify({ applied: true, version: 8 }), { status: 201 });
    }
    return new Response(JSON.stringify({ products: [PRODUCT_A, PRODUCT_B], nextCursor: null }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ETag: '"p"' },
    });
  }) as typeof fetch;
  return new ApiClient({ baseUrl: 'https://api.example', getToken: () => 'tok', onUnauthorized: () => {}, fetchImpl });
}

describe('money (WP-66)', () => {
  it('never renders a null price as $0 and always shows the code', () => {
    expect(formatUsdPrice(null)).toBe('Consultar precio');
    expect(formatUsdPrice({ amount: 350 })).toBe('USD 350.00');
    expect(formatUsdPrice({ amount: 0 })).toBe('USD 0.00');
    expect(formatMxnPrice(null)).toBe('—');
    expect(formatMxnPrice({ amount: 7999.5 })).toBe('MXN 7999.50');
  });

  it('groupByPlacement flags hidden and never serves it', () => {
    const items = [
      { sourceScopedId: 'a', source: 'coach_us', title: 'A', brand: 'B', price: null, suggestedRetailPrice: null, availability: 'inStock', detailUrl: 'u', imageUrl: null, lastObservedAt: '2026-09-03T12:00:00.000Z', dataOrigin: 'live_crawl' as const },
      { sourceScopedId: 'b', source: 'coach_us', title: 'B', brand: 'B', price: null, suggestedRetailPrice: null, availability: 'inStock', detailUrl: 'u', imageUrl: null, lastObservedAt: '2026-09-03T12:00:00.000Z', dataOrigin: 'curated_us_snapshot' as const },
    ];
    const groups = groupByPlacement(items, new Map([['a', ['home_rail']], ['b', ['hidden']]]));
    expect(groups.get('home_rail')).toHaveLength(1);
    expect(groups.get('hidden')).toHaveLength(1);
    expect(groups.has('catalog_browse')).toBe(false);
  });
});

describe('ProductsScreen (WP-66)', () => {
  it('renders prices correctly and pins optimistically', async () => {
    const seen: string[] = [];
    render(
      <MemoryRouter>
        <ProductsScreen client={productsClient(seen)} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText('Tabby Shoulder Bag 26')).toBeTruthy());
    // Null price renders the consult string, never $0.
    expect(screen.getByText('Consultar precio')).toBeTruthy();
    expect(screen.queryByText('$0')).toBeNull();
    expect(screen.getByText('USD 350.00')).toBeTruthy();

    fireEvent.click(screen.getByRole('button', { name: 'Pin coach_us:C8879' }));
    await waitFor(() =>
      expect(seen.some((call) => call.includes('/pin') && call.includes('C8879'))).toBe(true),
    );
  });

  it('search submits the query to the server', async () => {
    const seen: string[] = [];
    render(
      <MemoryRouter>
        <ProductsScreen client={productsClient(seen)} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText('Tabby Shoulder Bag 26')).toBeTruthy());
    fireEvent.change(screen.getByLabelText('search products'), { target: { value: 'tabby' } });
    fireEvent.click(screen.getByText('Search'));
    await waitFor(() => expect(seen.some((call) => call.includes('q=tabby'))).toBe(true));
  });
});

describe('EventsScreen (WP-66)', () => {
  it('shows the timeline, or the empty-watch warning', async () => {
    const fetchImpl = (async (url: unknown) => {
      const href = String(url);
      if (href.includes('/admin/events')) {
        return new Response(
          JSON.stringify({
            events: [
              { id: 'e1', kind: 'price_drop', source: 'coach_us', externalId: 'C8879', sourceScopedId: 'coach_us:C8879', observedAt: '2026-09-03T11:00:00.000Z', previous: null, current: null },
            ],
            nextSince: '2026-09-03T12:00:00.000Z',
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      return new Response('{}', { status: 404 });
    }) as typeof fetch;
    const client = new ApiClient({ baseUrl: 'https://api.example', getToken: () => 'tok', onUnauthorized: () => {}, fetchImpl });
    render(
      <MemoryRouter>
        <EventsScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText('price_drop')).toBeTruthy());
    expect(screen.getByText(/coach_us:C8879/)).toBeTruthy();
  });
});

describe('FeedPreviewScreen (WP-66)', () => {
  it('groups by placement, badges origins, and shows rule traceability', async () => {
    const fetchImpl = (async (url: unknown) => {
      const href = String(url);
      if (href.includes('/admin/feed-preview')) {
        return new Response(
          JSON.stringify({
            generatedAt: '2026-09-03T12:00:00.000Z',
            sources: [{ source: 'coach_us', merchant: 'Coach' }],
            items: [
              { sourceScopedId: 'coach_us:C8879', source: 'coach_us', title: 'Tabby', brand: 'Coach', price: { amount: 350, currency: 'USD' }, suggestedRetailPrice: { amount: 8400, currency: 'MXN' }, availability: 'inStock', detailUrl: 'u', imageUrl: null, lastObservedAt: '2026-09-03T10:00:00.000Z', dataOrigin: 'live_crawl' },
              { sourceScopedId: 'coach_us:C0000', source: 'coach_us', title: 'Snapshot Bag', brand: 'Coach', price: null, suggestedRetailPrice: null, availability: 'unknown', detailUrl: 'u', imageUrl: null, lastObservedAt: '2026-08-12T00:00:00.000Z', dataOrigin: 'curated_us_snapshot' },
            ],
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      if (href.includes('/admin/products')) {
        return new Response(JSON.stringify({ products: [PRODUCT_A], nextCursor: null }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      if (href.includes('/admin/selection')) {
        return new Response(JSON.stringify({ version: 7 }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return new Response('{}', { status: 404 });
    }) as typeof fetch;
    const client = new ApiClient({ baseUrl: 'https://api.example', getToken: () => 'tok', onUnauthorized: () => {}, fetchImpl });
    render(
      <MemoryRouter>
        <FeedPreviewScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByLabelText('placement catalog_browse')).toBeTruthy());
    expect(screen.getByLabelText('live badge')).toBeTruthy();
    expect(screen.getByLabelText('snapshot badge')).toBeTruthy();
    expect(screen.getByText(/rule all-coach/)).toBeTruthy();
    expect(screen.getByText(/selection v7/)).toBeTruthy();
    expect(screen.getByText(/Consultar precio/)).toBeTruthy();
  });
});
