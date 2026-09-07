/**
 * Required catalog / order fixture plans (brief §4).
 * Remote creation is stubbed; dry-run records planned rows in the manifest.
 */

export const CATALOG_FIXTURES = [
  {
    id: 'product:two-variants',
    kind: 'product',
    description: 'Product with two purchasable variants A/B, distinct prices and option values',
  },
  {
    id: 'variant:unavailable',
    kind: 'variant',
    description: 'Unavailable variant (and a product with no available variants)',
  },
  {
    id: 'product:headless-published',
    kind: 'product',
    description: 'Product published to Headless channel',
  },
  {
    id: 'product:headless-unpublished',
    kind: 'product',
    description: 'Product not published to Headless channel',
  },
  {
    id: 'product:mutable-during-test',
    kind: 'product',
    description: 'Product whose price, availability, publication, and images can change mid-test',
  },
  {
    id: 'product:beyond-admin-page',
    kind: 'product',
    description: 'Product beyond first 50 and first 100 admin results (prefer local pagination fixtures)',
  },
  {
    id: 'catalog:two-page',
    kind: 'other',
    description:
      'Two-page catalog coverage; 250/251, 21 variants, images/collections, cursors/truncation — prefer local fixtures over bulk remote create',
  },
  {
    id: 'collection:todays-picks',
    kind: 'collection',
    description: 'Manual monetta-todays-picks collection + editable content/metaobjects',
  },
  {
    id: 'discount:matrix',
    kind: 'other',
    description: 'Valid, invalid, expired, and inapplicable discount scenarios',
  },
];

export const ORDER_FIXTURES = [
  {
    id: 'order:pending',
    kind: 'order',
    description: 'Test order — pending',
    ownerPersona: null,
  },
  {
    id: 'order:paid',
    kind: 'order',
    description: 'Test order — paid',
    ownerPersona: null,
  },
  {
    id: 'order:fulfilled',
    kind: 'order',
    description: 'Test order — fulfilled',
    ownerPersona: null,
  },
  {
    id: 'order:cancelled',
    kind: 'order',
    description: 'Test order — cancelled (supported test cancellation; no real funds)',
    ownerPersona: null,
  },
  {
    id: 'order:refunded',
    kind: 'order',
    description: 'Test order — refunded (supported test refund; no real funds)',
    ownerPersona: null,
  },
  {
    id: 'order:historical-C',
    kind: 'order',
    description: 'Historical order owned by persona C (before first app login)',
    ownerPersona: 'C',
  },
  {
    id: 'order:exclusive-B',
    kind: 'order',
    description: 'Order owned exclusively by persona B',
    ownerPersona: 'B',
  },
];

export const SHIPPING_FIXTURES = [
  {
    id: 'shipping:supported',
    kind: 'other',
    description: 'Supported shipping address accepted by the test environment',
  },
  {
    id: 'shipping:unsupported',
    kind: 'other',
    description: 'Unsupported destination',
  },
  {
    id: 'shipping:edge-rule',
    kind: 'other',
    description: 'Shipping-rule edge case using synthetic delivery details',
  },
];

export function planCatalogOrderResources(prefix) {
  const all = [...CATALOG_FIXTURES, ...ORDER_FIXTURES, ...SHIPPING_FIXTURES];
  return all.map((f) => ({
    id: f.id,
    kind: f.kind,
    status: 'planned',
    meta: {
      description: f.description,
      ownerPersona: f.ownerPersona ?? null,
      tag: `${prefix}-${f.id.replace(/:/g, '-')}`,
      remoteWrite: false,
      warning:
        'Do not place orders that trigger real fulfillment, production financial transactions, or third-party messages.',
    },
  }));
}
