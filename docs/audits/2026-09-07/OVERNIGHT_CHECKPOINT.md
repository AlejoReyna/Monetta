# Overnight checkpoint — 2026-09-07

**Branch:** `monetta/audit-remediation-wip`  
**Phase D tip on remote (start of this follow-up):** `8f765f7`  
**Timezone for wall-clock notes:** America/Monterrey (UTC-6)  
**Purpose:** Honest status for phases A–G, code readiness vs store verification, owner actions, and J01–J11. This file is **not** production launch approval.

---

## Executive read

Code remediation on this branch is **substantially advanced** for identity, catalog retirement, checkout composition, admin operability, and webhook durability. **It is not production-ready.** Staging Storefront token / Customer Account live credentials, payment-device matrix, privacy export drill, and J01–J11 evidence are still missing. Phase G work was **dirty and uncommitted** at checkpoint time — treat G as in-flight.

---

## Phase map (A–G)

| Phase | WP | Findings (primary) | Status | Anchor commits / notes |
|-------|----|--------------------|--------|-------------------------|
| **A** | WP-01 | F01, F02, F19 | **Code remediated in backend**; tracking cells still `partial`/`open` until owner provisioning + prod flag | `2350c3e`, `PHASE_A_NOTES.md` |
| **B** | WP-02 | F03, F22, F25 | **External catalog product path retired** (`remediated`/`partial`); live infra decommission needs owner | `71900b4`, `EXTERNAL_CATALOG_DECOMMISSION.md` |
| **C** | WP-03 | F04, F08–F11, F26 | **Mostly done** in WIP (`766bbe8`); F26 still `partial` (context/nav) | `766bbe8` |
| **D** | WP-04 | F05–F07, F16–F18 | **Checkout composition fixed**; F05 staging token `partial`; F16 payment matrix `pending`; F18 profile/deletion still open | `8f765f7` |
| **E** | WP-05 | F12–F15, F18 | **F12/F15 closed** (`0508541`). **F13 partial** (overnight CAA + UI). **F14 fixed** (generation guard + test). F18 overlap with D | `0508541` + overnight F13/F14 |
| **F** | WP-06 | F20–F24 | **Closed as code/reviewable artifacts** — no production deploy | `c6617e0`, `PHASE_F_NOTES.md` |
| **G** | WP-07 | F27–F30 | **Dirty WIP on working tree** (shopper copy, partner hub, privacy migration `012`, engagement/admin routes). **Not committed** at this checkpoint | See `git status` dirty set |

---

## Finding roll-up (tracking matrix cells)

Statuses below are from `F01-F30_TRACKING.md` after overnight F13/F14 update (committed tip may lag Phase G dirty edits).

| ID | Status | Readiness note |
|----|--------|----------------|
| F01 | partial | Backend tests green; owner SQL bootstrap still required |
| F02 | partial | Same as F01 |
| F03 | remediated | App path retired; infra decommission owner-gated |
| F04 | done | Code; needs storefront E2E |
| F05 | partial | Blocks unavailable checkout; staging token empty |
| F06 | fixed | buyerIdentity + invalidate on scope change |
| F07 | fixed | Contact-only; Shopify owns address/shipping |
| F08 | done | Sync delete behavior |
| F09 | done | Pagination honesty |
| F10 | done | Shop-scoped cache/cursor |
| F11 | done | Account isolation for bag/wishlist |
| F12 | closed | Durable webhook inbox |
| **F13** | **partial** | **CAA primary + UI states + refresh; live history unverified** |
| **F14** | **fixed** | **Generation guard + regression test** |
| F15 | closed | Stale mirror overwrite refused |
| F16 | pending | Physical/simulator payment matrix |
| F17 | fixed | Completion clears purchased lines + `loadOrders` |
| F18 | partial | Hosted end-session; profile/deletion open |
| F19 | open | Cell lag vs Phase A notes — treat as owner migration still open |
| F20–F24 | closed | Admin operable in code; prod deploy not done |
| F25 | partial | External semantics leftover / decommission |
| F26 | partial | Commercial context still incomplete |
| F27 | open | Manual apartado/wholesale SOP (Phase G dirty may advance) |
| F28 | partial | Push stack present; device credentials missing |
| F29 | partial | Phase E task/`readyz` baseline; Phase G dirty privacy fulfill |
| F30 | open | CI/integration gates not claimed green |

---

## Overnight F13 work (this follow-up)

### Code

- **Primary source:** `lib/data/customer_auth/customer_orders.dart` — Customer Account GraphQL `customer.orders`.
- **Repository:** `OrderHistoryRepository.refresh` prefers CAA; on CAA success merges **apartados only** from mirror; never maps CAA failure → empty.
- **Statuses:** `empty` | `populated` | `unavailable` | `failed` | `staleCache`.
- **Controller:** `AccountController.ordersStatus`; still refreshes after login/checkout; generation guard discards cross-account responses.
- **UI:** `account_screen.dart` distinct copy + «Actualizar pedidos».
- **Wiring:** `main.dart` constructs `HttpCustomerOrdersService` when Customer Account config is usable.

