import { useEffect, useState } from 'react';
import type { ApiClient } from '../api/client.js';
import { createPoller, POLL_INTERVAL_DEFAULT_MS, type PollStatus } from '../api/poll.js';
import { ConnectionBanner } from '../components/ConnectionBanner.js';
import { formatUsdPrice } from '../catalog/money.js';
import type { AdminProduct } from '../api/types.js';

interface ProductList {
  readonly products: readonly AdminProduct[];
  readonly nextCursor: string | null;
}

function appliedBy(): string {
  try {
    return sessionStorage.getItem('monetta.dashboard.appliedBy') ?? 'owner';
  } catch {
    return 'owner';
  }
}

/** "What did we actually get?" — searchable, server-paged, pin/hide inline. */
export function ProductsScreen(props: { readonly client: ApiClient }): JSX.Element {
  const [q, setQ] = useState('');
  const [source, setSource] = useState('');
  const [state, setState] = useState('all');
  const [tier, setTier] = useState('');
  const [items, setItems] = useState<readonly AdminProduct[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [poll, setPoll] = useState<PollStatus>('ok');

  const query = `/admin/products?limit=50${q !== '' ? `&q=${encodeURIComponent(q)}` : ''}${source !== '' ? `&source=${encodeURIComponent(source)}` : ''}&state=${state}${tier !== '' ? `&tier=${encodeURIComponent(tier)}` : ''}`;

  useEffect(() => {
    setItems([]);
    setCursor(null);
    const poller = createPoller<ProductList>({
      client: props.client,
      path: query,
      intervalMs: POLL_INTERVAL_DEFAULT_MS,
      onData: (body) => {
        // Reconcile: the poll is the source of truth — it absorbs the
        // optimistic pin/hide updates once the server has applied them.
        setItems(body.products);
        setCursor(body.nextCursor);
      },
      onStatus: (next) => setPoll(next),
    });
    poller.start();
    return () => poller.stop();
  }, [props.client, query]);

  async function loadMore(): Promise<void> {
    if (cursor === null) return;
    const result = await props.client.get<ProductList>(`${query}&cursor=${encodeURIComponent(cursor)}`);
    if (result.data !== null) {
      setItems((previous) => [...previous, ...result.data!.products]);
      setCursor(result.data.nextCursor);
    }
  }

  async function act(product: AdminProduct, action: 'pin' | 'hide'): Promise<void> {
    // Optimistic: reflect immediately, then reconcile against the server's
    // answer. A failed write re-reads the list, reverting the optimistic
    // row — the UI never sits on an unconfirmed mutation.
    const snapshot = items;
    setItems((rows) =>
      rows.map((row) =>
        row.sourceScopedId === product.sourceScopedId
          ? {
              ...row,
              watchTier: action === 'pin' ? 'pinned' : row.watchTier,
              placements: action === 'hide' ? [...row.placements, 'hidden'] : row.placements,
            }
          : row,
      ),
    );
    const result = await props.client.send(
      `/admin/products/${encodeURIComponent(product.sourceScopedId)}/${action}`,
      'POST',
      {},
      { 'X-Applied-By': appliedBy() },
    );
    if (result.status === 401) return;
    const reconciled = await props.client.get<ProductList>(query);
    if (reconciled.data !== null) {
      setItems(reconciled.data.products);
      setCursor(reconciled.data.nextCursor);
    } else {
      setItems(snapshot);
    }
  }

  return (
    <section aria-label="Products">
      <h2>Products</h2>
      <ConnectionBanner status={poll} lastOkAt={null} />
      <form
        onSubmit={(event) => {
          event.preventDefault();
          const value = (new FormData(event.currentTarget).get('q') as string | null) ?? '';
          setQ(value);
        }}
      >
        <input name="q" aria-label="search products" placeholder="Search title or external ID" defaultValue={q} />{' '}
        <button type="submit">Search</button>{' '}
        <label>
          Source{' '}
          <select aria-label="filter source" value={source} onChange={(e) => setSource(e.target.value)}>
            <option value="">all</option>
            <option value="coach_us">coach_us</option>
            <option value="guess_us">guess_us</option>
          </select>
        </label>{' '}
        <label>
          State{' '}
          <select aria-label="filter state" value={state} onChange={(e) => setState(e.target.value)}>
            <option value="all">all</option>
            <option value="selected">selected</option>
            <option value="deselected">deselected</option>
            <option value="active">active</option>
            <option value="inactive">inactive</option>
            <option value="served">served</option>
          </select>
        </label>{' '}
        <label>
          Tier{' '}
          <select aria-label="filter tier" value={tier} onChange={(e) => setTier(e.target.value)}>
            <option value="">all</option>
            <option value="standard">standard</option>
            <option value="pinned">pinned</option>
          </select>
        </label>
      </form>
      <table>
        <thead>
          <tr>
            <th scope="col">product</th>
            <th scope="col">price</th>
            <th scope="col">availability</th>
            <th scope="col">tier</th>
            <th scope="col">rule</th>
            <th scope="col">actions</th>
          </tr>
        </thead>
        <tbody>
          {items.map((item) => (
            <tr key={item.sourceScopedId}>
              <td>
                {item.imageUrl !== null && <img src={item.imageUrl} alt="" width={40} />}{' '}
                <a href={item.detailUrl} target="_blank" rel="noreferrer">
                  {item.title}
                </a>{' '}
                <span>{item.source}</span>
              </td>
              <td>{formatUsdPrice(item.priceUsd === null ? null : { amount: item.priceUsd })}</td>
              <td>{item.availability}</td>
              <td>{item.watchTier}</td>
              <td>{item.matchedRuleId ?? '—'}</td>
              <td>
                <button type="button" onClick={() => void act(item, 'pin')}>
                  Pin {item.sourceScopedId}
                </button>{' '}
                <button type="button" onClick={() => void act(item, 'hide')}>
                  Hide {item.sourceScopedId}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {cursor !== null && (
        <button type="button" onClick={() => void loadMore()}>
          Load more
        </button>
      )}
    </section>
  );
}
