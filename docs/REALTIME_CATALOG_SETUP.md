# Real-time Shopify catalog: deployment checklist

> Historical Firebase Functions plan. Staging currently uses the synchronous
> Vercel implementation in `api/`; use
> `docs/VERCEL_CATALOG_WEBHOOK_SETUP.md` for verified status and operations.
> The Flutter listener described here is now implemented behind
> `FIRESTORE_CATALOG_ENABLED`, while delta sync remains the fallback.

This runbook deploys Step 1 (Firebase Functions + Firestore) and configures the
infrastructure needed for Step 3. Do this in staging first. Do not remove the
Flutter delta sync until the Firestore reconciliation has seeded the full
catalog and real webhook deliveries have passed acceptance testing.

## 0. Credential boundary

Use one store-owned Shopify custom app for all three of these values/actions:

1. its **client secret** signs webhook deliveries;
2. its **Admin API access token** lets the function resolve authoritative
   product and multi-location availability data;
3. its Admin API token creates the four webhook subscriptions.

Do not paste either credential into chat, Flutter configuration, a tracked
file, or a command that will remain in shell history. Enter them only into the
interactive Firebase secret prompts below.

## 1. Shopify Admin / Dev Dashboard

1. In the staging shop, create (or select) the store-owned custom app that will
   own the catalog mirror. Keep production and staging apps/credentials
   separate.
2. Configure Admin API scopes `read_products` and `read_inventory`, install the
   app, and approve the scopes. Reinstall/re-authorize after adding a scope.
3. Copy the Admin API access token when Shopify reveals it. Keep it in a
   password manager until the Firebase secret prompt; Shopify may only reveal
   it once.
4. Copy the same app's client secret. This is the HMAC secret, not the
   Storefront token and not the Admin access token.
5. Do not create subscriptions yet: the deployed Firebase URL is needed first.

For a CLI/Dev-Dashboard-managed app, the equivalent configuration is:

```toml
[access_scopes]
scopes = "read_products,read_inventory"

[webhooks]
api_version = "2026-07"

[[webhooks.subscriptions]]
topics = [
  "products/create",
  "products/update",
  "products/delete",
  "inventory_levels/update"
]
uri = "https://DEPLOYED_FUNCTION_URL"
```

The current `shopify.app*.toml` files still target the separate
`accounts_orders` service for some product events. During cutover, consolidate
each topic to one intended subscription or consciously keep both consumers;
do not accidentally register duplicate subscriptions.

## 2. Firebase Console

1. Reuse Monetta's existing Firebase project (already used for FCM) unless a
   separate staging project is intentional. Select the **Blaze** plan: Functions
   v2, Secret Manager, Cloud Scheduler, and outbound Shopify API calls require
   billing-enabled Google Cloud services.
2. Build → Firestore Database → **Create database** in production mode. Choose
   the existing project/Functions-compatible location carefully; a Firestore
   database location cannot be changed later.
3. Project settings → Your apps: register Android
   `mx.monetta.monetta_app` and iOS `mx.monetta.monettaApp` if they are not
   already registered.
4. Keep client writes closed. The checked-in `firestore.rules` grants public
   read-only access to `products` (public storefront data) and denies every
   other client read/write. Firebase Admin in the function bypasses these
   client rules through IAM.
5. Firestore → TTL (or Google Cloud Console → Firestore → Time-to-live): add a
   TTL policy for collection group `_shopifyWebhookDeliveries`, field
   `expiresAt`. This bounds the 30-day idempotency ledger.

## 3. Firebase CLI: configure and deploy

From the repository root:

