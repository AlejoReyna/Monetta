import { createHash } from 'node:crypto';
import type {
  CustomersRepository,
  OrdersRepository,
  PrivacyRequestsRepository,
  PushTokensRepository,
  WebhookEventsRepository,
} from '../domain/ports.js';
import { logger } from '../logger.js';
import { normalizePaymentMethod } from '../orders/paymentMethod.js';
import {
  noteAttribute,
  orderCorrelationToken,
  orderLogName,
  parseTags,
  type ShopifyCustomerDataRequestWebhookPayload,
  type ShopifyCustomerRedactWebhookPayload,
  type ShopifyOrderWebhookPayload,
  type ShopifyProductWebhookPayload,
  type ShopifyShopRedactWebhookPayload,
} from './payloads.js';

export interface HandlerDeps {
  readonly customers: CustomersRepository;
  readonly orders: OrdersRepository;
  readonly webhookEvents: WebhookEventsRepository;
  readonly pushTokens: PushTokensRepository;
  readonly privacyRequests?: PrivacyRequestsRepository;
  readonly catalogEvents?: {
    process(
      topic: 'products/create' | 'products/update',
      webhookId: string,
      payload: ShopifyProductWebhookPayload,
    ): Promise<void>;
  };
  readonly engagementPrivacy?: {
    deleteForShopifyCustomer(shopifyCustomerId: string): Promise<void>;
    deleteAll(): Promise<void>;
  };
  /**
   * `orders/updated` warns about missing checkout tokens only when the
   * order's Shopify `created_at` is at or after this instant. Defaults to
   * process start, which is this running deploy. `orders/create` is not
   * gated: a create handled by this process is a new order.
   */
  readonly checkoutTokensDeployedAt?: Date;
}

/** Process start. Orders created earlier are pre-deploy for this process. */
const runningDeployAt = new Date();

function shopifyTimestamp(value: string | null | undefined): Date | null {
  if (value === undefined || value === null || value.trim() === '') return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed;
}

/**
 * Both correlation tokens parsed to null. Field names only — never values.
 * `orders/updated` stays quiet for orders created before this deploy so a
 * historical update does not warn once per order.
 */
function warnIfOrderMissingCheckoutTokens(
  deps: HandlerDeps,
  topic: 'orders/create' | 'orders/updated',
  payload: ShopifyOrderWebhookPayload,
  shopifyOrderId: string,
  checkoutToken: string | null,
  cartToken: string | null,
): void {
  const missingFields = [
    ...(checkoutToken === null ? ['checkout_token' as const] : []),
    ...(cartToken === null ? ['cart_token' as const] : []),
  ];
  if (missingFields.length !== 2) return;
  if (topic === 'orders/updated') {
    const deployedAt = deps.checkoutTokensDeployedAt ?? runningDeployAt;
    const createdAt = shopifyTimestamp(payload.created_at);
    if (createdAt === null || createdAt.getTime() < deployedAt.getTime()) return;
  }
  logger.warn('order_webhook_missing_checkout_tokens', {
    shopifyOrderId,
    orderName: orderLogName(payload.name),
    missingFields,
    topic,
  });
}

/**
 * `AttributionCodeGenerator`'s alphabet
 * (`lib/data/shopify/cart_attribution.dart`) — deliberately excludes vowels
 * and `0/O/1/I`. Matched here, not just prefix-checked, so a coincidental
 * "MN-" in an unrelated tag can't be mistaken for an apartado code.
 */
const APARTADO_CODE = /^MN-[23456789BCDFGHJKLMNPQRSTVWXYZ]{4}$/;

function payloadHash(rawBody: Buffer): string {
  return createHash('sha256').update(rawBody).digest('hex');
}

function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

/**
 * `webhookId` is Shopify's `X-Shopify-Webhook-Id` header — stable across
 * retries of the same delivery. Claims with recoverable pending/failed (or
 * stale processing) states; completed deliveries and live concurrent claims
 * return without re-running effects (F12).
 */
