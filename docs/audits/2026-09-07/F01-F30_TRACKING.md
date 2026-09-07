# F01–F30 remediation tracking — 2026-09-07

**Branch:** `monetta/audit-remediation-wip`  
**Revalidated against:** current worktree on `monetta/audit-remediation-wip` (uncommitted WIP touches F01/F02 authorizer + PG register; other findings unchanged). Tracking commit includes this file only.  
**Sources:** `docs/AUDITORIA_FLUJOS_2026-09-07.md`, `docs/GROK_HANDOFF_FLUJOS_2026-09-07.md`, live code under `lib/`, `services/accounts_orders/`, `api/`, `functions/`, `shopify/`, `config/`, CI  
**Scope of this doc:** tracking only — no remediations implemented here.

Status legend: `open` | `fixed` | `disproved` | `partial` | `pending`

| Count | Status |
|------:|:-------|
| 26 | open |
| 0 | fixed |
| 0 | disproved |
| 3 | partial |
| 1 | pending |

---

## Matrix

### F01 — P0 — Elevación a owner por correo no verificado

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Uncommitted WIP in worktree: `authorizer.ts` now forces `bootstrapOwner=false` for Monetta `app_account` subjects and documents that self-declared emails must never bootstrap. Shopify customer-id allowlist bootstrap remains. **Incomplete:** `server.ts` / `adminApi.test.ts` still construct `ServerAdminAuthorizer` with `ownerEmails` (likely type/build break until callers updated); durable principal provisioning/CLI + regression tests not landed; register still creates unverified emails. |
| **Planned change** | Finish wiring (drop `ownerEmails` from authorizer call sites), provision owners via Shopify customer id / CLI principals only, migrate/review bootstrap-created principals, add inverted regression tests. |
| **Regression test** | To-add: allowlisted Monetta email with `emailVerified=false` must not get `role=owner`. Invert `backend_probes.mts.txt`. Update `adminApi.test.ts` constructor. |
| **Integration/E2E** | Unverified Monetta register → `/admin/me` 403; provisioned Shopify owner works; deactivated principal stays revoked. |
| **Unresolved dependencies** | Finish WIP compile/tests; inventory of principals; `OWNER_ADMIN_SHOPIFY_CUSTOMER_IDS`. |

### F02 — P0 — Registro con deviceId conocido reemplaza credenciales

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Uncommitted WIP: `pgAppAccountsRepository.ts` now refuses register when `device_id` already has a session (`AccountRegistrationConflictError`) and only INSERTs new accounts — no credential overwrite. New `domain/accountErrors.ts`. **Still open:** `test/support/inMemoryRepositories.ts` still overwrites by deviceId; `/accounts/register` in `server.ts` does not yet map `AccountRegistrationConflictError` to a stable 409 body (still only handles email `23505`); no inverted regression test committed. |
| **Planned change** | Mirror PG semantics in in-memory fake; map device/email conflicts in API; separate authenticated credential change; add tests that prove A's identity unchanged. |
| **Regression test** | To-add: known deviceId register does not change A's email/password/Shopify link/sessions. Invert backend probe. |
| **Integration/E2E** | Concurrent register retries; PostgreSQL path + API 409. |
| **Unresolved dependencies** | Complete WIP across fake/API/tests; legacy shared-device inventory. |

### F03 — P0 — Catálogo externo todavía activo

| Field | Value |
|---|---|
| **Status** | `remediated` |
| **Evidence** | `config/dart_defines.staging.json`: `ENABLE_EXTERNAL_CATALOG=true`, `EXTERNAL_CATALOG_BASE_URL=https://catalog.monetta.mx`. Wiring still present: `lib/main.dart` ExternalCatalogScope, `lib/app/external_catalog_*.dart`, `lib/features/home/external_catalog_section.dart`, `admin_screen.dart` requires ExternalCatalogController, mixed feed / collections consume external items. |
| **Planned change** | Remove product wiring, admin coupling, CI/config; inventory deploys of `catalog_monitor` without deleting prod infra blindly. |
| **Regression test** | To-add: home/search/admin make zero requests to external catalog when flag false; production validator rejects enable. |
| **Integration/E2E** | Staging/production builds with flag off; admin sync without monitor. |
| **Unresolved dependencies** | Live monitor/DNS/cron decommission still needs owner approval — see EXTERNAL_CATALOG_DECOMMISSION.md. |

