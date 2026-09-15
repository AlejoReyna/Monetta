# Phase F / WP-06 notes (F20–F24)

## F20 — `/admin/me` drives UI entry
- Live `AdminController.canAccess` requires `serverCapabilities.openAdmin` from
  `GET /admin/me`. Email allow-list alone no longer opens a live panel.
- Preview remains an explicit `ENABLE_OWNER_ADMIN_PREVIEW` design-review mode.
- Every mutation continues to use `requireOwner` server-side.

## F21 — Product pagination beyond 50/100
- `GET /admin/control-plane` and new `GET /admin/products` accept `cursor`,
  `limit` (max 100), and `q` search.
- Responses include `productsMeta` with `loadedCount`, `hasNextPage`,
  `endCursor`, and `totalCount` (when Admin API `productsCount` is available).
- Flutter admin UI shows loaded vs total and offers “Cargar más productos”.

## F22 — Sync completion = useful work
- `shopify-products` paginates until `hasNextPage` is false, persisting cursor /
  pages / products seen after each page (`011_admin_sync_job_progress.sql`).
- Interrupted pending/running jobs resume via job GET and process startup
  (`resumeInterruptedSyncJobs`). Truncation fails with `SYNC_TRUNCATED`.
- Product `syncAll` still omits retired `external-status`.

## F23 — Storefront save refreshes shopper content
- `saveStorefront` sets `refreshAfter: true`, which refreshes HomeContent,
  editorial, featured catalog, and Shopify catalog sync.
- Production/staging TOML define `$app:storefront_config` with
  `access.storefront = public_read`. Validate publication under real Admin +
  Storefront credentials before calling production ready.

## F24 — Production Shopify app config (reviewable, not deployed)
- `shopify/shopify.app.production.toml` scopes aligned with staging writes +
  metaobject definition. Placeholders remain; do not deploy from this phase.
- See `ADMIN_OPS_LEFT_IN_SHOPIFY.md` for operator boundaries.

## Featured reorder jobs
- `HttpAdminClient.replaceFeaturedCatalog` polls
  `/admin/featured-catalog/jobs/:id` to a terminal state and reloads canonical
  membership/order.
