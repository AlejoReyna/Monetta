# Admin Control Plane Implementation Plan

Status: implementation-ready
Last reviewed: 2026-08-30
Primary reader: an AI coding agent working in this repository

## 1. Objective

Complete the existing native owner-admin experience so an authorized Monetta owner can safely:

- inspect Shopify and external-catalog health;
- choose and order a small “Today’s Picks” catalog that appears automatically on the app home screen;
- edit Shopify product titles and individual variant prices;
- publish or unpublish products from the Monetta storefront;
- edit the announcement and home-section visibility used by every shopper;
- inspect external-source health and, later, edit supported source policies;
- request bounded synchronization jobs; and
- review an audit trail.

The Flutter UI already exists. This plan connects it to a trusted backend, Shopify, the signed-in account/profile, and `catalog_monitor` without placing privileged credentials in the app.

## 2. Existing context

Read these before implementation:

- `docs/ADMIN_CONTROL_PANEL.md`: existing UI and preliminary HTTP contract.
- `docs/SHOPIFY_CUTOVER_RUNBOOK.md`: Shopify environment and cutover procedure.
- `docs/CATALOG_DASHBOARD.md`: separate crawler-operations dashboard; do not merge it into the native admin.
- `docs/OPERATIONS.md`: deployment and operational notes.

Relevant code:

- UI/state/client/models: `lib/features/admin/admin_screen.dart`, `lib/app/admin_controller.dart`, `lib/data/admin/admin_client.dart`, `lib/domain/admin_control.dart`
- Account integration: `lib/app/account_controller.dart`, `lib/features/account/account_screen.dart`, `lib/main.dart`
- Trusted backend and existing owner authorization: `services/accounts_orders`, especially `src/engagement/api/routes.ts`
- Existing Shopify Admin client pattern: `server/catalog/shopifyAdmin.ts`
- External catalog: `services/catalog_monitor`
- Shopify configuration: `shopify/shopify.app.staging.toml` and `shopify/shopify.app.production.toml`

Search for a referenced class/route before creating a replacement if paths move.

### Already implemented

- `AdminScreen` sections for Overview, Products, Storefront, Sources, and Notifications.
- `AdminController`, DTOs, and `HttpAdminClient` calls to `/admin/*`.
- Account/Profile admin entry point.
- First-party Monetta sessions and Shopify Customer Account authentication.
- Owner authorization for notification-admin routes in `services/accounts_orders`.
- Storefront reads, Customer Account OAuth/PKCE, webhooks, and a server-side Shopify Admin read client elsewhere in the repo.
- An existing `admin_audit_events` table.

### Gaps

- The main control-plane routes are not implemented.
- Live access partly relies on a build-time email allowlist and requires a Shopify auth provider. Client checks are not authorization.
- `accessTokenForAdmin()` excludes first-party sessions although the backend supports them.
- The product DTO exposes one price even though Shopify products can have multiple variants.
- Storefront settings held in `AdminController` do not reliably reach other shoppers.
- There is no trusted service-to-service path from the native admin to `catalog_monitor`.
- Current Shopify scopes do not permit these writes.

### Verified staging context (read-only inspection, 2026-08-30)

- The accessible development store is `monetta-staging`.
- It has 17 products and an installed Headless sales channel.
- The Shopify product table currently reports zero Shopify Markets/B2B Catalog assignments; those Catalogs are unrelated to Today's Picks.
- At least the inspected sample product has an empty Shopify Description field. The admin picker therefore needs a visible missing-description warning, and acceptance tests must cover empty descriptions.
- No collection, scope, product, description, or account setting was changed during this inspection. Re-discover identifiers during WP-0/WP-9 rather than treating browser observations as configuration.

## 3. Target architecture

```text
Account/Profile -> Flutter AdminScreen
                       |
              Monetta session OR
              Shopify Customer token
                       v
              services/accounts_orders
              /admin/* control plane
                 |       |        |
                 |       |        +--> Postgres: principals/idempotency/audit
                 |       +-----------> catalog_monitor (service auth)
                 +-------------------> Shopify Admin GraphQL
                                           |
                               Shopify commerce truth
                                           |
                              Storefront API/webhooks
                                           v
                                  Normal shopper app
```

Rules:

