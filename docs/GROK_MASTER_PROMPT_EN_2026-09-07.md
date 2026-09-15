# Monetta: Complete Flow Remediation and Verification

You are the senior product engineer responsible for implementing, testing, and documenting the remediation of Monetta's functional audit. Execute the work; do not stop after proposing another plan. Prioritize security and commerce correctness, then complete account, administration, and operational flows. Visual redesign comes last and is outside this assignment.

## 1. Read the evidence and establish the baseline

Workspace: `/Users/alexis/develop/monetta-app`.

Read:

- `docs/AUDITORIA_FLUJOS_2026-09-07.md`: findings F01–F30, source evidence, acceptance criteria, and production migration requirements.
- `docs/GROK_HANDOFF_FLUJOS_2026-09-07.md`: implementation sequencing.
- `docs/audits/2026-09-07/README.md`: reproducible audit probes.
- Applicable `AGENTS.md`, actual source code, environment examples, native build configuration, and CI workflows.

The audit used commit `32f846df654705f938c397574081e22da04a8bb6` plus substantial existing uncommitted work. Inspect the current state before editing. Preserve unrelated changes and untracked files. Do not reset, clean, stash, or overwrite the worktree indiscriminately. If you use an isolated checkout, ensure it includes the relevant uncommitted implementation rather than auditing or fixing an older snapshot.

Revalidate findings against current code. Some historical documents describe already-implemented capabilities as missing. Do not rebuild working code based on stale documentation. If a finding is no longer applicable, demonstrate why with source and tests.

Create a tracking document with one row per F01–F30: severity, current status, planned change, regression test, integration/E2E evidence, and unresolved dependencies. Every finding must be explicitly resolved, disproved with evidence, or recorded as pending with a concrete next action.

## 2. Product decisions and scope

1. Monetta sells its own products from the real monetta.mx Shopify shop through official Shopify APIs. No third-party product extraction, crawlers, scraping proxies, external procurement feeds, or replacement extraction servers.
2. Use Shopify Storefront as the authority for the purchasable catalog and carts; Shopify Customer Accounts for customer identity and customer-owned data; Shopify Checkout for payment, shipping, and tax collection. A necessary first-party backend may handle administration, notifications, webhooks, and explicit enrichment. It must not become another product extraction service.
3. Catalog products, variant IDs, buyer identity, and checkout must belong to the same shop. Never attach a staging Storefront token to a cache populated with production variant IDs.
4. Guest shopping and checkout must remain available. Authentication adds capabilities; it is not a purchase wall.
5. Preserve the visual design. Change validation, disabled states, error messages, navigation, or redundant steps when required to fix a flow, but do not spend this assignment redesigning typography, animation, branding, or layout.
6. Preserve real legacy Monetta accounts and their data. Do not drop account tables, bulk revoke owners, or associate accounts merely because their email strings match.
7. This repository's `web/` is a screenshot viewer, and `dashboard/` serves the external catalog monitor. Neither is a complete transactional website. Do not report either as a working customer storefront. If a browser storefront is required, document it as a separate deliverable; do not silently replace the Flutter remediation with a website rewrite.
8. Do not build a second Shopify Admin unnecessarily. Stock management, fulfillment, refunds, payment settings, and other operations may remain in Shopify Admin when that is the explicitly documented operational path.

## 3. Execution boundaries

- Execute local implementation, disposable test-data creation, automated tests, and work against a clearly identified authorized development store. Verify the environment before each mutation.
- Do not create test customers, products, orders, campaigns, or discounts in production during ordinary testing. Do not change production payment mode, install apps, deploy production, perform real charges/refunds, or delete live infrastructure/data without explicit authorization for that operation.
- Before any operational approval request, prepare the actual change, test results, scope, and rollback so approval is the final actionable step.
- Do not expose passwords, OTPs, customer tokens, full checkout URLs, Admin tokens, or secrets in chat, logs, screenshots, or committed fixtures. Use local ignored files or secret stores with restricted access.
- Use only tester-controlled addresses and devices. Do not send messages to real customers, populate marketing audiences with them, or use invented deliverable email addresses.
- When interactive Shopify login requires an inbox, OTP, device permission, or owner action you cannot perform, record the exact step and continue independent work. Never bypass authentication, simulate a real-login success, or claim mock evidence as a real Shopify result.
- No broad dependency upgrades or architecture rewrites unrelated to findings. Verify current official Shopify documentation for the API/SDK behavior you implement.
- Report progress and blockers clearly. Missing credentials do not justify stopping all work; continue code, tests, migrations, validation tools, and documentation that do not depend on them.