### Tests run (local)

`flutter test` on:

- `test/data/customer_auth/customer_orders_test.dart`
- `test/data/repositories/order_history_repository_test.dart`
- `test/app/account_controller_test.dart`
- `test/features/account/account_screen_test.dart`

**Result:** all passed in that invocation.

### Still not done for F13

- Live Customer Account session showing **pre-install** Shopify orders.
- Post-checkout order appearance against real shop + optional mirror.
- Proof that staging/prod have required protected-customer / orders access.
- Pagination beyond first page in UI.

---

## Code readiness vs verification layers

| Layer | State |
|-------|--------|
| **Unit / widget (touched F13 paths)** | Green for listed suites above |
| **Backend HTTP/PG tests (Phase A/E commits)** | Previously reported green on those commits; not re-run in this follow-up |
| **Dev / staging Shopify store** | **Not verified overnight.** Staging Storefront token historically empty (F05). CAA client IDs must match shop |
| **Simulator / physical device payments (F16)** | **NOT RUN** |
| **Production canary** | **NOT RUN / BLOCKED** — launch criteria unmet |

---

## Pending owner actions

1. Provision legitimate owners (`admin_principals` / `OWNER_SHOPIFY_CUSTOMER_IDS`) per `PHASE_A_NOTES.md`.
2. Set `LEGACY_ACCOUNT_REGISTRATION_ENABLED=false` in production when ready.
3. Approve external-catalog infra decommission (`EXTERNAL_CATALOG_DECOMMISSION.md`).
4. Populate staging/production Storefront + Customer Account dart-defines (non-empty tokens, real shop id/client).
5. Confirm Customer Account protected data / orders access for the Headless client.
6. Enable and matrix-test payment methods (F16) on iOS + Android.
7. Run privacy export/redact drill and backup restore (F29) when Phase G lands.
8. Firebase/APNs/FCM + App Check for push (F28).
9. Production TOML / deploy decision for admin scopes (F24 closed as artifact only).
10. Commit or reconcile **Phase G dirty tree** before treating WP-07 closed.

---

## J01–J11 journey matrix (honest)

No overnight agent ran live journeys against a development shop, simulator payment sheet, or production canary. Evidence files under `docs/audits/2026-09-07/` are **defect probes**, not acceptance runs.

| Journey | Result | Why |
|---------|--------|-----|
| **J01** Fresh guest shopping | **NOT RUN** | Needs clean install + Storefront-configured build |
| **J02** New Shopify customer | **NOT RUN** | Needs hosted auth + real inbox/callback |
| **J03** Account isolation / lifecycle | **PARTIAL CODE ONLY** | Unit coverage for bag/wishlist isolation + F14 discard; no device race matrix |
| **J04** Legacy account / owner security | **PARTIAL CODE ONLY** | Phase A backend tests; no disposable staging principals exercise logged here |
| **J05** Guest + authenticated test purchases | **NOT RUN / BLOCKED** | Staging token / payments |
| **J06** Checkout failure / recovery | **PARTIAL CODE ONLY** | Coordinator/unit paths; no device matrix |
| **J07** Catalog changes / env transition | **NOT RUN** | Needs authorized dev store fixtures |
| **J08** Owner operations | **PARTIAL CODE ONLY** | Admin UI/API remediated; no operator E2E log |
| **J09** Order lifecycle / resilient events | **PARTIAL CODE ONLY** | F12/F15 unit/inbox; no signed staging webhook replay logged overnight |
| **J10** Notifications / manual ops | **NOT RUN / BLOCKED** | Push credentials; apartado remains manual |
| **J11** Privacy / outage / migration / restore | **NOT RUN / BLOCKED** | Phase G privacy fulfill dirty; no restore drill evidence |

---

## Remaining (priority)

1. **Land Phase G** without clobbering F13 files; reconcile tracking F27–F30 when G commits.
2. **F13 live:** CAA session on staging/prod-like shop; pre-install + post-checkout visibility.
3. **F05/F16:** Storefront token + payment method device evidence.
4. **F18/F19:** Profile/deletion + legacy migration owner path.
5. **F29/F30/J11:** Privacy fulfill commit + CI green + restore rehearsal.
6. **Only then** attempt J01–J11 with written evidence per environment.

---

## Files touched by overnight F13 follow-up (expected commit set)

- `lib/data/customer_auth/customer_orders.dart` *(new)*
- `lib/data/repositories/order_history_repository.dart`
- `lib/app/account_controller.dart`
- `lib/features/account/account_screen.dart`
- `lib/main.dart`
- `test/data/customer_auth/customer_orders_test.dart` *(new)*
- `test/data/repositories/order_history_repository_test.dart`
- `test/app/account_controller_test.dart`
- `test/features/account/account_screen_test.dart`
- `docs/audits/2026-09-07/F01-F30_TRACKING.md` *(F13/F14 + notes only)*
- `docs/audits/2026-09-07/OVERNIGHT_CHECKPOINT.md` *(this file)*

**Do not include** Phase G dirty paths in the F13 commit.
