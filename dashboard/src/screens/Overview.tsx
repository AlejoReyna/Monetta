import { useEffect, useState } from 'react';
import type { ApiClient } from '../api/client.js';
import { createPoller, POLL_INTERVAL_OVERVIEW_MS, type PollStatus } from '../api/poll.js';
import { ConnectionBanner } from '../components/ConnectionBanner.js';
import { MetricCard } from '../components/MetricCard.js';
import { StatusBadge } from '../components/StatusBadge.js';
import { toConnection, type OverviewResponse } from './overviewTypes.js';

/** "Is it working right now?" — one poll, per-source cards, budget, alerts. */
export function OverviewScreen(props: { readonly client: ApiClient }): JSX.Element {
  const [data, setData] = useState<OverviewResponse | null>(null);
  const [status, setStatus] = useState<PollStatus>('ok');
  const [lastOkAt, setLastOkAt] = useState<Date | null>(null);

  useEffect(() => {
    const poller = createPoller<OverviewResponse>({
      client: props.client,
      path: '/admin/overview',
      intervalMs: POLL_INTERVAL_OVERVIEW_MS,
      onData: (body) => {
        setData(body);
        setLastOkAt(new Date(body.generatedAt));
      },
      onStatus: (next) => setStatus(next),
    });
    poller.start();
    return () => poller.stop();
  }, [props.client]);

  const banner: PollStatus = data === null ? (status === 'ok' ? 'ok' : 'unreachable') : status === 'ok' ? 'ok' : 'degraded';
  return (
    <section aria-label="Overview">
      <h2>Overview</h2>
      <ConnectionBanner status={banner} lastOkAt={lastOkAt} />
      {data === null ? (
        <p>{status === 'ok' ? 'Loading…' : 'Waiting for the API — last-known data will appear here.'}</p>
      ) : (
        <>
          <p>
            Overall: <StatusBadge status={toConnection(data.status) === 'reachable' ? 'healthy' : 'degraded'} />{' '}
            <span>as of {data.generatedAt}</span>
          </p>
          {data.sources.map((source) => (
            <article key={source.source} aria-label={`source ${source.source}`}>
              <h3>
                {source.source} <StatusBadge status={source.status} />
              </h3>
              {source.reasons.length > 0 && <p>Reasons: {source.reasons.join(', ')}</p>}
              <p>
                Discovery freshness: {source.freshness.discoveryHours === null ? 'never' : `${source.freshness.discoveryHours.toFixed(1)} h`} ·{' '}
                Watch freshness: {source.freshness.watchHours === null ? 'never watched' : `${source.freshness.watchHours.toFixed(1)} h`}
              </p>
              <div>
                <MetricCard label="selected" value={source.counts.selected} />
                <MetricCard label="served" value={source.counts.served} />
                <MetricCard label="deselected" value={source.counts.deselected} />
                <MetricCard label="inactive" value={source.counts.inactive} />
                <MetricCard
                  label="coverage"
                  value={source.coverage === null ? '—' : `${(source.coverage * 100).toFixed(1)}%`}
                />
              </div>
            </article>
          ))}
          <div aria-label="page budget">
            <p>
              Page budget today: {data.pageBudget.usedToday} / {data.pageBudget.limit}
            </p>
            <progress value={data.pageBudget.usedToday} max={Math.max(data.pageBudget.limit, 1)} />
          </div>
          <p>
            Selection v{data.selection?.version ?? '—'} by {data.selection?.appliedBy ?? 'unknown'} ·{' '}
            {data.selection?.appliedAt ?? 'never'}
          </p>
          <section aria-label="alerts">
            <h3>Latest alerts</h3>
            {data.alerts.length === 0 ? (
              <p>No alerts.</p>
            ) : (
              <ul>
                {data.alerts.map((alert) => (
                  <li key={alert.key}>
                    {alert.key} — {alert.lastSentAt}
                    {alert.suppressed ? ' (suppressed: dedupe window)' : ''}
                  </li>
                ))}
              </ul>
            )}
          </section>
        </>
      )}
    </section>
  );
}
