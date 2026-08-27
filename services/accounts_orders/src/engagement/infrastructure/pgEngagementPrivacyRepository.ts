import type pg from 'pg';

export class PgEngagementPrivacyRepository {
  constructor(private readonly pool: pg.Pool) {}

  async deleteForShopifyCustomer(shopifyCustomerId: string): Promise<void> {
    await this.pool.query(
      'DELETE FROM device_installations WHERE shopify_customer_id = $1',
      [shopifyCustomerId],
    );
  }

  async deleteAll(): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query('DELETE FROM notification_campaigns');
      await client.query('DELETE FROM device_installations');
      await client.query('DELETE FROM catalog_events');
      await client.query('DELETE FROM admin_audit_events');
      await client.query('DELETE FROM shopify_product_notification_snapshots');
      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
