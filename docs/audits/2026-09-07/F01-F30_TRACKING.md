> **PR7 review supersedes prior closure claims.** See [PR7_REMEDIATION.md](PR7_REMEDIATION.md) for the current finding-to-fix matrix and local validation. R1–R8 reopened F08/F09/F10/F12/F13/F17/F30; earlier “closed” entries below are historical. Local tests, CI, development Shopify and device journeys remain separate. No live Shopify journey or production launch is approved by this update.

# F01–F30 remediation tracking — 2026-09-07

**Branch:** `monetta/audit-remediation-wip`  
**Revalidated against:** tip `b19da2a` on `monetta/audit-remediation-wip` (Phases A–G committed). Closeout 2026-09-07 CT.
**Sources:** `docs/AUDITORIA_FLUJOS_2026-09-07.md`, `docs/GROK_HANDOFF_FLUJOS_2026-09-07.md`, live code under `lib/`, `services/accounts_orders/`, `api/`, `functions/`, `shopify/`, `config/`, CI  
**Scope of this doc:** tracking only — no remediations implemented here.

Status legend: `open` | `fixed` | `disproved` | `partial` | `pending`

| Count | Status |
|------:|:-------|
| 0 | open |
| 19 | fixed/done/closed/remediated |
| 0 | disproved |
| 10 | partial |
| 1 | pending |

---

## Matrix

### F01 — P0 — Elevación a owner por correo no verificado

| Field | Value |
|---|---|
| **Status** | `fixed` |
| **Evidence** | Phase A commit `2350c3e`: ServerAdminAuthorizer no longer bootstraps owners from Monetta self-declared emails; OWNER_SHOPIFY_CUSTOMER_IDS + explicit admin_principals only. HTTP+PG regression tests green (closeout: 86/86). **Owner action remaining:** provision legitimate principals per PHASE_A_NOTES.md. |
| **Planned change** | Finish wiring (drop `ownerEmails` from authorizer call sites), provision owners via Shopify customer id / CLI principals only, migrate/review bootstrap-created principals, add inverted regression tests. |
| **Regression test** | To-add: allowlisted Monetta email with `emailVerified=false` must not get `role=owner`. Invert `backend_probes.mts.txt`. Update `adminApi.test.ts` constructor. |
| **Integration/E2E** | Unverified Monetta register → `/admin/me` 403; provisioned Shopify owner works; deactivated principal stays revoked. |
| **Unresolved dependencies** | Finish WIP compile/tests; inventory of principals; `OWNER_ADMIN_SHOPIFY_CUSTOMER_IDS`. |

### F02 — P0 — Registro con deviceId conocido reemplaza credenciales

| Field | Value |
|---|---|
| **Status** | `fixed` |
| **Evidence** | Phase A commit `2350c3e`: register creates only; known deviceId returns 409 registration_conflict without credential overwrite; in-memory fake + API mapping aligned; WP-01 tests green. |
| **Planned change** | Mirror PG semantics in in-memory fake; map device/email conflicts in API; separate authenticated credential change; add tests that prove A's identity unchanged. |
| **Regression test** | To-add: known deviceId register does not change A's email/password/Shopify link/sessions. Invert backend probe. |
| **Integration/E2E** | Concurrent register retries; PostgreSQL path + API 409. |
| **Unresolved dependencies** | Complete WIP across fake/API/tests; legacy shared-device inventory. |

### F03 — P0 — Catálogo externo todavía activo

| Field | Value |
|---|---|
| **Status** | `remediated` |
| **Evidence** | Phase B `71900b4`: ExternalCatalogConfig forced off; ENABLE_EXTERNAL_CATALOG rejected by RuntimeConfig/validators; admin syncAll omits external-status. Live monitor/DNS decommission still owner-gated — EXTERNAL_CATALOG_DECOMMISSION.md. |
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
| **Status** | `partial` |
| **Evidence** | Phase D: bag CTA blocks contact capture when no secure launcher/`ShopifyCartComposition` (`checkout_screen.dart`). Staging token still empty — live cart/checkout needs matching Storefront config. |
| **Planned change** | Coherent same-shop config; block checkout start before address if cart/checkout cannot complete. Do not mix real catalog IDs with staging cart. |
| **Regression test** | `checkout_screen_test` bag refuses contact when checkout unavailable. |
| **Integration/E2E** | Staging build with matching shop token creates real cart + Checkout Kit sheet. |
| **Unresolved dependencies** | Staging Storefront token + catalog from same shop (not Firestore mirror of production on staging cart). |

