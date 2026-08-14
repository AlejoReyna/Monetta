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
| `data/shopify/` | Storefront API client, queries, delta sync | **yes** | [README](../lib/data/shopify/README.md) |
| `data/normalize/` | Raw Shopify product → canonical facets | **yes** | [README](../lib/data/normalize/README.md) |
| `data/local/` | Drift database: cache, events, wishlist | yes | [README](../lib/data/local/README.md) |
| `data/repositories/` | Wire shopify + local + normalize together | yes | — |
| `data/external_catalog/` | External-catalog client, ETag cache, mapper (internal prototype, off by default) | yes | see § "External catalog prototype" below |
| `domain/` | Entities and repository interfaces | **yes** | — |
| `reco/` | Profile building and product ranking | **yes** | [README](../lib/reco/README.md) |
| `features/*` | UI + controllers | no | per-feature README |

## The two rules that keep this maintainable

**1. `reco/`, `data/normalize/`, `data/shopify/` and `domain/` must not import Flutter.**

These are the parts most worth testing and least likely to change for UI reasons. Keeping
them framework-free means their tests run in milliseconds with no widget pump, and it makes
the scoring logic portable if any of it ever needs to move server-side in Phase 2 (which it
will, for collaborative filtering).

`data/shopify/` stays in this set because its HTTP call is *injected* as a
`GraphQLTransport` rather than owned — which is also what lets the entire sync contract be
tested against a fake transport with no network.

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

## External catalog prototype (internal, off by default)

An internal-only prototype monitors the **public US Coach, Michael Kors,
GUESS, and Steve Madden** catalogs once daily and shows them in the app's feed as owner-managed
procurement candidates, alongside Monetta's own Shopify catalog. There is no
`supplierAuthorization` field or approval gate: the owner can inspect a US
listing and decide whether to procure it manually. This still is not an
automated supplier integration — there is no order placement, commissions, or
fulfillment in this service. An external card shows a USD price and links out
to the merchant's page; it cannot enter Monetta's cart, Shopify checkout, or
the WhatsApp apartado flow until the owner separately imports it into Shopify.

### Why scraping is isolated outside the mobile client

The crawler lives in `services/catalog_monitor/` — a separate Node.js/TypeScript
service, not Dart code shipped in the app — for reasons that don't change
even once this graduates past prototype:

- **The app must never make outbound HTTP requests to a third party's
  storefront on a user's device.** Rate limiting, retries, robots.txt
  compliance, and CAPTCHA/block detection all need a server that runs on a
  schedule the crawler controls, not a phone that opens the app whenever a
  shopper feels like it.
