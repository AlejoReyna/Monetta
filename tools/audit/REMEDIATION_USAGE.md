# Runnable remediation fixtures

Default remains dry-run. Never load the production backend `.env` into this CLI.

## Local personas: real registration and login

Run `services/accounts_orders/node_modules/.bin/tsx tools/audit/localAccounts.mts`.
It creates a uniquely named database on **loopback PostgreSQL only**, applies the
real migrations, starts the actual HTTP server on a loopback ephemeral port,
registers/logs in L/U/E/O/R, checks capability discovery and ordinary-user denial
on `/admin/products`, provisions local O/R principals, then verifies R revocation.
It closes the server and drops only the database it created. Credentials are
never printed or persisted. The ignored run manifest preserves sanitized IDs
and observations. Every invocation is a fresh disposable journey.

`WP01_PG_ADMIN_URL` may select the local administrative connection. No remote
host is accepted. This is legacy Monetta registration evidence, **not** Shopify
hosted authentication or production owner provisioning. The Shopify token
verifier is intentionally unavailable in this isolated legacy journey.

## Development Shopify resources

Configure the names in `env.example`. Set `AUDIT_ENVIRONMENT=development` (or
`staging`) and authorize an exact shop ID in the allowlist. The live Admin API
must independently report the expected ID, permanent domain, and a development
plan. The production `monetta.mx` target is refused. No strings-only guard can
open the mutation path. No live request was made in this remediation run.

```
node tools/audit/bin/audit.mjs init --env development
node tools/audit/bin/audit.mjs seed --run-id <id> --live
node tools/audit/bin/audit.mjs status --run-id <id>
node tools/audit/bin/audit.mjs cleanup --run-id <id> --live
```

Implemented adapters create tagged products with two distinct-price variants,
zero-inventory tracked unavailable variants, a run-specific collection, a
controlled-inbox historical customer C, and explicitly **test** pending/paid
orders (including history for recorded C/B identities). Order writes disable
receipts and inventory changes and send no real payment transaction. They are
fixtures, never evidence that checkout collected payment. `created` means an
actual ID was returned or recovered by exact run tag; scenario readiness is
separate (`fixture_ready`, blockers). Published-product scenarios need the
publication operation below. No arbitrary mutation document is accepted by CLI.

Hosted A/B creation stays in the app's supported OAuth/PKCE flow with separate
controlled inboxes. Missing inbox/mobile-client/callback setup is **BLOCKED**;
Admin customer creation is never substituted for that journey. Guest requires a
fresh disposable simulator installation. Pagination is covered with local
51-variant/26-collection and 26/60-order fixtures instead of mass remote writes.
Shipping and discount matrices need authorized shop configuration and device
checkout; planned manifest entries are not reported as created.

## Product publication and test-order lifecycle

All operations require `--live`, matching verified manifest shop, exact run tag,
and manifest resource ID. For product publication, `AUDIT_PUBLICATION_ID` must
resolve on the live verified development shop.

```
node tools/audit/bin/audit.mjs operate --run-id <id> --resource product:headless-published --action publish --live
node tools/audit/bin/audit.mjs operate --run-id <id> --resource order:paid --action cancel --live
node tools/audit/bin/audit.mjs operate --run-id <id> --resource order:paid --action fulfill --fulfillment-order-id <actual-id> --live
node tools/audit/bin/audit.mjs operate --run-id <id> --resource order:paid --action refund --transaction-id <actual-test-transaction-id> --amount 1.00 --live
```

Refunds require an actual successful **test** sale/capture transaction; an
Admin-created `PAID` fixture alone is not sufficient. Fulfillment IDs must belong
to the run order. Cancel never refunds, restocks, or notifies customers. No
notification is requested for fulfillment/refund. Check asynchronous job completion
and final order state before marking any journey PASS. Operations save actual
results, with `submitted` deliberately distinct from a verified terminal state.

## Idempotency and cleanup

A per-run exclusive writer lock prevents concurrent seed/cleanup. Manifests are
atomically replaced with mode 0600. Write intent is persisted before creation.
After interruption, exact run tags recover the actual resource ID. If a pending
write has no discoverable ID, creation is refused until an operator reconciles
its outcome (Shopify search may be eventually consistent). Never clear that state
and blindly recreate. A stale writer lock requires confirming its PID has exited.

Cleanup requires the same live shop and exact run tag/ID. Orders are deleted
before customers. No manifest/no ownership means no delete. Existing unrelated
resources cannot become cleanup targets. Missing or blocked resources remain
uncreated; dry runs preserve already-created IDs/statuses.

## Validation

`node --test tools/audit/test/*.test.mjs` exercises mocked official API contracts,
identity mismatch/production refusal, idempotent recovery, test-only orders, and
cleanup ownership. These are **local contract tests**, not live API compatibility
or authenticated customer journeys. Official references are linked in the PR7
remediation report. A live Admin schema/permission check is still required.
