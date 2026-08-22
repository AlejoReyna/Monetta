# Shopify production implementation plan

Status: Phase 0 largely complete for **dev-store staging**; backend HTTPS still optional for catalog/login, required for webhooks  
Prepared: 2026-08-16  
Updated: 2026-08-17  
Primary executor: coding agent with terminal access and Shopify CLI  
Owner involvement: interactive Shopify authentication, approvals, credentials, store configuration, and final test-order approval  
Branch: `agent/shopify-production`  
CLI: local install under `shopify/` (`npx shopify` → **4.6.1**)  

### Phase 0 owner answers (recorded)

| Question | Answer | Consequence |
|---|---|---|
| Real Monetta email/password accounts exist? | **Yes** | Do **not** delete `/accounts/*` password endpoints or drop password tables. Phase 6 must ship an explicit migration + communication plan before any data removal. New production UI still prefers Shopify Customer Accounts; password path stays available until migration completes. |
| Staging vs production store | **Use a development store only** | Never install the CLI app or point staging dart-defines at monetta.mx / fakcei-n9 / monetta-2 |

### Phase 0 progress (2026-08-17)

| Step | Status |
|---|---|
| Branch `agent/shopify-production` | done |
| Shopify CLI 4.6.1 under `shopify/` | done |
| Owner `shopify auth login` | done (org **Monetta** `211167120`) |
| Production store identity | **fakcei-n9 = monetta-2 = monetta.mx** (live). Shop id `72391655575`. Do not use for staging installs. |
| Staging **dev store** | done — **monetta-staging.myshopify.com**, shop id **`90228850722`** |
| Staging app linked | done — **monetta-staging**, client_id `4a29ba522a35bd476f3d1f467749234f` |
| Headless + public Storefront token (staging) | done (gitignored `config/dart_defines.staging.json`) |
| Customer Account mobile client (staging) | done — client UUID + callback `shop.90228850722.oauth://callback` |
| Native callback schemes (iOS/Android) | done — staging shop id hard-coded (needs flavors before production) |
| Accidental Headless on production | installed then **removed**; old public token returns 401 |
| Staging HTTPS backend + Postgres | **not required for catalog/login**; **required for webhooks / order mirror** |
| `SHOPIFY_APP_CLIENT_SECRET` on backend host | **blocked — owner** when backend exists |
| Production app link + Headless on live | later (after staging acceptance) |

## 1. Target outcome

Ship Monetta as a native Flutter client whose commerce experience is owned by Shopify end to end:

- Storefront API: products, collections, navigation, search, recommendations, contextual prices, inventory, cart, discounts, and checkout URL.
- Customer Account API: Shopify-hosted passwordless login, customer profile, saved addresses, orders, fulfillments, refunds, and authenticated checkout.
- Shopify Checkout: payment, shipping selection, taxes, discounts, Shop Pay, and PCI-sensitive fields.
- Monetta backend: only webhook receipt, compliance, push notifications, and optional apartado/attribution enrichment. It is not a second catalog or identity source.
- Drift: offline cache and device state, never the source of truth for Shopify data.

Guest checkout must remain fully functional. Login improves repeat checkout and unlocks account data; it must never become a purchase wall.

## 2. Decisions the implementation agent must preserve

1. **Shopify Customer Accounts replace the production Monetta password flow.** The current email/password UI and `/accounts/register` and `/accounts/login` endpoints must not be exposed in production. Before deleting data or migrations, stop and ask the owner whether real users exist. If none exist, remove the production path; if users exist, write an explicit migration and communication plan first.
2. **Use a public Storefront token in Flutter.** Never place a private Storefront token, Shopify app secret, Admin API token, database credential, or Firebase service-account credential in the app or repository.
3. **Use OAuth 2.0 Authorization Code + PKCE for mobile login.** Use Shopify's hosted account UI and the existing `flutter_appauth` integration. Never collect a Shopify password in Flutter.
4. **Query customer-owned data directly from the Customer Account API.** Order history, profile, and addresses should not trust a customer ID supplied to an unauthenticated Monetta endpoint.
5. **Use Storefront Cart API plus `checkoutUrl`.** Monetta must never collect card details.
6. **Develop against a development/staging app and store first.** Production configuration is deployed only after the staging acceptance suite passes.
7. **Pin API version `2026-07`.** Add a quarterly compatibility review; never use `unstable` in a release build.
8. **Keep the bundled catalog only as a cold-start/offline fallback.** After the first complete Shopify sync, live Shopify records replace legacy asset rows atomically.
9. **Keep the external catalog prototype disabled in public builds.** It is unrelated to Shopify production readiness.

