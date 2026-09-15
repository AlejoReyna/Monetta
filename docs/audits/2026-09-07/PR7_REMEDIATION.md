# PR #7 remediation report

Base and verified PR head: `5393ff818b50dc114b7b8a2a21a797d6d57ce4ed`.
Branch: `monetta/audit-remediation-wip`. Existing main.dart/startup reveal and .opencode work is preserved.

| Finding | Root cause | Implementation | Regression/verification | External dependency |
|---|---|---|---|---|
| R1 | Nested page limits treated as fatal | Six-image preview; fully fetch variants/collections for full and featured cache writers | Local regression: 51 variants, 26 collections, later failure | Authorized Storefront catalog |
| R2 | Null/malformed connection accepted as empty | Strict connection/page validation; atomic full cache/cursor commit | Local regression: malformed/empty/later pages | None for local |
| R3 | Null provenance treated as matching shop | Transactional migration before startup hydration; revoke local session references; new cart namespace | Local regression: actual v5 upgrade, restart/failure and legacy auth without cache | Canonical production identity and same-shop credentials |
| R4 | Busy claim indistinguishable from complete | PostgreSQL advisory ownership; busy fails HTTP, disconnect allows retry | Local regression: real disposable PG crash/retry/concurrency | Deployed signed delivery/retry journey |
| R5 | Completion uses active account and deletes whole lines | Immutable purchase scope/quantities, transactional receipt and subtraction | Local regression: account switches/duplicate/quantity | Device Checkout Kit test purchase |
| R6 | One page replaces whole history | Complete validated pagination before cache replacement | Local regression: 0/26/60/later failure | CAA credentials/protected order access |
| R7 | Concatenation, display number used as identity | Canonical merge, separate display and fulfillment fields, composite cache key | Local regression: enrichment/cross-account | Live mirror + CAA |
| R8 | Empty cache treated as never initialized | Persisted Shopify authority prevents asset reseeding | Local regression: empty restart/offline/recovery | None for local |

Flutter baseline: supported pin **3.44.8** (local installed stable SDK), shared by `.fvmrc` and CI. This removes the prior floating-stable discrepancy; no claim about a 3.47.2 run.

No CI run, live journey, deployment, merge, production traffic change, real payment, or external message is claimed or authorized by this report.

## Verified outcomes (2026-09-07)

Implementation and local regression work for R1–R8 is present in the working tree.
The independent probes remain unchanged as historical defect evidence; newly
added/updated tests assert correct behavior. No CI or development-Shopify PASS is
claimed. Existing and concurrently edited startup-reveal files are preserved.

| Area | Local evidence | CI | Development Shopify / device |
|---|---|---|---|
| R1/R2 | Nested 51 variants, 26 collections; six-image preview of seven-image product; malformed connection matrix; later required-page failure; cache/cursor preservation | NOT RUN | BLOCKED: Storefront token |
| R3 | Actual schema-5 bag/wishlist keys and missing provenance upgraded; recent legacy cursor; failed first sync; reopen/offline/full recovery; empty cache with legacy account/session references | NOT RUN | BLOCKED: coherent canonical-shop credentials |
| R4 | 90 backend tests include **six real PostgreSQL tests**: interrupted claim, signed busy HTTP 503, completed HTTP 200, concurrent duplicates, effect failure/retry, stale order, and burst/pool capacity | NOT RUN; PG service and mandatory failure gate implemented | NOT RUN against deployed webhook endpoint |
| R5 | Delayed native-result fake; immutable A scope while B active; A→guest; same variant in B; added quantities/unrelated items; lower quantity clamp; duplicate receipt; rollback on failed receipt write and retry without reopening payment | NOT RUN | BLOCKED: test-mode Checkout Kit/device journey |
| R6 | 0/26/60 orders; unique IDs; cursor advance; second-page failure and full retry; cached-history failure behavior; controller account-generation guards | NOT RUN | BLOCKED: authenticated CAA order access |
| R7 | Canonical numeric/GID merge; differing display number; CAA status/amount authority; optional mirror failure; account-composite cache key | NOT RUN | BLOCKED: CAA + mirror |
| R8 | Confirmed empty result survives seed/repository reopen offline; later products recover; existing first-install offline asset tests | NOT RUN | NOT RUN live |

### Commands and observed results

All commands ran from `/Users/alexis/develop/monetta-app` unless `--prefix` says otherwise.

