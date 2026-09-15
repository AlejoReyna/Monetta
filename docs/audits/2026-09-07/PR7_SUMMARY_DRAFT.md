# Preserve catalog integrity and isolate checkout, history, and webhook recovery

Fix PR7 R1–R8: complete variant/collection pagination for both catalog and featured-product cache writes; reject malformed sync responses; atomically migrate unknown/foreign shop state; preserve confirmed empty catalogs; capture checkout account/shop/quantities with transactional duplicate receipts; load complete Customer Account order history; and merge apartados by canonical Shopify identity with separate display numbers.

Webhook processing now returns retryable HTTP 503 for busy deliveries, uses transaction-scoped PostgreSQL ownership with reserved effect capacity, and recovers interrupted deliveries through HTTP retry without treating them as completed. Pin Flutter to 3.44.8, enable Android flavor resource generation, require PostgreSQL in CI, replace the empty integration harness with an actual app/navigation test, and add guarded official Shopify fixture adapters plus a real local HTTP registration/login persona runner.

Validation: full Flutter suite, analysis/format, backend tests with disposable PostgreSQL, backend typecheck/build, fixture contract tests, and secret/catalog gates are recorded in `PR7_REMEDIATION.md`. Native builds/device smoke are blocked by local disk capacity; CI and live Shopify/payment journeys have not run. No deployment, merge, production data change, real charge, or external PR message was performed.

Migration: SQLite schema 7 adds checkout receipts and account-composite order-cache keys. Shop migration revokes old local session references and requires full sync/sign-in. Cart storage moves to a fresh shop/account namespace. Backend schema is unchanged; drain old webhook workers before rollout because claim protocols must not be mixed.
