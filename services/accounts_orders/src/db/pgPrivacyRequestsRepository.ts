import type pg from 'pg';
import type { PrivacyRequestsRepository } from '../domain/ports.js';
import type {
  PrivacyDataRequestRecord,
  PrivacyFulfillmentInput,
  PrivacyRequestView,
} from '../domain/types.js';

export class PgPrivacyRequestsRepository implements PrivacyRequestsRepository {
  constructor(private readonly pool: pg.Pool) {}

  async openDataRequest(record: PrivacyDataRequestRecord): Promise<void> {
    await this.pool.query(
      `INSERT INTO privacy_requests (webhook_id, kind, shopify_customer_id, status)
       VALUES ($1, 'customers/data_request', $2, 'open')
       ON CONFLICT (webhook_id) DO NOTHING`,
      [record.webhookId, record.shopifyCustomerId],
    );
  }

  async openRedactRequest(record: PrivacyDataRequestRecord): Promise<void> {
    await this.pool.query(
      `INSERT INTO privacy_requests (
         webhook_id, kind, shopify_customer_id, status, fulfilled_at, notes, operator
       ) VALUES ($1, 'customers/redact', $2, 'fulfilled', now(), $3, $4)
       ON CONFLICT (webhook_id) DO NOTHING`,
      [
        record.webhookId,
        record.shopifyCustomerId,
        'Automatic mirror/engagement/token redaction applied by webhook handler',
        'webhook:customers/redact',
      ],
    );
  }

  async listOpen(): Promise<readonly PrivacyRequestView[]> {
    const result = await this.pool.query(
      `SELECT webhook_id, shopify_customer_id, kind, status, received_at,
              fulfilled_at, notes, export_artifact_ref, operator
         FROM privacy_requests
        WHERE status = 'open'
        ORDER BY received_at ASC`,
    );
    return result.rows.map(mapRow);
  }

  async markFulfilled(input: PrivacyFulfillmentInput): Promise<boolean> {
    const result = await this.pool.query(
      `UPDATE privacy_requests
          SET status = 'fulfilled',
              fulfilled_at = now(),
              notes = COALESCE($2, notes),
              export_artifact_ref = COALESCE($3, export_artifact_ref),
              operator = $4
        WHERE webhook_id = $1 AND status = 'open'`,
      [
        input.webhookId,
        input.notes ?? null,
        input.exportArtifactRef ?? null,
        input.operator,
      ],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async markCancelled(input: PrivacyFulfillmentInput): Promise<boolean> {
    const result = await this.pool.query(
      `UPDATE privacy_requests
          SET status = 'cancelled',
              fulfilled_at = now(),
              notes = COALESCE($2, notes),
              operator = $3
        WHERE webhook_id = $1 AND status = 'open'`,
      [input.webhookId, input.notes ?? null, input.operator],
    );
    return (result.rowCount ?? 0) > 0;
  }
}

function mapRow(row: Record<string, unknown>): PrivacyRequestView {
  return {
    webhookId: String(row.webhook_id),
    shopifyCustomerId: String(row.shopify_customer_id),
    kind: row.kind as PrivacyRequestView['kind'],
    status: row.status as PrivacyRequestView['status'],
    receivedAt: new Date(String(row.received_at)),
    fulfilledAt: row.fulfilled_at ? new Date(String(row.fulfilled_at)) : null,
    notes: row.notes == null ? null : String(row.notes),
    exportArtifactRef:
      row.export_artifact_ref == null ? null : String(row.export_artifact_ref),
    operator: row.operator == null ? null : String(row.operator),
  };
}