| Command | Observed result |
|---|---|
| `flutter --version` | Flutter 3.44.8 / Dart 3.12.2 |
| `dart run build_runner build --delete-conflicting-outputs` | Exit 0; Drift schema-7 generated code updated |
| `flutter pub get --offline` | Exit 0; existing crypto 3.0.7 made a direct dependency for non-secret receipt hashing |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Exit 0 / 245 files, zero changes before final added test formatting |
| `flutter analyze --no-pub` | Exit 0, no issues before final edge-case addition; final recheck recorded below |
| `flutter test --no-pub --reporter expanded` | **545 passed, zero failures** (latest full suite before final pending-recovery scope message; focused recheck below) |
| `REQUIRE_POSTGRES_TESTS=1 npm test --prefix services/accounts_orders` | **90 passed / 18 files / zero skips**, including six disposable PostgreSQL tests |
| `npm run typecheck --prefix services/accounts_orders` | Exit 0 |
| `npm run build --prefix services/accounts_orders` | Exit 0 |
| `node --test tools/audit/test/*.test.mjs` | **8 passed, zero failures/skips**; mocked official-API contracts |
| `services/accounts_orders/node_modules/.bin/tsx tools/audit/localAccounts.mts` | Five local personas registered/logged in through real HTTP; ordinary-user/admin revocation assertions passed |
| `./bin/check_no_secrets.sh` | Exit 0; CI fixture validated, no private secret patterns |
| `dart run bin/verify_catalog_snapshot.dart` | Exit 0; 145 products / 404 images (bundled asset only, not a live inventory count) |
| `flutter build ios --simulator --debug --no-pub --dart-define-from-file=config/dart_defines.ci.json` | BLOCKED/failed twice by local storage exhaustion, including ENOSPC; no iOS build PASS |
| `flutter build apk --debug --flavor staging --no-pub --dart-define-from-file=config/dart_defines.ci.json` | Initial storage failure; second attempt exposed disabled AGP resource generation; fixed `buildFeatures.resValues=true`; third attempt stopped when disk again fell below 500 MB. No Android build PASS |
| `flutter test integration_test/app_smoke_test.dart -d <isolated-simulator> --dart-define-from-file=config/dart_defines.ci.json` | NOT RUN: native-build disk-capacity blocker; code now launches the actual app, navigates catalog/filter UI, and checks unavailable auth |

The first Flutter pass was 520 passed/one failing old fixture without metadata;
new regressions caught a connection-shape mistake before final verification.
Initial backend crash tests exposed asynchronous PG termination/unlock timing;
explicit termination wait, transaction completion, and connection ownership were
fixed. One run under native-build disk pressure failed PG setup timeout; final
mandatory-PG rerun passed with zero skips. None of these failed runs is counted
as acceptance evidence.

## Fixture and journey evidence

Run `20260907203118-df12eabc`: local ephemeral HTTP server and disposable PostgreSQL,
five synthetic personas L/U/E/O/R, POST registration 201 and login 200. Ordinary
users and revoked R receive 403 on `/admin/products`; O has explicit owner
capabilities. `/admin/me` correctly returns capability discovery to authenticated
ordinary users too, without granting administration. Database was dropped at run
end; no credentials retained. Ignored manifest contains actual local fixture IDs.
This is **local legacy-account journey evidence**, not J02 hosted login PASS.

Shopify A/B hosted login, controlled-inbox verification, session expiration/device
restoration, guest/authenticated test payments, rejection/interruption/payment-
method matrix, real order history >25, deployed signed events, live admin, privacy
export, backup restore and production transition remain **BLOCKED / NOT RUN**.
The real app integration test is implemented but unexecuted on device. No fixture
or mocked integration test is labeled a live journey PASS.

See [tools/audit/REMEDIATION_USAGE.md](../../../tools/audit/REMEDIATION_USAGE.md)
for runnable official product/customer/test-order adapters, guarded publication/
refund/fulfillment/cancel operations, manifest recovery, and local personas.
Hosted A/B require the supported app OAuth/PKCE flow; no hosted verification is
bypassed. Planned shipping/discount/device scenarios stay planned. `created` is
reserved for an actual returned/recovered resource ID; publication/terminal-state
readiness is separate. No live Shopify fixtures were created in this task.

## Canonical identity evidence and precise owner actions

Read-only Shopify discovery from `https://monetta.mx/.well-known/openid-configuration`
returned issuer `https://shopify.com/authentication/72391655575` and authorization
host `clientes.monetta.mx`. The Customer Account discovery document returned
`https://clientes.monetta.mx/customer/api/2026-07/graphql`. This verifies the numeric
Shopify authentication identity behind the branded production host. It does
**not** establish the permanent `*.myshopify.com` domain, Admin installation,
Storefront publication, or usable coherent credentials. No hostname was changed.