### F06 — P1 — Sesión de app no se transfiere al checkout

| Field | Value |
|---|---|
| **Status** | `fixed` |
| **Evidence** | Phase D: `resolveCheckoutBuyerIdentity` + bag launcher; Shopify accounts use `AuthenticatedCartBuyerIdentity` via `accessTokenForShopifyCheckout`; guests/legacy Monetta stay Guest. Account scope change invalidates preloaded checkout (`main.dart`). |
| **Planned change** | Pass fresh Customer Account access token as buyerIdentity for Shopify sessions; keep guest path; invalidate preload on logout/account switch. |
| **Regression test** | `checkout_buyer_identity_test.dart`. |
| **Integration/E2E** | Authenticated checkout recognized in Shopify; expired token refresh; logout invalidates prior cart. |
| **Unresolved dependencies** | Working Customer Account client + scopes on target shop for live E2E. |

### F07 — P1 — Dirección capturada no se transmite; estimaciones locales

| Field | Value |
|---|---|
| **Status** | `fixed` |
| **Evidence** | Phase D: removed redundant address capture; contact-only pre-checkout; address/shipping collected in Shopify Checkout. Local shipping labeled non-final; bag uses ShopifyCartSummary totals when remote cart exists. |
| **Planned change** | Prefer Shopify-native address/shipping capture, or wire Cart API delivery address + costs; stop promising local constants as final. |
| **Regression test** | `checkout_screen_test` contact-only form. |
| **Integration/E2E** | CP without coverage, threshold discount, tax/shipping match Checkout. |
| **Unresolved dependencies** | Shopify shipping/markets config for MX (live). |

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
| **Evidence** | Phase E `0508541`: durable inbox tryClaim/markCompleted/markFailed (`010_webhook_durable_inbox.sql`); claim-then-fail retries; completed deliveries not re-applied. |
| **Planned change** | Durable inbox with states/retries; mark processed only after durable effects; concurrent-safe. |
| **Regression test** | To-add (invert backend probe): fail after claim → retry processes; full duplicate does not double-apply. |
| **Integration/E2E** | Shopify webhook retry against staging backend. |
| **Unresolved dependencies** | Deployed webhook endpoint + HMAC secrets. |

### F13 — P1 — Historial parcial, errores silenciosos, sin backfill

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Overnight follow-up: Customer Account API is primary via `customer_orders.dart` + `OrderHistoryRepository.refresh` (CAA success merges mirror apartados only). UI distinguishes empty / unavailable / failed / stale-cache + explicit «Actualizar pedidos». Checkout still calls `loadOrders`. Unit/widget tests green. Live CAA scopes / pre-install history / staging backend still unverified. |
| **Planned change** | Prefer Customer Account API for buyer history; or robust mirror backfill; distinguish empty / unconfigured / error / stale cache. |
| **Regression test** | Added: repository empty≠failed≠stale; CAA primary + apartado merge; account UI failed≠empty; controller generation discard. |
| **Integration/E2E** | Still required: pre-install orders on real Customer Account session; new order after checkout; backend down ≠ empty. |
| **Unresolved dependencies** | Customer Account protected data / orders scopes on target shop; staging Storefront + CAA credentials; optional mirror URL for apartados. |

### F14 — P1 — Respuesta tardía puede reponer pedidos tras logout

| Field | Value |
|---|---|
| **Status** | `fixed` |
| **Evidence** | `AccountController.loadOrders` uses `_ordersGeneration` + `_ordersStillCurrent` after every await; logout/sign-out clears orders and bumps generation. Regression test: delayed CAA response after logout does not repopulate UI. |
| **Planned change** | Generation/cancel token + identity guard after each await; invalidate private state on session change. |
| **Regression test** | Added in `account_controller_test.dart` (gated CAA after logout). |
| **Integration/E2E** | Rapid logout during refresh on device still recommended. |
| **Unresolved dependencies** | None for code fix. |

