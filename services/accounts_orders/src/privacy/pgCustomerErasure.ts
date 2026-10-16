import type pg from 'pg';
import type { CustomerDataEraser, CustomerDataErasureResult } from './ports.js';

/**
 * Removes the shopper's personal rows and detaches business records
 * (orders, rewards snapshots) so they no longer point at the customer.
 * Safe to run again after a partial failure.
 */
export class PgCustomerDataEraser implements CustomerDataEraser {
  constructor(private readonly pool: pg.Pool) {}

  async erase(shopifyCustomerId: string): Promise<CustomerDataErasureResult> {
    if (!/^[0-9]+$/.test(shopifyCustomerId)) throw new Error('invalid_customer_id');
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const account = await client.query<{ id: string }>(
        `SELECT id FROM app_accounts WHERE shopify_customer_id = $1`,
        [shopifyCustomerId],
      );
      const appAccountId = account.rows[0]?.id ?? null;

      await client.query(
        `DELETE FROM device_installations WHERE shopify_customer_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM push_tokens WHERE customer_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM app_accounts WHERE shopify_customer_id = $1`,
        [shopifyCustomerId],
      );

      await client.query(
        `DELETE FROM rewards_lot_allocations
          WHERE redemption_id IN (
                  SELECT id FROM rewards_redemptions WHERE account_id = $1
                )
             OR lot_id IN (
                  SELECT id FROM rewards_credit_lots WHERE account_id = $1
                )`,
        [shopifyCustomerId],
      );
      await client.query(
        `UPDATE rewards_ledger_entries
            SET reversed_entry_id = NULL
          WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_ledger_entries WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_redemptions WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_credit_lots WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_quotes WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_bonus_claims WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `UPDATE rewards_referrals SET guest_account_id = NULL WHERE guest_account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_referrals WHERE inviter_account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `UPDATE rewards_order_snapshots
            SET account_id = NULL, updated_at = now()
          WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_inbox WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_outbox WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_admin_audit WHERE account_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM rewards_accounts WHERE shopify_customer_id = $1`,
        [shopifyCustomerId],
      );

      await client.query(
        `UPDATE orders_mirror
            SET customer_id = NULL,
                attribution_device_id = NULL,
                updated_at = now()
          WHERE customer_id = $1`,
        [shopifyCustomerId],
      );
      await client.query(
        `DELETE FROM customers_mirror WHERE shopify_customer_id = $1`,
        [shopifyCustomerId],
      );

      await client.query('COMMIT');
      return { appAccountId };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