## 3. Current repository state and concrete gaps

| Area | Existing code | Production gap |
|---|---|---|
| Catalog | Storefront queries, mappers, delta sync, Drift cache | `main.dart` does not create a `StorefrontClient`/`CatalogSync`; startup uses only the asset |
| Full sync | Pagination and seven-day full-sync decision | A full sync only upserts; it does not remove unpublished/deleted products |
| Legacy IDs | Asset uses numeric IDs | Storefront API returns GIDs; naïve first sync can duplicate products and orphan bag/wishlist rows |
| Collections/menu | Queries exist | Owner-driven navigation, collections, and shop metafields are not wired through the UI repository |
| Cart | GraphQL documents and cart mapper exist | No cart repository/client methods, buyer identity integration, persisted Shopify cart, or real launcher wiring |
| Checkout | `CheckoutDraft` and launcher callback seam exist | Production falls back to `_SecureHandoffPreview` |
| Shopify login | OAuth/PKCE gateway and secure refresh-token storage exist | Not constructed in `main.dart`; native callback still contains placeholder shop ID |
| Account UI | Account controller and screen exist | Visible UI uses a separate Monetta email/password service instead of Shopify hosted login |
| Customer data | None beyond token exchange | Customer API discovery, customer/profile, addresses, orders, pagination, refresh, and error handling are missing |
| Backend | HMAC webhooks, idempotency, mirror tables, compliance routes | Public customer/order reads and push registration need bearer authentication; custom password service is not launch ready |
| Shopify CLI | No CLI project or TOML files | App configuration, scopes, subscriptions, staging/production linkage, and deploy workflow are absent |

## 4. Credential and owner-action matrix

There are three separate Shopify identities. Do not combine their credentials.

| Purpose | Created in | Mobile-safe values | Backend-only values |
|---|---|---|---|
| Headless storefront | Shopify Admin → Headless | shop domain, public Storefront token, API version | private Storefront token, if ever needed; normally unnecessary |
| Customer Account mobile client | Headless storefront → Customer Account API | shop ID, public mobile client ID, callback URI | no mobile client secret |
| CLI-managed Shopify app | Dev Dashboard/Shopify CLI | none | app client ID and client secret; short-lived Admin token only if an Admin API operation is required |

Owner must provide or complete:

- Access to the Shopify organization/store with Apps and channels permission.
- Interactive `shopify auth login` in the agent's terminal. Do not send the owner password to the agent.
- A development/staging Shopify app and target store, followed later by the production app/store selection.
- Headless storefront public token and `*.myshopify.com` domain.
- Customer Account mobile client ID, numeric shop ID, and permission approval.
- Public HTTPS backend URL and managed Postgres connection, or authorization for the agent to create them on the chosen host.
- Shopify app client ID/secret entered directly into the backend host's secret manager.
- Confirmation whether any real Monetta password accounts already exist.
- Test customer, test shipping address, and permission to place/refund test orders.

The agent must create a gitignored local configuration template and document its variable names. Real values belong in CI/hosting secret stores, not committed files or screenshots.

## 5. Shopify CLI workspace and environment strategy

Do not run `shopify app init` over the Flutter repository root. Keep Shopify app configuration isolated under `shopify/` so the CLI cannot replace or restructure the Flutter project.

Expected configuration layout:

