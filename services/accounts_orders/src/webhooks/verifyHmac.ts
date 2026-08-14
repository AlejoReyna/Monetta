import { createHmac, timingSafeEqual } from 'node:crypto';

/**
 * Verifies Shopify's `X-Shopify-Hmac-Sha256` header: base64-encoded
 * HMAC-SHA256 of the *raw* request body, keyed with the app's API secret
 * (the Partner-dashboard app's client secret — a different credential from
 * the Customer Account API mobile client's `clientId`, which is public and
 * has none; see `../config.ts`).
 *
 * Must run against the raw body bytes, before any JSON body-parser has
 * touched them — re-serializing a parsed object is not guaranteed to
 * reproduce the exact bytes Shopify signed. See `api/server.ts`'s use of
 * `express.raw()` on the webhook routes for how that's kept true.
 */
export function verifyShopifyWebhookHmac(
  rawBody: Buffer,
  headerValue: string | undefined,
  secret: string,
): boolean {
  if (!headerValue || secret === '') return false;

  const expected = createHmac('sha256', secret).update(rawBody).digest();

  let received: Buffer;
  try {
    received = Buffer.from(headerValue, 'base64');
  } catch {
    return false;
  }

  // timingSafeEqual throws on a length mismatch rather than returning
  // false — an attacker-controlled header must never crash the process, so
  // check first.
  if (received.length !== expected.length) return false;

  return timingSafeEqual(received, expected);
}
