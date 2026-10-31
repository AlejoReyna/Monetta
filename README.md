# Monetta

iOS + Android Flutter client for [monetta.mx](https://monetta.mx) — bolsas, carteras y
relojes importados originales.

Two things make this more than a storefront wrapper:

1. **The catalog is never hardcoded.** Products, collections, navigation, home sections and
   badges all come from Shopify at runtime. The owner adds a product in Shopify Admin and it
   appears in the app on the next open — no release, no developer.
2. **It learns what each shopper likes** on-device and explains its recommendations
   (*"Porque te gustan las bolsas crossbody de Guess"*).

## Status

The app runs on iOS and Android with:

- a Drift cache for offline use;
- the Shopify Storefront catalog with delta sync;
- Customer Account login;
- Shopify checkout through the Checkout Sheet Kit;
- on-device recommendations;
- an owner admin panel.

Its backend is `services/accounts_orders`. An in-place refactor is in progress. The current
system is described in [`docs/SYSTEM_IMPLEMENTATION.md`](docs/SYSTEM_IMPLEMENTATION.md).

**Toolchain (pinned):** Flutter 3.44.8 through fvm (`.fvmrc`), Dart 3.12.2, Node 24, and
PostgreSQL 16 for the backend tests. iOS and Android only; Flutter web is not a target.

## Repository

| Path | What it is |
|---|---|
| `lib/`, `test/`, `integration_test/` | The Flutter app and its tests |
| `services/accounts_orders/` | Backend: Node + Express + PostgreSQL (staging on Fly.io) |
| `api/`, `server/catalog/` | Shopify catalog mirror on Vercel (experimental) |
| `functions/` | Firebase Functions for the experimental real-time catalog (retirement planned) |
| `web/` | Vite screenshot gallery — not the app |
| `services/catalog_monitor/`, `dashboard/` | Retired; kept in the tree until their operational retirement |

## Getting started

```bash
make doctor     # verify the toolchain
make setup      # flutter pub get
make test       # Flutter test suite
make analyze    # static analysis
make test-all   # format, analyze, tests, TypeScript services, catalog and secret checks
make report     # catalog health report — the list Monetta acts on
```

`make report` prints coverage, facet distribution, and the exact products to fix in
Shopify, in Spanish, with the action to take.

The pure-Dart core (`domain`, `data/normalize`, `data/shopify`, `reco`) is hand-written with
**no codegen** on purpose, so it compiles and tests before `build_runner` has ever run. The
only generated file is the Drift database (`make gen`).

### Backend tests with PostgreSQL (G7)

G7 requires Node 24 and **PostgreSQL 16 running locally on `localhost:5432`**, with
user `postgres`, password `postgres`, and the administrative database `postgres`.
The [backend README](services/accounts_orders/README.md#postgresql-16-on-macos-for-g7)
explains how to install and start it on macOS with Homebrew, without Docker.

Run from the repository root, after installing the backend dependencies:

```bash
npm --prefix services/accounts_orders ci
REQUIRE_POSTGRES_TESTS=1 WP01_PG_ADMIN_URL=postgres://postgres:postgres@localhost:5432/postgres npm --prefix services/accounts_orders test
```

`REQUIRE_POSTGRES_TESTS=1` makes an unavailable database fail the run rather than skip
the PostgreSQL tests. G7 requires zero failures and zero skipped tests. The tests
create, migrate, and delete their own temporary databases.

### PostgreSQL in production

Production requires a separate managed PostgreSQL 16 database, a dedicated role,
verified TLS, and a private `DATABASE_URL` stored in the hosting platform's secrets.
The credentials above belong to local test fixtures. See the
[production configuration guide](services/accounts_orders/README.md#13-postgresql-in-production)
for permissions, secret injection, migrations, readiness, and backups.

## Documentation

Every core module carries an explainable `README.md` next to its code — purpose, mechanism,
the decisions taken *and rejected*, gotchas, and how to extend it.

- [`docs/SYSTEM_IMPLEMENTATION.md`](docs/SYSTEM_IMPLEMENTATION.md) — the running system,
  with exact code references
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the modules fit together and the
  rules that keep the boundaries
- [`docs/EDITORIAL_CONTENT_METAOBJECTS.md`](docs/EDITORIAL_CONTENT_METAOBJECTS.md) —
  Shopify content fields for Conoce Monetta and Vende con Monetta
- [`docs/OWNER_ADMIN_GUIDE.md`](docs/OWNER_ADMIN_GUIDE.md) — instrucciones diarias
  para la persona propietaria
- [`docs/ADMIN_CONTROL_PANEL.md`](docs/ADMIN_CONTROL_PANEL.md) — arquitectura,
  seguridad, endpoints y operación del control plane
- [`lib/data/normalize/README.md`](lib/data/normalize/README.md) — catalog repair, and the
  measured data problems it exists to solve
- [`lib/reco/README.md`](lib/reco/README.md) — the scoring model, in business terms
- [`docs/US_SOURCING_DURABILITY.md`](docs/US_SOURCING_DURABILITY.md) — historical: why the
  US catalog stayed research and never became dropshipping (the external catalog is now
  retired)

## Why the normalize layer exists

Measured against the live catalog on 2026-08-05 (271 products):

- `vendor` is the **store name** (`'Monetta '`, trailing space) on 36 products, so it is
  unusable as brand on 13% of the catalog
- `product_type` has **20 spellings for ~8 real categories**, and is empty on 36 products
- 36 products have **no tags at all**

Normalization lifts brand resolution from **86.7% → 99.6%** and category to **100%**.
Full numbers and method: [`lib/data/normalize/README.md`](lib/data/normalize/README.md).
