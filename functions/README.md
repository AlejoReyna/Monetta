# Monetta catalog webhooks

Firebase Functions v2 backend for the public Shopify-to-Firestore catalog
mirror. It exports:

- `shopifyCatalogWebhook`: one public HTTPS endpoint that authenticates and
  durably queues `products/create`, `products/update`, `products/delete`, and
  `inventory_levels/update`, then acknowledges Shopify within its deadline.
- `processShopifyCatalogWebhook`: a retry-enabled Firestore trigger that
  resolves authoritative Shopify state and updates the public catalog.
- `reconcileShopifyCatalog`: a daily repair/seed job. Webhooks provide low
  latency; this pass repairs missed deliveries and removes stale products.

## Security and consistency properties

- HMAC-SHA256 is checked against `request.rawBody` with a constant-time byte
  comparison before JSON or routing headers are trusted.
- The exact `*.myshopify.com` tenant is allowlisted.
- Only four topics and structurally valid payloads are accepted.
- `X-Shopify-Webhook-Id` is the durable receipt document id. Duplicate receipt
  creation is harmless; background product mutation and receipt completion are
  committed in one transaction.
- The Admin access token and app client secret are separate Secret Manager
  secrets. Neither belongs in Flutter, a dotenv file, or git.
- Inventory webhook payloads identify an inventory item/location, not a
  product. The handler resolves the item through Admin GraphQL and stores
  Shopify's authoritative `availableForSale` state, including multi-location
  inventory semantics.
- Draft, archived, unlisted, and unpublished products are deleted from the
  public collection. Firestore clients have read-only access to `products` and
  no access to delivery metadata.

The product document id is Shopify's numeric legacy product id (valid as a
Firestore path segment); the `id` field remains the Storefront-compatible GID
used by Monetta's current Dart `Product` model.

## Local verification

```bash
cd functions
npm install
npm run typecheck
npm test
npm run build
```

Deployment and Shopify registration are documented in
`../docs/REALTIME_CATALOG_SETUP.md`.
