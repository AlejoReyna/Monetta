import type pg from 'pg';
import type { SelectionSnapshotCommitter } from '../crawl/ports.js';
import { finishCrawlRunWithClient } from './pgCrawlRunRepository.js';
import { applySelectionSnapshotWithClient } from './pgProductRepository.js';

/**
 * The selected-snapshot commit boundary. Product lifecycle rows, their event
 * outbox rows, and the successful crawl-run completion use the same Postgres
 * client transaction, so a finalization failure rolls all product writes back.
 */
export class PgSelectionSnapshotCommitter implements SelectionSnapshotCommitter {
  constructor(private readonly pool: pg.Pool) {}

  async commit(params: Parameters<SelectionSnapshotCommitter['commit']>[0]): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await applySelectionSnapshotWithClient(client, params.diff);
      await finishCrawlRunWithClient(client, params.runId, params.completion);
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
