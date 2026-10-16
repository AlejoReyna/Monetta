import type pg from 'pg';
import type { OrdersRepository } from '../domain/ports.js';
import type { MirroredOrder, OrderRecord } from '../domain/types.js';

interface OrderRow {
  id: number;
  shopify_order_id: string | null;
  customer_id: string | null;
  source: 'shopify_checkout' | 'whatsapp_apartado';
  attribution_code: string | null;
  tags: string[];
  financial_status: string | null;
  payment_method: string | null;
  fulfillment_status: string | null;
  total_amount: string | null;
  currency_code: string | null;
  attribution_device_id: string | null;
  attribution_reco_source: string | null;
  checkout_token: string | null;
  cart_token: string | null;
  placed_at: Date | null;
  shopify_updated_at: Date | null;
  updated_at: Date;
}

function fromRow(row: OrderRow): MirroredOrder {
  return {
    id: row.id,
    shopifyOrderId: row.shopify_order_id,
    customerId: row.customer_id,
    source: row.source,
    attributionCode: row.attribution_code,
    tags: row.tags,
    financialStatus: row.financial_status,
    paymentMethod: row.payment_method,
    fulfillmentStatus: row.fulfillment_status,
    // NUMERIC comes back from `pg` as a string, to avoid silently losing
    // precision on a value JS numbers can't represent exactly.
    totalAmount: row.total_amount === null ? null : Number.parseFloat(row.total_amount),
    currencyCode: row.currency_code,
    attributionDeviceId: row.attribution_device_id,
    attributionRecoSource: row.attribution_reco_source,
    checkoutToken: row.checkout_token,
    cartToken: row.cart_token,
    placedAt: row.placed_at,
    shopifyUpdatedAt: row.shopify_updated_at,
    updatedAt: row.updated_at,
  };
}

export class PgOrdersRepository implements OrdersRepository {
  constructor(private readonly pool: pg.Pool) {}

  async upsertByShopifyOrderId(order: OrderRecord): Promise<void> {
    // `shopify_order_id` is UNIQUE but nullable — Postgres never treats two
    // NULLs as conflicting, so this correctly *inserts* a new row for each
    // apartado order that has no Shopify order yet, rather than colliding
    // them into one.
    //
    // F15: the WHERE clause on DO UPDATE refuses to apply a stale delivery
    // when both sides carry shopify_updated_at and the incoming one is older.
    await this.pool.query(
      `INSERT INTO orders_mirror
         (shopify_order_id, customer_id, source, attribution_code, tags,
          financial_status, payment_method, fulfillment_status, total_amount, currency_code,
          attribution_device_id, attribution_reco_source, checkout_token, cart_token,
          placed_at, shopify_updated_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, now())
       ON CONFLICT (shopify_order_id) DO UPDATE SET
         customer_id = EXCLUDED.customer_id,
         source = EXCLUDED.source,
         attribution_code = COALESCE(EXCLUDED.attribution_code, orders_mirror.attribution_code),
         tags = EXCLUDED.tags,
         financial_status = EXCLUDED.financial_status,
         payment_method = COALESCE(EXCLUDED.payment_method, orders_mirror.payment_method),
         fulfillment_status = EXCLUDED.fulfillment_status,
         total_amount = EXCLUDED.total_amount,
         currency_code = EXCLUDED.currency_code,
         checkout_token = COALESCE(EXCLUDED.checkout_token, orders_mirror.checkout_token),
         cart_token = COALESCE(EXCLUDED.cart_token, orders_mirror.cart_token),
         shopify_updated_at = COALESCE(EXCLUDED.shopify_updated_at, orders_mirror.shopify_updated_at),
         updated_at = now()
       WHERE orders_mirror.shopify_updated_at IS NULL
          OR EXCLUDED.shopify_updated_at IS NULL
          OR EXCLUDED.shopify_updated_at >= orders_mirror.shopify_updated_at`,
      [
        order.shopifyOrderId,
        order.customerId,
        order.source,
        order.attributionCode,
        order.tags,
        order.financialStatus,
        order.paymentMethod ?? null,
        order.fulfillmentStatus,
        order.totalAmount,
        order.currencyCode,
        order.attributionDeviceId,
        order.attributionRecoSource,
        order.checkoutToken ?? null,
        order.cartToken ?? null,
        order.placedAt,
        order.shopifyUpdatedAt ?? null,
      ],
    );
  }

  async linkApartadoByAttributionCode(
    attributionCode: string,
    shopifyOrderId: string,
  ): Promise<boolean> {
    const result = await this.pool.query(
      `UPDATE orders_mirror
       SET shopify_order_id = $1, updated_at = now()
       WHERE attribution_code = $2 AND shopify_order_id IS NULL`,
      [shopifyOrderId, attributionCode],
    );
    return (result.rowCount ?? 0) > 0;
  }

  async detachCustomer(shopifyCustomerId: string): Promise<void> {
    await this.pool.query(
      'UPDATE orders_mirror SET customer_id = NULL WHERE customer_id = $1',
      [shopifyCustomerId],
    );
  }

  async listForCustomer(shopifyCustomerId: string): Promise<MirroredOrder[]> {
    const result = await this.pool.query<OrderRow>(
      'SELECT * FROM orders_mirror WHERE customer_id = $1 ORDER BY placed_at DESC NULLS LAST',
      [shopifyCustomerId],
    );
    return result.rows.map(fromRow);
  }

  async deleteAll(): Promise<void> {
    await this.pool.query('DELETE FROM orders_mirror');
  }
}
