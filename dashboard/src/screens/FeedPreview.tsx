import { useEffect, useState } from 'react';
import type { ApiClient } from '../api/client.js';
import { createPoller, POLL_INTERVAL_DEFAULT_MS, type PollStatus } from '../api/poll.js';
import { ConnectionBanner } from '../components/ConnectionBanner.js';
import { formatMxnPrice, formatUsdPrice } from '../catalog/money.js';
import type { AdminProduct, FeedItem, FeedPreviewBody } from '../api/types.js';

function relativeAge(iso: string, nowMs: number): string {
  const diffMs = Math.max(nowMs - Date.parse(iso), 0);
  const hours = Math.floor(diffMs / 3_600_000);
  if (hours < 1) return 'actualizado hace menos de 1 h';
  if (hours < 24) return `actualizado hace ${hours} h`;
  return `actualizado hace ${Math.floor(hours / 24)} d`;
}

export function groupByPlacement(
  items: readonly FeedItem[],
  placementsById: ReadonlyMap<string, readonly string[]>,
): ReadonlyMap<string, readonly FeedItem[]> {
  const groups = new Map<string, FeedItem[]>();
  for (const item of items) {
    const placements = placementsById.get(item.sourceScopedId) ?? [];
    const visible = placements.filter((p) => p !== 'hidden');
    const keys = placements.includes('hidden') ? ['hidden'] : visible.length === 0 ? ['unplaced'] : visible;
    for (const key of keys) {
      const bucket = groups.get(key) ?? [];
      bucket.push(item);
      groups.set(key, bucket);
    }
  }
  return groups;
}

/**
 * Canonical staging payload, grouped by placement (§ 6.6). Placement and
 * rule data come from the products read (the public feed carries merchant
 * data only — see WP-16 follow-up); hidden items are flagged, never shown
 * as served.
 */
export function FeedPreviewScreen(props: { readonly client: ApiClient }): JSX.Element {
  const [feed, setFeed] = useState<FeedPreviewBody | null>(null);
  const [products, setProducts] = useState<readonly AdminProduct[]>([]);
  const [selectionVersion, setSelectionVersion] = useState<number | null>(null);
  const [poll, setPoll] = useState<PollStatus>('ok');

  useEffect(() => {
    const feedPoller = createPoller<FeedPreviewBody>({
      client: props.client,
      path: '/admin/feed-preview',
      intervalMs: POLL_INTERVAL_DEFAULT_MS,
      onData: (body) => setFeed(body),
      onStatus: (next) => setPoll(next),
    });
    // Metadata join (placements, rule ids) needs hidden rows too, so this
    // reads `state=all` — capped at 200, server-side. Rows beyond the cap
    // fall back to `unplaced`, never to `hidden`.
    const productsPoller = createPoller<{ products: AdminProduct[] }>({
      client: props.client,
      path: '/admin/products?limit=200&state=all',
      intervalMs: POLL_INTERVAL_DEFAULT_MS,
      onData: (body) => setProducts(body.products),
      onStatus: () => {},
    });
    feedPoller.start();
    productsPoller.start();
    let cancelled = false;
    void props.client
      .get<{ version: number }>('/admin/selection')
      .then((result) => {
        if (!cancelled && result.data !== null) setSelectionVersion(result.data.version);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
      feedPoller.stop();
      productsPoller.stop();
    };
  }, [props.client]);

  const placementsById = new Map<string, readonly string[]>();
  const ruleById = new Map<string, string | null>();
  for (const product of products) {
    placementsById.set(product.sourceScopedId, product.placements);
    ruleById.set(product.sourceScopedId, product.matchedRuleId);
  }
  const groups: ReadonlyMap<string, readonly FeedItem[]> = feed === null
    ? new Map<string, readonly FeedItem[]>()
    : groupByPlacement(feed.items, placementsById);
  const nowMs = Date.now();

  return (
    <section aria-label="Feed preview">
      <h2>Feed preview</h2>
      <ConnectionBanner status={poll} lastOkAt={null} />
      {feed === null ? (
        <p>Loading…</p>
      ) : (
        <>
          <p>
            selection v{selectionVersion ?? '—'} · {feed.items.length} items · generated {feed.generatedAt}
          </p>
          {[...groups.entries()].map(([placement, items]) => (
            <section key={placement} aria-label={`placement ${placement}`}>
              <h3>
                {placement} ({items.length}){placement === 'hidden' ? ' — suppressed from the app' : ''}
              </h3>
              <ul>
                {items.map((item) => (
                  <li key={item.sourceScopedId}>
                    {item.imageUrl !== null && <img src={item.imageUrl} alt="" width={40} />}{' '}
                    <strong>{item.title}</strong> · {formatUsdPrice(item.price)} ·{' '}
                    {formatMxnPrice(item.suggestedRetailPrice)} · rule {ruleById.get(item.sourceScopedId) ?? '—'}{' '}
                    {item.dataOrigin === 'live_crawl' ? (
                      <span aria-label="live badge">● live · {relativeAge(item.lastObservedAt, nowMs)}</span>
                    ) : (
                      <span aria-label="snapshot badge">▲ Snapshot de referencia · 2026-08-12</span>
                    )}
                  </li>
                ))}
              </ul>
            </section>
          ))}
        </>
      )}
    </section>
  );
}
