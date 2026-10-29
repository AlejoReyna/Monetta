import { describe, expect, it } from 'vitest';
import { canonicalShopifyProductKey } from '../src/engagement/domain/productKey.js';

describe('notification product keys', () => {
  it.each(['shopify:123', 'shopify:gid://shopify/Product/123', ' shopify:123 '])(
    'normalizes %s to the app Product GID', (key) => {
      expect(canonicalShopifyProductKey(key)).toBe('shopify:gid://shopify/Product/123');
    },
  );

  it('preserves IDs without rounding through a JavaScript number', () => {
    expect(canonicalShopifyProductKey('shopify:9007199254740993'))
      .toBe('shopify:gid://shopify/Product/9007199254740993');
  });

  it.each([null, 123, '', 'shopify:', 'shopify:abc', 'shopify:-1', 'shopify:1.2',
    'shopify:gid://shopify/ProductVariant/123', 'shopify:gid://shopify/Product/123?x=1',
    'external:123', `shopify:${'1'.repeat(301)}`])('rejects invalid key %s', (key) => {
    expect(canonicalShopifyProductKey(key)).toBeNull();
  });
});
