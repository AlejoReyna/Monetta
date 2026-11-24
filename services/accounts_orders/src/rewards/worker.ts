import { fileURLToPath } from 'node:url';
import { loadConfig } from '../config.js';
import { getPool, getDirectPool, closePool } from '../db/pool.js';
import { logger } from '../logger.js';
import { PgRewardsRepository } from './pgRewardsRepository.js';
import { loadRewardsEnv } from './rewardsConfig.js';
import { RewardsService } from './service.js';
import { createRewardsDiscountAdapter } from './shopifyAdminCouponProvisioner.js';

const DEFAULT_MAINTENANCE_INTERVAL_MS = 60 * 60_000;
const MIN_MAINTENANCE_INTERVAL_MS = 60_000;

export function maintenanceIntervalMs(env: NodeJS.ProcessEnv = process.env): number {
  const raw = env.REWARDS_MAINTENANCE_INTERVAL_MS;
  if (raw === undefined || raw.trim() === '') return DEFAULT_MAINTENANCE_INTERVAL_MS;
  const parsed = Number.parseInt(raw, 10);
  if (!Number.isFinite(parsed) || parsed < MIN_MAINTENANCE_INTERVAL_MS) {
    return MIN_MAINTENANCE_INTERVAL_MS;
  }
  return parsed;
}

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
  const directPool = getDirectPool();
  const config = loadConfig();
  const rewardsEnv = loadRewardsEnv();
  const service = new RewardsService({
    rewards: new PgRewardsRepository(pool),
    env: rewardsEnv,
    discounts: createRewardsDiscountAdapter(config, rewardsEnv),
    shopDomain: config.shopDomain !== '' ? config.shopDomain : null,
  });
  const lockClient = await directPool.connect();
  let acquired = false;
  try {
    const lock = await lockClient.query(
      `SELECT pg_try_advisory_lock(hashtextextended('rewards_maintenance', 0)) AS acquired`,
    );
    acquired = lock.rows[0].acquired === true;
    if (!acquired) {
      return { expiredLots: 0, expiredCents: 0, releasedReservations: 0, needReconciliation: [], retriedInbox: 0 };
    }
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
    if (acquired) {
      await lockClient
        .query(`SELECT pg_advisory_unlock(hashtextextended('rewards_maintenance', 0))`)
        .catch(() => {});
    }
    lockClient.release();
  }
}

const isMain = process.argv[1] === fileURLToPath(import.meta.url);
if (isMain) {
  const intervalMs = maintenanceIntervalMs();
  const tick = async () => {
    try {
      await runRewardsMaintenanceOnce();
    } catch (error) {
      logger.warn('rewards maintenance failed', { error: error instanceof Error ? error.message : String(error) });
    } finally {
      // Cierra sockets entre ciclos para que Neon Free suspenda la base tras 5 min inactiva.
      await closePool().catch(() => {});
    }
  };
  void tick();
  const timer = setInterval(() => {
    void tick();
  }, intervalMs);
  const shutdown = () => {
    clearInterval(timer);
    void closePool().finally(() => process.exit(0));
  };
  process.once('SIGTERM', shutdown);
  process.once('SIGINT', shutdown);
}