### F15 — P1 — Espejo acepta actualizaciones de pedidos fuera de orden

| Field | Value |
|---|---|
| **Status** | `closed` |
| **Evidence** | Phase E `0508541`: orders_mirror.shopify_updated_at refuses stale overwrites; unexpected X-Shopify-Shop-Domain rejected when SHOPIFY_STORE_DOMAIN configured. |
| **Planned change** | Temporal versioning / canonical read; verify expected shop; metrics + replay. |
| **Regression test** | To-add: paid→refunded then stale paid delivery keeps refunded. |
| **Integration/E2E** | Out-of-order Shopify webhook deliveries on staging. |
| **Unresolved dependencies** | Separate staging/prod DB + webhook secrets. |

### F16 — P1 operativo — Métodos de pago / enlaces externos sin verificar

| Field | Value |
|---|---|
| **Status** | `pending` |
| **Evidence** | Phase D: still requires physical/simulator matrix. Native stubs unchanged; browser fallback explicitly does not confirm payment. |
| **Planned change** | Verify enabled Shopify payment methods + 3DS/wallets/cancel/timeout/background; implement official link-return support only as needed. |
| **Regression test** | Coordinator tests: external fallback never marks completion; double-tap guarded. |
| **Integration/E2E** | **Required:** iOS + Android evidence per enabled payment method (test mode). |
| **Unresolved dependencies** | Payment methods enabled on shop; test cards; physical/simulator devices. |

### F17 — P2 — Terminación de compra no cierra la posventa

| Field | Value |
|---|---|
| **Status** | `fixed` |
| **Evidence** | Phase D: rebuild live bag intent at present; `onCompleted(purchasedVariantIds)` → `clearPurchasedBagLines` + `loadOrders`; truthful completion snackbar; browser fallback copy states it does not confirm payment; double-tap still single-flight. |
| **Planned change** | Result state + canonical recovery; refresh order history; rebuild intent from current variants; never treat browser return as paid. |
| **Regression test** | `shopify_checkout_coordinator_test` purchased IDs; cancel/fail preserve bag. |
| **Integration/E2E** | Guest + auth purchase; browser fallback path on device. |
| **Unresolved dependencies** | Live Shopify + order mirror for post-purchase history visibility. |

### F18 — P2 — Cuenta incompleta y logout sólo local

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Phase D: persist `id_token` for RP-initiated logout; `CustomerAuthGateway.endSession`; logout attempts hosted end-session then local cleanup; preload invalidated on account scope change. Profile/address CRUD and account deletion still open. Identity authorized-API preference already present with claims fallback. |
| **Planned change** | Hosted logout where supported; resolve identity via authorized API before linking; profile/addresses or portal link; account deletion process. |
| **Regression test** | `customer_session_repository_test` hosted end-session + cancel still clears local. |
| **Integration/E2E** | A logout → B login without silent A cookie confusion on device. |
| **Unresolved dependencies** | Profile/portal/deletion UX; live Shopify end-session behavior. |

### F19 — P1 — Cuentas heredadas sin transición segura

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Phase A: validation + rate limits on register/login; LEGACY_ACCOUNT_REGISTRATION_ENABLED closes new signups when false; UI primary path is Shopify Customer Accounts. Prod flag still default-open in example env; legacy inventory/migration remains owner ops. |
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
| **Status** | `partial` |
| **Evidence** | Phase G `b19da2a`: APARTADO_AND_RESELLER_SOP.md + honest shopper/partner copy; WhatsApp/Canva/Drive do not reserve/charge/create orders. Manual ops unchanged by design. |
| **Planned change** | Document owner SOP (response, reserve, charge, link order, deliver); do not claim “apartado confirmado” from WhatsApp open alone. |
| **Regression test** | Message payload includes correct variant/qty (unit). |
| **Integration/E2E** | Operator creates/links Shopify order; stock/state verifiable. |
| **Unresolved dependencies** | Business owner for SOP + wholesale access policy. |