1. Flutter calls only `services/accounts_orders` for privileged operations.
2. Shopify Admin and catalog-service credentials stay in backend secrets, never Dart defines, assets, logs, or responses.
3. Shopify is authoritative for products, variants, publication state, and shared storefront configuration.
4. `catalog_monitor` is authoritative for crawler state and external-source policy.
5. Postgres stores principals, idempotency, and audit—not a competing product catalog.
6. Every backend route independently authenticates, authorizes, validates, rate-limits, and audits.
7. The web crawler dashboard remains an operations tool; the native page is the commerce/content control plane.

## 4. Fixed implementation decisions

- Keep the admin entry inside signed-in Account/Profile; do not add global navigation.
- Add the API to `services/accounts_orders`; do not create a new backend or call Shopify Admin from Flutter.
- Accept either first-party or Shopify Customer authentication and resolve it to a stable server actor.
- Never authorize from an email/role sent by the client.
- Edit prices per variant. Never copy one entered price to all variants implicitly.
- “Visible” means published to the server-configured Monetta Headless publication. It does not mean deletion.
- Inventory is read-only in release one. Do not request `write_inventory` without a separate design for location and concurrency semantics.
- Store shared homepage configuration in one app-owned Shopify metaobject and load it through the normal shopper content repository.
- Model the daily featured catalog as one manual Shopify collection with handle `monetta-todays-picks`, manual sorting, and publication to the Monetta Headless channel. Do not use Shopify Markets/B2B “Catalogs” for this merchandising feature.
- Shopify product content remains canonical. The daily selection stores only product references/order; it never copies titles, descriptions, images, prices, or inventory.
- Do not auto-create Shopify products from external items, order from suppliers, bypass CAPTCHA, or force blocked crawls. Existing `ownerProcurement` behavior remains.

## 5. Identity/profile connection

### Capability API

Implement:

```http
GET /admin/me
Authorization: Bearer <monetta-session-or-shopify-customer-token>
```

Example response:

```json
{
  "actor": {"id": "opaque-actor-id", "provider": "monetta"},
  "roles": ["owner"],
  "capabilities": {
    "openAdmin": true,
    "manageFeaturedCatalog": true,
    "manageProducts": true,
    "manageStorefront": true,
    "manageExternalSources": false,
    "manageNotifications": true
  },
  "environment": "staging"
}
```

Return `200` with capabilities false for an authenticated non-admin. Return `401` for an absent/invalid/expired/revoked token. The server calculates capabilities; there is no client-writable `isAdmin` profile field.

### Principals

Add an `admin_principals` migration in `services/accounts_orders/src/db/migrations` with:

- `id`
- `subject_type`: `app_account` or `shopify_customer`
- stable `subject_id`
- `role` (initially `owner`)
- `active`
- `created_at`, `created_by`, nullable `revoked_at`
- uniqueness on `(subject_type, subject_id, role)`

Bootstrap the first owner with existing `OWNER_ADMIN_EMAILS` and/or `OWNER_SHOPIFY_CUSTOMER_IDS`, then authorize the stable subject. Never link identities solely because emails match. A later verified linking flow may use `app_accounts.shopify_customer_id`; entitlements remain attached to principals.

### Flutter changes

1. Make `AccountController.accessTokenForAdmin()` use the supported token path in `accessTokenForBackend()`.
2. Load `/admin/me` during session restoration and after login/logout.
3. Gate the Account/Profile card and `AdminController.canAccess` on the returned capability.
4. Remove the live requirement that `authProvider == 'shopify'`.
5. Keep `OWNER_ADMIN_EMAILS`/`ENABLE_OWNER_ADMIN_PREVIEW` as development preview only; they cannot grant backend access.
6. Clear capabilities and admin state on logout; fail closed if refresh fails.

## 6. Backend contract

### Common mutation behavior

Every mutation requires:

- `Idempotency-Key`;
- an idempotency record scoped to actor and operation;
- input validation before external calls;
- an audit event containing actor, action, target, request ID, outcome, and bounded before/after fields;
- a server-generated `requestId` returned to Flutter;
- mutation-specific rate limits; and
- a canonical updated resource in the response.

Error shape:

```json
{
  "error": {
    "code": "STALE_RESOURCE",
    "message": "The product changed after it was loaded.",
    "fields": {},
    "requestId": "req_..."
  }
}
```

Use `401` invalid auth, `403` missing capability, `409` stale/idempotency conflict, `422` validation/user error, `429` rate limit, and `502`/`503` bounded upstream failure. Never return raw Shopify errors.

### Read API

```http
GET /admin/me
GET /admin/control-plane
GET /admin/audit?cursor=<opaque>&limit=50
```