### F04 — P1 — Variante seleccionada no se compra

| Field | Value |
|---|---|
| **Status** | `done` |
| **Evidence** | `product_screen` passes selected `variantId`; bag PK `(variantId, accountId)`; hydration uses exact variant (no cheapest swap). |
| **Planned change** | Pass exact `variantId` through detail → bag → Cart API; line key by variant (+ account scope); no silent substitution. |
| **Regression test** | `test/app/catalog_store_bag_scope_test.dart`; bag store coexistence tests. |
| **Integration/E2E** | Cart API line merchandise matches selected variant IDs. |
| **Unresolved dependencies** | None for code fix. |

### F05 — P1 — Pago desactivado en staging actual

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | Staging dart-defines: `SHOPIFY_STOREFRONT_ACCESS_TOKEN` empty; `ACCOUNTS_ORDERS_BASE_URL` empty. `main.dart` only builds `ShopifyCartComposition.production` when `StorefrontConfig.isUsable`. User can still enter checkout capture/review; final button reports checkout unavailable. |
| **Planned change** | Coherent same-shop config; block checkout start before address if cart/checkout cannot complete. Do not mix real catalog IDs with staging cart. |
| **Regression test** | To-add: unusable StorefrontConfig refuses launch earlier than payment step. |
| **Integration/E2E** | Staging build with matching shop token creates real cart + Checkout Kit sheet. |
| **Unresolved dependencies** | Staging Storefront token + catalog from same shop (not Firestore mirror of production on staging cart). |

### F06 — P1 — Sesión de app no se transfiere al checkout

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | `checkout_screen.dart` always passes `GuestCartBuyerIdentity(email, phone, countryCode: 'MX')`. API supports `AuthenticatedCartBuyerIdentity` (`cart_api.dart`, `storefront_cart_api.dart`) but UI never uses it. |
| **Planned change** | Pass fresh Customer Account access token as buyerIdentity for Shopify sessions; keep guest path; invalidate preload on logout/account switch. |
| **Regression test** | To-add: signed-in path supplies AuthenticatedCartBuyerIdentity; guest still Guest. |
| **Integration/E2E** | Authenticated checkout recognized in Shopify; expired token refresh; logout invalidates prior cart. |
| **Unresolved dependencies** | Working Customer Account client + scopes on target shop. |

### F07 — P1 — Dirección capturada no se transmite; estimaciones locales

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | Draft collects full address; launcher only sends email/phone/MX. `motion.dart`: `kFreeShippingThreshold = 1499`, `kStandardShippingFee = 149`; checkout UI shows “3 a 5 días” / local shipping estimates. |
| **Planned change** | Prefer Shopify-native address/shipping capture, or wire Cart API delivery address + costs; stop promising local constants as final. |
| **Regression test** | To-add: buyerIdentity/cart update includes delivery address when using that path; UI labels estimates as non-final. |
| **Integration/E2E** | CP without coverage, threshold discount, tax/shipping match Checkout. |
| **Unresolved dependencies** | Shopify shipping/markets config for MX. |

### F08 — P1 — Full sync no elimina productos retirados

| Field | Value |
|---|---|
| **Status** | `done` |
| **Evidence** | Verified full sync calls `replaceProducts` (incl. empty); partial/incomplete preserves cache. |
| **Planned change** | Atomic full replace after validated complete page set; preserve last good cache on partial failure. |
| **Regression test** | `catalog_repository_test` A+B→B and empty full sync. |
| **Integration/E2E** | Unpublish/delete product disappears after full sync. |
| **Unresolved dependencies** | Must land after F09 completeness guard. |