async function withClaimedDelivery(
  deps: Pick<HandlerDeps, 'webhookEvents'>,
  args: {
    webhookId: string;
    topic: string;
    shopifyResourceId: string | null;
    rawBody: Buffer;
    shopDomain?: string | null;
  },
  effect: () => Promise<void>,
): Promise<void> {
  const claimed = await deps.webhookEvents.tryClaim({
    webhookId: args.webhookId,
    topic: args.topic,
    shopifyResourceId: args.shopifyResourceId,
    payloadHash: payloadHash(args.rawBody),
    shopDomain: args.shopDomain ?? null,
  });
  if (!claimed) {
    logger.info('completed webhook delivery ignored', {
      webhookId: args.webhookId,
      topic: args.topic,
    });
    return;
  }

  try {
    await effect();
    await deps.webhookEvents.markCompleted(args.webhookId);
  } catch (error) {
    try {
      await deps.webhookEvents.markFailed(args.webhookId, errorMessage(error));
    } catch (markError) {
      logger.error('failed to mark webhook delivery as failed', {
        webhookId: args.webhookId,
        topic: args.topic,
        error: errorMessage(markError),
      });
    }
    throw error;
  }
}

export async function handleProductsWebhook(
  deps: HandlerDeps,
  webhookId: string,
  topic: 'products/create' | 'products/update',
  payload: ShopifyProductWebhookPayload,
  rawBody: Buffer,
  shopDomain?: string | null,
): Promise<void> {
  const productId = String(payload.id);
  await withClaimedDelivery(
    deps,
    { webhookId, topic, shopifyResourceId: productId, rawBody, shopDomain },
    async () => {
      await deps.catalogEvents?.process(topic, webhookId, payload);
      logger.info('Shopify catalog transition evaluated', { productId, topic });
    },
  );
}

export async function handleOrdersWebhook(
  deps: HandlerDeps,
  webhookId: string,
  topic: 'orders/create' | 'orders/updated',
  payload: ShopifyOrderWebhookPayload,
  rawBody: Buffer,
  shopDomain?: string | null,
): Promise<void> {
  const shopifyOrderId = String(payload.id);
  await withClaimedDelivery(
    deps,
    { webhookId, topic, shopifyResourceId: shopifyOrderId, rawBody, shopDomain },
    async () => {
      const tags = parseTags(payload.tags);
      const attributionCode = tags.find((t) => APARTADO_CODE.test(t)) ?? null;
      const customerId = payload.customer ? String(payload.customer.id) : null;
      const checkoutToken = orderCorrelationToken(payload.checkout_token);
      const cartToken = orderCorrelationToken(payload.cart_token);
      warnIfOrderMissingCheckoutTokens(
        deps,
        topic,
        payload,
        shopifyOrderId,
        checkoutToken,
        cartToken,
      );

      if (payload.customer) {
        await deps.customers.upsert({
          shopifyCustomerId: String(payload.customer.id),
          email: payload.customer.email ?? null,
          firstName: payload.customer.first_name ?? null,
          lastName: payload.customer.last_name ?? null,
          phone: payload.customer.phone ?? null,
          // The order webhook doesn't carry marketing consent — a
          // `customers/update` webhook (not yet subscribed here) would be the
          // source for that field; never fabricate `true`.
          marketingConsent: false,
        });
      }

      await deps.orders.upsertByShopifyOrderId({
        shopifyOrderId,
        customerId,
        // An apartado order still arrives through this same webhook once the
        // owner manually enters it in Shopify — the MN- tag is what tells us
        // its *originating channel* was WhatsApp, not the app's checkout.
        source: attributionCode ? 'whatsapp_apartado' : 'shopify_checkout',
        attributionCode,
        tags,
        financialStatus: payload.financial_status ?? null,
        paymentMethod: normalizePaymentMethod({
          payment_gateway_names: payload.payment_gateway_names,
          gateway: payload.gateway,
          transactions: payload.transactions,
        }),
        fulfillmentStatus: payload.fulfillment_status ?? null,
        totalAmount: payload.current_total_price
          ? Number.parseFloat(payload.current_total_price)
          : null,
        currencyCode: payload.currency ?? null,
        attributionDeviceId: noteAttribute(payload, '_device_id'),
        attributionRecoSource: noteAttribute(payload, '_rec_source'),
        checkoutToken,
        cartToken,
        placedAt: payload.created_at ? new Date(payload.created_at) : null,
        shopifyUpdatedAt: payload.updated_at ? new Date(payload.updated_at) : null,
      });

      logger.info('order mirrored', {
        shopifyOrderId,
        source: attributionCode ? 'whatsapp_apartado' : 'shopify_checkout',
      });
    },
  );
}

