import { describe, expect, it, afterEach } from 'vitest';
import { render, screen, fireEvent, waitFor, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { ApiClient } from '../src/api/client.js';
import { OverviewScreen } from '../src/screens/Overview.js';
import { RunsScreen } from '../src/screens/Runs.js';

afterEach(() => cleanup());

function clientWith(routes: Record<string, unknown>, opts?: { fail?: boolean }): {
  client: ApiClient;
  calls: string[];
} {
  const calls: string[] = [];
  const fetchImpl = (async (url: unknown) => {
    const href = String(url);
    calls.push(href);
    if (opts?.fail === true) throw new Error('network down');
    const path = href.replace('https://api.example', '');
    for (const [prefix, body] of Object.entries(routes)) {
      if (path.startsWith(prefix)) {
        return new Response(JSON.stringify(body), {
          status: 200,
          headers: { 'Content-Type': 'application/json', ETag: `"${prefix}"` },
        });
      }
    }
    return new Response(JSON.stringify({ error: 'no route' }), { status: 404 });
  }) as typeof fetch;
  const client = new ApiClient({
    baseUrl: 'https://api.example',
    getToken: () => 'tok',
    onUnauthorized: () => {},
    fetchImpl,
  });
  return { client, calls };
}

const NOW_ISO = '2026-09-03T12:00:00.000Z';

function overviewBody(status: 'healthy' | 'degraded', sources: unknown[]): unknown {
  return {
    generatedAt: NOW_ISO,
    status,
    sources,
    pageBudget: { limit: 3000, usedToday: 120, remaining: 2880 },
    selection: { version: 7, hash: 'h', appliedBy: 'owner', appliedAt: NOW_ISO, note: null },
    alerts: [{ key: 'source.blocked:guess_us', lastSentAt: NOW_ISO, suppressed: true }],
  };
}

function sourceCard(source: string, healthy: boolean, reasons: string[]): unknown {
  return {
    source,
    status: healthy ? 'healthy' : 'unhealthy',
    reasons,
    freshness: { discoveryHours: 1.5, watchHours: healthy ? 0.5 : null },
    lastDiscoveryRun: null,
    lastWatchRun: null,
    counts: { selected: 4, served: 2, deselected: 1, inactive: 1 },
    lastSuccessfulRunAt: NOW_ISO,
    coverage: 0.98,
  };
}

describe('OverviewScreen (WP-64)', () => {
  it('renders healthy and degraded sources with labels, counts and budget', async () => {
    const { client } = clientWith({
      '/admin/overview': overviewBody('degraded', [
        sourceCard('coach_us', true, []),
        sourceCard('guess_us', false, ['watch_stale']),
      ]),
    });
    render(
      <MemoryRouter>
        <OverviewScreen client={client} />
      </MemoryRouter>,
    );
    expect(await screen.findByText('Overview')).toBeTruthy();
    await waitFor(() => expect(screen.getByLabelText('source coach_us').textContent).toContain('healthy'));
    expect(screen.getByLabelText('source guess_us').textContent).toContain('unhealthy');
    expect(screen.getByLabelText('source guess_us').textContent).toContain('watch_stale');
    // Counts and budget bar render from the same payload.
    expect(screen.getByLabelText('source coach_us').textContent).toContain('98.0%');
    expect(screen.getByText(/Page budget today: 120 \/ 3000/)).toBeTruthy();
    expect(screen.getByText(/Selection v7 by owner/)).toBeTruthy();
    // Watch freshness is a separate clock from discovery freshness.
    expect(screen.getByLabelText('source coach_us').textContent).toContain('Watch freshness');
  });

  it('an unreachable API says so loudly and never looks healthy', async () => {
    const { client } = clientWith({}, { fail: true });
    render(
      <MemoryRouter>
        <OverviewScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByRole('status').textContent).toContain('unreachable'));
    expect(screen.queryByLabelText(/source coach_us/)).toBeNull();
  });
});

const RUN_A = {
  id: 'r-watch-2',
  source: 'coach_us',
  kind: 'watch',
  status: 'success',
  startedAt: '2026-09-03T11:00:00.000Z',
  endedAt: '2026-09-03T11:01:00.000Z',
  durationMs: 60_000,
  selectionVersion: 7,
  urlsDiscovered: 12,
  urlsSelected: 12,
  pagesFetched: 12,
  successfulParses: 12,
  coverage: 1,
  newItems: 0,
  changedItems: 0,
  missingItems: 0,
  inactiveItems: 0,
  deselectedItems: 0,
  errorsByType: {},
};

const RUN_B = {
  id: 'r-guess-1',
  source: 'guess_us',
  kind: 'discovery',
  status: 'blocked',
  startedAt: '2026-09-03T10:00:00.000Z',
  endedAt: '2026-09-03T10:00:30.000Z',
  durationMs: 30_000,
  selectionVersion: 7,
  urlsDiscovered: 50,
  urlsSelected: 50,
  pagesFetched: 0,
  successfulParses: 0,
  coverage: null,
  newItems: 0,
  changedItems: 0,
  missingItems: 0,
  inactiveItems: 0,
  deselectedItems: 0,
  errorsByType: { captcha_or_block: 40 },
};

describe('RunsScreen (WP-64)', () => {
  function runsClient(): { client: ApiClient; calls: string[] } {
    return clientWith({
      '/admin/runs/r-guess-1': { run: RUN_B },
      '/admin/runs/r-watch-2': { run: RUN_A },
      '/admin/runs': { runs: [RUN_A, RUN_B], nextCursor: null },
    });
  }

  it('renders the run table with coverage, duration and selection version', async () => {
    const { client } = runsClient();
    render(
      <MemoryRouter>
        <RunsScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByRole('button', { name: 'Open r-watch-2' })).toBeTruthy());
    expect(screen.getByText('100.0%')).toBeTruthy();
    expect(screen.getByText('1m 0s')).toBeTruthy();
  });

  it('filters refetch with the query and the drawer explains a block with no retry', async () => {
    const { client, calls } = runsClient();
    render(
      <MemoryRouter>
        <RunsScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByRole('button', { name: 'Open r-guess-1' })).toBeTruthy());

    fireEvent.change(screen.getByLabelText('filter status'), { target: { value: 'blocked' } });
    await waitFor(() =>
      expect(calls.some((url) => url.includes('status=blocked'))).toBe(true),
    );

    fireEvent.click(screen.getByRole('button', { name: 'Open r-guess-1' }));
    await waitFor(() => expect(screen.getByLabelText('run detail')).toBeTruthy());
    expect(screen.getByLabelText('run detail').textContent).toContain('captcha_or_block: 40');
    expect(screen.getByLabelText('run detail').textContent).toContain('Disable it in the selection');
    // There is deliberately no retry control for a blocked source.
    expect(screen.queryByRole('button', { name: /retry/i })).toBeNull();
  });

  it('renders the coverage sparkline without a chart library', async () => {
    const { client } = runsClient();
    const { container } = render(
      <MemoryRouter>
        <RunsScreen client={client} />
      </MemoryRouter>,
    );
    await waitFor(() => expect(container.querySelector('svg[aria-label^="coverage trend"]')).not.toBeNull());
  });
});
