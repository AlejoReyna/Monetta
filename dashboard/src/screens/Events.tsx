import { useEffect, useState } from 'react';
import type { ApiClient } from '../api/client.js';
import { createPoller, POLL_INTERVAL_DEFAULT_MS, type PollStatus } from '../api/poll.js';
import { ConnectionBanner } from '../components/ConnectionBanner.js';
import type { CatalogEvent } from '../api/types.js';

/** "What changed since yesterday?" — the timeline that makes live visible. */
export function EventsScreen(props: { readonly client: ApiClient }): JSX.Element {
  const [events, setEvents] = useState<readonly CatalogEvent[]>([]);
  const [poll, setPoll] = useState<PollStatus>('ok');

  useEffect(() => {
    const poller = createPoller<{ events: CatalogEvent[]; nextSince: string }>({
      client: props.client,
      path: '/admin/events',
      intervalMs: POLL_INTERVAL_DEFAULT_MS,
      onData: (body) => setEvents(body.events),
      onStatus: (next) => setPoll(next),
    });
    poller.start();
    return () => poller.stop();
  }, [props.client]);

  return (
    <section aria-label="Events">
      <h2>Events</h2>
      <ConnectionBanner status={poll} lastOkAt={null} />
      {events.length === 0 ? (
        <p>No events in the last 24 hours — if a full day stays empty, the watch tier is not running.</p>
      ) : (
        <ol>
          {events.map((event) => (
            <li key={event.id}>
              <strong>{event.kind}</strong> {event.sourceScopedId} · {event.observedAt}
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}
