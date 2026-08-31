import type pg from 'pg';
import type { SourceId } from '../domain/types.js';
import type { SourcePolicy, SourcePolicyRepository } from '../admin/sourcePolicy.js';

interface SourcePolicyRow {
  source_id: string;
  enabled: boolean;
  item_limit: number;
  base_commission_bps: number;
  high_value_commission_bps: number;
  high_value_threshold_mxn: string;
  updated_at: Date;
}

function fromRow(row: SourcePolicyRow): SourcePolicy {
  return {
    sourceId: row.source_id as SourceId,
    enabled: row.enabled,
    itemLimit: row.item_limit,
    baseCommissionBps: row.base_commission_bps,
    highValueCommissionBps: row.high_value_commission_bps,
    highValueThresholdMxn: Number.parseFloat(row.high_value_threshold_mxn),
    updatedAt: row.updated_at,
  };
}

export class PgSourcePolicyRepository implements SourcePolicyRepository {
  constructor(private readonly pool: pg.Pool) {}

  async list(): Promise<SourcePolicy[]> {
    const result = await this.pool.query<SourcePolicyRow>(
      `SELECT source_id, enabled, item_limit, base_commission_bps,
              high_value_commission_bps, high_value_threshold_mxn, updated_at
         FROM external_source_policies
        ORDER BY source_id`,
    );
    return result.rows.map(fromRow);
  }

  async find(sourceId: SourceId): Promise<SourcePolicy | null> {
    const result = await this.pool.query<SourcePolicyRow>(
      `SELECT source_id, enabled, item_limit, base_commission_bps,
              high_value_commission_bps, high_value_threshold_mxn, updated_at
         FROM external_source_policies
        WHERE source_id = $1`,
      [sourceId],
    );
    return result.rows[0] === undefined ? null : fromRow(result.rows[0]);
  }

  async upsert(input: {
    readonly sourceId: SourceId;
    readonly enabled: boolean;
    readonly itemLimit: number;
    readonly baseCommissionBps: number;
    readonly highValueCommissionBps: number;
    readonly highValueThresholdMxn: number;
  }): Promise<SourcePolicy> {
    const result = await this.pool.query<SourcePolicyRow>(
      `INSERT INTO external_source_policies
         (source_id, enabled, item_limit, base_commission_bps,
          high_value_commission_bps, high_value_threshold_mxn, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, now())
       ON CONFLICT (source_id) DO UPDATE SET
         enabled = EXCLUDED.enabled,
         item_limit = EXCLUDED.item_limit,
         base_commission_bps = EXCLUDED.base_commission_bps,
         high_value_commission_bps = EXCLUDED.high_value_commission_bps,
         high_value_threshold_mxn = EXCLUDED.high_value_threshold_mxn,
         updated_at = now()
       RETURNING source_id, enabled, item_limit, base_commission_bps,
                 high_value_commission_bps, high_value_threshold_mxn, updated_at`,
      [
        input.sourceId,
        input.enabled,
        input.itemLimit,
        input.baseCommissionBps,
        input.highValueCommissionBps,
        input.highValueThresholdMxn,
      ],
    );
    const row = result.rows[0];
    if (row === undefined) throw new Error('source policy upsert returned no row');
    return fromRow(row);
  }
}