## 4. Build a repeatable test environment first

Create setup/seed/cleanup tooling with documented commands. Use disposable local PostgreSQL and isolated Flutter storage for automated tests. Add an explicit development-shop allowlist, expected shop-ID check, and run identifier before remote seed tools are allowed to write. A hostname substring such as “staging” is not sufficient verification.

Use a unique `audit_run_id` and prefix such as `monetta-qa-<run-id>` for test records. Maintain an ignored manifest containing IDs of resources created by this run, their environment, and cleanup status. Cleanup must act only on manifest-listed test resources. Never run an unqualified delete-all against a shared database or Shopify store.

### Required user/persona fixtures

| Persona | Setup | Purpose |
|---|---|---|
| Guest G | Fresh app installation with no account | Guest browsing, wishlist, bag, and checkout |
| Shopify customer A | New customer created through the actual hosted sign-in/sign-up flow using a controlled inbox | Prove first-time onboarding and real authentication |
| Shopify customer B | A separate controlled inbox and Shopify identity | Prove cross-account isolation and account switching |
| Existing customer C | Development-store customer with test orders created before the app's first login | Historical order/backfill verification |
| Legacy customer L | Synthetic legacy Monetta account in disposable PostgreSQL | Password migration, session, and identity-linking tests |
| Owner O | Explicitly provisioned principal tied to a verified identity | Administrative capabilities and operational tests |
| Ordinary user U | Valid authenticated non-owner | Authorization-negative tests |
| Unverified user E | Synthetic local account whose email matches a configured owner email | Reproduce and close unverified-email privilege escalation |
| Revoked owner R | Previously authorized test principal explicitly deactivated | Verify revocation is durable |

Do not assume creating a customer through Admin API proves hosted login or ownership of an email. Seed historical data as needed, but test hosted authentication separately. If Shopify's enabled account flow creates customers at first verified login, test that behavior instead of inventing a password-registration screen.

Store synthetic local passwords outside committed files. Real Shopify verification codes must remain within the authorized tester's authentication process. Record only redacted identity references in evidence.

### Required catalog/order fixtures

- A product with two purchasable variants A/B, distinct prices and identifiable option values.
- An unavailable variant and a product with no available variants.
- A product published to Headless and another not published to that channel.
- Products whose price, availability, publication, and images can be changed during a test.
- A product beyond the first 50 and first 100 admin results.
- A two-page catalog; cover 250/251 products, 21 variants, additional images/collections, repeated cursors, and truncation with fixtures. Use a real multi-page development-store check when practical; do not bulk-create hundreds of remote records unnecessarily.
- Manual `monetta-todays-picks` collection and required editable content/metaobjects.
- Valid, invalid, expired, and inapplicable discount scenarios supported by the test shop.
- Test orders representing pending, paid, fulfilled, cancelled, and refunded states, with at least one historical order owned by C and one order owned exclusively by B.
- Supported shipping address, unsupported destination, and a shipping-rule edge case using synthetic delivery details accepted by the test environment.

Tag remote fixtures for cleanup. Do not place an order that triggers real fulfillment, a production financial transaction, or messages to third parties.

## 5. Implement in dependency order

### Phase A — Close security issues (F01, F02, F19)

- Remove administrative privilege bootstrap from unverified, self-declared emails. Provision owners by stable, verified identity or an explicit server-controlled principal.
- Ensure `/accounts/register` cannot replace an existing account's email, password, Shopify linkage, role, or session simply by supplying its deviceId.
- Separate account creation, authenticated credential changes, session registration, and account linking.
- Validate request types/lengths and rate-limit authentication endpoints. Keep errors useful without leaking credentials or unnecessarily enumerating accounts.
- Preserve legacy account data and implement/document an explicit migration and recovery path. New legacy registrations may be disabled if the product no longer supports them, but existing legitimate users need a tested transition.
- Prepare a reviewable principal/account migration and rollback. Do not silently promote or remove users.

