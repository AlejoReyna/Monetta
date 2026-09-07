# Overnight checkpoint — 2026-09-07 (closeout refresh)

**Branch:** `monetta/audit-remediation-wip`
**Tip:** `b19da2a50aaa8c3eb2344f917cf9e89208f6d8f4` (Phase G landed)
**Timezone for wall-clock notes:** America/Monterrey (UTC-6)
**Purpose:** Honest status for phases A–G, code readiness vs store verification, owner actions, and J01–J11. This file is **not** production launch approval.

---

## Executive read

Code remediation on this branch is **substantially advanced** for identity, catalog retirement, checkout composition, admin operability, webhook durability, privacy fulfill API, and CI fixture hygiene. **It is not production-ready.** Staging Storefront token / Customer Account live credentials, payment-device matrix, privacy export/restore drill, and live J01–J11 evidence are still missing.

Phase G is **committed** at `b19da2a` (no longer dirty WIP). Closeout docs: `J01-J11_RESULTS.md`, `FINAL_DELIVERABLES.md`.

---

## Phase map (A–G)

| Phase | WP | Findings (primary) | Status | Anchor commits / notes |
|-------|----|--------------------|--------|-------------------------|
| **A** | WP-01 | F01, F02, F19 | **Code remediated**; owner provisioning + prod flag remain | `2350c3e`, `PHASE_A_NOTES.md` |
| **B** | WP-02 | F03, F22, F25 | **External catalog product path retired**; live infra decommission owner-gated | `71900b4`, `EXTERNAL_CATALOG_DECOMMISSION.md` |
| **C** | WP-03 | F04, F08–F11, F26 | **Mostly done**; F26 still partial | `766bbe8` |
| **D** | WP-04 | F05–F07, F16–F18 | **Checkout composition fixed**; F05 staging token partial; F16 pending; F18 profile/deletion open | `8f765f7` |
| **E** | WP-05 | F12–F15, F18 | **F12/F15 closed**. F13 partial (CAA UI). F14 fixed. | `0508541` + `300e49f` |
| **F** | WP-06 | F20–F24 | **Closed as code/reviewable artifacts** — no production deploy | `c6617e0`, `PHASE_F_NOTES.md` |
| **G** | WP-07 | F27–F30 | **Committed** — SOP/copy, deep links, privacy fulfill, CI fixture gates | `b19da2a`, `PHASE_G_NOTES.md` |

---

## Finding roll-up (tracking matrix cells after closeout)

| ID | Status | Readiness note |
|----|--------|----------------|
| F01 | fixed | Code + tests; owner SQL bootstrap still required |
| F02 | fixed | Register conflict 409; no deviceId credential overwrite |
| F03 | remediated | App path retired; infra decommission owner-gated |
| F04 | done | Selected variant persists |
| F05 | partial | Blocks unavailable checkout; staging token still required |
| F06 | fixed | buyerIdentity + invalidate on scope change |
| F07 | fixed | Contact-only; Shopify owns address/shipping |
| F08 | done | Full sync replace/delete behavior |
| F09 | done | Pagination honesty |
| F10 | done | Shop-scoped cache/cursor |
| F11 | done | Account isolation for bag/wishlist |
| F12 | closed | Durable webhook inbox |
| F13 | partial | CAA primary + UI states; live history unverified |
| F14 | fixed | Generation guard + regression test |
| F15 | closed | Stale mirror overwrite refused |
| F16 | pending | Physical/simulator payment matrix |
| F17 | fixed | Completion clears purchased lines + loadOrders |
| F18 | partial | Hosted end-session; profile/deletion open |
| F19 | partial | Hardening + flag present; prod disable + legacy migration owner path |
| F20–F24 | closed | Admin operable in code; prod deploy not done |
| F25 | partial | Storefront authority; Firestore optional leftover |
| F26 | partial | Commercial context still incomplete |
| F27 | partial | Honest SOP + copy; manual ops by design |
| F28 | partial | Deep links + external rejection; device push credentials missing |
| F29 | partial | Privacy fulfill/list + readyz; export/restore drill pending |
| F30 | partial | integration_test harness + CI fixture exception; full suite green not claimed this closeout |

---

## Closeout local evidence (tip b19da2a)

| Check | Exit |
|---|---:|
| accounts_orders typecheck | 0 |
| accounts_orders vitest (86 tests / 17 files) | 0 |
| bin/check_no_secrets.sh | 0 |
| Focused flutter subset | 0 |

Full flutter/CI suite: **not claimed** from subset runs.

---

## Code readiness vs verification layers

| Layer | State |
|-------|--------|
| **Code readiness** | Substantially remediated on branch; remaining partials listed above |
| **Dev / staging Shopify store** | **Not verified.** Staging Storefront token historically empty (F05). |
| **Simulator / physical payments (F16)** | **NOT RUN** |
| **Production canary** | **NOT RUN / BLOCKED** |

---

## Pending owner actions

1. Provision legitimate owners (PHASE_A_NOTES.md).
2. LEGACY_ACCOUNT_REGISTRATION_ENABLED=false in production when ready.
3. Approve external-catalog infra decommission.
4. Populate staging/production Storefront + Customer Account dart-defines (same shop).
5. Confirm CAA protected data / orders access.
6. Payment method matrix on iOS + Android (F16).
7. Privacy export/redact drill + backup restore (F29/J11).
8. Firebase/APNs/FCM + App Check for push (F28).
9. Production TOML / deploy decision (F24 artifact only).
10. Separate authorization for any real canary charge/refund.

---

## J01–J11

Authoritative table: `J01-J11_RESULTS.md`. No live journey PASS this closeout. PARTIAL CODE ONLY for J03/J04/J06/J08/J09; NOT RUN J01/J02/J07; BLOCKED J05/J10/J11.

---

## Remaining (priority)

1. Staging credentials + same-shop Storefront/CAA (unlocks J01/J02/J05).
2. F16 device payment evidence.
3. F13 live history + post-checkout appearance.
4. F29/J11 restore drill.
5. Only then attempt full J01–J11 with written evidence per environment.

---

*Refreshed at audit closeout. Prior checkpoint claimed Phase G dirty; that is obsolete after `b19da2a`.*
