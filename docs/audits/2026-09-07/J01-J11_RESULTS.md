# J01-J11 journey results — 2026-09-07 closeout

**Branch:** `monetta/audit-remediation-wip`
**Commit:** `b19da2a50aaa8c3eb2344f917cf9e89208f6d8f4`
**Wall clock:** 2026-09-07 ~04:05 CT (America/Monterrey)
**Honesty rule:** Live Shopify, hosted auth, Checkout Kit sheets, physical/simulator payment methods, signed webhook replay against a deployed host, and production canary were **not** executed overnight. Unit/widget/backend tests are **code evidence only**, not journey PASS.

**Legend:** PASS | FAIL | BLOCKED | NOT RUN | PARTIAL CODE ONLY (code/tests present; no accepted live journey evidence)

---

## Environment matrix (this closeout)

| Environment | Used for J01-J11? | Notes |
|---|---|---|
| mock / in-memory / unit | Yes (supporting) | Flutter widget/unit + accounts_orders vitest fakes |
| local disposable PG | Supporting only | WP-01 PG tests + audit compose scaffolding available; not a journey run |
| development shop / staging Shopify | **No** | Staging Storefront token historically empty; CAA/Admin live credentials not exercised |
| iOS/Android simulator | **No** | No Checkout Kit / payment sheet session logged |
| physical device | **No** | F16 payment matrix not run |
| production canary | **No / BLOCKED** | Launch criteria unmet; no production mutations |

**Device:** N/A for live journeys
**Fixture IDs:** N/A (no live tools/audit seed against an allowlisted shop this closeout)

---

## Journey table

| ID | Journey | Result | Expected | Actual | Evidence (sanitized) |
|----|---------|--------|----------|--------|----------------------|
| **J01** | Fresh guest shopping | **NOT RUN** | Guest browses same-shop catalog; checkout blocked when Storefront unusable | No clean-install Storefront build exercised | Needs Storefront-configured build + clean install. Code: F05 blocks contact when checkout unavailable (unit). |
| **J02** | New Shopify customer | **NOT RUN** | Hosted Customer Account login completes | No hosted auth / inbox / callback run | Needs Mobile client ID + callback on target shop. |
| **J03** | Account isolation / lifecycle | **PARTIAL CODE ONLY** | A cannot read B bag/wishlist; delayed orders after logout discarded | Unit/widget coverage green; no device race matrix | catalog_store_bag_scope_test + account_controller_test F14 discard (closeout subset exit 0). |
| **J04** | Legacy account / owner security | **PARTIAL CODE ONLY** | Unverified allowlisted email is not owner; deviceId register 409; revoked stays revoked | Backend vitest + disposable PG green; no staging principals exercise | wp01Security tests among 86/86 accounts_orders tests (exit 0). Owner SQL provisioning still owner action. |
| **J05** | Guest + authenticated test purchases | **BLOCKED** | Guest + Shopify buyer complete test-mode checkout | No cart/checkout against live shop | Blocked by empty/mismatched staging Storefront token + payment config (F05/F16). |
| **J06** | Checkout failure / recovery | **PARTIAL CODE ONLY** | Bag preserved on cancel/fail; browser return is not paid; single-flight present | Coordinator/unit paths present; no device matrix | Phase D code + tests on branch; no simulator evidence this closeout. |
| **J07** | Catalog changes / env transition | **NOT RUN** | Removed products disappear after complete full sync; shop mismatch clears foreign IDs | No authorized dev-store fixture run | Code: F08-F10 marked done with unit coverage; live catalog ops not logged. |
| **J08** | Owner operations | **PARTIAL CODE ONLY** | Authorized owner operates; normal user never; syncAll without external monitor | Admin UI/API remediated in code; no operator E2E log | Phase F c6617e0. Needs Admin API base URL + provisioned principal per env. |
| **J09** | Order lifecycle / resilient events | **PARTIAL CODE ONLY** | Failed delivery retries; completed not double-applied; stale paid cannot overwrite refunded | Unit/inbox tests green; no signed staging webhook replay | F12/F15 closed in 0508541; handlers tests include claim-then-fail. |
| **J10** | Notifications / manual ops | **BLOCKED** | Opt-out respected; collection deep link opens handle; WhatsApp is not a reservation | Push credentials absent; apartado remains manual by design | F27/F28 partial after Phase G. Deep-link unit test green. Device push NOT RUN. |
| **J11** | Privacy / outage / migration / restore | **BLOCKED** | data_request opens durable task; fulfill records artifact ref; readyz fails if DB down; restore drill evidence | Privacy fulfill API + migration 012 in code; no restore drill / test export package | See ACCOUNTS_ORDERS_OPS.md. Operator export still out-of-band. |

---

## Supporting local evidence (not journey PASS)

Recorded during closeout on tip b19da2a:

| Command | Exit | Notes |
|---|---:|---|
| accounts_orders typecheck (tsc --noEmit) | 0 | Via local node_modules binary |
| accounts_orders vitest run | 0 | 86 tests / 17 files |
| bin/check_no_secrets.sh | 0 | CI fixture validated; no private secret patterns |
| Focused flutter test subset (orders/account/bag/copy/deep-link) | 0 | Subset only — not full Flutter suite |

---

## Fixture tooling (available; not live-run this closeout)

Documented under tools/audit/README.md. Dry-run default. Required env **names**: EXPECTED_SHOP_ID, AUDIT_SHOP_ALLOWLIST, AUDIT_ALLOW_REMOTE_WRITES, AUDIT_DRY_RUN, AUDIT_ENVIRONMENT, AUDIT_DATABASE_URL.

Typical sequence: copy tools/audit/env.example → tools/audit/.env; run audit.mjs guards; init; seed (dry-run); cleanup by run-id. Remote adapters remain stubs; live mode still refuses invented remote IDs without allowlist gates.

---

*This file is acceptance evidence for journeys. Absence of PASS on live rows is intentional honesty, not an oversight.*
