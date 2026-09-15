import { assertRemoteWriteAllowed, loadGuardConfig } from './guards.mjs';

/** Official Admin GraphQL only. Never sends raw API errors or credentials to logs. */
export class ShopifyAuditAdapter {
  constructor({ env = process.env, fetchImpl = fetch } = {}) {
    this.env = env; this.fetch = fetchImpl;
    const domain = env.AUDIT_SHOP_DOMAIN;
    if (!/^[a-z0-9][a-z0-9-]*\.myshopify\.com$/.test(domain ?? '')) throw new Error('AUDIT_SHOP_DOMAIN must be the permanent Shopify host');
    if (!env.AUDIT_ADMIN_ACCESS_TOKEN) throw new Error('Missing AUDIT_ADMIN_ACCESS_TOKEN');
    this.endpoint = `https://${domain}/admin/api/2026-07/graphql.json`;
  }
  async query(query, variables = {}) {
    const response = await this.fetch(this.endpoint, { method: 'POST', redirect: 'error',
      headers: {'Content-Type': 'application/json', 'X-Shopify-Access-Token': this.env.AUDIT_ADMIN_ACCESS_TOKEN},
      body: JSON.stringify({query, variables}), signal: AbortSignal.timeout(20000) });
    if (!response.ok) throw new Error(`Shopify audit HTTP ${response.status}`);
    const body = await response.json();
    if (body.errors?.length || !body.data) throw new Error('Shopify audit GraphQL rejected request');
    for (const result of Object.values(body.data)) {
      if (result?.userErrors?.length || result?.orderCancelUserErrors?.length) throw new Error('Shopify audit mutation rejected input');
    }
    return body.data;
  }
  async verify() {
    const gate = assertRemoteWriteAllowed(loadGuardConfig(this.env));
    if (!gate.allowed || !['development', 'staging'].includes(this.env.AUDIT_ENVIRONMENT)) throw new Error('Authorized development environment required');
    const {shop} = await this.query('query AuditIdentity { shop { id myshopifyDomain primaryDomain { host } plan { partnerDevelopment } } }');
    const identities = [shop?.id, shop?.id?.split('/').at(-1), shop?.myshopifyDomain];
    if (!shop?.plan?.partnerDevelopment || !identities.includes(gate.expectedShopId) ||
        shop.myshopifyDomain !== this.env.AUDIT_SHOP_DOMAIN || shop.primaryDomain?.host === 'monetta.mx') {
      throw new Error('Live Shopify identity/development-plan verification failed');
    }
    this.shop = shop;
    return {id: shop.id, myshopifyDomain: shop.myshopifyDomain, partnerDevelopment: true};
  }
  async find(resource) {
    const kind = this.kind(resource);
    if (!kind) return null;
    const connection = {product: 'products', customer: 'customers', order: 'orders', collection: 'collections'}[kind];
    // Collections do not have tags: use their deterministic run-specific handle.
    const selector = kind === 'collection' ? `handle:${resource.meta.tag}` : `tag:${resource.meta.tag}`;
    const fields = kind === 'collection' ? 'id handle' : 'id tags';
    const data = await this.query(`query AuditFind($query: String!) { ${connection}(first: 10, query: $query) { nodes { ${fields} } } }`, {query: selector});
    const matches = data[connection].nodes.filter(n => kind === 'collection' ? n.handle === resource.meta.tag : n.tags.includes(resource.meta.tag));
    if (matches.length > 1) throw new Error('Multiple run resources found; operator reconciliation required');
    return matches[0]?.id ?? null;
  }
  kind(resource) {
    if (resource.kind === 'persona' && resource.meta.code === 'C') return 'customer';
    if (resource.kind === 'variant') return 'product';
    return ['product', 'collection', 'order'].includes(resource.kind) ? resource.kind : null;
  }
  async create(resource, manifest) {
    if (!this.shop) throw new Error('Verify live shop before writes');
    const kind = this.kind(resource), tag = resource.meta.tag;
    if (!kind) return {status: 'blocked', meta: {...resource.meta, blocker: resource.kind === 'persona'
      ? 'Hosted login/controlled inbox or local account adapter required; no customer invented'
      : 'Scenario needs explicit operator setup after base fixtures'}};
    const found = await this.find(resource);
    if (found) return {status: 'created', remote_id: found, meta: {...resource.meta, recovered: true}};
    if (resource.status === 'creating') throw new Error('Prior creation outcome unknown; reconcile run tag before retrying a write');
    let data, id;
    if (kind === 'product') {
      data = await this.query(`mutation AuditProduct($input: ProductSetInput!) { productSet(input: $input, synchronous: true) { product { id variants(first: 10) { nodes { id } } } userErrors { field message } } }`, {
        input: {title: tag, handle: tag, tags: [tag, manifest.resource_prefix], status: 'ACTIVE',
          productOptions: [{name: 'Audit variant', values: [{name: 'A'}, {name: 'B'}]}],
          variants: ['A','B'].map((name, i) => ({optionValues: [{optionName: 'Audit variant', name}], price: i ? '200.00' : '100.00', inventoryPolicy: resource.kind === 'variant' ? 'DENY' : 'CONTINUE', inventoryItem: {tracked: resource.kind === 'variant'}}))},
      });
      id = data.productSet.product?.id;
      resource.meta.variant_ids = data.productSet.product?.variants.nodes.map(v => v.id);
      resource.meta.publication = 'unpublished';
      if (resource.id === 'product:headless-published') {
        resource.meta.fixture_ready = false;
        resource.meta.blocker = 'Run operate --action publish with verified AUDIT_PUBLICATION_ID';
      }
    } else if (kind === 'customer') {
      const email = this.env.AUDIT_CUSTOMER_C_EMAIL;
      if (!email) return {status: 'blocked', meta: {...resource.meta, blocker: 'Missing controlled AUDIT_CUSTOMER_C_EMAIL'}};
      data = await this.query('mutation AuditCustomer($input: CustomerInput!) { customerCreate(input: $input) { customer { id } userErrors { field message } } }', {input: {email, tags: [tag, manifest.resource_prefix]}});
      id = data.customerCreate.customer?.id;
    } else if (kind === 'collection') {
      data = await this.query('mutation AuditCollection($input: CollectionInput!) { collectionCreate(input: $input) { collection { id } userErrors { field message } } }', {input: {title: tag, handle: tag}});
      id = data.collectionCreate.collection?.id;
    } else {
      const owner = resource.meta.ownerPersona;
      const customer = owner ? manifest.resources.find(r => r.id === `persona:${owner}`)?.remote_id : null;
      if (owner && !customer) return {status: 'blocked', meta: {...resource.meta, blocker: 'Owner persona must complete verified setup first'}};
      if (['order:fulfilled','order:cancelled','order:refunded'].includes(resource.id)) return {status: 'blocked', meta: {...resource.meta, blocker: 'Create test purchase then execute fulfillment/cancel/refund journey; no fabricated terminal state'}};
      data = await this.query('mutation AuditOrder($order: OrderCreateOrderInput!, $options: OrderCreateOptionsInput) { orderCreate(order: $order, options: $options) { order { id test } userErrors { field message } } }', {
        order: {test: true, currency: 'MXN', tags: [tag, manifest.resource_prefix],
          ...(customer ? {customer: {toAssociate: {id: customer}}} : {}),
          financialStatus: resource.id === 'order:paid' ? 'PAID' : 'PENDING',
          lineItems: [{title: tag, quantity: 1, requiresShipping: false, priceSet: {shopMoney: {amount: '100.00', currencyCode: 'MXN'}}}]},
        options: {sendReceipt: false, sendFulfillmentReceipt: false, inventoryBehaviour: 'BYPASS'},
      });
      if (data.orderCreate.order?.test !== true) throw new Error('Shopify did not return a test order');
      id = data.orderCreate.order.id;
    }
    if (!id) throw new Error('Shopify returned no resource ID');
    return {status: 'created', remote_id: id, meta: {...resource.meta, remote_write_attempted: true}};
  }
  async remove(resource) {
    if (!this.shop) throw new Error('Verify live shop before cleanup');
    const kind = this.kind(resource);
    if (!kind || !resource.remote_id) return false;
    const {node} = await this.query(`query AuditCleanupOwner($id: ID!) { node(id: $id) {
      id ... on Product { tags } ... on Customer { tags }
      ... on Order { tags test } ... on Collection { handle }
    } }`, {id:resource.remote_id});
    if (node === null) return true;
    const owned = kind === 'collection' ? node?.handle === resource.meta.tag : node?.tags?.includes(resource.meta.tag);
    if (!node || node.id !== resource.remote_id || !owned || (kind === 'order' && node.test !== true)) throw new Error('Cleanup ownership mismatch');
    const found = node.id;
    const mutation = `${kind}Delete`;
    const field = kind === 'order' ? 'deletedId' : `deleted${kind[0].toUpperCase()}${kind.slice(1)}Id`;
    const input = kind === 'order' ? '$id: ID!' : `$input: ${kind[0].toUpperCase()}${kind.slice(1)}DeleteInput!`;
    const args = kind === 'order' ? 'orderId: $id' : 'input: $input';
    const data = await this.query(`mutation AuditDelete(${input}) { ${mutation}(${args}) { ${field} userErrors { field message } } }`, kind === 'order' ? {id: found} : {input: {id: found}});
    if (data[mutation][field] !== found) throw new Error('Deletion not confirmed');
    return true;
  }
}
