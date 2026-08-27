import type pg from 'pg';
import type { CustomersRepository } from '../domain/ports.js';
import type { CustomerRecord } from '../domain/types.js';

export class PgCustomersRepository implements CustomersRepository {
  constructor(private readonly pool: pg.Pool) {}

  async ensureExists(shopifyCustomerId: string): Promise<void> {
    await this.pool.query(
      `INSERT INTO customers_mirror (shopify_customer_id)
       VALUES ($1)
       ON CONFLICT (shopify_customer_id) DO NOTHING`,
      [shopifyCustomerId],
    );
  }

  async upsert(record: CustomerRecord): Promise<void> {
    await this.pool.query(
      `INSERT INTO customers_mirror
         (shopify_customer_id, email, first_name, last_name, phone, marketing_consent, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, now())
       ON CONFLICT (shopify_customer_id) DO UPDATE SET
         email = EXCLUDED.email,
         first_name = EXCLUDED.first_name,
         last_name = EXCLUDED.last_name,
         phone = EXCLUDED.phone,
         marketing_consent = EXCLUDED.marketing_consent,
         updated_at = now()`,
      [
        record.shopifyCustomerId,
        record.email,
        record.firstName,
        record.lastName,
        record.phone,
        record.marketingConsent,
      ],
    );
  }

  async delete(shopifyCustomerId: string): Promise<void> {
    await this.pool.query('DELETE FROM customers_mirror WHERE shopify_customer_id = $1', [
      shopifyCustomerId,
    ]);
  }

  async deleteAll(): Promise<void> {
    await this.pool.query('DELETE FROM customers_mirror');
  }
}
