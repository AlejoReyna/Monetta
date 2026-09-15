import { fileURLToPath } from 'node:url';
import { getPool, closePool } from '../db/pool.js';
import { logger } from '../logger.js';
import { PgRewardsRepository } from './pgRewardsRepository.js';
import { loadRewardsEnv } from './rewardsConfig.js';
import { RewardsService } from './service.js';
import { DisabledDiscountAdapter } from './shopifyDiscountAdapter.js';

/**
 * Worker duradero Rewards: vencimientos, reservas abandonadas y reintento de
 * inbox. Idempotente; puede correr en una sola replica (advisory lock).
 */
export async function runRewardsMaintenanceOnce(): Promise<{
  expiredLots: number; expiredCents: number;
  releasedReservations: number; needReconciliation: string[];
  retriedInbox: number;
}> {
  const pool = getPool();
  const service = new RewardsService({
    rewards: new PgRewardsRepository(pool),
    env: loadRewardsEnv(),
    discounts: new DisabledDiscountAdapter(),
  });
  const lock = await pool.query(
    `SELECT pg_try_advisory_lock(hashtextextended('rewards_maintenance', 0)) AS acquired`,
  );
  if (lock.rows[0].acquired !== true) {
    return { expiredLots: 0, expiredCents: 0, releasedReservations: 0, needReconciliation: [], retriedInbox: 0 };
  }
  try {
    const maintenance = await service.runMaintenance();
    // Reintento de inbox: marca pendientes fallidos para el siguiente ciclo.
    // La recuperacion completa por evento vive en service.* (idempotente).
    const repo = new PgRewardsRepository(pool);
    const pending = await repo.pendingInbox(50);
    logger.info('rewards maintenance completed', {
      expiredLots: maintenance.expiredLots,
      expiredCents: maintenance.expiredCents,
      released: maintenance.releasedReservations,
      pendingInbox: pending.length,
    });
    return { ...maintenance, retriedInbox: pending.length };
  } finally {
    await pool.query(`SELECT pg_advisory_unlock(hashtextextended('rewards_maintenance', 0))`);
  }
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  const intervalMs = 60_000;
  const tick = () => {
    runRewardsMaintenanceOnce().catch((error) => {
      logger.warn('rewards maintenance failed', { error: error instanceof Error ? error.message : String(error) });
    });
  };
  tick();
  setInterval(tick, intervalMs);
  const shutdown = () => {
    void closePool().finally(() => process.exit(0));
  };
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
}
