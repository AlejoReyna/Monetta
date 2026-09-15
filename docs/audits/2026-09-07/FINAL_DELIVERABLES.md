> **PR7 review supersedes prior closure claims.** See [PR7_REMEDIATION.md](PR7_REMEDIATION.md) for the current finding-to-fix matrix and local validation. R1–R8 reopened F08/F09/F10/F12/F13/F17/F30; earlier “closed” entries below are historical. Local tests, CI, development Shopify and device journeys remain separate. No live Shopify journey or production launch is approved by this update.

# Final deliverables — Monetta audit remediation closeout

**Branch:** `monetta/audit-remediation-wip`
**Tip at closeout evidence:** `b19da2a50aaa8c3eb2344f917cf9e89208f6d8f4`
**Date:** 2026-09-07 (America/Monterrey)
**Sources:** AUDITORIA_FLUJOS_2026-09-07.md §9 launch criteria; GROK_HANDOFF end-of-night items; phase notes A–G.

**Explicit conclusion:** **code readiness**, **development-store verification**, and **production verification** are **SEPARATE** statuses. This branch advances code remediation substantially. It does **not** certify a development shop E2E pass, and it does **not** authorize production launch or canary.

---

## 1. Phase commits (A–G)

| Phase | WP | Primary findings | Anchor commit | Status |
|-------|----|------------------|---------------|--------|
| A | WP-01 | F01, F02, F19 | `2350c3e` (+ note `aa79a0e`) | Code remediated; owner provisioning / prod flag remain |
| Fixture scaffolding | — | audit seed/cleanup | `c16f36d` | Dry-run tooling only |
| B | WP-02 | F03, F22, F25 | `71900b4` | Product path retired; live infra decommission owner-gated |
| E | WP-05 | F12, F15, F29 baseline | `0508541` | Durable inbox + stale mirror guards + readyz/privacy task baseline |
| C | WP-03 | F04, F08–F11, F26 | `766bbe8` | Catalog completeness/variants/scope; F26 still partial |
| F | WP-06 | F20–F24 | `c6617e0` | Admin operable in code; production TOML reviewable, not deployed |
| D | WP-04 | F05–F07, F16–F18 | `8f765f7` | Checkout composition fixed; F05/F16/F18 still partial/pending |
| Overnight | — | F13, F14 | `300e49f` | CAA-primary history UI; F14 fixed |
| G | WP-07 | F27–F30 | `b19da2a` | SOP/copy, deep links, privacy fulfill, CI fixture hygiene |

---

## 2. F01–F30 matrix summary (post-phases reality)

| Status bucket | IDs |
|---|---|
| **fixed / done / closed / remediated** (code) | F01, F02, F03, F04, F06, F07, F08, F09, F10, F11, F12, F14, F15, F17, F20, F21, F22, F23, F24 |
| **partial** | F05, F13, F18, F19, F25, F26, F27, F28, F29, F30 |
| **pending** | F16 (device payment matrix) |
| **open** | none remaining as pure open after Phase G reconciliation (see tracking file cells) |

Detail + evidence: `F01-F30_TRACKING.md`. Highest remaining product risks for *selling*: staging Storefront/CAA credentials (F05), payment device matrix (F16), live order history (F13), owner provisioning (F01/F19), privacy restore drill (F29), external infra teardown approval (F03).

---

## 3. J01–J11

See `J01-J11_RESULTS.md`. Summary:

| Result | Journeys |
|---|---|
| PASS (live) | *(none)* |
| PARTIAL CODE ONLY | J03, J04, J06, J08, J09 |
| NOT RUN | J01, J02, J07 |
| BLOCKED | J05, J10, J11 |

---

## 4. Fixture commands (tools/audit)

Pointer: `tools/audit/README.md` + `tools/audit/env.example`.

Env **names** (no values here): EXPECTED_SHOP_ID, AUDIT_SHOP_ALLOWLIST, AUDIT_ALLOW_REMOTE_WRITES, AUDIT_DRY_RUN, AUDIT_ENVIRONMENT, AUDIT_DATABASE_URL.

Commands (dry-run default): audit.mjs guards → init → seed → status → cleanup --run-id. Live remote writes require allowlist + flags; adapters are still stubs.

Disposable PG: tools/audit/docker-compose.audit-pg.yml (host port 5435).

---

## 5. Migrations / rollback pointers

| Migration | Purpose |
|---|---|
| `services/accounts_orders/src/db/migrations/006_admin_principals.sql` | Owner principals |
| `010_webhook_durable_inbox.sql` | Durable webhook inbox states |
| `011_admin_sync_job_progress.sql` | Admin sync progress/resume |
| `012_privacy_request_fulfillment.sql` | Privacy fulfill fields |

Rollback / ops: `ACCOUNTS_ORDERS_OPS.md` (readyz, privacy fulfill, backup restore drill, additive SQL rollback notes). Phase A principal SQL: `PHASE_A_NOTES.md`. External infra teardown inventory (do not delete without approval): `EXTERNAL_CATALOG_DECOMMISSION.md`.

