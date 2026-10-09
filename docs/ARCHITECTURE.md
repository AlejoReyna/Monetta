# Architecture

How the modules fit together, and why the boundaries sit where they do.

> **Authoritative description:** [`SYSTEM_IMPLEMENTATION.md`](SYSTEM_IMPLEMENTATION.md)
> documents the running system with exact code references. This document is
> the map: layers, boundaries, and the rules that keep them. An in-place
> refactor is reshaping parts of it (composition, scopes, view models); its
> plan and decisions live in `.claude/refactor/PLAN.md`.

> This document and the per-module `README.md` files are a contract. If code
> and doc disagree, one of them is a bug — fix both in the same change.

## The one-paragraph version

The app is a **native Flutter client for iOS and Android over Shopify**. Shopify
is the source of truth for the catalog; the app keeps a Drift cache so it
paints at once and keeps working offline. On top of the raw Shopify data sits a
**normalization layer** that repairs a messy taxonomy into canonical facets,
and on top of *that* an **on-device recommendation engine** that learns from
browsing behaviour. Checkout is delegated to Shopify (Checkout Sheet Kit), so
the app never touches payment data. A small backend,
`services/accounts_orders`, holds what a phone cannot: Shopify webhooks, order
history, first-party accounts, Rewards, notifications, and the owner's admin
control plane.

## Layers

```
┌──────────────────────────────────────────────────────────────────┐
│ features/*   screens: home · catalog · product · checkout ·       │  Flutter widgets
│              account · orders · admin · notifications · …         │
└───────────────┬──────────────────────────────────────────────────┘
                │ reads state through InheritedNotifier scopes
┌───────────────▼──────────────────────────────────────────────────┐
│ app/         ChangeNotifier controllers and stores: CatalogStore, │  Flutter
│              AccountController, CartController, AdminController,  │
│              NotificationController, … plus runtime config, theme │
└───────────────┬──────────────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────────────┐
│ data/*       repositories and clients: Storefront, Customer       │  mixed
│              Account, Drift (local), accounts_orders, admin,      │
│              notifications, Firestore (experimental)              │
└───────────────┬──────────────────────────────────────────────────┘
                │
┌───────────────▼──────────────────────────────────────────────────┐
│ domain/ · data/normalize/ · data/shopify/ · reco/                 │  pure Dart
└──────────────────────────────────────────────────────────────────┘
```

**Composition.** `lib/main.dart` builds every dependency at startup
(`_MonettaAppState._load`) and exposes it through `InheritedNotifier` scopes:
`StoreScope`, `AccountScope`, `CartScope`, `AdminScope`, `NotificationScope`,
`HomeContentScope` and others. Moving composition out of `main.dart` and above
the Navigator is refactor WP RF-30.

**State and navigation.** State is plain `ChangeNotifier` plus
`InheritedNotifier`; there is no Riverpod. Navigation is the imperative
Navigator (`MaterialPageRoute`, `monettaFadeRoute`); there is no router package
(decision E6). The unused Riverpod, go_router, freezed and json_serializable
dependencies were removed in RF-22.

## Module map

| Module | Responsibility | Flutter-free | Doc |
|---|---|---|---|
| `app/` | Controllers, stores, runtime config, theme and typography (bundled fonts, text scale policy), shopper copy, money formatting | no | — |
| `data/shopify/` | Storefront API client, queries, delta sync, cart, attribution | **yes, enforced** | [README](../lib/data/shopify/README.md) |
| `data/normalize/` | Raw Shopify product → canonical facets | **yes, enforced** | [README](../lib/data/normalize/README.md) |
| `data/local/` | Drift database `monetta.sqlite`, schema 7: catalog cache, bag, wishlist, events, accounts, sessions, orders, checkout receipts | no (Drift + plugins) | [README](../lib/data/local/README.md) |
| `data/repositories/` | Catalog repository and write coordinator; order history | not enforced | — |
| `data/customer_auth/` | Customer Account API OAuth 2.0 + PKCE, identity, orders, shared endpoint discovery | no (`flutter_appauth`) | [README](../lib/data/customer_auth/README.md) |
| `data/accounts_orders/` | Client for first-party accounts and order history | not enforced | — |
| `data/admin/` | Admin control plane client | not enforced | — |
| `data/notifications/` | Push, inbox and campaign clients | not enforced | — |
| `data/firestore/`, `data/firebase/` | Experimental real-time catalog (off by default, E3) and Firebase bootstrap | no | — |
| `data/http/`, `data/media/`, `data/reviews/` | Timeout transport, image URLs, Loox reviews | not enforced | — |
| `domain/` | Entities: product, bag line, cart, money, home and editorial content, admin control | **yes, enforced** | — |
| `reco/` | Profile building and product ranking | **yes, enforced** | [README](../lib/reco/README.md) |
| `platform/` | Native checkout channel and external opener | no | — |
| `features/*` | Screens | no | — |
| `tooling/` | Dart-define validation | not enforced | — |

## The rules that keep this maintainable

**1. `reco/`, `data/normalize/`, `data/shopify/` and `domain/` must not import
Flutter.** They are the parts most worth testing and least likely to change for
UI reasons; their tests run in milliseconds with no widget pump.
`data/shopify/` qualifies because its HTTP call is *injected* as a transport,
which is also what lets the sync contract run against a fake. Enforced by
`test/architecture_test.dart`.

**2. The retired external catalog stays retired.**
`test/architecture/external_catalog_retired_test.dart` (ARCH-03) fails on any
reference to it in `lib/` or `test/`. The only exceptions are the guard that
rejects `ENABLE_EXTERNAL_CATALOG` and the label for historical
`external_source` audit entries.

