# Shopify → Vercel → Firestore staging runbook

This is the deployment checklist for the synchronous Vercel implementation in
`api/`. It reads the public catalog from the live Monetta Shopify store and
writes only to an isolated staging Firebase project. The Admin API integration is read-only;
the endpoint never changes Shopify products or inventory.

Do not configure the Flutter delta fallback with credentials from a different
store. Firestore is authoritative; a matching live Storefront token may be
added later, but the old development-store fallback must stay disabled.

## Verified staging status — 2026-08-27

- Vercel deployment `dpl_AMF3hCJgWj3BudKoK9V2iFtVdZbm` is `READY`, and the
  stable alias resolves to it. `GET /api` returns `405`; unsigned `POST /api`
  returns `401 {"error":"invalid_signature"}`. The deployed functions are
  `api/index.ts` and `api/reconcile.ts`.
- Firestore `(default)` exists in `monetta-catalog-staging-edfb8` as Standard,
  Native mode. Rules and product field exemptions are deployed. Public reads
  of `products` return `200` with 139 documents; public reads of the delivery
  ledger return `403`.
- TTL for `_shopifyWebhookDeliveries.expiresAt` is declared in
  `firestore.indexes.json` but remains absent remotely. Billing activation is
  blocked externally with `OR_BACR2_44`, and Firestore still returns `403`
  `billing disabled`; do not retry the index deployment until that external
  issue is explicitly resolved. The three `products` field exemptions remain.
- Vercel confirms that `FIREBASE_SERVICE_ACCOUNT` exists as a protected
  Production variable, but protected values were not pulled. The deployed
  guard rejects any embedded `project_id` other than
  `monetta-catalog-staging-edfb8` before Admin initialization. A successful
  reconciliation and the resulting staging-only Firestore writes confirmed the
  runtime project identity without exposing the service-account JSON.
- Shopify app version `monetta-catalog-mirror-3` is active with API `2026-07`,
  scopes `read_products,read_inventory`, the four required topics, and this
  document's stable endpoint. It is installed on both Monetta Staging and the
  live Monetta store; the backend tenant allowlist accepts only the live source
  after the next deployment.
- The authorized source is now the live store
  (`fakcei-n9.myshopify.com` / `monetta.mx`). The destination remains strictly
  isolated: Vercel project `monetta-catalog-staging` and Firebase project
  `monetta-catalog-staging-edfb8`. The app cannot edit Shopify products,
  inventory, customers, or orders.
- Flutter has a feature-gated Firestore listener, single-flight shared Firebase
  initialization, atomic Drift replacement, retry/backoff, and preservation of
  a valid cache on empty/invalid/error snapshots. Shopify GIDs are the canonical
  product/variant identity; database v2 migrates numeric catalog, wishlist, bag,
  and interaction-history references. Delta sync is blocked while Firestore is
  connecting/live and runs only as the no-listener or error/disconnection
  fallback. Repository/store/migration/concurrency fake tests pass. Live device
  Android and iOS staging apps are registered, and their distinct public API
  key/app-id pairs are selected by platform from the ignored staging
  Dart-define file. Live device validation remains pending.
- After switching to the live source, two protected reconciliations were
  invoked through Vercel Cron: the first seeded the catalog and the second
  followed the image-limit correction. The final invocation began at
  `2026-08-27T23:39:23.633Z`. Firestore contains 139 live products and no
  development-store snowboards.
- All 139 Firestore documents were compared against the public `monetta.mx`
  catalog: 345 variants and 386 images were checked. Product IDs, handles,
  titles, vendors, product types, descriptions, images, variant IDs, prices,
  compare-at prices, availability and SKUs have zero mismatches. Product and
  variant GIDs are canonical and every document has
  `lastWebhookTopic: reconciliation` plus `syncedAt`.
- The iOS staging runtime reports `CatalogStore.ready == true`, realtime status
  `live`, and 139 products. Drift contains 139 products and 345 variants with
  zero invalid GIDs and zero snowboard records; the catalog screen visibly
  reports `139 artículos` and shows live Monetta merchandise.
