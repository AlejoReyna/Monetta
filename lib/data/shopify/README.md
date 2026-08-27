# `data/shopify` — the Storefront API layer

> Pure Dart. The HTTP call is injected as a `GraphQLTransport`, so every file
> here is testable with a fake transport and no network.

## 1. Purpose

Everything the app knows about the catalog comes through this module: products, collections,
**navigation**, search, cart and checkout hand-off.

Its defining constraint: **Shopify is the source of truth and the owner is the only editor.**
Nothing about the catalog — including the app's own navigation structure — may be hardcoded
here.

**Not responsible for:** classifying products (`data/normalize`), caching them
(`data/local`), or ranking them (`reco/`).

## 2. How it works

### The owner-autonomy contract

| App surface | Driven by | Owner edits it in |
|---|---|---|
| Category navigation | `menu(handle: "main-menu")` | Shopify → Navigation |
| Collection screens | `collection(handle:)` | Adding a collection |
| Home section order | shop metafield `app.home_sections` | Settings → Metafields |
| Home collections | shop metafield `app.home_collections` + collection images | Settings → Metafields / Collections |
| Home bag types | shop metafield `app.home_bag_types` + collection images | Settings → Metafields / Collections |
| Social URLs | shop metafield `app.social_links` | Settings → Metafields |
| About home image | shop metafield `app.about_image_url` | Settings → Metafields |
| Customer reviews | Loox Storefront API | Loox → Manage reviews |
| Product badge | product metafield `app.badge` | The product page |
| Brand/category fix-ups | `app.brand_override`, `app.category_override` | The product page |
| Search | `predictiveSearch` | automatic |
| Related products | `productRecommendations` | automatic |

Add a collection in Shopify Admin → it is in the app's menu on the next open. No release.

### Home metafield contract

Expose these **shop** metafields to the Storefront API (`PUBLIC_READ`). All are
optional; missing or malformed values retain the bundled mobile-home fallback.

| Key | Suggested type | Example |
|---|---|---|
| `app.home_sections` | JSON | `["collections","new_products","bag_types","brands","about","social","testimonials"]` |
| `app.home_collections` | JSON | `["guess","carteras-1","relojes"]` |
| `app.home_bag_types` | JSON | `["totes","crossbodys","hombro"]` |
| `app.social_links` | JSON | `{"instagram":"https://…","tiktok":"https://…","facebook":"https://…"}` |
| `app.about_image_url` | Single line text / URL | `https://cdn.shopify.com/…` |

The app reads collection titles and images directly from the referenced
Shopify collections. Products and brands continue to come from the regular
catalog delta sync. Reviews use Loox's public, read-only Storefront API when
the store plan allows it and fall back locally on network/configuration errors.

### Delta sync — retained as the offline/error fallback

```
app foreground
   │
   ├─ read SyncCursor.lastUpdatedAt        (e.g. 2026-08-05T07:24:40Z)
   ├─ products(query: "updated_at:>2026-08-05T07:24:39Z", sortKey: UPDATED_AT)
   │     └─ steady state: 0 products, a few hundred bytes
   ├─ map → normalize → write to drift
   └─ advance cursor to the highest updatedAt seen
```

Staging can additionally enable the Firestore `products` snapshot listener
with `FIRESTORE_CATALOG_ENABLED=true`. A complete valid snapshot replaces the
Drift cache atomically; empty, invalid, disconnected, and error states preserve
the last valid cache. While Firestore is connecting or live, delta sync is
blocked. It becomes eligible only after an error/disconnection (or when no
Firestore listener is configured). Both writers share an exclusive coordinator;
if Firestore reconnects during a fallback sync, its queued snapshot is applied
last and restores Firestore authority.

`Product.id` and `ProductVariant.id` are always Shopify GIDs. The numeric Ajax
ids in the bundled snapshot are canonicalized by its mapper, and database v2
migrates cached v1 product/variant ids plus wishlist, bag, and interaction-event
references.

The `query` argument's supported filter fields on this connection are `available_for_sale`,
`created_at`, `product_type`, `tag`, `tag_not`, `title`, `updated_at`, `variants.price`,
`vendor`.

A **full resync runs every 7 days** regardless, because deletions and unpublishes do not
move `updated_at` on anything we can still see — a delta-only client would keep displaying a
product that had been removed from the store.

### Checkout

```
cartCreate(lines, attributes)  →  cart.checkoutUrl  →  CheckoutLauncher
```

We never see a card number. Shop Pay, MSI and all PCI scope stay with Shopify. The legacy
Checkout API was shut down in April 2025, so cart + `checkoutUrl` is the only supported path.

## 3. Key decisions and why