```text
shopify/
  shopify.app.toml                 # development default
  shopify.app.staging.toml         # staging app linkage
  shopify.app.production.toml      # production app linkage
  README.md                        # exact CLI and owner handoff procedure
```

The existing Express service remains in `services/accounts_orders/`. The Shopify directory may be configuration-only. If the installed CLI requires a web role for `app dev`, add a minimal isolated admin shell under `shopify/`; do not move the Flutter app or duplicate the Express service.

Initial CLI sequence:

```bash
npm install -g @shopify/cli@latest
shopify version
shopify auth login
cd shopify
shopify app config link
shopify app config validate --config staging
```

Use distinct linked app configs. Every mutating command must include `--config staging` or `--config production`; do not rely on whichever config happens to be the default.

Across the CLI-managed app and Headless storefront, use least privilege and include only scopes justified by implemented behavior:

- CLI app `[access_scopes]`: initially `read_orders,read_customers` if the webhook mirror remains.
- Headless Customer Account permissions: `customer_read_customers`, `customer_write_customers`, `customer_read_orders`, and `customer_read_markets` if market data is rendered.
- Headless Storefront permissions: product listings, product tags, product inventory, content/navigation, metafields/metaobjects, and cart/checkout access needed by the checked-in queries.

Do not guess scope names or silently request broad write access. Validate the final configuration with the installed CLI and current API schema.

Configure app-specific webhooks in TOML using API version `2026-07`:

- `orders/create` → `/webhooks/orders/create`
- `orders/updated` → `/webhooks/orders/updated`
- `customers/data_request` → `/webhooks/customers/data_request`
- `customers/redact` → `/webhooks/customers/redact`
- `shop/redact` → `/webhooks/shop/redact`
- `app/uninstalled` → add a handler that disables shop-specific processing immediately

Use `topics` for ordinary subscriptions and `compliance_topics` for the three privacy subscriptions. Use absolute HTTPS production URIs unless a verified CLI relative-URI deployment is in place.

## 6. Implementation phases

### Phase 0 — preflight, safety, and staging setup

Tasks:

1. Preserve the current dirty worktree and create a dedicated implementation branch/worktree.
2. Install and record the Shopify CLI version.
3. Create/link staging and production app configurations, with staging selected for all initial work.
4. Install/open Headless in the staging store, create a storefront, and publish representative products to it.
5. Enable Shopify Customer Accounts in the staging store.
6. Configure a **Mobile** Customer Account client with callback:

   `shop.<SHOP_ID>.oauth://callback`

7. Add protected customer-data access requested by the exact UI fields.
8. Deploy the current backend to a staging HTTPS URL with staging Postgres, then run migrations.
9. Add secret scanning and confirm no private tokens are tracked by Git.

Acceptance:

- `shopify app config validate --config staging` passes.
- A read-only Storefront GraphQL smoke query returns a known staging product.
- Customer Account discovery endpoints return valid OpenID and GraphQL URLs.
- Invalid webhook HMAC returns 401; valid sample delivery returns 200.
- No production store data has been modified.

### Phase 1 — production-grade Storefront configuration and transport

Files likely affected:

- `lib/main.dart`
- `lib/data/shopify/storefront_config.dart`
- `lib/data/shopify/storefront_client.dart`
- new HTTP transport/config bootstrap files under `lib/data/shopify/` or `lib/core/`

Tasks:

1. Add a validated `StorefrontConfig.fromEnvironment` or equivalent bootstrap using public values only.
2. Load release values from CI `--dart-define-from-file` and optionally Firebase Remote Config for token rotation. A failed Remote Config fetch must retain last-known-good values.
3. Implement the real `package:http` GraphQL transport with timeout, cancellation/disposal, retry with bounded exponential backoff and jitter for transient failures, and response-size/status validation.
4. Construct `StorefrontClient` and `CatalogSync` in `main.dart` and inject them into `CatalogStore`.
5. Add market context for Mexico (`country=MX`, Spanish locale) so prices and availability match checkout.
6. Never log request headers, customer tokens, full cart IDs, or checkout URLs.

