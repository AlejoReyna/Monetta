import type pg from 'pg';
import type { PushTokensRepository } from '../domain/ports.js';
import type { PushTokenRecord } from '../domain/types.js';

export class PgPushTokensRepository implements PushTokensRepository {
  constructor(private readonly pool: pg.Pool) {}

  async upsert(token: PushTokenRecord): Promise<boolean> {
    const result = await this.pool.query(
      `INSERT INTO push_tokens (device_id, customer_id, fcm_token, platform, updated_at)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (device_id) DO UPDATE SET
         customer_id = EXCLUDED.customer_id,
         fcm_token = EXCLUDED.fcm_token,
         platform = EXCLUDED.platform,
         updated_at = now()
       WHERE push_tokens.customer_id IS NULL
          OR push_tokens.customer_id = EXCLUDED.customer_id
       RETURNING device_id`,
      [token.deviceId, token.customerId, token.fcmToken, token.platform],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async deleteAllForCustomer(shopifyCustomerId: string): Promise<void> {
    await this.pool.query('DELETE FROM push_tokens WHERE customer_id = $1', [shopifyCustomerId]);
  }

  async deleteAll(): Promise<void> {
    await this.pool.query('DELETE FROM push_tokens');
  }
}
