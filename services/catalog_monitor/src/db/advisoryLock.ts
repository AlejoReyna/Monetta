import type pg from 'pg';
import type { SourceId } from '../domain/types.js';

/**
 * Fixed numeric keys for Postgres session-level advisory locks, one per
 * source. Used so an overlapping cron fire or a second monitor replica can
 * never run the same source's crawl concurrently — see `monitor/scheduler.ts`.
 */
export const SOURCE_LOCK_KEYS: Record<SourceId, number> = {
  coach_us: 84_201_001,
  michael_kors_us: 84_201_002,
  guess_us: 84_201_003,
  steve_madden_us: 84_201_004,
  marc_jacobs_us: 84_201_005,
  tory_burch_us: 84_201_006,
  kate_spade_us: 84_201_007,
  guess_factory_us: 84_201_008,
  gp_mcallen_perfumes: 84_201_009,
};

/**
 * Runs `task` while holding a session-level Postgres advisory lock keyed by
 * `lockKey`, using the non-blocking `pg_try_advisory_lock`: if another
 * session already holds the lock, `task` never runs and this resolves to
 * `false`. The lock is always released afterward, even if `task` throws.
 */
export async function withDbLock(
  pool: pg.Pool,
  lockKey: number,
  task: () => Promise<void>,
): Promise<boolean> {
  const client = await pool.connect();
  try {
    const { rows } = await client.query<{ locked: boolean }>(
      'SELECT pg_try_advisory_lock($1) AS locked',
      [lockKey],
    );
    if (!rows[0]?.locked) return false;
    try {
      await task();
      return true;
    } finally {
      await client.query('SELECT pg_advisory_unlock($1)', [lockKey]);
    }
  } finally {
    client.release();
  }
}