Acceptance:

- A release-like staging build starts from cache and refreshes from Shopify.
- Offline startup renders cached/asset data and reports a non-blocking sync state.
- Invalid configuration fails closed without exposing token values.

### Phase 2 — complete catalog, collections, navigation, and image reconciliation

Files likely affected:

- `lib/data/shopify/catalog_sync.dart`
- `lib/data/repositories/catalog_repository.dart`
- `lib/data/local/catalog_cache_store.dart`
- `lib/data/shopify/queries.dart`
- catalog/navigation feature controllers

Tasks:

1. Make a full sync atomic: fetch every page first, reject an incomplete/max-page result, then replace the Shopify catalog in one transaction.
2. Delete cached products, variants, and collections absent from a successful full response. Never delete cache after a partial or failed response.
3. Migrate legacy numeric asset IDs to Shopify GIDs. Map products by the numeric GID tail and/or unique handle; map variants by numeric tail and verify SKU/product ownership. Migrate device wishlist and bag references before deleting legacy rows.
4. Ensure first live sync yields one row per Shopify product, not asset + GID duplicates.
5. Keep delta sync for updates, but schedule full reconciliation on first authenticated storefront run and at least every seven days.
6. Wire paginated collections, `main-menu`, shop announcement/home-section metafields, predictive search, and product recommendations into repositories/controllers used by the UI.
7. Detect truncation for product images, variants, and collection memberships. Paginate or fail with telemetry when the store exceeds current per-product limits.
8. Refresh on app foreground and explicit pull-to-refresh with a single-flight lock.
9. Preserve the honest image fallback. Re-uploaded Shopify media should replace the 125 currently dead snapshot URLs on the next complete sync.

Acceptance:

- Shopify's published product count equals the app's unique cached product count.
- Unpublishing a product removes it after forced full sync.
- Price, inventory, images, tags, collections, and navigation changes appear without an app release.
- Existing guest wishlist/bag survives numeric-ID → GID migration where a deterministic match exists; unresolved rows are reported and safely omitted.
- Pagination tests cover 0, 1, 250, 251, and max-page overflow cases.

### Phase 3 — real Shopify cart and checkout

Files likely affected:

- `lib/data/shopify/queries.dart`
- `lib/data/shopify/storefront_client.dart` or a new `cart_client.dart`
- new cart repository under `lib/data/repositories/`
- `lib/features/checkout/checkout_screen.dart`
- local bag/cart persistence

Tasks:

1. Implement typed operations for `cartCreate`, `cartLinesAdd`, `cartLinesUpdate`, `cartLinesRemove`, `cartBuyerIdentityUpdate`, `cartDiscountCodesUpdate`, cart retrieval, and fresh `checkoutUrl` retrieval.
2. Parse both top-level GraphQL errors and mutation `userErrors`; show safe Spanish messages for sold-out, changed price, invalid variant, invalid discount, and network failure.
3. Persist the complete Shopify cart ID locally without logging or exposing its secret query component. Treat it as sensitive session data.
4. Reconcile the local bag with Shopify before handoff. Shopify's returned lines, prices, discounts, and availability win over local estimates.
5. For guests, set email/phone/country and delivery preferences from the checkout draft where supported.
6. For signed-in customers, attach the current Customer Account access token as cart buyer identity so checkout opens signed in.
7. Generate attribution attributes from `cart_attribution.dart` without PII.
8. Replace `_SecureHandoffPreview` in configured release builds with Checkout Kit. Keep an HTTPS external-browser fallback behind the existing launcher seam.
9. Fetch `checkoutUrl` immediately before opening it; validate scheme and allowed Shopify/store hosts.
10. Clear the local bag only after confirmed checkout completion or verified order creation, not merely when checkout opens.

Acceptance:

- Guest and signed-in staging customers can add/update/remove variants and reach real Shopify checkout.
- Sold-out inventory cannot be purchased from a stale cache.
- Signed-in checkout recognizes the customer.
- Cancelled checkout preserves the bag.
- One test order carries Monetta attribution and appears correctly in Shopify Admin.

