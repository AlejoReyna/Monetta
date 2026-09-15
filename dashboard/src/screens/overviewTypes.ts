import type { ConnectionState, SelectionMeta, SourceOverview } from '../api/types.js';

export interface OverviewResponse {
  readonly generatedAt: string;
  readonly status: 'healthy' | 'degraded';
  readonly sources: readonly SourceOverview[];
  readonly pageBudget: { readonly limit: number; readonly usedToday: number; readonly remaining: number };
  readonly selection: (SelectionMeta & { readonly hash: string }) | null;
  readonly alerts: ReadonlyArray<{ readonly key: string; readonly lastSentAt: string; readonly suppressed: boolean }>;
}

export function toConnection(status: 'healthy' | 'degraded' | null): ConnectionState {
  if (status === null) return 'unreachable';
  return status === 'healthy' ? 'reachable' : 'degraded';
}