### F09 — P1 — Paginación incompleta se declara exitosa

| Field | Value |
|---|---|
| **Status** | `done` |
| **Evidence** | `CatalogSyncIncompleteException` on maxPages/missing/repeated cursor/inner truncation; cursor not advanced. |
| **Planned change** | Abort without advancing cursor when truncated/repeated cursor; page or declare inner connection limits. |
| **Regression test** | `catalog_sync_test` abort cases; `catalog_repository_test` incomplete pagination. |
| **Integration/E2E** | Catalog > 20×250 products or forced truncation. |
| **Unresolved dependencies** | Precedes destructive F08 replace. |

### F10 — P1 — Caché y cursor no identifican el shop

| Field | Value |
|---|---|
| **Status** | `done` |
| **Evidence** | `shopDomain` on SyncCursors/CatalogStates; mismatch clears catalog/cursor/bag/wishlist before full sync. |
| **Planned change** | Persist shop/source identity; reject incompatible cursor/catalog; force full sync on shop change. |
| **Regression test** | `catalog_repository_test` shop domain mismatch. |
| **Integration/E2E** | Rebuild with different `SHOPIFY_STORE_DOMAIN` does not buy with foreign variant IDs. |
| **Unresolved dependencies** | Migration strategy for existing installs. |

### F11 — P1 — Favoritos y bolsa no aislados por cuenta

| Field | Value |
|---|---|
| **Status** | `done` |
| **Evidence** | Bag/wishlist reads filter by account scope (`''` guest); CatalogStore.setAccountScope rehydrates; login callback wired. |
| **Planned change** | Explicit guest vs account policy; filter reads; rehydrate CatalogStore on session change; safe merge on login. |
| **Regression test** | `catalog_store_bag_scope_test` + stores account scope tests. |
| **Integration/E2E** | Login/logout/login cycle on one device. |
| **Unresolved dependencies** | Product decision on merge-vs-replace for guest bag. |

### F12 — P1 — Webhook fallido queda consumido; retry descartado

| Field | Value |
|---|---|
| **Status** | `closed` |
| **Evidence** | `handlers.ts` `claimDelivery` → `recordIfNew` INSERT … ON CONFLICT DO NOTHING before effects; on conflict returns false without checking `processed_at`. Failed order upsert leaves row claimed; retry skipped. |
| **Planned change** | Durable inbox with states/retries; mark processed only after durable effects; concurrent-safe. |
| **Regression test** | To-add (invert backend probe): fail after claim → retry processes; full duplicate does not double-apply. |
| **Integration/E2E** | Shopify webhook retry against staging backend. |
| **Unresolved dependencies** | Deployed webhook endpoint + HMAC secrets. |

### F13 — P1 — Historial parcial, errores silenciosos, sin backfill

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | App uses `GET /customers/me/orders` (`order_history_client.dart`). Staging `ACCOUNTS_ORDERS_BASE_URL` empty. Admin channel `shopify-orders` throws `SYNC_CHANNEL_NOT_CONFIGURED` (`admin/routes.ts`). UI: `account_screen.dart` shows «Aún no tienes pedidos.» when not loading — no error differentiation. |
| **Planned change** | Prefer Customer Account API for buyer history; or robust mirror backfill; distinguish empty / unconfigured / error / stale cache. |
| **Regression test** | To-add: repository surfaces error states; UI does not map failure to empty. |
| **Integration/E2E** | Pre-install orders visible; new order appears; backend down ≠ empty. |
| **Unresolved dependencies** | Customer Account orders scopes or Admin backfill permissions. |

### F14 — P1 — Respuesta tardía puede reponer pedidos tras logout

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | `account_controller.dart` `loadOrders()` captures `current` then awaits cache/refresh and assigns `orders` / clears `ordersLoading` with **no** re-check that `account` is still the same. |
| **Planned change** | Generation/cancel token + identity guard after each await; invalidate private state on session change. |
| **Regression test** | To-add: delayed refresh for A after logout/login B discarded. |
| **Integration/E2E** | Rapid logout during refresh. |
| **Unresolved dependencies** | None for code fix. |