### Phase 4 — Shopify Customer Account login and session lifecycle

Files likely affected:

- `lib/main.dart`
- `lib/app/account_controller.dart`
- `lib/features/account/account_screen.dart`
- `lib/data/customer_auth/*`
- `ios/Runner/Info.plist`
- `android/app/build.gradle.kts`

Tasks:

1. Replace placeholder native callback schemes using the real numeric shop ID for each flavor/environment.
2. Replace hardcoded authorization/token endpoints with runtime discovery from:

   - `/.well-known/openid-configuration`
   - `/.well-known/customer-account-api`

   Cache discovery safely and retain a last-known-good configuration.
3. Construct `CustomerAccountConfig`, `AppAuthCustomerGateway`, and `CustomerSessionRepository` in `main.dart`.
4. Replace the visible email/password forms with one Shopify-hosted sign-in/create-account action and clear guest continuation.
5. Keep refresh tokens only in Keychain/Keystore. Keep access tokens in memory and refresh before expiry with single-flight concurrency.
6. After OAuth, call `customer { id ... }` with the access token and use that API result as the authoritative customer identity. Do not rely solely on unverified decoded ID-token claims.
7. Implement Shopify logout/end-session where supported, then delete local refresh tokens and detach local account state.
8. Preserve merge-on-login for guest bag/wishlist. Add explicit behavior for switching between two customer accounts on one device.
9. Distinguish user cancellation, offline failure, invalid configuration, expired/revoked session, and server errors in UI and telemetry.
10. Remove or feature-disable production construction of `SystemAccountSessionRepository` and its password UI.

Acceptance:

- Login/create-account completes through Shopify hosted UI on physical iOS and Android devices.
- App restart silently restores a valid session via refresh token.
- Revoked/expired tokens return the user to a safe signed-out state without losing the guest bag.
- Logout invalidates Shopify/local session state.
- No password is entered into or stored by Monetta.

### Phase 5 — profile, saved addresses, orders, fulfillment, and refunds

Create a dedicated Customer Account GraphQL layer parallel to `data/shopify`:

```text
lib/data/customer_account/
  customer_account_config.dart
  discovery_client.dart
  customer_account_client.dart
  queries.dart
  mappers.dart
```

Tasks:

1. Implement authenticated, paginated Customer Account API queries for profile, saved addresses, orders, order lines, financial/fulfillment status, fulfillments, refunds, and tracking URLs actually rendered by the UI.
2. Implement profile/address mutations only where the UX exists: address create/update/delete/default and customer name update.
3. Request the minimum `customer_read_*`/`customer_write_*` scopes and protected customer fields needed.
4. Cache non-secret summaries in Drift, namespaced by Shopify customer ID. Clear or detach them on logout/redaction.
5. Replace `OrderHistoryRepository`'s unauthenticated `/customers/:id/orders` source with Customer Account API as the primary source.
6. Shopify orders manually created for an apartado must be attached to the correct Shopify customer by the owner; then they appear through the same secure order query. Never reveal an order by matching only caller-supplied email/phone/customer ID.
7. If backend-only apartado enrichment remains, require a valid Customer Account bearer token, resolve the customer server-side, and return only records owned by that resolved customer.
8. Provide order detail, fulfillment/tracking, refund, and cancellation-status UI without claiming unsupported cancellation actions.

Acceptance:

- A customer can see only their own profile, addresses, and orders.
- Pagination and token refresh work together without duplicate requests.
- A newly placed order appears after refresh, including fulfillment/refund changes.
- Cross-account cache isolation tests pass.
- An arbitrary customer ID cannot retrieve another shopper's data.

### Phase 6 — backend hardening, webhooks, compliance, and push

Files likely affected:

- `services/accounts_orders/src/api/server.ts`
- `services/accounts_orders/src/config.ts`
- webhook handlers, repository ports, migrations, tests, and README
- `shopify/shopify.app.*.toml`

