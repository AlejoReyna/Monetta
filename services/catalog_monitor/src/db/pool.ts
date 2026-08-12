import pg from 'pg';
import { loadConfig } from '../config.js';

let pool: pg.Pool | null = null;

/** Lazily-created singleton pool. Never constructed at import time, so importing this module in a test is free of side effects. */
export function getPool(): pg.Pool {
  if (!pool) {
    pool = new pg.Pool({ connectionString: loadConfig().databaseUrl });
  }
  return pool;
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.end();
    pool = null;
  }
}
