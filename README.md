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

Phase 0 — pure-Dart core is in place and **green**: `flutter analyze` reports no issues and
**52 tests pass** (Flutter 3.44.8 / Dart 3.12.2). The Flutter platform scaffold
(`flutter create` for the iOS/Android folders) is the next step; see `docs/ARCHITECTURE.md`.

| Module | State |
|---|---|
| `lib/domain` | ✅ entities |
| `lib/data/normalize` | ✅ built + validated against the live catalog |
| `lib/reco` | ✅ built + validated |
| `lib/data/shopify` | ✅ queries, delta sync, mappers, attribution |
| `lib/data/local` | ⬜ next — drift cache, event log, wishlist |
| `lib/features/*` | ⬜ |
| iOS/Android platform folders | ⬜ needs `flutter create` |

## Getting started

```bash
make setup      # flutter pub get
make test       # 52 tests, ~1s
make report     # catalog health report — the list Monetta acts on
make analyze
```

`make report` prints coverage, facet distribution, and the exact products to fix in
Shopify, in Spanish, with the action to take.

The pure-Dart core (`domain`, `data/normalize`, `reco`) is hand-written with **no codegen**
on purpose, so it compiles and tests before `build_runner` has ever run.

## Documentation

Every module carries an explainable `README.md` next to its code — purpose, mechanism, the
decisions taken *and rejected*, gotchas, and how to extend it.

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the modules fit together
- [`docs/US_SOURCING_DURABILITY.md`](docs/US_SOURCING_DURABILITY.md) — why the US
  catalog stays research, not dropshipping
- [`lib/data/normalize/README.md`](lib/data/normalize/README.md) — catalog repair, and the
  measured data problems it exists to solve
- [`lib/reco/README.md`](lib/reco/README.md) — the scoring model, in business terms

## Why the normalize layer exists

Measured against the live catalog on 2026-08-05 (271 products):

- `vendor` is the **store name** (`'Monetta '`, trailing space) on 36 products, so it is
  unusable as brand on 13% of the catalog
- `product_type` has **20 spellings for ~8 real categories**, and is empty on 36 products
- 36 products have **no tags at all**

Normalization lifts brand resolution from **86.7% → 99.6%** and category to **100%**.
Full numbers and method: [`lib/data/normalize/README.md`](lib/data/normalize/README.md).
