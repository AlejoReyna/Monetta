/** Keep notification subscriptions, catalog events and app deep links on one key. */
export function canonicalShopifyProductKey(value: unknown): string | null {
  if (typeof value !== 'string' || value.length > 300) return null;
  // Accept legacy numeric keys from older clients, but only persist/send GIDs.
  const match = /^shopify:(?:gid:\/\/shopify\/Product\/)?([0-9]+)$/.exec(value.trim());
  return match === null ? null : `shopify:gid://shopify/Product/${match[1]}`;
}
