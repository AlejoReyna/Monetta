# External catalog decommission inventory (WP-02 / F03 / F22 / F25)

**Date:** 2026-09-07 (America/Monterrey)  
**Product decision:** Monetta sells its own Shopify products only. No third-party extraction. `dashboard/` and `services/catalog_monitor` are **not** the customer storefront.

This document inventories **live** jobs/resources that still require **authorized** decommission. Repo product wiring has been retired; **do not delete live infrastructure** from this change alone.

## Already retired in product / CI (this WP)

- App runtime: `ExternalCatalogConfig.fromEnvironment()` always disabled; `ENABLE_EXTERNAL_CATALOG` rejected by `RuntimeConfig` and `validateDartDefines`.
- Startup / home / browse / notifications / admin: no external catalog controller, no `external-status` in `syncAll`.
- Staging may run Storefront-only (Firestore mirror optional).
- Makefile `test-services` no longer runs `catalog_monitor` tests.
- GitHub `quality.yml` catalog-monitor job replaced with a flag-off gate.
- `dashboard.yml` automatic PR/push triggers disabled (manual `workflow_dispatch` only).

## Live resources requiring owner authorization before teardown

| Resource | Evidence in repo | Action needed (authorized) |
|---|---|---|
| Host / DNS `catalog.monetta.mx` | `docs/OPERATIONS.md`, `services/catalog_monitor/deploy/atlantic/Caddyfile.snippet` | Confirm DNS A/AAAA, Caddy site; schedule cutover + historical backup |
| Atlantic VPS compose stack | `services/catalog_monitor/deploy/atlantic/compose*.yml` | Stop API + monitor containers only after backup; keep Postgres dump |
| systemd units | `monetta-catalog-api.service`, `monetta-catalog-monitor.service` | Disable/stop after owner approval |
| Healthcheck / backup scripts | `monetta-catalog-healthcheck`, `monetta-catalog-backup` | Retire cron after services stopped |
| Postgres data (monitor DB) | `services/catalog_monitor` migrations | Dump + retain before drop |
| Dashboard deploy (Vercel or static) | `dashboard/vercel.json`, ops notes with `VITE_CATALOG_API_BASE_URL` | Unpublish or point away from retired API |
| Secrets | `INTERNAL_CATALOG_EVENT_SECRET`, monitor DB URLs, HMAC admin keys | Rotate/revoke after teardown; search secret store |
| Push / event coupling | `docs/PUSH_NOTIFICATIONS_RUNBOOK.md` references catalog event secret | Confirm notifications path no longer depends on monitor |

## Code retained (historical, not product path)

- `services/catalog_monitor/**`
- `dashboard/**`
- `lib/data/external_catalog/**`, `lib/features/home/external_catalog_section.dart`, `lib/features/product/external_product_screen.dart`
- Deploy docs under `docs/OPERATIONS.md` / `docs/EXTERNAL_CATALOG_PRODUCTION_PLAN.md`

These may remain for forensic reference until an authorized delete PR. They must not be re-wired into the shopper app.

## Acceptance checks for this WP

1. App/admin start with monitor unavailable.
2. Zero calls to retired external catalog hosts in redacted outbound host info.
3. No external products in recommendations, alerts, or cached navigation.
4. Production/staging configs cannot enable `ENABLE_EXTERNAL_CATALOG` via Makefile bypass (runtime + validator).