```bash
npm install --global firebase-tools
firebase login
firebase use --add
firebase functions:secrets:set SHOPIFY_APP_CLIENT_SECRET
firebase functions:secrets:set SHOPIFY_ADMIN_ACCESS_TOKEN
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Enter secrets only at the hidden prompts. On the first deploy, parameterized
configuration prompts for:

- `SHOPIFY_SHOP_DOMAIN`: exact permanent hostname, for example
  `monetta-staging.myshopify.com` (never the vanity domain);
- `SHOPIFY_API_VERSION`: accept the checked-in `2026-07` default.

The HTTPS function performs only authentication, validation, and a durable
Firestore queue write before returning `200`; `processShopifyCatalogWebhook`
does the Admin GraphQL work in the background with retries. This respects
Shopify's five-second total HTTPS deadline.

The CLI saves non-secret parameter values in ignored
`functions/.env.<firebase-project-id>`. Record the printed URL for
`shopifyCatalogWebhook`. A GET to it should return `405`; an unsigned POST
should return `401`. Both prove the route is public while database writes
remain HMAC-gated.

No composite Firestore index is needed for the initial unfiltered product
stream. `firestore.indexes.json` disables indexing only for large fields that
are never queried (`descriptionHtml`, `images`, and `variants`). If Step 2 adds
a compound server query, use the index-creation link Firestore returns and
commit the resulting index definition.

## 4. Register the Shopify subscriptions

For a CLI-managed app, replace the URI in the TOML fragment above, validate,
deploy a new app version, review it, and release it:

```bash
cd shopify
npx shopify app config validate --config staging
npx shopify app deploy --config staging
```

For a store-owned custom app created inside Shopify Admin, Shopify's current
guidance is to create custom-app subscriptions with the GraphQL Admin API. Run
`webhookSubscriptionCreate` four times with the deployed HTTPS URL and these
topic enum values:

- `PRODUCTS_CREATE`
- `PRODUCTS_UPDATE`
- `PRODUCTS_DELETE`
- `INVENTORY_LEVELS_UPDATE`

Example mutation (variables change for each topic):

```graphql
mutation CreateWebhook(
  $topic: WebhookSubscriptionTopic!
  $subscription: WebhookSubscriptionInput!
) {
  webhookSubscriptionCreate(
    topic: $topic
    webhookSubscription: $subscription
  ) {
    webhookSubscription { id topic uri }
    userErrors { field message }
  }
}
```

```json
{
  "topic": "PRODUCTS_CREATE",
  "subscription": {
    "uri": "https://DEPLOYED_FUNCTION_URL",
    "format": "JSON"
  }
}
```

Use Shopify's Admin GraphiQL app or a local authenticated Shopify CLI session
so the token is not written into a script. In Dev Dashboard → app → Versions →
Configuration (or query `webhookSubscriptions`), verify all four topics point
to the exact same URL and use API version `2026-07`.

## 5. Seed and acceptance-test staging

1. Deployment creates the Cloud Scheduler job for
   `reconcileShopifyCatalog`. In Google Cloud Console → Cloud Scheduler, select
   the generated job and choose **Force run**. It also runs daily at 03:17
   `America/Monterrey`.
2. In Firestore, confirm `products` contains the full published Shopify
   catalog. Documents should have `schemaVersion: 1`, Shopify GIDs in `id` and
   `variants[].id`, numeric prices, and `isInStock`.
3. Run the Shopify CLI transport test if desired:

   ```bash
   npx shopify app webhook trigger \
     --api-version=2026-07 \
     --address=https://DEPLOYED_FUNCTION_URL \
     --topic=products/update
   ```

   A synthetic payload can verify delivery/HMAC plumbing, but a real staging
   edit is the authoritative end-to-end test because the handler resolves the
   referenced product through Admin GraphQL.
4. Perform four real staging tests and watch both Firestore and Functions logs:
   create a published product; change its title/price; set tracked inventory to
   zero and back above zero; delete the product. The same Firestore document
   should be created/updated and then disappear on deletion.
5. Redeliver a webhook from Shopify. The receipt function should answer 200
   with `status: duplicate`, and the catalog must remain unchanged.
6. Only after these pass should production credentials/project values be
   configured and the subscriptions repeated against production.

## 6. FlutterFire preparation (used in Step 2)

From the repository root, after registering both mobile apps:

```bash
dart pub global activate flutterfire_cli
flutterfire configure \
  --project=YOUR_FIREBASE_PROJECT_ID \
  --platforms=android,ios \
  --out=lib/firebase_options.dart
```

This repository currently ignores `lib/firebase_options.dart` and native
Firebase config files to keep environment-specific configuration local. In
Step 2 we will choose one consistent initialization path (generated options or
the existing dart-defines-based `NotificationConfig`) instead of initializing
the default Firebase app twice.

Before enforcing App Check for Firestore, ship and verify the existing
Play Integrity / App Attest integration on staging; enabling enforcement first
would make every unverified catalog listener fail.

## Official references

- Shopify: https://shopify.dev/docs/apps/build/webhooks/verify-deliveries
- Shopify subscriptions: https://shopify.dev/docs/apps/build/webhooks/subscribe
- Shopify webhook payload reference: https://shopify.dev/docs/api/webhooks/latest
- Firebase parameter/secrets: https://firebase.google.com/docs/functions/config-env
- Firestore rules: https://firebase.google.com/docs/firestore/security/get-started
- FlutterFire setup: https://firebase.google.com/docs/flutter/setup
