import { useEffect, useState } from 'react';
import type { ApiClient } from '../api/client.js';
import { createPoller, POLL_INTERVAL_DEFAULT_MS, type PollStatus } from '../api/poll.js';
import { ConnectionBanner } from '../components/ConnectionBanner.js';
import { DataTable } from '../components/DataTable.js';
import { Sparkline } from '../components/Sparkline.js';
import { StatusBadge } from '../components/StatusBadge.js';
import type { AdminRun } from '../api/types.js';

interface RunsList {
  readonly runs: readonly AdminRun[];
  readonly nextCursor: string | null;
}

function formatDuration(ms: number | null): string {
  if (ms === null) return '—';
  const seconds = Math.round(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
}

/** "What happened, and why did it stop?" — filters, drawer, sparkline, no retry. */
export function RunsScreen(props: { readonly client: ApiClient }): JSX.Element {
  const [source, setSource] = useState('');
  const [kind, setKind] = useState('');
  const [status, setStatus] = useState('');
  const [list, setList] = useState<RunsList | null>(null);
  const [poll, setPoll] = useState<PollStatus>('ok');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [detail, setDetail] = useState<AdminRun | null>(null);
  const [spark, setSpark] = useState<ReadonlyArray<number | null>>([]);

  const query = `/admin/runs?limit=50${source !== '' ? `&source=${encodeURIComponent(source)}` : ''}${kind !== '' ? `&kind=${encodeURIComponent(kind)}` : ''}${status !== '' ? `&status=${encodeURIComponent(status)}` : ''}`;

  useEffect(() => {
    const poller = createPoller<RunsList>({
      client: props.client,
      path: query,
      intervalMs: POLL_INTERVAL_DEFAULT_MS,
      onData: (body) => setList(body),
      onStatus: (next) => setPoll(next),
    });
    poller.start();
    return () => poller.stop();
  }, [props.client, query]);

  useEffect(() => {
    let cancelled = false;
    void props.client
      .get<RunsList>('/admin/runs?kind=discovery&limit=30')
      .then((result) => {
        if (!cancelled && result.data !== null) {
          setSpark(result.data.runs.map((run) => run.coverage));
        }
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [props.client]);

  useEffect(() => {
    if (selectedId === null) {
      setDetail(null);
      return;
    }
    let cancelled = false;
    void props.client
      .get<{ run: AdminRun }>(`/admin/runs/${encodeURIComponent(selectedId)}`)
      .then((result) => {
        if (!cancelled && result.data !== null) setDetail(result.data.run);
      })
      .catch(() => {});
    return () => {
      cancelled = true;
    };
  }, [props.client, selectedId]);

  return (
    <section aria-label="Runs">
      <h2>Runs</h2>
      <ConnectionBanner status={poll} lastOkAt={null} />
      <div>
        <label>
          Source{' '}
          <select aria-label="filter source" value={source} onChange={(e) => setSource(e.target.value)}>
            <option value="">all</option>
            <option value="coach_us">coach_us</option>
            <option value="guess_us">guess_us</option>
          </select>
        </label>{' '}
        <label>
          Kind{' '}
          <select aria-label="filter kind" value={kind} onChange={(e) => setKind(e.target.value)}>
            <option value="">all</option>
            <option value="discovery">discovery</option>
            <option value="watch">watch</option>
          </select>
        </label>{' '}
        <label>
          Status{' '}
          <select aria-label="filter status" value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">all</option>
            <option value="success">success</option>
            <option value="partial">partial</option>
            <option value="failed">failed</option>
            <option value="blocked">blocked</option>
          </select>
        </label>
      </div>
      <div aria-label="coverage sparkline">
        <span>Coverage (last 30 discovery runs)</span> <Sparkline values={spark} />
      </div>
      {list === null ? (
        <p>Loading…</p>
      ) : (
        <DataTable
          headers={['started', 'source', 'kind', 'status', 'sel', 'discovered', 'selected', 'fetched', 'parsed', 'coverage', 'new', 'changed', 'missing', 'inactive', 'deselected', 'duration']}
          rowKeys={list.runs.map((run) => run.id)}
          rows={list.runs.map((run) => [
            run.startedAt,
            run.source,
            run.kind,
            <StatusBadge key="s" status={run.status} />,
            run.selectionVersion ?? '—',
            run.urlsDiscovered,
            run.urlsSelected,
            run.pagesFetched,
            run.successfulParses,
            run.coverage === null ? '—' : `${(run.coverage * 100).toFixed(1)}%`,
            run.newItems,
            run.changedItems,
            run.missingItems,
            run.inactiveItems,
            run.deselectedItems,
            formatDuration(run.durationMs),
          ])}
        />
      )}
      {list !== null && (
        <ul>
          {list.runs.map((run) => (
            <li key={run.id}>
              <button type="button" onClick={() => setSelectedId(run.id)}>
                Open {run.id}
              </button>
            </li>
          ))}
        </ul>
      )}
      {detail !== null && (
        <aside aria-label="run detail">
          <h3>
            Run {detail.id} <StatusBadge status={detail.status} />
          </h3>
          {detail.status === 'blocked' && (
            <p>
              Stop — this source is blocked. Disable it in the selection; do not work around the
              block. There is no retry: unblock at the merchant, not in this console.
            </p>
          )}
          <dl>
            <dt>errors_by_type</dt>
            <dd>{Object.entries(detail.errorsByType).map(([k, v]) => `${k}: ${v}`).join(', ') || 'none'}</dd>
            <dt>selection version</dt>
            <dd>{detail.selectionVersion ?? '—'}</dd>
            <dt>duration</dt>
            <dd>{formatDuration(detail.durationMs)}</dd>
          </dl>
          <button type="button" onClick={() => { setSelectedId(null); setDetail(null); }}>
            Close
          </button>
        </aside>
      )}
    </section>
  );
}
