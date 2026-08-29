import { createHmac, timingSafeEqual } from "node:crypto";

/**
 * Verifies Shopify's base64 HMAC-SHA256 over the exact raw request bytes.
 * The parsed JSON must never be re-serialized for this check.
 */
export function verifyShopifyHmac(
  rawBody: Buffer,
  headerValue: string | undefined,
  clientSecret: string,
): boolean {
  if (clientSecret.length === 0 || headerValue === undefined) return false;

  // A SHA-256 digest is exactly 32 bytes and its padded base64 representation
  // is 44 ASCII characters. Buffer.from() is permissive, so reject malformed
  // input before decoding it.
  if (!/^[A-Za-z0-9+/]{43}=$/.test(headerValue)) return false;

  const received = Buffer.from(headerValue, "base64");
  const expected = createHmac("sha256", clientSecret).update(rawBody).digest();
  return received.length === expected.length && timingSafeEqual(received, expected);
}
