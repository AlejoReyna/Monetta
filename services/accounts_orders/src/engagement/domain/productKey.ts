const productGidPrefix = 'gid://shopify/Product/';

/**
 * Canonical product key for alerts, campaign routes and catalog events:
 * `shopify:gid://shopify/Product/<id>`, the form the app and in-app admin send.
 * Shopify webhooks carry the numeric REST id instead, so `shopify:<id>` is
 * accepted and rewritten. Anything else is not a Shopify product and yields
 * null. Migration 016 applies the same rewrite to stored keys.
 */
export function canonicalShopifyProductKey(key: string): string | null {
  if (!key.startsWith('shopify:')) return null;
  const id = key.slice('shopify:'.length);
  const numericId = id.startsWith(productGidPrefix) ? id.slice(productGidPrefix.length) : id;
  return /^\d+$/.test(numericId) ? `shopify:${productGidPrefix}${numericId}` : null;
}