Acceptance: E has no admin capabilities; U receives authorization denial on every privileged route; O succeeds; R cannot regain privileges by logging in again. Reusing L's deviceId cannot alter L. Verify both HTTP boundary behavior and real PostgreSQL persistence, not only mocked repositories.

### Phase B — Remove external-catalog dependencies (F03, F22, F25)

- Remove external catalog runtime calls from startup, home, browse/search, recommendations, product details, notifications, and admin flows.
- Decouple AdminScreen from ExternalCatalogController; remove unconditional `external-status` synchronization.
- Retire monitor-specific flags, build/deploy references, and CI jobs where appropriate. Document live jobs/resources requiring an authorized decommission rather than blindly deleting them.
- Allow coherent Storefront-only staging without a mandatory Firestore mirror. If any first-party mirror remains temporarily, document its limited role and ensure it cannot enlarge the purchasable catalog or substitute another shop.
- Enforce the product decision at runtime/release configuration, including builds that bypass Makefile validation.

Acceptance: start and exercise the app/admin with monitor services unavailable; capture redacted outbound host information showing zero calls to the retired external catalog. No external products appear in any recommendation, alert, or cached navigation path.

### Phase C — Fix catalog, variants, and local data (F04, F08–F11, F26)

- Detect incomplete pagination before implementing destructive full replacement. Abort on truncation, missing/repeated cursors, and incomplete responses without advancing successful-sync metadata.
- Make a verified full sync replace the catalog atomically, including a legitimate empty result. Commit cursor and metadata consistently. Failed partial reads preserve last-known-good data.
- Namespace catalog authority and cursors by shop/environment. Define safe behavior for switching sources and upgrading existing installations.
- Carry the exact selected variantId through product detail, minicart, bag persistence, hydration, and Cart API. Permit separate variants of the same product. Never substitute a different variant automatically when stock changes.
- Implement effective account/guest scoping for wishlist and bag, including database keys, reads/writes, in-memory state, and login/logout merge behavior.
- Refresh general catalog on foreground/manual refresh with single-flight control. Apply market/language context and explicit currency where required.
- Reconcile navigation and collections with the intended Shopify-managed contract; distinguish deliberately local search/recommendations from unused API documents.

Acceptance: A+B full sync followed by B removes A; valid empty removes all; partial failure removes nothing. Selected variant B survives restart and remains B after A changes stock. A and B variants coexist. Customer B never reads or edits customer A's bag/wishlist. Switching shops cannot reuse old variant IDs or cursors.

### Phase D — Complete authentication, checkout, and confirmation (F05–F07, F16–F18)

- Detect unavailable checkout before collecting delivery data.
- Authenticate Shopify buyerIdentity using a valid Customer Account token when logged in; preserve guest checkout. A local authenticated storage scope is not Shopify buyer authentication.
- Remove redundant delivery capture or transmit it through a supported Shopify contract. Shipping/tax/discount totals must come from Shopify; estimates must be clearly distinguished.
- Rebuild current intent immediately before checkout, reconcile changed stock/prices, and preserve the strict checkout URL policy. Explicitly validate actual checkout hosts; do not introduce arbitrary URL redirects or wildcard allowlists.
- Handle token refresh, expiry/revocation, account switching, hosted logout, local cleanup, and invalidation of preloaded checkout from the previous identity.
- Fix completion behavior: refresh order information, show a truthful result, retain unpurchased/newly added lines, and recover appropriately after browser fallback or process interruption.
- Verify offsite/3DS/wallet behavior for methods actually enabled in the shop. Successful checkout completion, order creation, pending payment, and settled payment are distinct states.
- Provide profile/address management and account deletion through implemented functionality or a verified authenticated hosted flow. A dead link or undocumented manual promise is not completion.

Acceptance: first-time A and returning A can buy; G can buy without login; B never inherits A's authenticated checkout. Address is not unnecessarily collected twice. Cancellation/rejection preserves intent. Double tap or ambiguous timeout does not duplicate purchases. Hosted logout permits switching to B.