### F15 — P1 — Espejo acepta actualizaciones de pedidos fuera de orden

| Field | Value |
|---|---|
| **Status** | `closed` |
| **Evidence** | `pgOrdersRepository.ts` ON CONFLICT always overwrites `financial_status` / `fulfillment_status` and sets `updated_at = now()` with no comparison to Shopify updated_at / version. Shop domain not validated in order upsert path beyond webhook HMAC. |
| **Planned change** | Temporal versioning / canonical read; verify expected shop; metrics + replay. |
| **Regression test** | To-add: paid→refunded then stale paid delivery keeps refunded. |
| **Integration/E2E** | Out-of-order Shopify webhook deliveries on staging. |
| **Unresolved dependencies** | Separate staging/prod DB + webhook secrets. |

### F16 — P1 operativo — Métodos de pago / enlaces externos sin verificar

| Field | Value |
|---|---|
| **Status** | `pending` |
| **Evidence** | Native bridges present; `onCheckoutLinkClicked` / `checkoutDidClickLink` are empty stubs (“denied until audited return-link phase”) in Android/iOS ShopifyCheckoutBridge. No device/provider matrix executed in audit. |
| **Planned change** | Verify enabled Shopify payment methods + 3DS/wallets/cancel/timeout/background; implement official link-return support only as needed. |
| **Regression test** | To-add: bridge contract tests once return-link phase defined; do not treat sheet close as paid. |
| **Integration/E2E** | **Required:** iOS + Android evidence per enabled payment method (test mode). |
| **Unresolved dependencies** | Payment methods enabled on shop; test cards; physical/simulator devices. |

### F17 — P2 — Terminación de compra no cierra la posventa

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | Checkout completion wires `onCompleted: store.clearBagAfterCheckout` only — no `loadOrders`, no order confirmation surface. External browser fallback does not confirm completion. |
| **Planned change** | Result state + canonical recovery; refresh order history; rebuild intent from current variants; never treat browser return as paid. |
| **Regression test** | To-add: complete clears purchased lines only; cancel keeps bag; completion triggers orders refresh. |
| **Integration/E2E** | Guest + auth purchase; browser fallback path. |
| **Unresolved dependencies** | Depends on F05/F06 working checkout. |

### F18 — P2 — Cuenta incompleta y logout sólo local

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | `customer_session_repository.dart` `logout` deletes local secure token/session only; comments explicitly note no Shopify `end_session`. `_resolveIdentity` falls back to decoding idToken claims when identity fetch fails (except sessionExpired). No in-app profile/address CRUD or account deletion flow found. |
| **Planned change** | Hosted logout where supported; resolve identity via authorized API before linking; profile/addresses or portal link; account deletion process. |
| **Regression test** | To-add: logout clears local session; identity fetch failure does not forge inconsistent link when token rejected. |
| **Integration/E2E** | A logout → B login without silent A cookie confusion (document Shopify cookie behavior). |
| **Unresolved dependencies** | Shopify Customer Account logout UX constraints (`id_token_hint`). |

### F19 — P1 — Cuentas heredadas sin transición segura

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | `/accounts/register` + `/accounts/login` still live (`server.ts`). Rate limiter (`SlidingWindowAdminRateLimiter`) applies to admin mutations only — not login/register. UI primary path is Shopify Customer Accounts. |
| **Planned change** | Harden or flag-disable new legacy registration; rate-limit auth endpoints; migrate/link with proof, not email alone; backup/rollback plan. |
| **Regression test** | To-add: rate limit; register disabled flag; no email-only order linking. |
| **Integration/E2E** | Legacy user retains history after migration. |
| **Unresolved dependencies** | Inventory of real legacy accounts (ops). |

### F20 — P1 — Permisos servidor vs entrada UI difieren

