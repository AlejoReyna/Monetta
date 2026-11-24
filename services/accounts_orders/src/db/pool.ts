import pg from 'pg';
import { loadConfig } from '../config.js';

let pool: pg.Pool | null = null;
let directPool: pg.Pool | null = null;

/** Lazily-created pooled singleton for application queries. */
export function getPool(): pg.Pool {
  if (!pool) {
    pool = new pg.Pool({
      connectionString: loadConfig().databaseUrl,
      max: 5,
      idleTimeoutMillis: 5_000,
    });
  }
  return pool;
}

/**
 * Lazily-created direct/unpooled singleton for DDL migrations and session-level
 * advisory locks (falls back to `DATABASE_URL` when `DATABASE_URL_UNPOOLED` is unset).
 */
export function getDirectPool(): pg.Pool {
  if (!directPool) {
    const config = loadConfig();
    const connectionString = config.databaseUrlUnpooled !== ''
      ? config.databaseUrlUnpooled
      : config.databaseUrl;
    directPool = new pg.Pool({
      connectionString,
      max: 3,
      idleTimeoutMillis: 5_000,
    });
  }
  return directPool;
}

export async function closePool(): Promise<void> {
  const pools = [pool, directPool];
  pool = null;
  directPool = null;
  await Promise.all(
    pools
      .filter((p): p is pg.Pool => p !== null)
      .map((p) => p.end()),
  );
}