### Phase E — Make orders and webhooks reliable (F12–F15, F17, F29)

- Implement durable processing with recoverable pending/failed states, transactional effects or equivalent guarantees, and concurrent duplicate protection.
- A claimed but failed event must be retried. A completed event must not duplicate effects.
- Validate the expected shop and isolate environment data/secrets, especially destructive shop redaction.
- Prevent out-of-order events from regressing financial/fulfillment state. Add canonical reconciliation and historical recovery where needed.
- Prefer Customer Account API for customer order history; if retaining a mirror as the source, implement tested backfill and periodic reconciliation with the required permissions.
- Separate empty, unavailable, failed, and stale-cache UI states. Refresh after checkout and on explicit user action.
- Cancel/discard stale account-bound requests so A's delayed response cannot populate B's screen or repopulate data after logout.
- Provide order details/status/tracking or a verified secure portal path. Clearly document where cancellation, return, refund, and invoice requests are actually handled.

Acceptance: C sees pre-existing orders; A never sees B's order; paid→refunded→old paid remains refunded. Inject failures after event claim and after each persistence step; retry/restart recovers. Database state and API results agree. Invalid HMAC and a correctly signed wrong-shop test event cannot alter the configured shop.

### Phase F — Complete administrative operations (F20–F24)

- Drive UI capabilities from `/admin/me`; authorize every action server-side.
- Paginate product lists/search beyond 50/100. Distinguish loaded count from total.
- Preserve optimistic-concurrency and idempotency guarantees; handle partially successful compound edits truthfully.
- Refresh shopper HomeContent after content writes; validate actual metaobject namespace/access/publication under the credentials used by each side.
- Follow featured-collection reorder jobs to a terminal state and reload canonical membership/order.
- Define sync job completion as completed useful work, not a single page read or HTTP 202. Persist/recover interrupted jobs.
- Prepare production Shopify app configuration, minimal scopes, Headless publication ID, collection/content resources, and uninstall lifecycle handling. Do not deploy production automatically.
- Document operations intentionally left in Shopify Admin, including stock/location management, product media, fulfillment, refunds, and payment settings.

Acceptance: O edits product 51/101; U cannot. Conflicting edits are rejected/reconciled without silent overwrite. Retrying a mutation does not duplicate it. Another customer device sees saved content and featured changes. Sync works without the retired monitor and recovers after server restart.

### Phase G — Notifications, manual business flows, operations, and CI (F27–F30)

- Verify push registration, App Check, APNs/FCM, consent, token rotation, worker delivery, audience isolation, deep links, and cancellation/reporting paths retained in the product.
- Fix collection routing to use the intended collection identity. Remove external-catalog event sources and misleading post-purchase reminders.
- Use a strictly isolated test campaign audience. Do not use production customer lists.
- Document apartado and reseller flows: WhatsApp opening does not reserve stock, charge a deposit, create an order, approve reseller status, or calculate a commission ledger. Ensure the visible promises match the implemented/manual process.
- Verify supplied support/catalog links and access requirements. Apply restricted reseller access only if the business requires it; do not invent a wholesale program.
- Implement data-request export/redaction tracking with a responsible operator and durable completion evidence. Test retention/deletion boundaries across every retained store.
- Add database readiness, error/webhook lag alerts, privacy-safe commerce telemetry, backup/restore verification, and rollback instructions.
- Fix formatting/analyzer failures and missing integration-test infrastructure. Correct the CI fixture exception narrowly without weakening secret scanning. Remove retired service gates intentionally and use a reproducible toolchain.

Acceptance: test device receives an opted-in notification; opt-out prevents subsequent marketing delivery; wrong/expired device credentials fail; deep links open correct resources after cold start. Export/redaction completes for a synthetic user without deleting another. DB outage fails readiness. A backup restores into a disposable DB with verified records. All retained CI gates pass.

## 6. Mandatory end-to-end journeys

For every journey, record environment, commit/build, device/platform, fixture IDs, exact steps, expected result, actual result, and sanitized evidence. Mark each as PASS, FAIL, BLOCKED, or NOT RUN. Automated assertions and manually observed steps must be identified separately.

### J01 — Fresh guest shopping