| Field | Value |
|---|---|
| **Status** | `closed` |
| **Evidence** | Live `AdminController.canAccess` requires `serverCapabilities.openAdmin` from `GET /admin/me`; preview is explicit `ENABLE_OWNER_ADMIN_PREVIEW`. Mutations still `requireOwner` server-side. `main.dart` refreshes capabilities on account changes. |
| **Planned change** | Drive navigation from `/admin/me` capabilities; keep server auth; separate preview from real owner. |
| **Regression test** | To-add: server-authorized owner without compile-time email allowlist sees admin; normal user never. |
| **Integration/E2E** | Revoke principal → actions fail; incomplete config does not fake live panel. |
| **Unresolved dependencies** | Admin API base URL + provisioned principal in each environment. |

### F21 — P2 — Admin sólo carga primera página

| Field | Value |
|---|---|
| **Status** | `closed` |
| **Evidence** | `GET /admin/products` + control-plane `cursor`/`limit`/`q` with `productsMeta` (loadedCount, hasNextPage, endCursor, totalCount). Flutter load-more + search; UI distinguishes loaded vs total. |
| **Planned change** | Paginate product search/list; show real limits; keep deep ops in Shopify Admin. |
| **Regression test** | To-add: product 51/101 discoverable via pagination. |
| **Integration/E2E** | Shop with >100 products. |
| **Unresolved dependencies** | Live Admin API credentials for shops >100 products. |

### F22 — P1 — «Sincronizar todo» requiere monitor

| Field | Value |
|---|---|
| **Status** | `closed` |
| **Evidence** | Product `syncAll` omits external-status. `shopify-products` paginates all pages with durable cursor/pages/products (`011_admin_sync_job_progress.sql`); resume on job GET + process start; truncation fails with `SYNC_TRUNCATED` instead of claiming complete. |
| **Planned change** | Drop external channel; define each job’s completeness; durable progress/recovery; full catalog reconcile beyond first 100. |
| **Regression test** | To-add: syncAll succeeds with no external backend. |
| **Integration/E2E** | Created/edited/removed product reflected without monitor. |
| **Unresolved dependencies** | None for code path; deploy migration on staging/prod hosts. |

### F23 — P2 — Guardar portada no refresca fuente del comprador

| Field | Value |
|---|---|
| **Status** | `closed` |
| **Evidence** | `saveStorefront` uses `refreshAfter: true` → HomeContent/editorial/featured/catalog refresh. Featured reorder polls job to terminal then reloads canonical membership. Production/staging TOML define `$app:storefront_config` public_read. |
| **Planned change** | Refresh HomeContent after save; validate metaobject namespace/permissions on real credentials. |
| **Regression test** | To-add: saveStorefront triggers shopper-facing content reload path. |
| **Integration/E2E** | Second client sees banner/section change without reinstall. |
| **Unresolved dependencies** | Validate metaobject publication under real Admin + Storefront credentials. |

### F24 — P1 — TOML producción y permisos incompletos

| Field | Value |
|---|---|
| **Status** | `closed` |
| **Evidence** | `shopify/shopify.app.production.toml` scopes aligned with staging writes + storefront_config metaobject; placeholders remain. Ops left in Shopify Admin documented in `ADMIN_OPS_LEFT_IN_SHOPIFY.md`. Not deployed. |
| **Planned change** | Link real app, minimal verified scopes for retained mutations, real hosts/webhooks; keep reviewable, do not auto-deploy. |
| **Regression test** | Config validation tests; webhook route tests already partially cover compliance paths. |
| **Integration/E2E** | Staging app install with read+write scopes needed for panel. |
| **Unresolved dependencies** | Partner app link + production host decisions before deploy. |