The control-plane response contains integration health, bounded/paginated products and variants, storefront config/version, permitted source status/policy, recent audit events, and fetch timestamps. Each section has `ready`, `degraded`, or `unavailable` status so one failed upstream does not blank the page.

### Product API

```http
PATCH /admin/products/:productGid
PATCH /admin/products/:productGid/variants/:variantGid
PUT   /admin/products/:productGid/publication
```

Bodies:

```json
{"title":"Updated title","expectedUpdatedAt":"2026-08-30T12:00:00Z"}
```

```json
{"price":"1299.00","expectedProductUpdatedAt":"2026-08-30T12:00:00Z"}
```

```json
{"published":true,"expectedUpdatedAt":"2026-08-30T12:00:00Z"}
```

Rules:

- Parse Shopify global IDs and use GraphQL variables; never concatenate untrusted input into queries.
- Use decimal strings for money and validate currency rules.
- Re-read and reject stale timestamps before mutation.
- The server owns the publication ID; Flutter sends only desired visibility.
- Surface a validation error if a product cannot be published; do not silently alter unrelated state.
- Return the updated projection.

### Daily featured catalog API

```http
GET /admin/featured-catalog
PUT /admin/featured-catalog
PUT /admin/featured-catalog/products/:productGid
```

The read endpoint returns:

- all eligible products for the picker, with Shopify title, image, description excerpt, price range, inventory summary, publication eligibility, and variants;
- the selected product IDs in manual display order;
- collection `updatedAt`, last successful publish time, and section health; and
- a limit, initially 4–12 selected products.

The write body is deliberately references-only:

```json
{
  "productIds": [
    "gid://shopify/Product/8593798299682",
    "gid://shopify/Product/8593798266914"
  ],
  "expectedCollectionUpdatedAt": "2026-08-30T12:00:00Z"
}
```

The row-level one-click body is:

```json
{
  "featured": true,
  "expectedCollectionUpdatedAt": "2026-08-30T12:00:00Z"
}
```

`featured: true` backs the `Mostrar hoy` button and appends the product to the manual collection order. `featured: false` backs `Quitar de hoy`. `PUT /admin/featured-catalog` remains the full ordered-list endpoint used by drag/reorder and reconciliation; adding/removing a single product must not require a second global Save action.

Implementation rules:

1. The collection is provisioned once with title `Today’s Picks`, handle `monetta-todays-picks`, `MANUAL` sorting, and publication to the Monetta Headless publication.
2. Only active products already published to the Monetta Headless publication are eligible in release one. Selection must not silently publish a product.
3. Read current membership, reject stale `expectedCollectionUpdatedAt`, compute an add/remove/reorder diff, and use Shopify collection mutations. Since Shopify performs reorder asynchronously, return `202` with a job ID while ordering is pending and expose job status; return canonical membership only after reconciliation.
4. Idempotency and audit apply to the complete requested ordered list. If a multi-step Shopify operation partially fails, report `degraded`, reconcile actual membership, and never claim the requested list is live until verified.
5. Saving updates the current live selection immediately and leaves it active until the owner replaces it. Do not clear the section automatically at midnight; an empty homepage caused by a missed daily update is worse than carrying yesterday’s valid selection.
6. Record the local merchandising date using `America/Monterrey` in audit metadata. Scheduling future dates is a separate phase with a durable schedule/worker; do not imply future scheduling in the first UI.

### Exact admin location and interaction

Use the existing route and section picker. The owner navigates:

```text
Mi cuenta → Panel administrativo → Productos → Catálogo de hoy
```

`Catálogo de hoy` is the first/default subsection inside the existing `Productos` section in `lib/features/admin/admin_screen.dart`; `Editar productos` is the secondary/advanced subsection. Do not bury daily merchandising in `Tienda`, `Fuentes`, or Shopify's separate admin UI.

The screen contains:

- a search field and filters (`Todos`, `Con stock`, `Mostrándose hoy`, `Sin descripción`);
- a Shopify-backed row/card for every eligible product with image, title, price, stock, and description excerpt/status;
- one primary per-row toggle: `Mostrar hoy` when absent, a spinner while pending, and `Mostrándose hoy`/`Quitar de hoy` after canonical confirmation;
- a selected-products tray at the top with count and drag order; and
- a shopper-style preview of the home section.

Button semantics:

1. Tapping `Mostrar hoy` immediately calls the row-level endpoint with a fresh idempotency key. It is not an optimistic success.
2. The backend adds the product to the configured Shopify collection, re-reads canonical membership, and returns it.
3. Only then does the button become `Mostrándose hoy`; on failure it returns to `Mostrar hoy` and displays the request ID.
4. The owner device immediately refreshes `FeaturedCatalogController`, so navigating back to Home shows the product without an app release or second action.
5. `Quitar de hoy` follows the same confirmed path. Dragging changes order through the full-list endpoint and may show an `Ordenando…` job state.

The shopper app queries `collection(handle: "monetta-todays-picks")` using the existing full `ProductFields` fragment. It must use the collection's manual order and upsert returned products into the local cache before rendering. Refresh on initial app load, entering Home, returning from background, explicit pull-to-refresh, and immediately after an owner mutation on the same device. While Home remains visible, use a bounded 60-second freshness check so an already-open shopper receives a change within approximately one minute; stop it when Home is not visible and coalesce overlapping requests. If later product requirements demand sub-second propagation, add a lightweight real-time invalidation signal whose payload is only collection ID/version—Shopify remains the data source.

If the collection is missing, unavailable, or empty, hide this section or fall back to the current newest-products section according to an explicit product decision; never show stale IDs as current picks.

### Product description synchronization

No separate description-sync job or admin description field is required. The existing code already requests Shopify `Product.descriptionHtml` in `lib/data/shopify/queries.dart`, maps it in `lib/data/shopify/mappers.dart`, and renders it in `lib/features/product/product_screen.dart`.

For the daily featured section:

- reuse `kProductFragment` in the collection query so title, `descriptionHtml`, images, variants, prices, and availability come from the same Shopify response;
- never persist a copied description in the featured-catalog record or collection metadata;
- render the Shopify description on product detail; a card may use a safely stripped/truncated excerpt if product design calls for it;
- change the current `factualDescription` behavior so generated text is never presented as the Shopify product description. When Shopify is empty, omit the description block or show a clearly generic UI empty state, and flag the product as `Sin descripción en Shopify` in the admin picker; and
- after Shopify product webhooks or delta sync, invalidate/upsert that product so edits made directly in Shopify appear on the next normal app refresh.

The current product screen strips HTML before display, so its text is sourced correctly but rich formatting does not visually match Shopify. Release one may compare/render normalized plain text. If exact rich formatting is required, use a reviewed allowlist-based HTML renderer and sanitize links/elements; never inject raw `descriptionHtml` into a WebView. An Admin API response and a Storefront API response can differ briefly because of propagation/caching. The UI may show “Updating” during reconciliation, but must not overwrite Shopify text with fallback content.

### Storefront settings API

```http
PUT /admin/storefront-config
```

```json
{
  "announcement": "Free delivery this weekend",
  "showHero": true,
  "showNewest": true,
  "showTodaysPicks": true,
  "showExternalPicks": false,
  "expectedVersion": 4
}
```

Store an integer `version` in the metaobject. Read current state, reject a stale version, increment, and upsert the complete field set. Shopify `metaobjectUpsert` values mode is full replacement; never accidentally omit existing fields.

### External source API

```http
GET /admin/external-policy/:sourceId
PUT /admin/external-policy/:sourceId
```

Release one is read-only unless `catalog_monitor` has durable policy storage and a service-authenticated write endpoint. The accounts service acts as a BFF: authorize owner, validate bounded policy, sign a short-lived service request, correlate request IDs, and write the owner audit event. Use HMAC or an equivalent rotated credential with timestamp/replay protection. Never send it to Flutter.

### Sync API

```http
POST /admin/sync
```

```json
{"channel":"shopify-products"}
```

Allow only explicit enums such as `shopify-products`, `shopify-orders`, `storefront-content`, and `external-status`. This reconciles existing state; it cannot force crawling. Queue/bound long jobs and return a job ID rather than holding an HTTP request indefinitely.

## 7. Shopify connection

### Admin authentication

Add a Shopify Admin GraphQL client inside `services/accounts_orders`. Borrow the token/cache/error behavior in `server/catalog/shopifyAdmin.ts` without importing across deployment packages unless a real shared package is introduced.

Use client credentials only when the Shopify app/store belong to the same organization and the app is installed. Cache the 24-hour token server-side and refresh before expiry. Retry token acquisition once after auth failure; do not blindly retry mutations. Pin one supported Admin API version in config and tests.

### Scopes

Add only:

- `write_products` for titles and variant prices (and corresponding reads);
- `write_publications` for publish/unpublish;
- `write_metaobjects` for storefront configuration;
- existing required order/customer read scopes; and
- read-only inventory access only if the selected read query requires it.