---

## 6. Env / secret **names** + owner actions

### App dart-defines (names only)

APP_ENV, SHOPIFY_STORE_DOMAIN, SHOPIFY_STOREFRONT_ACCESS_TOKEN, SHOPIFY_API_VERSION, CUSTOMER_ACCOUNT_SHOP_ID, CUSTOMER_ACCOUNT_CLIENT_ID, ACCOUNTS_ORDERS_BASE_URL, ADMIN_API_BASE_URL, ENABLE_OWNER_ADMIN_PREVIEW, FIRESTORE_CATALOG_ENABLED, ENABLE_EXTERNAL_CATALOG, NOTIFICATIONS_ENABLED (when used), FIREBASE_* public client keys/ids (templates in config/*.example).

### accounts_orders host env (names only)

DATABASE_URL, PORT, SHOPIFY_APP_CLIENT_SECRET, SHOPIFY_APP_CLIENT_ID, SHOPIFY_ADMIN_API_VERSION, SHOPIFY_HEADLESS_PUBLICATION_ID, SHOPIFY_FEATURED_COLLECTION_ID, ADMIN_MUTATIONS_ENABLED, ADMIN_SHOPIFY_WRITES_ENABLED, SHOPIFY_STORE_DOMAIN, PUBLIC_BASE_URL, NOTIFICATIONS_ENABLED, FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY, PUSH_TOKEN_ENCRYPTION_SECRET, OWNER_SHOPIFY_CUSTOMER_IDS, OWNER_ADMIN_EMAILS (legacy informational), LEGACY_ACCOUNT_REGISTRATION_ENABLED.

### Top owner actions remaining

1. Provision legitimate owners (`admin_principals` / OWNER_SHOPIFY_CUSTOMER_IDS) — PHASE_A_NOTES.md.
2. Set LEGACY_ACCOUNT_REGISTRATION_ENABLED=false in production when ready.
3. Populate coherent staging/production Storefront + Customer Account dart-defines (same shop).
4. Confirm CAA protected data / orders access for Headless client.
5. Approve external-catalog infra decommission — EXTERNAL_CATALOG_DECOMMISSION.md.
6. Enable + matrix-test payment methods on iOS/Android (F16).
7. Run privacy export/fulfill drill + backup restore on disposable DB (F29/J11).
8. Firebase/APNs/FCM/App Check for push; enable NOTIFICATIONS_ENABLED on staging first (F28).
9. Production Partner app / TOML deploy decision (F24 artifact only today).
10. Authorize any real canary order / refund separately — not implied by this branch.

---

## 7. Test commands / exit codes (known this closeout)

| Check | Exit | Detail |
|---|---:|---|
| accounts_orders typecheck | **0** | tsc --noEmit on tip b19da2a |
| accounts_orders vitest | **0** | 86 passed / 17 files |
| bin/check_no_secrets.sh | **0** | public CI fixture validated |
| Focused flutter subset | **0** | orders/account/bag/copy/deep-link paths |
| Full flutter test / analyze / format / CI | **not claimed** | Do not treat subset as full suite |
| Live Shopify E2E / production canary | **not run** | See J01-J11 |

Earlier overnight F13 follow-up also recorded green focused flutter suites on CAA/history UI (commit 300e49f notes).

---

## 8. Ops procedures pointers

| Doc | Topic |
|---|---|
| ACCOUNTS_ORDERS_OPS.md | readyz, privacy queue/fulfill, webhook lag, backup/restore, rollback |
| APARTADO_AND_RESELLER_SOP.md | Manual apartado/wholesale; WhatsApp is not confirmation |
| ADMIN_OPS_LEFT_IN_SHOPIFY.md | Stock/media/refunds/payments stay in Shopify Admin |
| EXTERNAL_CATALOG_DECOMMISSION.md | Live monitor/DNS teardown inventory |
| PHASE_A_NOTES.md / PHASE_F_NOTES.md / PHASE_G_NOTES.md | Phase-specific owner follow-ups |
| docs/PUSH_NOTIFICATIONS_RUNBOOK.md | Push ops (updated in Phase G) |

---

## 9. Readiness statuses (SEPARATE)

| Layer | Status |
|---|---|
| **Code readiness** | **Advanced / substantially remediated** on this branch for P0 identity holes, external catalog product path, catalog integrity, checkout composition, admin operability, webhook durability, privacy task/fulfill API, CI fixture hygiene. Remaining code gaps are partial (F05 config gate, F13 live wiring deps, F18 profile/deletion, F25/F26 polish, F28/F30 full green claim). |
| **Development-store verification** | **NOT VERIFIED.** No allowlisted live seed; staging Storefront token historically empty; no hosted login / Checkout Kit / signed webhook E2E log in this closeout. |
| **Production verification** | **NOT RUN / BLOCKED.** Audit §9 launch criteria unmet. No production mutations, deploys, or canary orders from this work. |

---

*Closeout docs are evidence packages, not launch approval.*