### F25 — P2 — Firestore vs Storefront semántica distinta

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Staging `FIRESTORE_CATALOG_ENABLED=true`. Duplicated mirrors: `server/catalog/catalog.ts` and `functions/src/catalog.ts` use `ACTIVE && publishedAt != null` (not Headless publication). `catalog_cache_store` documents callers must reject empty/invalid snapshots. |
| **Planned change** | Storefront-direct as purchasable authority; if cache kept, never widen visibility; single writer per env. |
| **Regression test** | To-add: Headless unpublish removes purchasable experience when on Storefront path. |
| **Integration/E2E** | Compare Storefront vs Firestore visibility for same product. |
| **Unresolved dependencies** | Storefront-only staging allowed; Firestore mirror optional. Remaining: ensure Headless unpublish visibility parity when Storefront path is live. |

### F26 — P2 — Navegación/contexto comercial parcialmente estáticos

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Catalog delta query uses `@inContext(country, language)`; Home resumed triggers `syncWithShopify` single-flight. Menu/predictive search still unused; collections pagination not expanded. |
| **Planned change** | Connect managed nav if required; paginate collections; apply MX/ES market context; refresh full catalog on foreground with single-flight. |
| **Regression test** | `catalog_sync_test` inContext variables. |
| **Integration/E2E** | Currency/price align with MX checkout market. |
| **Unresolved dependencies** | Product decision: local search vs Shopify predictive. |

### F27 — P2 — Apartados / mayoreo / soporte manuales

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | Product/partner flows open WhatsApp (and Canva/Drive links); webhook recognizes `MN-` apartado tags but reservation/payment remain manual. No auto hold/deposit/expiry in app. |
| **Planned change** | Document owner SOP (response, reserve, charge, link order, deliver); do not claim “apartado confirmado” from WhatsApp open alone. |
| **Regression test** | Message payload includes correct variant/qty (unit). |
| **Integration/E2E** | Operator creates/links Shopify order; stock/state verifiable. |
| **Unresolved dependencies** | Business owner for SOP + wholesale access policy. |

### F28 — P2 — Push implementado pero no operativo

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Notification stack present (`notification_config.dart` reads `NOTIFICATIONS_ENABLED`; controllers/API/worker exist). Staging dart-defines omit `NOTIFICATIONS_ENABLED` (defaults false). Deep-link collection→category filter issue called out in audit still relevant to verify in `main.dart`. |
| **Planned change** | Enable with App Check/APNs/FCM per app id; fix collection deep links; remove external catalog triggers; wire useful checkout telemetry without mistaking completion for capture. |
| **Regression test** | Existing notification unit tests; to-add: opt-out respected; collection deep link opens handle. |
| **Integration/E2E** | Cold start + foreground push on real devices. |
| **Unresolved dependencies** | Firebase prod project, APNs/FCM, backend worker secrets. |

### F29 — P1 — Privacidad / mantenimiento sin cierre durable

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | `handleCustomersDataRequest` only `logger.warn` then `markProcessed` — no export queue. Redact deletes mirror PII/engagement/tokens. `/healthz` and `/livez` return ok without PostgreSQL check; no `readyz`. |
| **Planned change** | Tracked data-request/export workflow; readiness probes; backup/restore drill; business policy owner. |
| **Regression test** | To-add: data_request leaves durable open task; readiness fails when DB down. |
| **Integration/E2E** | Test request export/close; restore rehearsal. |
| **Unresolved dependencies** | Legal/ops owner; backup tooling. |

### F30 — P1 — Gates de calidad no verdes

| Field | Value |
|---|---|
| **Status** | `open` |
| **Evidence** | `.github/workflows/quality.yml` formats `lib test integration_test` but `integration_test/` missing. `config/dart_defines.ci.json` is tracked; `bin/check_no_secrets.sh` fails any `config/dart_defines*.json` that is not `*.example`. Audit noted analyze infos + format drift on some files (re-run at gate time). |
| **Planned change** | Fix format/lints; narrow CI fixture exception with content validation; add real integration tests; update CI; prefer FVM pin. |
| **Regression test** | CI green on final commit: format, analyze, flutter/test suites, secrets scanner, builds. |
| **Integration/E2E** | Replace missing `integration_test` with useful flows (catalog/checkout fakes). |
| **Unresolved dependencies** | None to start; keep scanner strict. |