Install with clean storage → complete/skip onboarding → browse and search → filter a collection → open two-variant product → select B → add B → add A separately → change quantities → favorite product → restart → verify exact variants, quantities, and favorites → remove a line → proceed to checkout without signing in.

### J02 — Create a real new Shopify customer

Use a fresh controlled inbox → invoke hosted sign-in/sign-up from the app → complete verification through the authorized inbox → return via native callback → confirm exactly one account and expected shop identity → verify no admin capabilities → restart and restore session → log out through the supported complete flow → sign in again. Repeat callback validation on both iOS and Android. Also test cancellation, wrong/expired code as permitted by Shopify, and offline interruption without automating abusive repeated attempts.

### J03 — Account isolation and lifecycle

As A, save wishlist/bag and view an A-owned order → start a deliberately delayed refresh → logout → login as B → release A's delayed response → verify no A data appears. Repeat after app restart, token expiry/revocation, and secure-storage removal. Verify guest merge happens once and does not merge another account's records. On a second device, explicitly verify the documented cross-device behavior; do not claim local-only data is synchronized.

### J04 — Legacy account and owner security

Create L in disposable backend storage → authenticate legitimately → attempt registration using L's deviceId with different credentials → verify original account unchanged. Create E → attempt all admin endpoints → verify denial. Provision O → verify authorized operations. Revoke R → logout/login/retry privileged operations → verify denial. Exercise migration/linking with mismatching and unverified identity data; no ownership transfer without proof.

### J05 — Successful guest and authenticated test purchases

For G and A separately: add exact variant and quantity → apply valid discount → use supported test address → complete a Shopify-supported test payment → confirm one order in Shopify → verify line IDs, quantities, currency, discounts, shipping, taxes, totals, and inventory → verify proper pending/paid state → confirm customer-visible order result and history when attributable to an authenticated customer. Do not assume arbitrary guest orders become visible to an unrelated account.

### J06 — Checkout failure and recovery

Exercise invalid/inapplicable discount, price change, sold-out variant, insufficient stock, unsupported address, declined test payment, cancel, double tap, expired cart, transient outage, lost mutation response, background/foreground, force-close/relaunch, offsite payment return, and browser fallback. Confirm no silent variant replacement, false “paid” state, unintended bag loss, or duplicate order. Assert any order created despite response loss is recovered rather than blindly purchased again.

### J07 — Catalog changes and environment transition

In authorized development store: create/publish fixture → verify app → edit price/media → verify refresh → unpublish from Headless → verify removal → republish → verify return. Simulate full-empty and truncated pagination locally. Switch app from isolated shop/config A to B and prove no reuse of A's catalog, cursor, OAuth tokens, or cart. Inspect outbound hosts for retired external-catalog traffic.

### J08 — Owner operations

Login O → find product outside initial page → edit supported fields → resolve a concurrent edit conflict → publish/unpublish test product → change featured membership/order → change announcement → verify on another shopper device → trigger sync with monitor absent → interrupt/restart backend during a job → verify terminal recovery and audit trail. Attempt the same mutations with U and an expired token; verify no writes.

### J09 — Order lifecycle and resilient events

Use test order → update fulfillment/tracking → perform supported test cancellation/refund without real funds → verify customer-visible state. Send signed local/staging fixtures for duplicate, malformed, wrong-shop, out-of-order, and interrupted deliveries. Restart workers and replay pending events. Compare final DB/API state with Shopify's canonical state or the deterministic fixture. Verify C's pre-installation order history independently of newly received webhooks.

### J10 — Notifications and manual operations

Register controlled device → grant permission and category consent → send only a test-audience campaign → open product and collection from cold start → rotate token → withdraw consent → verify suppression. Walk apartado/reseller paths without sending unsolicited messages; inspect the prepared message/share payload and verify the documented operator procedure using test records. Send only to an explicitly authorized test recipient if delivery itself is being tested.

### J11 — Privacy, outage, migration, and restore

Create synthetic user with data in all retained stores → generate export → request deletion/redaction → run/retry jobs → verify expected removal/retention and no effect on another user. Run migrations on empty and representative pre-upgrade databases; verify bag/variant/account references. Stop PostgreSQL → verify readiness/failure states → restore backup into a different disposable database → verify counts, ownership, pending jobs, and recovery. Do not mistake a successful backup command for a successful restore drill.