### F28 — P2 — Push implementado pero no operativo

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Phase G: collection deep link keeps collectionHandle; reject external: engagement keys/events/product routes. Device push (APNs/FCM/App Check) still owner-gated; NOTIFICATIONS_ENABLED off in staging templates. |
| **Planned change** | Enable with App Check/APNs/FCM per app id; fix collection deep links; remove external catalog triggers; wire useful checkout telemetry without mistaking completion for capture. |
| **Regression test** | Existing notification unit tests; to-add: opt-out respected; collection deep link opens handle. |
| **Integration/E2E** | Cold start + foreground push on real devices. |
| **Unresolved dependencies** | Firebase prod project, APNs/FCM, backend worker secrets. |

### F29 — P1 — Privacidad / mantenimiento sin cierre durable

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Phase E+G: privacy_requests durable open task; /readyz probes PG; admin privacy list/fulfill + migration 012; redact evidence. Full export package + backup restore drill still operator-run (ACCOUNTS_ORDERS_OPS.md). |
| **Planned change** | Tracked data-request/export workflow; readiness probes; backup/restore drill; business policy owner. |
| **Regression test** | To-add: data_request leaves durable open task; readiness fails when DB down. |
| **Integration/E2E** | Test request export/close; restore rehearsal. |
| **Unresolved dependencies** | Legal/ops owner; backup tooling. |

### F30 — P1 — Gates de calidad no verdes

| Field | Value |
|---|---|
| **Status** | `partial` |
| **Evidence** | Phase G: integration_test harness present; narrow CI fixture exception with content validation (check_no_secrets exit 0 on closeout tip); home tests drop ExternalCatalogScope. Full flutter/CI suite green not claimed this closeout. |
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

1. **F05 (P1, partial)** — staging/production Storefront token / same-shop config still required for live carts.
2. **F16 (P1, pending)** — payment method matrix on simulator/physical devices not run.
3. **F13 (P1, partial)** — CAA-primary UI in code; live pre-install/post-checkout history unverified.
4. **F03 (P0, remediated)** — product path retired; live monitor/DNS decommission still needs owner approval.
5. **F01/F19 (owner ops)** — code fixed/partial; legitimate owner provisioning + legacy flag still owner actions.

Note: F04/F08/F12 code remediations landed in Phase C/E; do not treat stale bullet text above as current defects.

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


## Phase D / WP-04 status (appended)

- F05 partial: unavailable checkout blocked before contact capture; staging Storefront token still required for live carts.
- F06 fixed: authenticated Shopify buyerIdentity + guest/legacy guest path; preload invalidated on account switch.
- F07 fixed: contact-only pre-checkout; address/shipping delegated to Shopify; estimates labeled non-final.
- F16 pending: payment method / external link matrix still needs physical devices.
- F17 fixed: rebuild intent at present; clear purchased lines only; refresh orders; browser fallback not treated as paid.
- F18 partial: hosted end-session with `id_token_hint` + local cleanup; profile/deletion still open.
- Also: `AccountController.loadOrders` generation guard (F14 race) for safe post-checkout refresh.

## Overnight F13/F14 follow-up (appended)

- F13 advanced to `partial`: Customer Account API primary (`lib/data/customer_auth/customer_orders.dart`), repository status surface, account UI empty/unavailable/failed/stale-cache + refresh action; mirror apartados enrichment only after CAA success.
- F14 marked `fixed` (generation guard already present from Phase D; regression test added).
- Live shop verification of pre-install history and post-checkout appearance still open.

## Phase G / WP-07 status (committed `b19da2a`)

- F27 partial: honest SOP + UI/WhatsApp copy; manual ops unchanged by design.
- F28 partial: collection deep links + external event rejection in code; device push config still owner-gated.
- F29 partial: privacy fulfill/list + redact evidence + ops docs; `/readyz` from Phase E; export package still operator-run.
- F30 partial: integration_test harness, narrow CI fixture exception, ExternalCatalogScope test cleanup, format paths.
- Closeout tip includes Phase G. See PHASE_G_NOTES.md + FINAL_DELIVERABLES.md.


## Closeout refresh (appended)

- Tip `b19da2a`. Tracking cells reconciled to Phases A–G + closeout evidence.
- Local: accounts_orders typecheck 0; vitest 86/86; check_no_secrets 0; focused flutter subset 0.
- See J01-J11_RESULTS.md and FINAL_DELIVERABLES.md. Code / dev-store / production remain SEPARATE statuses.