- **A phone should never carry credentials, IPs, or a user agent that
  identifies this crawl.** Centralizing it in one service with one
  contactable user agent (see `services/catalog_monitor/README.md` § "The
  live-crawl gate") is what makes the crawl inspectable and stoppable.
- **Parsing HTML is exactly the kind of I/O-heavy, frequently-changing logic
  `docs/ARCHITECTURE.md`'s two rules keep out of `domain/`, `reco/`, and
  `data/normalize/`.** It belongs behind a stable JSON API, the same way
  Shopify sits behind the Storefront API rather than the app scraping
  monetta.mx directly.

### Why the feature is internal-only

`ENABLE_EXTERNAL_CATALOG` defaults to `false` and is a **build-time**
`--dart-define`, not a remote flag — see `lib/app/external_catalog_config.dart`.
This is deliberate: external listings are unverified prototype data (no
production acceptance run has happened yet — see
`services/catalog_monitor/README.md` § "Known limitations"), and shipping
them to real shoppers before that data has been operationally validated
would mean showing prices and availability nobody has checked. Internal
builds can turn it on to demo and test the mixed feed; a public release
build cannot, unless someone changes the build command.

### Two purchase modes, one domain model

`lib/domain/product.dart`'s `Product` stays exactly what it always was: a
raw Shopify entity. `lib/domain/catalog_item.dart` adds `CatalogItem`, a
source-independent type both Monetta and external listings map into for
*presentation only* — never for checkout:

| | `PurchaseMode.monettaCheckout` | `PurchaseMode.ownerProcurement` |
|---|---|---|
| Source | Monetta's Shopify catalog | Coach US / Michael Kors US / GUESS US / Steve Madden US |
| Currency | MXN | USD |
| Price | Always known (`Money`, never null) | Nullable (`Money?`) — a missing/malformed/unexpected-currency price renders `Consultar precio`, never a fabricated `$0`, see `app/theme.dart#formatCatalogMoney` |
| Variants | Shopify `ProductVariant` | External `CatalogVariant`: SKU, color name/code, image, USD price, availability and merchant URL; selecting a color never enters checkout |
| Mapper | `data/shopify/catalog_item_mapper.dart` | `data/external_catalog/external_catalog_mapper.dart` |
| Product tap | In-app `ProductScreen` (via `shopifyProductId`) | In-app read-only `ExternalProductScreen` with description, source, availability and color/SKU details |
| Merchant CTA | N/A | Opens the selected variant on the merchant's site via `LaunchMode.externalApplication`, only after re-validating HTTPS and the source-owned host |
| Add to bag / WhatsApp apartado | Yes — unchanged, see `features/product/product_screen.dart` | Never — owner-managed candidates remain outside every Monetta checkout path |

The two mappers are intentionally separate functions with no shared code
path, so an external record can never be silently mapped through the
Shopify path (or vice versa) and accidentally pick up checkout behavior.

### Mixed-feed rules

`lib/app/mixed_feed.dart` builds one unified, deduplicated `CatalogItem`
collection out of Monetta's catalog and external research items:

- **Dedupe is exact-match only** — normalized `brand::title` — preferring
  the Monetta item. No fuzzy matching without SKU/UPC evidence, per spec.
- **No currency conversion, ever.** `lib/app/theme.dart#formatCatalogMoney`
  always renders the currency code (`$1,999 MXN`, `$350 USD`, or `Consultar
  precio` when unknown); the two currencies are never summed, compared, or
  sorted against each other by absolute price. Where a price *does*
  influence ranking, it is through `reco/external_facets.dart`'s
  categorical, USD-only price-band table (`accesible`/`medio`/`alto`/
  `premium`) — a taste-tier signal, never a numeric cross-currency
  comparison.
- **`unifiedRecommendations` feeds external items into the same
  `Recommender.rank` call Monetta products already go through** — each
  external item is mapped to a `CanonicalFacets` (brand slug, best-effort
  category slug, the price-band above) keyed by its `sourceScopedId`, so the
  *same* candidate set, scoring and brand-diversity re-ranking apply across
  all sources. This is what lets an external item appear interleaved
  naturally in `HomeScreen`'s catalog grid, not only in the dedicated
  "También en marcas de Estados Unidos" rail (`relevantExternalItems`, still
  present as a lighter-weight, no-longer-fixed-at-8 rail).
- **`fullDeduplicatedCatalog` + `features/catalog/catalog_browse_screen.dart`**
  expose every deduplicated item, Monetta and external, with no ranking and
  no cap, reachable from the home drawer ("Ver todo el catálogo"). Rendered
  with a top-level `GridView.builder` (no `shrinkWrap`) so it stays lazy at
  any catalog size.

### Configuring and running the monitor locally

```bash
cd services/catalog_monitor
cp .env.example .env
docker compose up -d postgres
npm install && npm run migrate
npm test                                  # fixtures + in-memory fakes, no network
npm start                                 # API on :8081
npm run crawl -- --brand coach --limit 5 --dry-run   # see README for the live-crawl gate
```

Then run the Flutter app pointed at it:

```bash
flutter run \
  --dart-define=ENABLE_EXTERNAL_CATALOG=true \
  --dart-define=EXTERNAL_CATALOG_BASE_URL=http://localhost:8081
```

Full details, including the daily scheduler and the manual CLI, are in
`services/catalog_monitor/README.md`. If you'd rather use a native Postgres
install and Apple's `container` CLI than Docker, see that README's § "Local
preview without Docker" for the exact alternative commands. No seed is
needed: the API has a dated, 10-per-source US presentation floor while live
records are unavailable.

### Inspecting crawl metrics

`GET http://localhost:8081/livez` for process liveness and
`GET http://localhost:8081/healthz` for crawl/data freshness per source, or
query `crawl_runs` directly for the underlying numbers
(discovered/fetched/parsed counts, new/changed/missing/inactive items, errors
by type) — see `services/catalog_monitor/README.md` § "Health and metrics".

### Disabling the external feed immediately

- **App**: rebuild without `--dart-define=ENABLE_EXTERNAL_CATALOG=true`. The
  app never calls the service at all in that configuration.
- **Backend**: set `LIVE_CRAWL_ENABLED=false` (the default) and stop
  `npm run monitor`. `GET /v1/external-catalog` keeps serving active rows plus
  the dated curated floor — or stop the API process too, if the client's
  cache-first behavior (`data/external_catalog/external_catalog_repository.dart`)
  should fall back to its local cache instead.

### Owner-managed procurement

The owner workflow does not depend on supplier authorization metadata. The
external feed remains a sourcing list: the owner verifies the current price,
stock, shipping cost, duties, margin, and ability to fulfill the order, then
creates or imports a Shopify product manually. Until that happens, the item
stays outside Monetta checkout. The `CatalogItem`/mapper/repository boundary
keeps this workflow separate so a future feed or supplier API can be added
without rewriting `features/home` or the mixed-feed rules.

## Codegen

`build_runner` drives freezed, json_serializable, drift and riverpod_generator. Run
`make gen`. **Generated files are committed** — CI then builds without a codegen step, which
keeps PR runs fast and makes generated-output diffs reviewable.

**GraphQL is deliberately *not* code-generated.** The original plan specified `ferry`; the
Storefront surface turned out to be ~10 documents over 4 entity shapes, which hand-written
tested mappers cover with less machinery and no `build_runner` dependency for the data layer
to compile. Rationale and the path back: [`lib/data/shopify/README.md`](../lib/data/shopify/README.md) § 3.

`domain/`, `data/normalize/`, `data/shopify/` and `reco/` therefore all compile and test
**before `build_runner` has ever run** — which is why the core could be built and validated
ahead of the toolchain install.

## What lives where — decision log

| Decision | Choice | Why |
|---|---|---|
| Source of truth for catalog | Shopify, always | The owner must never need us to ship a build to change the catalog |
| Where normalization runs | On device (Phase 1) | No backend needed to launch; rules are hot-swappable via Remote Config |
| Where the user profile lives | On device, never uploaded (Phase 1) | Privacy by default under LFPDPPP, and no backend needed |
| Payments | Delegated to Shopify checkout | Keeps PCI scope entirely out of this codebase |
| Navigation structure | Shopify `main-menu` query | Owner controls app nav from Shopify → Navigation |
