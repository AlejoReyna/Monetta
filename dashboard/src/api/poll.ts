import { ApiClient } from './client.js';

/**
 * Polling loop (WP-63, CATALOG_DASHBOARD § 7.1):
 *
 * - Overview every 15 s, other screens every 30 s, always with
 *   `If-None-Match` (handled inside `ApiClient`).
 * - Paused while `document.hidden` — a forgotten tab must not poll a
 *   crawler box all night.
 * - On failure: exponential backoff to a 2-minute ceiling; last-known data
 *   stays on screen with its timestamp. Never blank the screen on a failed
 *   refresh.
 */
export const POLL_INTERVAL_OVERVIEW_MS = 15_000;
export const POLL_INTERVAL_DEFAULT_MS = 30_000;
export const POLL_BACKOFF_CEILING_MS = 120_000;

export type PollStatus = 'ok' | 'degraded' | 'unreachable';

export interface PollerDeps<T> {
  readonly client: ApiClient;
  readonly path: string;
  readonly intervalMs?: number;
  readonly isHidden?: () => boolean;
  readonly schedule?: (fn: () => void, ms: number) => { cancel: () => void };
  readonly onData: (data: T, etag: string | null, at: Date) => void;
  readonly onStatus: (status: PollStatus, at: Date) => void;
  readonly now?: () => Date;
}

export interface Poller {
  start(): void;
  stop(): void;
  refreshNow(): void;
}

export function createPoller<T>(deps: PollerDeps<T>): Poller {
  const interval = deps.intervalMs ?? POLL_DEFAULT_MS();
  const now = deps.now ?? (() => new Date());
  const schedule = deps.schedule ?? ((fn, ms) => {
    const timer = setTimeout(fn, ms);
    return { cancel: () => clearTimeout(timer) };
  });
  const isHidden = deps.isHidden ?? (() => typeof document !== 'undefined' && document.hidden);
  let stopped = false;
  let timer: { cancel: () => void } | null = null;
  let failures = 0;
  let started = false;

  function POLL_DEFAULT_MS(): number {
    return POLL_INTERVAL_DEFAULT_MS;
  }

  async function tick(): Promise<void> {
    if (stopped) return;
    if (isHidden()) {
      // Skip this round entirely; re-check on the base interval.
      timer = schedule(() => void tick(), interval);
      return;
    }
    let status: PollStatus = 'unreachable';
    try {
      const result = await deps.client.get<T>(deps.path);
      if (result.status === 401) {
        // Session handoff handled by the client; stop polling quietly.
        return;
      }
      if (result.notModified) {
        // Cached copy revalidated: repopulate from it (covers screens
        // remounting onto a warm client cache) and stay healthy.
        failures = 0;
        status = 'ok';
        if (result.data !== null) deps.onData(result.data, result.etag, now());
        deps.onStatus(status, now());
      } else if (result.data !== null) {
        failures = 0;
        status = 'ok';
        deps.onData(result.data, result.etag, now());
        deps.onStatus(status, now());
      } else {
        failures += 1;
        status = failures === 1 ? 'degraded' : 'unreachable';
        deps.onStatus(status, now());
      }
    } catch {
      failures += 1;
      status = failures === 1 ? 'degraded' : 'unreachable';
      deps.onStatus(status, now());
    }
    if (stopped) return;
    const delay = status === 'ok' ? interval : Math.min(interval * 2 ** (failures - 1), POLL_BACKOFF_CEILING_MS);
    timer = schedule(() => void tick(), delay);
  }

  return {
    start() {
      if (started) return;
      started = true;
      stopped = false;
      void tick();
    },
    stop() {
      stopped = true;
      timer?.cancel();
      timer = null;
    },
    refreshNow() {
      if (stopped) return;
      timer?.cancel();
      void tick();
    },
  };
}