---

## Work-package mapping (from handoff)

| WP | Findings | Notes |
|----|----------|-------|
| WP-01 | F01, F02, F19 | Security — first |
| WP-02 | F03, F22, F25 | External catalog retirement |
| WP-03 | F04, F08, F09, F10, F11, F26 | Phase C done in WIP (F26 partial: inContext + foreground catalog refresh) |
| WP-04 | F05, F06, F07, F16, F17 | Checkout |
| WP-05 | F12–F15, F18 | Orders / webhooks / logout |
| WP-06 | F20–F24 | Admin operable |
| WP-07 | F27–F30 | Ops, privacy, CI |

## Top highest-severity still-open findings

1. **F03 (P0, remediated in WIP)** — external catalog retired from product; live infra decommission pending owner approval.
2. **F04 (P1, open)** — `product_screen.dart` calls `addToBag(product)`; store picks cheapest available; `BagLines` PK is `productId`.
3. **F05 (P1, open)** — staging Storefront token empty; cart composition gated by `StorefrontConfig.isUsable`.
4. **F12 (P1, closed)** — durable webhook inbox with pending/processing/completed/failed; claim-then-fail retries; completed not double-applied.
5. **F08 (P1, open)** — full sync only `upsertProducts`; never deletes absent products (`catalog_repository.dart`).

Note: **F01/F02** remain P0 but are `partial` in uncommitted WIP — finish wiring/tests before treating closed.

---

*Generated by revalidation on 2026-09-07 (America/Monterrey). Update status cells as remediations land; do not treat this file as proof of production readiness.*


## Phase A / WP-01 status (appended)

- Commit: `2350c3eb26833d05fb7bf3dceaa7a4491a1d4b18`
- F01/F02/F19 remediated in `services/accounts_orders` with HTTP + disposable PG tests (75/75 green; typecheck exit 0).
- Owner action: explicitly provision legitimate owners via `admin_principals` SQL in `PHASE_A_NOTES.md`; set `LEGACY_ACCOUNT_REGISTRATION_ENABLED=false` in production when ready; configure `OWNER_SHOPIFY_CUSTOMER_IDS` for verified Shopify bootstrap.


## Phase E / WP-05 status (appended)

- F12 closed: `tryClaim` / `markCompleted` / `markFailed` durable inbox (`010_webhook_durable_inbox.sql`, `pgWebhookEventsRepository.ts`, `handlers.ts`). Claimed-but-failed deliveries retry; completed deliveries do not re-apply effects. Concurrent in-flight claims are ignored until stale (5m).
- F15 closed (backend): `orders_mirror.shopify_updated_at` refuses stale out-of-order overwrites; webhook route rejects unexpected `X-Shopify-Shop-Domain` when `SHOPIFY_STORE_DOMAIN` is configured.
- F29 partial: `privacy_requests` durable open task for `customers/data_request`; `/readyz` probes PostgreSQL. Full export/fulfill workflow + backup drill still open.
- Still open in Phase E: F13 (Customer Account history / UI empty-vs-error), F14 (Flutter logout race — deferred to avoid Phase B `lib/` conflict), F17 (post-checkout UX — Flutter/checkout), F18.


## Phase F / WP-06 status (appended)

- F20 closed: UI entry from `/admin/me` capabilities; preview separated; server still authorizes every action.
- F21 closed: paginated `/admin/products` + `productsMeta`; Flutter load-more/search distinguishes loaded vs total.
- F22 closed: full-page shopify-products sync with durable progress/resume; syncAll without external monitor.
- F23 closed: storefront save refreshes shopper HomeContent; featured reorder waits for terminal job.
- F24 closed as reviewable artifact: production TOML scopes/metaobject prepared; no production deploy.
- See `PHASE_F_NOTES.md` and `ADMIN_OPS_LEFT_IN_SHOPIFY.md`.