Tasks:

1. Remove or disable unauthenticated customer-ID order reads.
2. Authenticate every customer-facing backend route with a Customer Account bearer token and resolve identity through Shopify. Do not trust `customerId` in request bodies.
3. Authenticate push-token registration; bind a token to the resolved customer and current device. Add token delete/logout handling.
4. Decide the custom password-account migration using the Phase 0 owner answer. **Owner answer (2026-08-16): real Monetta password accounts exist.** Therefore: keep `/accounts/*` and password tables; do not drop data; ship an explicit migration + communication plan before any removal. New production UI should prefer Shopify Customer Accounts while the password path remains available until migration completes. Do not destructively drop tables without a reviewed backup/migration.
5. Add edge rate limits, body limits, security headers, request IDs, strict method/content-type checks, and PII/token redaction in logs.
6. Add `/readyz` with a database check; retain `/livez` for process liveness.
7. Keep raw-body HMAC verification and webhook idempotency. Reject missing/invalid HMAC before JSON parsing.
8. Add `app/uninstalled` handling and make all handlers shop-aware even if launch is single-store.
9. Turn `customers/data_request` from a log-only warning into a durable compliance job with status, audit trail, owner alert, export procedure, and completion tracking. Test customer/shop redaction end to end.
10. Add encrypted managed Postgres, automated backups, migration-before-start, secret rotation procedure, retention policy, and restore test.
11. Subscribe/deploy with Shopify CLI only after staging endpoint tests pass.

Staging CLI verification:

```bash
cd shopify
shopify app config validate --config staging
shopify app deploy --config staging --no-release
shopify app webhook trigger --api-version=2026-07 --address=https://STAGING_HOST/webhooks/orders/create --topic=orders/create
```

Review the unreleased version before releasing it. Repeat with the compliance endpoints and invalid-HMAC tests. Do not use sample webhook delivery alone as proof of a real order payload contract; also create a staging order.

Acceptance:

- Customer-facing endpoints return 401 without a valid bearer token.
- Webhooks return 401 for invalid HMAC, 200 for valid delivery, and 200 without duplicate effects on retry.
- Data request and redact topics have tested, auditable outcomes.
- Database restore drill succeeds.
- No secrets or raw PII appear in logs.

### Phase 7 — release engineering and production rollout

Tasks:

1. Add staging/production Flutter flavors with distinct public config, callback schemes, Firebase projects, app IDs, and backend URLs.
2. Add CI gates:

   ```bash
   flutter analyze
   flutter test
   cd services/accounts_orders && npm ci && npm run typecheck && npm test && npm run build
   cd ../../shopify && shopify app config validate --config production
   ```

3. Add integration tests for cold cache, offline cache, full catalog, login, token refresh, cart reconciliation, guest checkout, authenticated checkout, account data, and logout.
4. Configure crash reporting and privacy-safe analytics for sync outcome, image failure, login outcome, cart mutation errors, checkout open/completion, and webhook lag.
5. Add alerts for backend errors, database saturation, webhook failures/retries, compliance jobs, and catalog full-sync failure.
6. Complete App Store/Play Store signing, privacy disclosures, account-deletion instructions, universal/app links if used, and production Firebase configuration.
7. Run a production canary build with owner/staff devices only.
8. Deploy the production Shopify app config as an unreleased version, review its diff, release it, and verify subscriptions in the Dev Dashboard.
9. Place one inexpensive real order on iOS and Android, confirm order, attribution, email, tax, shipping, inventory decrement, account history, and webhook delivery, then cancel/refund it.
10. Roll out gradually and monitor. Keep the last known good mobile build, Shopify app version, and backend image available for rollback.

## 7. Required tests by layer

### Flutter unit/widget

