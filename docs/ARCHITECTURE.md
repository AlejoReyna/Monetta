# Architecture

How the modules fit together, and why the boundaries sit where they do.

> This document and the per-module `README.md` files are the contract. If code and doc
> disagree, one of them is a bug — fix both in the same commit.

## The one-paragraph version

The app is a **native Flutter client over the Shopify Storefront API**. It never holds its
own copy of the catalog as source of truth: Shopify is the source of truth, and the app
caches it. On top of the raw Shopify data sits a **normalization layer** that repairs a
genuinely messy taxonomy into canonical facets, and on top of *that* sits an **on-device
recommendation engine** that learns from browsing behaviour. Checkout is delegated back to
Shopify so we never touch payment data.

## Layer diagram

```
┌──────────────────────────────────────────────────────────────┐
│ features/          home · catalog · product · search · cart   │  Flutter widgets
│                    wishlist · profile · onboarding            │  + Riverpod controllers
└───────────────┬──────────────────────────────────────────────┘
                │ depends on domain interfaces only
┌───────────────▼──────────────────────────────────────────────┐
│ domain/            entities (freezed) + repository interfaces │  pure Dart
└───────────────┬──────────────────────────────────────────────┘
                │
     ┌──────────┴───────────┬────────────────────┐
┌────▼─────────┐  ┌─────────▼────────┐  ┌────────▼──────────┐
│ data/shopify │  │ data/normalize   │  │ reco/             │
│ Storefront   │─▶│ Product →        │─▶│ events → profile  │  pure Dart
│ GraphQL      │  │ CanonicalFacets  │  │ → ranked feed     │  (no Flutter imports)
└────┬─────────┘  └──────────────────┘  └────────┬──────────┘
     │                                            │
┌────▼────────────────────────────────────────────▼──────────┐
│ data/local       drift: catalog cache · events · profile    │
│                  · wishlist · sync cursors                  │
└─────────────────────────────────────────────────────────────┘
```

## Module map

| Module | Responsibility | Flutter-free? | Doc |
|---|---|---|---|
| `core/` | Config, Remote Config, theme, l10n, errors | no | [README](../lib/core/README.md) |
| `data/shopify/` | Storefront API client, queries, delta sync | yes | [README](../lib/data/shopify/README.md) |
| `data/normalize/` | Raw Shopify product → canonical facets | **yes** | [README](../lib/data/normalize/README.md) |
| `data/local/` | Drift database: cache, events, wishlist | yes | [README](../lib/data/local/README.md) |
| `data/repositories/` | Wire shopify + local + normalize together | yes | — |
| `domain/` | Entities and repository interfaces | **yes** | — |
| `reco/` | Profile building and product ranking | **yes** | [README](../lib/reco/README.md) |
| `features/*` | UI + controllers | no | per-feature README |

## The two rules that keep this maintainable

**1. `reco/`, `data/normalize/` and `domain/` must not import Flutter.**

These are the parts most worth testing and least likely to change for UI reasons. Keeping
them framework-free means their tests run in milliseconds with no widget pump, and it makes
the scoring logic portable if any of it ever needs to move server-side in Phase 2 (which it
will, for collaborative filtering).

This is enforced by a test, not by convention — see `test/architecture_test.dart`. It fails
the build if a `package:flutter` import appears in those directories.

**2. `features/` depends on `domain/` interfaces, never on `data/` directly.**

Swapping the checkout implementation, or moving normalization to the backend in Phase 2,
must not touch a single widget.

## Data flow: opening the app

1. `features/home` asks `CatalogRepository` for the home feed.
2. The repository returns **cached** products from Drift immediately — the UI paints at once,
   even offline.
3. In the background, `data/shopify` issues a **delta query** using the stored high-water
   mark: `products(query: "updated_at:>...")`. Usually this returns nothing.
4. Anything returned is passed through `data/normalize` to produce `CanonicalFacets`, then
   written to Drift.
5. `reco/` reads the (already decayed) profile from Drift, scores the candidate set, applies
   diversity re-ranking, and returns a ranked feed with an explanation per item.
6. Widgets rebuild off the Riverpod stream.

Steps 3–4 are why the owner never needs us to publish a build when they add a product. See
[`lib/data/shopify/README.md`](../lib/data/shopify/README.md) for the sync contract.

## Data flow: checkout

```
cart state (drift)
  → cartCreate / cartLinesAdd (Storefront)   attributes: _channel, _platform, _device_id, _rec_source
  → cart.checkoutUrl
  → CheckoutLauncher (interface)
       ├─ CheckoutKitLauncher   (checkout_sheet_kit_flutter — default)
       └─ WebViewLauncher       (fallback)
  → order lands in Shopify with our attribution attributes intact
```

The `CheckoutLauncher` seam exists because `checkout_sheet_kit_flutter` is a **v0.0.2**
plugin sitting on the revenue path. If it disappoints, swapping to the WebView fallback is
a one-line provider change. The attribution attributes are not cosmetic: they are what makes
the revenue-share arrangement auditable.

## Codegen

`build_runner` drives freezed, json_serializable, drift, ferry and riverpod_generator.
Run `make gen`. **Generated files are committed** — CI then builds without a codegen step,
which keeps PR runs fast and makes generated-output diffs reviewable.

## What lives where — decision log

| Decision | Choice | Why |
|---|---|---|
| Source of truth for catalog | Shopify, always | The owner must never need us to ship a build to change the catalog |
| Where normalization runs | On device (Phase 1) | No backend needed to launch; rules are hot-swappable via Remote Config |
| Where the user profile lives | On device, never uploaded (Phase 1) | Privacy by default under LFPDPPP, and no backend needed |
| Payments | Delegated to Shopify checkout | Keeps PCI scope entirely out of this codebase |
| Navigation structure | Shopify `main-menu` query | Owner controls app nav from Shopify → Navigation |