**No ferry, no GraphQL codegen — a change from the original plan.** The plan specified
`ferry` + `ferry_generator` for typed queries. Building it out, the surface turned out to be
**~10 documents against 4 entity shapes**. Codegen would add a schema-download step, a
generated-code tree, and a hard dependency on `build_runner` running before anything
compiles — in exchange for type safety that ~180 lines of hand-written, individually tested
mappers already provide. The plan explicitly allowed the lighter option if codegen proved
annoying, so this takes it. Reverting is contained: the documents in `queries.dart` are
valid GraphQL and can move to `.graphql` files unchanged.

**The transport is injected.** `StorefrontClient` takes a `GraphQLTransport` function rather
than owning an HTTP client. That keeps this module Flutter-free and network-free under test,
and it is where retry/backoff and offline detection get layered in without touching query
code.

**Errors are unwrapped centrally.** Shopify returns **HTTP 200 with an `errors` array** for
GraphQL-level problems, so status codes alone are misleading. `StorefrontClient` classifies
throttling as `isRetryable` and everything else as permanent — retrying a malformed query
just burns rate limit.

**The delta filter re-requests one second of overlap.** `updated_at` has second granularity,
so an exclusive `>` filter on an exact boundary can silently skip a product saved in the same
second as the previous sync's last record. Re-fetching a few products costs nothing; missing
one is invisible and permanent.

**The access token comes from Remote Config, not the binary.** Storefront tokens are designed
to be public and expose a limited surface, but delivering it remotely means rotation takes
minutes instead of an App Store review.

**The Firestore mirror is authoritative while healthy, not the only boot
path.** It gives the app low-latency product updates, while the bundled
snapshot, Drift cache, and Storefront delta fallback prevent a backend outage
or malformed snapshot from blanking the catalog.

## 4. Data in / data out

**In:** `StorefrontConfig` (domain + token + pinned API version `2026-07`), a
`GraphQLTransport`, and a `SyncCursor` from `data/local`.

**Out:** `Product`, `Collection`, `MenuEntry`, `Cart` (all in `lib/domain/`), plus a
`SyncResult` carrying the advanced cursor.

## 5. Attribution — a commercial requirement, not analytics

Every cart is stamped via `CartAttribution`:

```
_channel: app · _platform: ios|android · _device_id: <anon uuid>
_app_version: 1.0.3 · _rec_source: profile|trending|search|… · _campaign: <id>
```

Keys are `_`-prefixed so Shopify treats them as private — visible in Admin and the Orders
export, hidden from the customer's confirmation.

WhatsApp apartado orders are created by hand in Shopify, so they carry a
human-transcribable code instead: `MN-7K3Q`. The alphabet excludes vowels (no accidental
words) and `0/O/1/I` (mistyped when read off a phone).

Both paths are independently countable by either party, which is what makes a percentage
deal survive a disagreement.

## 6. Gotchas

**`money()` parses strings, not numbers.** Shopify sends `MoneyV2.amount` as a decimal
string (`"1749.00"`). Do not `as num` it.

**Metafields are `null` when unset, and the whole object is absent, not the value.**
`metafieldValue()` handles both; don't index into them directly.

**Never use `apiVersion: 'unstable'`.** The version is pinned and bumped deliberately twice a
year. A sunset version starts failing without warning.

**`predictiveSearch` is not `products(query:)`.** It is cheaper and better ranked for
type-ahead, but it returns a *reduced* product shape — no variants, no tags. Don't feed its
results to `data/normalize`; fetch the full product when the user taps through.

**Collection product counts are inferred, not requested.** We ask for `products(first: 1)`
purely to learn whether a collection is empty (7 of 21 currently are). `productCount` is
`0` or `null` — never a real total.

**Pagination is bounded at 20 pages.** 271 products fit in two. If the catalog ever exceeds
5,000 products the cap needs raising — the loop stops early rather than hanging.

## 7. Tests

```bash
flutter test test/shopify
```

- `test/shopify/catalog_sync_test.dart` — first run fetches everything; the second run sends
  a delta filter; the cursor advances to the highest `updatedAt`; the one-second overlap is
  present; a full resync is forced after 7 days; pagination terminates and is bounded.
- `test/shopify/mappers_test.dart` — real Storefront response shapes, missing images,
  absent metafields, string money amounts.
- `test/shopify/cart_attribution_test.dart` — attribute payload shape, WhatsApp deep link,
  and that generated codes contain no vowels or `0/O/1/I`.

### How to extend

- **New query:** add the document to `queries.dart` reusing `kProductFragment`, add a mapper
  if it returns a new shape, and test it against a captured real response.
- **New owner-controlled surface:** prefer a metafield or metaobject over a hardcoded
  constant — that is the whole design rule of this module.
- **Add retry/backoff:** wrap the injected transport, not the client. `isRetryable` on
  `StorefrontException` already tells you what is safe to repeat.