**3. Direction of dependencies (goal, not yet true).** Features should depend
on `app/` and `domain/`, not on `main.dart` or on concrete `data/`
implementations. Today several feature files do both. Refactor WPs RF-30 and
RF-33 ratchet these down with architecture tests (ARCH-01, ARCH-02, ARCH-04).

**4. Type comes from two bundled families, and text scale is bounded once,
at the root.** Every typography helper resolves to Inter (sans) or Playfair
Display (serif), declared in `pubspec.yaml` with their SIL OFL texts, which
`registerFontLicenses()` adds to the license page. `MonettaApp` installs
`BoundedTextScaler` (`lib/app/text_scale_policy.dart`) in `MaterialApp.builder`:
text of 20 px or more grows at most 1.2x, smaller text up to 1.5x without
passing 24 px (decisions E-T1 and D-12). A box that reserves room for text
scales with `textScaleFactorFor(scaler, fontSize)` of the text it holds, never
with `scaler.scale(boxHeight)`: a height is not a font size, and under the
size-based cap it would grow less than its text. UI-01 to UI-03 enforce it.

## Data flow: opening the app

1. `CatalogStore.loadFromAsset()` first checks **shop provenance**. If the
   configured shop differs from the one recorded in the cursor or the catalog
   metadata, it wipes that shop's local state (CHAR-03).
2. On a fresh install it seeds the bundled snapshot
   (`assets/catalog/catalog.json`), then reads the Drift cache and hydrates bag,
   wishlist and events. The UI paints immediately, even offline.
3. In the background, `data/shopify` runs a **delta sync** from the stored
   cursor, and every write goes through `CatalogWriteCoordinator`. A verified
   full sync replaces the catalog atomically; an incomplete sync never replaces
   the cache.
4. `reco/` ranks the catalog from the on-device profile and explains each pick.

This is why the owner never needs a new build to add a product. Details:
[`SYSTEM_IMPLEMENTATION.md`](SYSTEM_IMPLEMENTATION.md) § 3.12 and
[`lib/data/shopify/README.md`](../lib/data/shopify/README.md).

## Data flow: checkout

```
local bag (Drift)
  → cartCreate / cartLinesAdd (Storefront)
       attributes: _channel, _platform, _device_id, _app_version, _rec_source
                   (+ _campaign when a campaign applies)
  → cart.checkoutUrl
  → CheckoutLauncher (interface)
       ├─ MethodChannelCheckoutLauncher → Shopify Checkout Sheet Kit
       └─ validated browser fallback (explicit only)
  → the order lands in Shopify with the attribution intact
```

- Cart amounts travel as decimal strings (`CartMoney`); no commercial total is
  computed with `double`.
- The UI depends on `CheckoutLauncher`, never on the native SDK, and the
  checkout URL is never logged or persisted.
- The attribution attributes are what makes the commercial arrangement
  auditable.

## Repository pieces outside the app

- **`services/accounts_orders/`.** Node + Express + PostgreSQL; staging runs on
  Fly.io. It handles Shopify webhooks, orders, first-party accounts, Rewards,
  notifications and the admin control plane. See its README and
  [`ADMIN_CONTROL_PANEL.md`](ADMIN_CONTROL_PANEL.md).
- **`api/` and `server/catalog/`.** Shopify catalog mirror on Vercel. It is
  experimental: production uses Storefront directly (decision E3).
- **`functions/`.** Firebase Functions for the experimental real-time catalog.
  Its retirement is refactor WP RF-23.
- **`web/`.** A Vite screenshot gallery; it is not the app.
- **Retired:**
  - `services/catalog_monitor/` and `dashboard/`;
  - the external (US) catalog, removed from the app in RF-20 and from the admin
    in RF-21 (decision E2). Its history is in
    [`US_SOURCING_DURABILITY.md`](US_SOURCING_DURABILITY.md).

## Codegen

Only Drift uses code generation. `make gen` runs `build_runner` to produce
`lib/data/local/database.g.dart`, which is committed, so CI builds without a
codegen step.

**GraphQL is deliberately not code-generated:** the Storefront surface is small
enough for hand-written, tested mappers. Rationale:
[`lib/data/shopify/README.md`](../lib/data/shopify/README.md) § 3. The pure-Dart
core therefore compiles and tests before `build_runner` has ever run.

## Decision log

| Decision | Choice | Why |
|---|---|---|
| Source of truth for the catalog | Shopify, always | The owner must never need a new build to change the catalog |
| Catalog authority in production | Storefront direct; mirror and Firestore stay experimental | Decision E3 |
| Where normalization runs | On device | No backend needed; rules ship with the app |
| Where the user profile lives | On device, never uploaded | Privacy by default under LFPDPPP |
| Payments | Delegated to Shopify checkout | Keeps PCI scope out of this codebase |
| Navigation structure | Shopify `main-menu` query | The owner controls navigation from Shopify |
| Account login | Customer Account API, mobile client, `flutter_appauth` | Classic accounts and Multipass are deprecated; see `ACCOUNTS_AND_SYNC_PLAN.md` § 2 |
| Where the account backend lives | Its own service, `services/accounts_orders/` | Compliance-bearing (redact webhooks) and unrelated to the app's catalog cache |
| State management and routing | `ChangeNotifier` + `InheritedNotifier`; imperative Navigator | What the app actually uses; decision E6 keeps routers out for now |
| External (US) catalog | Retired | Decision E2 |
| Typography | Bundled Inter and Playfair Display (SIL OFL) for every role | The same face on iOS and Android; decision E-T2 |
| Text scale | Bounded at the root: 1.5x overall, 1.2x from 20 px | Body text can grow for whoever needs it without headlines overflowing; decisions E-T1 and D-12 |