- Storefront transport HTTP/GraphQL/throttle/error classification.
- Full-sync atomic replacement and no deletion on partial failure.
- Numeric asset ID → GID migration, including bag/wishlist.
- Cart mutation `userErrors`, price/stock reconciliation, full cart-ID persistence.
- OAuth cancellation, refresh rotation, revoked token, logout, and account switching.
- Customer API pagination, cross-account cache isolation, and address mutation validation.
- Checkout launcher allowlist and browser fallback.

### Backend

- Raw-body HMAC, malformed payload, missing webhook ID, duplicate delivery.
- Bearer-token verification and customer ownership for every customer route.
- Push token create/rotate/delete authorization.
- Compliance export/redact state machine and idempotency.
- Migration against empty and existing databases.
- No secret/PII logging tests where practical.

### Real Shopify staging

- 251+ product pagination or an equivalent seeded connection fixture plus at least a two-page live test.
- Product create/update/unpublish and media replacement.
- Guest and logged-in checkout.
- Customer profile/address CRUD.
- Order, fulfillment, refund, and webhook refresh.
- App uninstall/redaction behavior on a disposable development store only.

## 8. Production definition of done

Production is ready only when all statements are true:

- The app's unique product count matches the published Headless catalog and no numeric/GID duplicates exist.
- Every product card either renders current Shopify media or the intentional fallback; dead snapshot URLs are no longer the primary source.
- Guest and Shopify-authenticated checkout both complete through Shopify.
- Login, restart restoration, refresh, logout, profile, addresses, and order history pass on physical iOS and Android devices.
- No first-party password form is visible in the production build unless an explicitly approved migration requires it.
- Customer/order endpoints cannot be queried with arbitrary IDs.
- Webhook and compliance tests pass against the deployed production endpoint before release traffic.
- Payments, Markets, shipping, taxes, policies, inventory, notifications, and test orders have owner sign-off.
- CI is green; release signing and privacy disclosures are complete.
- Monitoring, backups, secret rotation, and rollback procedures have been exercised.

## 9. Agent stop points

The implementation agent should work autonomously except at these gates:

1. Owner must complete Shopify CLI browser authentication and choose the organization/store/app.
2. Owner must create/approve Headless and Customer Account credentials and protected customer data permissions.
3. Owner must answer whether real Monetta password-account users exist before account removal/migration.
4. Owner must authorize the hosting/database target and enter backend secrets there.
5. Owner must approve any operation that changes production products, payment/test mode, app installation/scopes, or webhook deployment.
6. Owner must approve and perform/observe the final real order and refund.

At every stop point, the agent should provide the exact screen/command, the value needed, where it will be stored, and a verification command. It must never request the owner's password, 2FA code, private token, or client secret in chat.

## 10. Handoff requirements from the implementation agent

Each phase should end with:

- changed-file summary;
- commands run and pass/fail output;
- remaining owner action, if any;
- evidence from staging, with secrets and customer PII redacted;
- rollback instructions;
- updated documentation when code and this plan diverge.

The agent must not claim production readiness based only on unit tests or a successful Shopify CLI deploy. The definition of done requires a real staging journey and owner-approved production canary order.

## 11. Official Shopify references

- [Getting started with the Storefront API](https://shopify.dev/docs/storefronts/headless/building-with-the-storefront-api/getting-started)
- [Storefront API authentication and capabilities](https://shopify.dev/docs/storefronts/headless/building-with-the-storefront-api/index)
- [Getting started with the Customer Account API](https://shopify.dev/docs/storefronts/headless/building-with-the-customer-account-api/getting-started)
- [Customer Account API discovery and authentication reference](https://shopify.dev/docs/api/customer/latest)
- [Create and update a Storefront cart](https://shopify.dev/docs/storefronts/headless/building-with-the-storefront-api/cart/manage)
- [Manage Shopify CLI app configuration files](https://shopify.dev/docs/apps/build/cli-for-apps/manage-app-config-files)
- [Manage webhook subscriptions](https://shopify.dev/docs/apps/build/webhooks/subscribe)
- [Privacy-law compliance webhooks](https://shopify.dev/docs/apps/build/compliance/privacy-law-compliance)
