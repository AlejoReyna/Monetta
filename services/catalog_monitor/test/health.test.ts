import { describe, expect, it } from 'vitest';
import { evaluateSourceHealth } from '../src/monitor/health.js';
import { InMemoryCrawlRunRepository } from './support/inMemoryRepositories.js';
import type { CrawlRunMetrics } from '../src/domain/types.js';

const now = new Date('2026-08-10T12:00:00.000Z');

function run(overrides: Partial<CrawlRunMetrics> = {}): Omit<CrawlRunMetrics, 'sourceId'> & {
  sourceId: 'coach_us';
} {
  return {
    sourceId: 'coach_us',
    startedAt: now,
    endedAt: now,
    status: 'success',
    isFullSnapshot: true,
    selectionVersion: null,
    urlsDiscovered: 100,
    urlsSelected: 100,
    pagesFetched: 100,
    successfulParses: 100,
    newItems: 0,
    changedItems: 0,
    missingItems: 0,
    inactiveItems: 0,
    deselectedItems: 0,
    errorsByType: {},
    ...overrides,
  };
}

describe('evaluateSourceHealth', () => {
  it('is healthy with a fresh, complete, stable run', async () => {
    const repo = new InMemoryCrawlRunRepository();
    repo.seedRun(run({ endedAt: new Date(now.getTime() - 60 * 60 * 1000) }));
    const health = await evaluateSourceHealth('coach_us', repo, now);
    expect(health.status).toBe('healthy');
    expect(health.reasons).toHaveLength(0);
  });

  it('flags no_recent_successful_run when the last success is older than 36h', async () => {
    const repo = new InMemoryCrawlRunRepository();
    repo.seedRun(run({ endedAt: new Date(now.getTime() - 40 * 60 * 60 * 1000) }));
    const health = await evaluateSourceHealth('coach_us', repo, now);
    expect(health.reasons).toContain('no_recent_successful_run');
  });

  it('flags no_recent_successful_run when there is no successful run at all', async () => {
    const repo = new InMemoryCrawlRunRepository();
    repo.seedRun(run({ status: 'failed', endedAt: now }));
    const health = await evaluateSourceHealth('coach_us', repo, now);
    expect(health.status).toBe('unhealthy');
    expect(health.reasons).toContain('no_recent_successful_run');
  });

  it('flags low_parse_coverage when required-field coverage drops below 98%', async () => {
    const repo = new InMemoryCrawlRunRepository();
    repo.seedRun(
      run({
        endedAt: new Date(now.getTime() - 60 * 60 * 1000),
        pagesFetched: 100,
        successfulParses: 90,
      }),
    );
    const health = await evaluateSourceHealth('coach_us', repo, now);
    expect(health.reasons).toContain('low_parse_coverage');
    expect(health.lastRequiredFieldCoverage).toBeCloseTo(0.9);
  });

  it('flags product_count_drop when successfulParses falls more than 20% run over run', async () => {
    const repo = new InMemoryCrawlRunRepository();
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 48 * 60 * 60 * 1000),
        endedAt: new Date(now.getTime() - 48 * 60 * 60 * 1000),
        successfulParses: 100,
      }),
    );
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 60 * 60 * 1000),
        endedAt: new Date(now.getTime() - 60 * 60 * 1000),
        successfulParses: 70,
      }),
    );
    const health = await evaluateSourceHealth('coach_us', repo, now);
    expect(health.reasons).toContain('product_count_drop');
  });

  it('flags widespread_failures when the most recent run was blocked', async () => {
    const repo = new InMemoryCrawlRunRepository();
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 2 * 60 * 60 * 1000),
        endedAt: new Date(now.getTime() - 60 * 60 * 1000),
      }),
    ); // a healthy success further back in history
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 10 * 60 * 1000),
        endedAt: new Date(now.getTime() - 5 * 60 * 1000),
        status: 'blocked',
        successfulParses: 0,
      }),
    );
    const health = await evaluateSourceHealth('coach_us', repo, now);
    expect(health.reasons).toContain('widespread_failures');
  });

  it('a recent capped (--limit) run cannot make an old, stale catalog look healthy', async () => {
    const repo = new InMemoryCrawlRunRepository();
    // The last *full* snapshot is old enough to be stale on its own.
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 40 * 60 * 60 * 1000),
        endedAt: new Date(now.getTime() - 40 * 60 * 60 * 1000),
        isFullSnapshot: true,
      }),
    );
    // A capped smoke run landed minutes ago — status: success, but not a
    // full snapshot. It must not count as "the catalog was refreshed."
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 5 * 60 * 1000),
        endedAt: new Date(now.getTime() - 5 * 60 * 1000),
        status: 'success',
        isFullSnapshot: false,
      }),
    );

    const health = await evaluateSourceHealth('coach_us', repo, now);
    expect(health.status).toBe('unhealthy');
    expect(health.reasons).toContain('no_recent_successful_run');
    // Freshness must be measured against the old full snapshot, not the
    // recent capped run.
    expect(health.freshnessHours).toBeCloseTo(40, 0);
  });

  it('a partial run never becomes the product-count comparison baseline', async () => {
    const repo = new InMemoryCrawlRunRepository();
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 48 * 60 * 60 * 1000),
        endedAt: new Date(now.getTime() - 48 * 60 * 60 * 1000),
        status: 'success',
        isFullSnapshot: true,
        successfulParses: 100,
      }),
    );
    // A partial run in between — status !== 'success', so it must be
    // skipped entirely by the consecutive-full-snapshot comparison.
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        endedAt: new Date(now.getTime() - 24 * 60 * 60 * 1000),
        status: 'partial',
        isFullSnapshot: false,
        successfulParses: 1,
      }),
    );
    repo.seedRun(
      run({
        startedAt: new Date(now.getTime() - 60 * 60 * 1000),
        endedAt: new Date(now.getTime() - 60 * 60 * 1000),
        status: 'success',
        isFullSnapshot: true,
        successfulParses: 95,
      }),
    );

    const health = await evaluateSourceHealth('coach_us', repo, now);
    // 100 -> 95 is a 5% drop, well under the 20% threshold; the partial run's
    // successfulParses: 1 must never be used as a comparison point.
    expect(health.reasons).not.toContain('product_count_drop');
  });
});