- The Shopify last-seven-days activity contains successful Admin GraphQL
  requests but no observed natural webhook delivery. A real webhook delivery
  and a redelivery/deduplication check remain pending until a normal authorized
  catalog or inventory change occurs in the live store.

## 1. Use an isolated staging destination

The isolated staging resources are:

- Vercel project: `monetta-catalog-staging`
- Stable endpoint: `https://monetta-catalog-staging.vercel.app/api`
- Firebase project: `monetta-catalog-staging-edfb8`
- Shopify source shop: `fakcei-n9.myshopify.com` (live, read-only)

The source identity must agree at all three boundaries:

- Vercel `SHOPIFY_SHOP_DOMAIN`: `fakcei-n9.myshopify.com`;
- Shopify app: **Monetta Catalog Mirror**, installed read-only on Monetta;
- Flutter preview `SHOPIFY_STORE_DOMAIN`: `monetta.mx` when a matching public
  Storefront token is available, otherwise no Storefront delta fallback.

Create a dedicated Vercel project and a dedicated Firebase project for this
mirror. It is fine for the Vercel deployment to be the **Production** deployment
inside that staging-only Vercel project; that gives Shopify a stable URL while
keeping it separate from Monetta's production app environment. Do not register
webhooks against a per-commit Preview URL because it changes after deployments.

The linked Vercel project should use the repository root. The checked-in
`vercel.json` builds the existing Vite site and exposes:

- `POST /api` — Shopify webhook receiver;
- `GET /api/reconcile` — protected daily seed/repair job.

## 2. Vercel environment variables

In Vercel → Project → Settings → Environment Variables, add these to the
staging project's Production environment:

1. `SHOPIFY_APP_CLIENT_SECRET`: the Shopify app client secret used to sign the
   webhook, not the Storefront token.
2. `SHOPIFY_APP_CLIENT_ID`: the public client ID from the Dev Dashboard. The
   backend exchanges the client ID and secret for a short-lived Admin token.
3. `SHOPIFY_SHOP_DOMAIN`: exactly `fakcei-n9.myshopify.com`. This is the
   mandatory tenant allowlist for live read-only webhook deliveries.
4. `FIREBASE_SERVICE_ACCOUNT`: paste the complete one-line or multi-line JSON
   service-account key downloaded from the staging Firebase project.
5. `CRON_SECRET`: at least 32 random characters. Generate it locally with
   `openssl rand -hex 32`; do not paste it into chat or commit it.

`SHOPIFY_API_VERSION` is optional and defaults to `2026-07`.

Redeploy after changing environment variables. Vercel applies new values only
to new deployments. Never prefix these server credentials with `VITE_`; doing
so would expose them to browser code.

## 3. Firebase console and CLI

1. Create or select the staging Firebase project.
2. Build → Firestore Database → Create database in production mode. Choose the
   location carefully; it cannot be changed later.
3. Project settings → Service accounts → Generate new private key. Put the
   entire JSON only in Vercel's `FIREBASE_SERVICE_ACCOUNT` value, then store or
   destroy the downloaded file securely.
4. TTL is currently pending because billing activation is blocked externally.
   Its absence does not block webhook idempotency, but delivery-ledger records
   will not be removed automatically after 30 days.
5. Deploy the checked-in client rules and field-index exemptions:

   ```bash
   firebase use --add
   firebase deploy --only firestore:rules,firestore:indexes
   ```

The rules expose read-only public merchandising data from `products` and deny
all client writes and all access to the delivery ledger. Firebase Admin uses
IAM and is not constrained by client security rules. No composite index is
needed for the initial unfiltered catalog stream.

## 4. Deploy and verify unauthenticated behavior

Deploy the staging Vercel project. Verify that `GET https://YOUR-STAGING-HOST/api`
returns `405`; an unsigned `POST` must return `401` and must not create a
Firestore document. Also verify that an unauthenticated `GET /api/reconcile`
returns `401`, while `POST /api/reconcile` returns `405` with `Allow: GET`.
These checks use no protected values and must happen before installation.