Do not add `write_inventory`, `write_orders`, or `write_customers`. Update staging and production TOMLs, but deploy and approve staging scopes first; editing TOML alone does not grant them.

### GraphQL mapping

- Title/product projection: `productUpdate`
- Specific price: `productVariantsBulkUpdate`
- Visibility: `publishablePublish` / `publishableUnpublish`
- Storefront config: `metaobjectUpsert`
- Daily selection membership: `collectionAddProducts` / `collectionRemoveProducts`
- Daily selection order: `collectionReorderProducts`, followed by job polling and a canonical collection read

Provision the manual collection once through an audited operator step (Shopify Admin UI or `collectionCreate`) and publish it to Headless. The runtime endpoint should fail with `FEATURED_COLLECTION_NOT_CONFIGURED` rather than silently creating/replacing a collection in response to an ordinary owner save.

Inspect top-level errors and mutation `userErrors`, handle cost/throttle metadata deliberately, and expose degraded health without leaking upstream payloads.

### Shared storefront metaobject

Declare an app-owned metaobject in both Shopify app TOMLs:

- type `$app:storefront_config`
- singleton handle `monetta`
- announcement text, four visibility booleans (including Today's Picks), and integer version
- merchant Admin read/write access and public Storefront read access

Grant the Storefront permission to read metaobjects. Update `lib/data/shopify/queries.dart` and the normal home-content repository to query the singleton during ordinary refresh. Missing/malformed configuration maps to safe defaults.

After save, update admin state from the canonical response and refresh the normal home repository on that device. Other shoppers see it on their next normal refresh/cache expiry. Shopper behavior must not depend on the owner opening `AdminScreen`.

### Webhooks

Keep existing product/order and mandatory compliance webhooks. Verify HMAC and process idempotently. Direct mutation results are the immediate response; webhooks reconcile later. Do not include protected customer data in DTOs or audit records.

## 8. Flutter product/UI model

Replace the single-price record with:

```text
AdminProductRecord
  id, title, imageUrl, status, publishedToMonetta, updatedAt
  variants[]

AdminProductVariant
  id, title, priceAmount, currencyCode, inventorySummary (read-only)
```

Requirements:

- Simplified editor for one variant; explicit selection for multiple variants.
- Disable controls when capability is false or the section is unavailable.
- Pending state per resource rather than a global blocker.
- On `409`, preserve draft, reload canonical data, and ask the owner to review.
- On upstream failure, keep canonical state and show the request ID.
- Do not optimistically claim mutation success.
- Add `Catálogo de hoy` as the first/default subsection under the existing `Productos` section, with a searchable eligible-product list, per-row `Mostrar hoy`/`Quitar de hoy` action, selection count, selected-product tray, drag/reorder controls, Shopify description excerpt, and live preview. Adding/removing is one click; only drag-order changes use the full ordered-list save.
- Put this subsection ahead of low-level price/title controls: daily merchandising is the primary routine workflow, while product editing is an advanced action.
- Add a shopper home section that observes the configured section order and renders the collection's manual product order. Keep the current newest-products section as a distinct section/fallback rather than changing the meaning of “newest.”

## 9. Persistence, observability, and configuration

Add idempotency storage with key, actor/operation, body hash, bounded response, timestamps/expiry, and uniqueness preventing cross-operation collisions.

Extend the existing audit path rather than creating a disconnected logger. Include request ID/environment, actor/role, action/target, success/rejected/failed outcome, redacted before/after fields, and error code. Never record tokens, secrets, full upstream payloads, or unnecessary PII.

Add structured metrics for requests, auth rejection, latency, Shopify error class/throttling, catalog errors, and idempotency replay. Provide global mutation, Shopify-write, and external-write kill switches.

Suggested backend variables:

```text
SHOPIFY_STORE_DOMAIN
SHOPIFY_APP_CLIENT_ID
SHOPIFY_APP_CLIENT_SECRET
SHOPIFY_ADMIN_API_VERSION
SHOPIFY_HEADLESS_PUBLICATION_ID
SHOPIFY_FEATURED_COLLECTION_ID
SHOPIFY_FEATURED_COLLECTION_HANDLE
CATALOG_MONITOR_BASE_URL
CATALOG_MONITOR_SERVICE_SECRET
ADMIN_MUTATIONS_ENABLED
ADMIN_SHOPIFY_WRITES_ENABLED
ADMIN_EXTERNAL_WRITES_ENABLED
```

Reuse existing owner bootstrap variables. Validate enabled integrations at startup. None of these secrets belongs in Flutter configuration.

## 10. Ordered work packages

Complete in order, using one focused/reviewable change set per package where possible.

### WP-0 — Baseline and contract lock

1. Run existing Flutter/service tests and record pre-existing failures.
2. Confirm staging app/store organization, non-secret store domain, app ID, publication, and chosen API version.
3. Confirm migration sequence and route composition.
4. Point `docs/ADMIN_CONTROL_PANEL.md` to this contract.

Acceptance: no production configuration changed; baseline recorded.

### WP-1 — Server owner capability

1. Add principal migration/repository.
2. Refactor notification owner authorization into shared admin middleware.
3. Support both authentication providers.
4. Implement `/admin/me` and tests for missing/invalid/non-owner/revoked/owner cases.

Acceptance: both provisioned providers work; forged client email/role never grants access.

### WP-2 — Shopify client and read projection

1. Add token handling and typed Admin GraphQL transport.
2. Query products, variants, publication state, and integration health.
3. Implement bounded pagination in `/admin/control-plane`.
4. Test errors, `userErrors`, token refresh, throttling, and partial failure.

Acceptance: no secret reaches app/logs; variants are not collapsed; Shopify outage affects only its sections.

### WP-3 — Product mutations

1. Add idempotency and shared mutation wrapper.
2. Implement title, variant price, publish, and unpublish endpoints.
3. Add stale checks, rate limits, audit, and switches.
4. Test replay/conflict/multi-variant targeting/upstream failures.

Acceptance: replay does not duplicate, stale writes return `409`, only the chosen variant changes, every attempt has an audit outcome.

### WP-4 — Daily featured catalog

1. Provision a manual `Today’s Picks` staging collection, publish it to Headless, and configure its ID/handle.
2. Implement featured-catalog read, one-click add/remove, full-list reorder/reconciliation, and reorder-job endpoints with stale checks, idempotency, and audit.
3. Add a Storefront repository/controller that fetches the collection with the full product fragment and upserts returned products.
4. Add `HomeSectionId.todaysPicks`, safe empty/error behavior, and the admin picker/reorder/preview UI.
5. Verify direct Shopify description edits, membership changes, order changes, and webhook/delta reconciliation.

Expected Flutter touch points include `lib/data/shopify/queries.dart`, `lib/data/shopify/mappers.dart`, a focused featured-catalog repository/controller, `lib/domain/home_content.dart`, `lib/features/home/home_screen.dart`, the admin DTO/client/controller, and `lib/features/admin/admin_screen.dart`. Do not overload `HomeContentRepository` with mutable admin operations; it remains a shopper read path.

Acceptance: one `Mostrar hoy` tap changes to confirmed `Mostrándose hoy` and makes the product appear on the owner's Home immediately and on a separate already-open signed-out Home within the bounded refresh interval; non-empty title/description, images, price, and stock come from current Shopify fields, while an empty description remains an explicit empty state.

### WP-5 — Shared storefront configuration

1. Declare the staging metaobject.
2. Implement backend read/upsert/version checks.
3. Implement `/admin/storefront-config`.
4. Update normal Storefront queries/repository and remove admin state as shopper truth.

Acceptance: a signed-out staging session sees an owner change after refresh; stale version fails; absent data defaults safely.

### WP-6 — Flutter account/admin wiring

1. Load capability during auth restoration/transitions.
2. Permit first-party backend tokens.
3. Update variant/storefront DTOs/controllers.
4. Connect UI to live endpoints and handle conflicts/errors.
5. Keep fallback explicitly development-only.

Acceptance: non-owner lacks a functional entry point and still gets backend `403` if bypassing UI; logout clears access/state; failed mutations never show success.

### WP-7 — External catalog adapter

1. Aggregate read-only source health.
2. Define bounded, durable policy ownership in `catalog_monitor`.
3. Add service-authenticated internal endpoints with replay protection.
4. Enable policy writes only after contract/integration tests.

Acceptance: no credential in Flutter; policies persist and affect only supported future scheduling; no forced crawling/CAPTCHA bypass.

### WP-8 — Sync, audit UI, resilience

1. Add enum-scoped jobs/status polling.
2. Connect audit pagination.
3. Add timeouts/degraded states/metrics.
4. Verify webhook reconciliation.

Acceptance: long work returns job status; integrations fail independently; request IDs correlate across services.

### WP-9 — Staging rollout

1. Deploy/reapprove Shopify staging scopes, featured collection, and metaobject.
2. Deploy migrations and backend with writes off.
3. Deploy staging clients and provision owner by stable ID.
4. Enable storefront settings, featured catalog, product, publication, then external writes one class at a time.
5. Run and record the verification matrix.

Acceptance: real owner/non-owner cases pass; kill switches are tested; owner approves staging.

#### Staging provisioning record (2026-08-31)

- Shopify app release `monetta-staging-4` declares the app-owned
  `$app:storefront_config` schema, with merchant read/write and public
  Storefront read access. Its singleton is `monetta` and is initialized with
  safe defaults: all native sections enabled except external picks.
- The staging collection is `Today's Picks` (`monetta-todays-picks`), manual
  sort, and published only to `Monetta Staging Headless`. Configure the
  deployment with the discovered GIDs; do not recreate this collection from an
  owner request.
- The staging API runs at `https://monetta-accounts-staging.fly.dev` against a
  separate Neon Free project. All three mutation switches remain `false` until
  a real, stable owner principal is provisioned and the read-only verification
  pass is recorded.
- Shopify webhooks use the app client secret for their HMAC secret. Store that
  value only as the server's `SHOPIFY_WEBHOOK_SECRET`; do not expose it to
  Flutter or browser clients.
- Before testing owner flows, create/sign in to the intended first-party
  staging account, then insert only its stable UUID into `admin_principals`
  with `subject_type = 'app_account'`, `role = 'owner'`, and an auditable
  `created_by` value. Never bootstrap ownership from an email address.

### WP-10 — Production rollout

1. Repeat scope review/config deployment.
2. Apply additive migrations/deploy with writes off.
3. Provision principals by stable ID.
4. Enable capabilities/writes progressively while monitoring.
5. Keep rollback versions available.

Acceptance: no production mutation precedes staging evidence and owner approval; switches safely make writes unavailable without affecting shopper reads.

#### Production hosting baseline (cost-capped VPS)

The first production release may run on one managed Ubuntu VPS instead of a
separate managed application platform and database. This is an explicit
cost/availability trade-off for low initial traffic, not a high-availability
architecture.

- Minimum host: 1 vCPU, 2 GB RAM, 25 GB SSD, stable public IPv4, and an
  operator-managed Ubuntu LTS installation. A 1 GB host is not sufficient for
  Node, PostgreSQL, the operating system, and a reverse proxy together.
- Run `accounts_orders` API and worker, PostgreSQL, and Caddy as isolated
  Compose services. Persist PostgreSQL on a named volume; the service process
  must restart automatically after a reboot.
- Terminate TLS at Caddy and expose only HTTPS plus SSH. PostgreSQL stays on
  the internal Compose network and never receives a public port.
- Store service credentials only in a root-owned `0600` production env file or
  an equivalent host secret store. Never copy them to Flutter, git, logs, or
  shell history.
- Take encrypted, off-host daily `pg_dump` backups; retain a bounded history;
  test a restore before enabling Shopify writes. Monitor HTTPS `/livez`, disk,
  memory, and backup success. Keep the previous application image available.
- Create a least-privilege database role and a dedicated `accounts_orders`
  database. Do not reuse the catalog database role or expose cross-service
  superuser credentials.
- The deployment remains single-node: a VPS or provider outage makes the admin
  control plane temporarily unavailable, while shopper Storefront reads remain
  independent. The write kill switches provide the operational fallback.

For staging, use a separate Neon Free project/database with scale-to-zero
enabled. It is suitable for migrations, authorization, and mutation tests but
is not the production database: its free allocation and cold-start behavior
are deliberately not treated as a production availability guarantee. Do not
create Fly Managed Postgres for this rollout; its managed plan is materially
more expensive than the agreed cost-capped VPS path.

## 11. Verification matrix

| Area | Required cases |
| --- | --- |
| Authentication | missing/expired/revoked tokens; invalid Shopify token |
| Authorization | non-owner, inactive principal, both owner providers, forged email/role |
| Products | one/many variants, invalid money, stale resource, `userErrors`, idempotent replay |
| Today's Picks | one-click add/remove, confirmed button states, reorder, 4–12 limit, ineligible product, stale collection, reorder failure, owner immediate refresh, open-shopper bounded refresh, empty state, exact Shopify description text |
| Publication | publish/unpublish, missing publication, already desired state, inactive product |
| Storefront | valid/stale updates, missing/malformed object, signed-out refresh |
| External | healthy/timeout, bad/replayed signature, unsupported source, writes disabled |
| Resilience | Shopify/catalog/database unavailable, rate limit, each kill switch |
| Security | token/audit redaction, no secret in Flutter artifact, no unnecessary customer PII |
| UI | logout/restore, per-row pending, `403`, `409`, partial failure, request ID display |

Run Flutter analyze/relevant tests, accounts service typecheck/tests, catalog tests when changed, mocked Shopify contract tests, and real staging smoke tests. Discover and use actual package scripts; do not invent CI commands.

## 12. Rollback

1. Disable external writes if the catalog adapter fails.
2. Disable Shopify writes if Shopify mutations fail.
3. Disable all mutations to make the control plane read-only.
4. Roll back backend if auth/read paths fail.
5. Roll back client only if it cannot tolerate read-only/degraded responses.

Do not guess a compensating Shopify value. Present the audited previous value and perform a new explicit mutation/idempotency key. Migrations must be backward-compatible for at least one deployment; destructive cleanup is a later release.

## 13. AI-agent execution and stop conditions

The implementing agent must inspect adjacent code/tests, preserve unrelated worktree changes, make the smallest coherent change for the active package, use staging for real writes through WP-9, justify every scope, add tests with behavior, and report changed files/tests/risks/operator actions.

Stop and request operator direction when:

- the app/store cannot use the client credentials grant;
- the store, app, environment, or publication is ambiguous;
- a price request does not identify a variant;
- a needed scope is not listed here;
- implementation would expose a privileged credential to Flutter;
- identity linking would depend only on email;
- external changes would trigger a live crawl, supplier action, or procurement;
- production would change before staging evidence/approval; or
- user-owned changes overlap required edits and cannot be preserved.

## 14. Definition of done

- A provisioned owner sees/administers through either supported profile flow; a non-owner cannot.
- Backend authorization holds even if Flutter navigation is bypassed.
- Title, one explicit variant price, and Monetta publication state can be changed server-side.
- The owner can select/reorder Today's Picks and a separate shopper session receives that exact ordered collection automatically.
- Featured product title, description, media, price, and availability always resolve from Shopify product data, with no copied merchandising snapshot.
- Shared config reaches a signed-out shopper through the normal Storefront path.
- External status is visible and any enabled policy writes are durable/service-authenticated.
- Mutations are idempotent, rate-limited, kill-switchable, and audited.
- Credentials/customer PII are absent from Flutter artifacts, logs, and admin DTOs.
- Partial upstream failure preserves unaffected functionality.
- Staging evidence, production rollout, and rollback verification are documented.

## 15. Official Shopify references

- Access tokens: https://shopify.dev/docs/apps/build/authentication-authorization/access-tokens
- Client credentials: https://shopify.dev/docs/apps/build/authentication-authorization/client-credentials-grant
- Customer Account API: https://shopify.dev/docs/api/customer/latest
- Access scopes: https://shopify.dev/docs/api/usage/access-scopes
- Product update: https://shopify.dev/docs/api/admin-graphql/latest/mutations/productUpdate
- Variant update: https://shopify.dev/docs/api/admin-graphql/latest/mutations/productVariantsBulkUpdate
- Add/remove collection products: https://shopify.dev/docs/api/admin-graphql/latest/mutations/collectionAddProducts and https://shopify.dev/docs/api/admin-graphql/latest/mutations/collectionRemoveProducts
- Reorder collection products: https://shopify.dev/docs/api/admin-graphql/latest/mutations/collectionReorderProducts
- Storefront collection query: https://shopify.dev/docs/api/storefront/latest/queries/collectionByHandle
- Storefront product descriptions: https://shopify.dev/docs/api/storefront/latest/objects/Product
- Publish/unpublish: https://shopify.dev/docs/api/admin-graphql/latest/mutations/publishablePublish and https://shopify.dev/docs/api/admin-graphql/latest/mutations/publishableUnpublish
- Metaobject upsert: https://shopify.dev/docs/api/admin-graphql/latest/mutations/metaobjectUpsert
- App-owned definitions: https://shopify.dev/docs/apps/build/metaobjects/manage-metaobject-definitions
- Storefront metaobjects: https://shopify.dev/docs/api/storefront/latest/objects/Metaobject
- Privacy webhooks: https://shopify.dev/docs/apps/build/compliance/privacy-law-compliance
- Protected customer data: https://shopify.dev/docs/apps/launch/protected-customer-data