Configuration presence check (values never printed): staging
`SHOPIFY_STOREFRONT_ACCESS_TOKEN` and `ACCOUNTS_ORDERS_BASE_URL` are empty. Mobile
Customer Account client/shop values exist but were not exercised. Audit
`AUDIT_SHOP_DOMAIN`, `AUDIT_ADMIN_ACCESS_TOKEN`, `EXPECTED_SHOP_ID`,
`AUDIT_SHOP_ALLOWLIST`, and authorized environment are absent. Existing backend
`.env` has app-client credentials but no configured shop identity; it was not used
for shared/production DB or Shopify access.

Owners must:

1. Free sufficient local disk capacity (recommend at least 10 GB) or run the pinned
   CI native-build jobs, then run the actual integration test on an isolated
   simulator. Never use an existing personal-device installation for destructive
   fixture reset. No device was reset/installed by this task.
2. Supply an authorized **development** permanent shop domain, offline Admin
   token/scopes, exact live shop ID allowlist, publication ID, and controlled C
   inbox to run fixtures. A/B need separate controlled inboxes plus configured
   mobile client/callback and device hosted login.
3. Verify production `shop { id myshopifyDomain primaryDomain { host } }` through
   authorized Admin configuration/API and reconcile it to shop 72391655575.
   Verify Storefront channel publication, CAA protected order access, callback
   schemes, Admin install and signed webhook host all refer to that same shop.
4. Run test-mode checkout/device matrix and validate orders against Shopify;
   browser return remains insufficient proof of payment. Run privacy/export and
   restore drills per operational runbooks. Provision/revoke real dev admins via
   explicit principal ownership; never infer ownership from email.
5. Run CI on a commit containing these changes. CI evidence is currently NOT RUN.
   No deploy, merge, production mutation, traffic switch, real charge, external
   message or PR review was performed.

## Migration and rollback

SQLite schema **7** adds transactional checkout receipts and separate display/
fulfillment fields; order-cache key becomes `(id, accountId)`. Existing cache rows
are copied, with legacy CAA display-number IDs converted from their canonical
row GID. Tests recreate actual v5 key/nullable-provenance definitions before
upgrading. Unknown/foreign shop state is cleared transactionally before startup
hydration: catalog, cursor, bag/wishlist, sessions/accounts, order cache and
interactions. The migration marker prevents bundled products from returning
while the first full new-shop sync fails. Same-shop required-page failures retain
last successful data/cursor. Full-sync replacement and cursor commit together.

Secure cart storage uses a new **v2** shop/account namespace. Old cart entries and
auth token references cannot be reused; removed auth references leave secure
orphan values unreachable (no secret copied to SQLite). Users must sign in again
after a shop migration. Back up the local DB for diagnostic/dev rollback first;
an older binary must not be opened on schema 7. Roll back by restoring a matching
pre-upgrade DB/build together, then require shop verification/full sync again.
Do not restore staging credentials or IDs into a production configuration.

A checkout removes `min(current quantity, purchased quantity)` in its captured
scope. Added quantities and unrelated lines survive; decreased quantities clamp
to zero. Receipt and subtraction are one transaction; failed writes roll back.
An in-process completion retry retains the captured callback and cannot open a
second payment or report A's recovery as B's purchase. Device termination before
a confirmed native completion is durably recorded still requires the unexecuted
SDK/Shopify reconciliation journey; no browser-return payment inference was added.

Backend recovery uses transaction advisory locks/HTTP retries, not a payload queue.
See [ACCOUNTS_ORDERS_OPS.md](ACCOUNTS_ORDERS_OPS.md#pr7-r4-recovery-update-supersedes-the-five-minute-claim-policy).
No backend migration was added. Drain old workers before rollout; mixed old/new
claim protocols are unsafe. Retain idempotent business keys and upstream retry/
operator replay procedures. This task performs no rollout.

## Official schema references checked

Customer Account API **2026-07**: [Customer.orders arguments](https://shopify.dev/docs/api/customer/latest/objects/Customer),
[Order fields](https://shopify.dev/docs/api/customer/latest/objects/Order), and
[PageInfo](https://shopify.dev/docs/api/customer/latest/objects/pageinfo) support
`first/after`, canonical `id`, separate `name/number`, statuses, and total price.
The live discovered endpoint is versioned 2026-07. A token-authorized live query
is still blocked, so this is reference-schema verification, not live acceptance.

Fixture APIs: [productSet](https://shopify.dev/docs/api/admin-graphql/latest/mutations/productSet),
[orderCreate](https://shopify.dev/docs/api/admin-graphql/latest/mutations/orderCreate),
[orderCreate input](https://shopify.dev/docs/api/admin-graphql/latest/input-objects/OrderCreateOrderInput),
[orderDelete](https://shopify.dev/docs/api/admin-graphql/latest/mutations/OrderDelete).