Do not invoke the protected reconciliation yet. Shopify's client-credentials
exchange cannot succeed until Catalog Mirror is installed on the authorized
source store.

## 5. Shopify app and webhooks

Install **Monetta Catalog Mirror** on the live Monetta store. Its destination
is still staging-only and its scopes must remain read-only:

1. Grant only Admin API scopes `read_products,read_inventory`; reinstall the
   app after changing scopes.
2. Use the same app's client secret for HMAC and the client-credentials grant
   used for authoritative Admin API reads.
3. Register JSON subscriptions with the stable staging URL
   `https://YOUR-STAGING-HOST/api` for:
   - `products/create`
   - `products/update`
   - `products/delete`
   - `inventory_levels/update`
4. Confirm every subscription uses API version `2026-07` and the same HTTPS
   destination. Avoid leaving duplicate subscriptions in another app unless
   both consumers are intentional.

For a Shopify CLI-managed app, the relevant configuration is:

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
uri = "https://YOUR-STAGING-HOST/api"
```

For an Admin-created custom app, create the subscriptions with Shopify Admin
GraphQL `webhookSubscriptionCreate` using topic enums `PRODUCTS_CREATE`,
`PRODUCTS_UPDATE`, `PRODUCTS_DELETE`, and `INVENTORY_LEVELS_UPDATE`.

## 6. Reconcile and run the safe acceptance test

Only after Catalog Mirror is installed, invoke the protected reconciliation
once. Vercel Cron calls `/api/reconcile` daily at `09:17 UTC` (03:17 in
Monterrey); use Vercel's Cron dashboard or another mechanism that does not put
`CRON_SECRET` in shell history. Confirm HTTP `200` and that Firestore
`products` contains the published live-store catalog.

The reconciliation route also repairs missed webhook deliveries and removes
products that no longer exist. Its transaction guard will not overwrite a
newer product document written by a concurrent webhook.

Do not create, unpublish, zero inventory, or delete a product solely for
testing. Instead:

1. Seed the catalog with reconciliation and compare several records against
   Shopify Admin.
2. Observe a normal authorized product or inventory update and confirm the same
   Firestore document changes within seconds.
3. If the owner approves a controlled test, use a clearly designated hidden
   test product and restore its state immediately.
4. Check Vercel logs for `processed`, `ignored`, or `duplicate`; logs never
   include credentials or webhook bodies.
5. Redeliver one event from Shopify and confirm it returns `duplicate` without
   an extra catalog mutation.

The synchronous implementation intentionally returns `500`/`503` when Shopify
or Firestore cannot complete. Shopify can then retry. Shopify's five-second
webhook deadline still applies, so this free-tier design is suitable for
staging but a durable queue is the recommended production topology.

## 7. Flutter real-time listener

Android `mx.monetta.monetta_app` and iOS `mx.monetta.monettaApp` are registered
in the staging Firebase project. Supply their platform-specific public options
through `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`,
`FIREBASE_IOS_API_KEY`, and `FIREBASE_IOS_APP_ID` in the ignored staging
Dart-define file, together with the shared project/sender/bucket values, and
set:

```json
"FIRESTORE_CATALOG_ENABLED": "true"
```

The app initializes the default Firebase app through one memoized Future shared
by notifications and Firestore. `FirestoreCatalogSource` listens to `products`;
the repository validates the full schema before atomically replacing Drift.
Empty snapshots, invalid documents, listener errors, and reconnects never clear
a valid local catalog. Delta sync does not run while Firestore is connecting or
live; it is enabled after listener error/disconnection. Their writes are
serialized, and a reconnecting Firestore snapshot is applied last.

If generated platform configuration is preferred, run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure \
  --project=YOUR_STAGING_FIREBASE_PROJECT_ID \
  --platforms=android,ios \
  --out=lib/firebase_options.dart
```

Do not enable the flag in production until reconciliation and a real webhook
delivery have passed against that environment. Do not remove delta sync until
the owner explicitly accepts Firestore as the primary catalog source.
