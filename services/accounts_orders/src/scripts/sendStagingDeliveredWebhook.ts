import { createHmac, randomUUID } from 'node:crypto';

/**
 * Staging-only helper to simulate a carrier DELIVERED webhook for an order
 * during iPhone video recording or QA verification.
 *
 * Usage:
 *   SHOPIFY_APP_CLIENT_SECRET=shpss_... npx tsx src/scripts/sendStagingDeliveredWebhook.ts <shopifyOrderId>
 */
async function main(): Promise<void> {
  const orderIdArg = process.argv[2]?.trim() ?? '';
  if (!/^[0-9]+$/.test(orderIdArg)) {
    console.error('Usage: npx tsx src/scripts/sendStagingDeliveredWebhook.ts <numericShopifyOrderId>');
    process.exit(1);
  }

  const secret = (process.env.SHOPIFY_APP_CLIENT_SECRET ?? '').trim();
  if (secret.length < 8) {
    console.error('Error: SHOPIFY_APP_CLIENT_SECRET is required.');
    process.exit(1);
  }

  const baseUrl = (process.env.STAGING_BACKEND_URL ?? 'https://monetta-accounts-staging.fly.dev')
    .trim()
    .replace(/\/+$/, '');
  const parsed = new URL(baseUrl);
  const host = parsed.hostname.toLowerCase();
  const isLocalhost = host === 'localhost' || host === '127.0.0.1';
  if (
    host.includes('monetta.mx') ||
    host.includes('production') ||
    (!isLocalhost && parsed.protocol !== 'https:')
  ) {
    console.error(`Refusing to send staging webhook to disallowed target: ${baseUrl}`);
    process.exit(1);
  }

  const payload = JSON.stringify({
    order_id: Number(orderIdArg),
    status: 'delivered',
    happened_at: new Date().toISOString(),
  });
  const signature = createHmac('sha256', secret).update(payload).digest('base64');
  const webhookId = randomUUID();

  const res = await fetch(`${baseUrl}/webhooks/fulfillment_events/create`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Hmac-Sha256': signature,
      'X-Shopify-Webhook-Id': webhookId,
      'X-Shopify-Shop-Domain': 'monetta-staging.myshopify.com',
    },
    body: payload,
  });

  const text = await res.text();
  console.log(`POST ${baseUrl}/webhooks/fulfillment_events/create -> HTTP ${res.status}`);
  console.log(text);
  if (!res.ok) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