/**
 * GDPR-style compliance topic: a shopper asked what data this app holds
 * about them. Shopify requires only that the request be acknowledged
 * (200) and acted on within 30 days — not a synchronous data dump in the
 * webhook response — so this opens a durable privacy_requests row for
 * manual follow-up rather than trying to assemble and return a data export
 * inline (F29).
 */
export async function handleCustomersDataRequest(
  deps: HandlerDeps,
  webhookId: string,
  payload: ShopifyCustomerDataRequestWebhookPayload,
  rawBody: Buffer,
  shopDomain?: string | null,
): Promise<void> {
  const shopifyCustomerId = String(payload.customer.id);
  await withClaimedDelivery(
    deps,
    {
      webhookId,
      topic: 'customers/data_request',
      shopifyResourceId: shopifyCustomerId,
      rawBody,
      shopDomain,
    },
    async () => {
      if (deps.privacyRequests) {
        await deps.privacyRequests.openDataRequest({ webhookId, shopifyCustomerId });
      } else {
        logger.warn(
          'customer data request received — privacyRequests repository not configured; manual fulfillment required within 30 days',
          { shopifyCustomerId },
        );
      }
      logger.warn('customer data request received — durable open task recorded', {
        shopifyCustomerId,
        webhookId,
      });
    },
  );
}

export async function handleCustomersRedact(
  deps: HandlerDeps,
  webhookId: string,
  payload: ShopifyCustomerRedactWebhookPayload,
  rawBody: Buffer,
  shopDomain?: string | null,
): Promise<void> {
  const shopifyCustomerId = String(payload.customer.id);
  await withClaimedDelivery(
    deps,
    {
      webhookId,
      topic: 'customers/redact',
      shopifyResourceId: shopifyCustomerId,
      rawBody,
      shopDomain,
    },
    async () => {
      // Explicit detach before delete, even though the FK's ON DELETE SET NULL
      // (see db/migrations/001_init.sql) would do this anyway — compliance
      // deletion should not depend solely on an implicit cascade for its
      // correctness to be visible/auditable in this code.
      await deps.orders.detachCustomer(shopifyCustomerId);
      await deps.pushTokens.deleteAllForCustomer(shopifyCustomerId);
      await deps.engagementPrivacy?.deleteForShopifyCustomer(shopifyCustomerId);
      await deps.customers.delete(shopifyCustomerId);
      if (deps.privacyRequests) {
        await deps.privacyRequests.openRedactRequest({ webhookId, shopifyCustomerId });
      }

      logger.info('customer redacted', { shopifyCustomerId });
    },
  );
}

/** Fires ~48h after the app is uninstalled. Single-tenant service: this wipes everything. */
export async function handleShopRedact(
  deps: HandlerDeps,
  webhookId: string,
  payload: ShopifyShopRedactWebhookPayload,
  rawBody: Buffer,
  shopDomain?: string | null,
): Promise<void> {
  await withClaimedDelivery(
    deps,
    {
      webhookId,
      topic: 'shop/redact',
      shopifyResourceId: String(payload.shop_id),
      rawBody,
      shopDomain,
    },
    async () => {
      await deps.pushTokens.deleteAll();
      await deps.engagementPrivacy?.deleteAll();
      await deps.orders.deleteAll();
      await deps.customers.deleteAll();

      logger.warn('shop redact processed — all mirrored data wiped', { shopId: payload.shop_id });
    },
  );
}