## 7. Verification layers and commands

Use all layers: unit/domain tests; HTTP authorization/contract tests; integration tests with real local PostgreSQL and migrations; Flutter widget/integration tests; actual development-store API journeys; native simulator/emulator builds; physical iOS/Android for hosted authentication, Checkout Kit, payments, and push where those capabilities require device validation.

For the six audit defects, add regression tests that demonstrate failure before the fix and pass afterward. Do not simply retain the audit probes' expectations of broken behavior.

Baseline commands, adjusted only if a component is intentionally retired:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
npm --prefix services/accounts_orders run typecheck
npm --prefix services/accounts_orders test
npm --prefix services/accounts_orders run build
npm run typecheck:api
npm run test:api
npm --prefix functions run typecheck
npm --prefix functions test
npm run build:web
./bin/check_no_secrets.sh
```

Add documented commands for seed/cleanup, database integration tests, migration upgrade/restore, Flutter integration tests, and native builds. Read current Makefile/native schemes before choosing commands; do not assume iOS and Android use identical flavor names. Capture actual exit codes—piping or appending `tail` must not turn a failed test into a successful result.

The historical baseline was 610 passing existing tests, 20 analyzer observations, format failures, missing integration_test, and a secret-check false positive for a public CI fixture. It is not proof that new code or checkout works. Do not keep retired tests solely to preserve the count, and do not claim physical-device validation from a simulator compile.

## 8. Prepare the production transition

Verify actual shop identity rather than relying on aliases in old documents. The audit observed production Customer Account shop ID `72391655575` and staging `90228850722`; reconfirm before setup.

Prepare a production readiness matrix covering:

- Canonical shop hostname and branded domain, public Storefront token, API version, MX/ES context, and Headless product publication.
- Production Customer Account Mobile client, exact native callback, customer-data permissions, and hosted identity/logout endpoints.
- Existing Android/iOS flavor/build settings, bundle/application IDs, signing, and installation isolation.
- Shop-scoped cache migration and no staging session/cart/token reuse.
- Real backend HTTPS host, separate database, secrets, owner principal, write flags, minimal scopes, webhook subscriptions, and uninstall lifecycle.
- Featured collection, editable content definitions/access, reviews, support links, and any retained Firebase/push configuration.
- Actual checkout host allowlist, supported payment methods, shipping coverage/tariffs, taxes, currency, inventory behavior, transactional notifications, and policies.
- Monitoring, backups, restore evidence, rollback, and responsibilities for support/fulfillment/refunds.

Prepare, but do not automatically execute, an owner-authorized production canary on both platforms with a low-value real order and approved cancellation/refund procedure. Test mode must never be enabled on the live shop as a shortcut for staging tests. Production cannot be declared verified until the approved canary evidence exists.

## 9. Final deliverables and definition of done

Deliver:

1. Implementation changes grouped by phase with commit/file references and preserved unrelated work.
2. F01–F30 coverage matrix with evidence and any remaining dependency.
3. J01–J11 results, clearly separated by mock, local integration, development shop, simulator/emulator, physical device, and production canary.
4. Repeatable fixture/user creation and cleanup commands, safe environment guards, and sanitized resource manifest/report. Keep test credentials out of Git.
5. Migration and rollback instructions for accounts, roles, variants, cache namespaces, and webhook processing.
6. Environment/secret requirements by name, plus exact owner actions still needed. Do not ask for secrets in chat.
7. Test commands, exit codes, failures resolved, remaining unexecuted tests, and evidence paths.
8. Updated operational procedures for checkout recovery, order support, apartados, reseller inquiries, notifications, privacy requests, and incident recovery.
9. Explicit conclusion: code readiness, development-store verification, and production verification are separate statuses.

Do not mark the project complete while a finding is silently omitted. Do not claim all flows work because tests compile, endpoints return 200, or a checkout page opens. Completion requires demonstrated user outcomes, authorization boundaries, recoverable failures, correct shop/variant/order ownership, and the audit's launch criteria. If time expires, leave a precise continuation checkpoint and truthful pending-work list rather than weakening acceptance criteria.
