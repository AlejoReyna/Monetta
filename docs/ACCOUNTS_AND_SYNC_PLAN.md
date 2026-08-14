# Accounts, real persistence, and Shopify sync — plan

Companion diagram: `~/Desktop/monetta-erd.png` (`.svg` alongside it) — the target
entity model referenced throughout this plan. Gray = real today, blue =
documented in `ARCHITECTURE.md` but never built, gold = new.

## Status: Phases 0–3 implemented (14 Aug 2026)

All four phases below are built and tested. Three things landed differently
than originally sketched, worth knowing before reading the rest as history
rather than as still-open design:

- **No `go_router` wiring was needed for login.** § 4's Phase 1 entry
  assumed the custom-scheme redirect would need `go_router` deep-link
  routing. It doesn't: `flutter_appauth` (wrapping the native AppAuth
  iOS/Android SDKs) captures the OAuth redirect itself and returns control
  directly to the awaiting `Future` — see `lib/data/customer_auth/README.md`
  § 2. `go_router` remains an unused dependency.
- **The backend is `services/accounts_orders/`**, not a name this doc had
  settled on — mirrors `services/catalog_monitor`'s conventions exactly
  (plain SQL migrations, `pg`, `createApp(deps)` DI). See its own README for
  the webhook registration, the two-credential distinction (Customer
  Account API client vs. this service's `SHOPIFY_APP_CLIENT_SECRET`), and
  known limitations (`POST /push-tokens` and `GET /customers/:id/orders`
  currently have no request-level auth — flagged there as prototype-status,
  same posture `catalog_monitor` ships its live-crawl gate with).
- **§ 4 Phase 2's `buyerIdentity`/address-prefill line was never actionable
  yet.** It assumed Storefront `cartCreate`/`cartLinesAdd` mutations already
  existed to attach a `buyerIdentity` to. They don't — checkout still ends
  at `CheckoutDraft` (`lib/features/checkout/checkout_screen.dart`),
  explicitly not wired to a real Shopify cart
  (`docs/CHECKOUT_DESIGN.md` § "Security and integration boundary"). That
  gap predates this plan and wasn't created or closed by it; what *did* ship
  for "real sync" is `CatalogRepository.sync()`
  (`lib/data/repositories/catalog_repository.dart`) — a real, tested delta
  sync against `data/shopify`'s `CatalogSync`, inert only because no
  Storefront token is configured yet, and the webhook-driven order mirror
  in `services/accounts_orders`.

§ 5's three open decisions: merge-on-login was confirmed and implemented
(`CustomerSessionRepository.login`); Partner-dashboard registration was
deferred to you, with `CustomerAccountConfig`/native config left on clearly
literal placeholders — see `lib/data/customer_auth/README.md` § 8; login
methods (OTP/social/passkeys) turned out not to be an app-side decision at
all — that's Shopify Admin configuration of the hosted login page, not
something this codebase selects.

> Written 14 Aug 2026. Shopify deprecated legacy Liquid-based customer
> accounts (and Multipass with them) in February 2026 — this plan assumes
> the Customer Account API as the only available path, not a choice among
> several.

## 1. Where the app actually is today

Two things are true at once, and the gap between them is the reason this
plan exists:

1. **There are no accounts.** No `firebase_auth`, no `Customer` type, no
   login screen, nothing named `auth` anywhere in `lib/`. Checkout is
   guest-only: `CheckoutDraft` (`lib/features/checkout/checkout_screen.dart`)
   collects contact + delivery details fresh every time and is never
   persisted. A large share of orders bypass Shopify checkout entirely — the
   WhatsApp *apartado* (layaway) flow (`lib/data/shopify/cart_attribution.dart`)
   — and exist only as hand-entered Shopify orders tagged with a short code
   (`MN-7K3Q`).
2. **`data/local/` (Drift) is documented, not implemented.** `docs/ARCHITECTURE.md`
   describes a Drift database for the catalog cache, sync cursor, wishlist,
   and recommendation events — `drift` is even in `pubspec.yaml` — but
   `lib/data/local/` doesn't exist and nothing is generated. Today the bag is
   in-memory (`StoreScope`), the recommendation profile rebuilds every
   session, and there's no delta-sync cursor to persist, so `data/shopify`'s
   documented sync contract has nowhere to write.

The only **real, running database** in this repo is `services/catalog_monitor`'s
Postgres instance (`sources`, `products`, `crawl_runs`) — an internal
scraper for competitor catalogs, unrelated to accounts or orders, but a
useful existing pattern: plain SQL migrations tracked in `schema_migrations`,
no ORM, `pg` driver. Reuse that shape rather than inventing a second one.

## 2. What I checked before proposing anything

Shopify's headless auth story changed enough in the last year that it was
worth verifying against current docs rather than assuming the old classic-accounts
model still applied:

- **Classic customer accounts + Multipass are gone** (deprecated Feb 2026).
  The **Customer Account API** (GraphQL, OAuth 2.0) is now the only
  Shopify-native way to authenticate a shopper — there is no "simpler,
  legacy" fallback to reach for instead.
- It ships a **Mobile client type built for exactly this app's shape**: a
  *public* OAuth client (no client secret, because a compiled app can't keep
  one) using **PKCE**, with a mandated custom callback scheme
  (`shop.{shop_id}.`) instead of a web redirect URL. This is a native
  deep-link login, not a WebView wrapping a web login form.
- It supports **passwordless (email/SMS OTP), social login, and passkeys**
  out of the box — Shopify's hosted UI handles credential collection, so
  this app never touches a password.
- Getting a `client_id` requires registering a Shopify app in the Partner
  dashboard, which in turn brings **three mandatory compliance webhooks**
  (`customers/data_request`, `customers/redact`, `shop/redact`) — a 200
  response within 30 days is a hard requirement, not best-effort. This is
  the concrete reason a backend is unavoidable even though the login flow
  itself needs no server.

Sources: [Getting started with the Customer Account API](https://shopify.dev/docs/storefronts/headless/building-with-the-customer-account-api/getting-started) · [Privacy law compliance](https://shopify.dev/docs/apps/build/compliance/privacy-law-compliance) · [Shopify New Customer Accounts 2026 — What Changed](https://ogresto.com/blogs/shopify-new-customer-accounts-2026)

**What this settles:** don't build custom auth, don't store passwords, and
don't expect to skip a backend just because the OAuth client is public. The
login flow is client-only; order sync and compliance are not.

## 3. Proposed architecture (see the ERD)

Four systems, matching the ERD's four clusters:

| Cluster | Status | This plan's job |
|---|---|---|
| Shopify (remote) | Real; adds `Customer`, `CustomerAddress`, `Order` read-back | Auth + identity source of truth |
| Monetta local DB (Drift) | **Documented, unbuilt** | Build it for real; add `Account`, `Device`, `Session`, `OrderSummaryCache` |
| `catalog_monitor` Postgres | Real, unrelated | Pattern to copy, not to extend |
| Accounts & Orders service | **New** | Webhook receiver + compliance + order mirror |

The new backend is deliberately small and single-purpose — it does not
become a general API layer in front of Shopify. The Storefront API and
Customer Account API stay directly reachable from the app, unchanged from
today's "Shopify is the source of truth, we cache it" design. The backend
exists only where a phone structurally cannot do the job: receiving
webhooks, and holding compliance obligations tied to a registered app.

## 4. Phased rollout

**Phase 0 — Build the local DB that's already documented (no accounts needed)**
Implement `lib/data/local/` per `ARCHITECTURE.md`: `CachedProduct/Variant/Collection`,
`SyncCursor`, `WishlistItem`, `InteractionEvent`. Move `BagLine` from
`StoreScope` in-memory state into Drift. This is overdue independently of
accounts — `data/shopify`'s delta-sync contract and `reco/`'s event log both
assume it exists — and de-risks Phase 1+ by proving the Drift setup before
an `Account` FK gets added on top of it.

**Phase 1 — Login, additive to guest checkout**
Register the Partner app, implement the Mobile-client OAuth+PKCE flow
(custom URL scheme via `go_router`, already a dependency), store the refresh
token in `flutter_secure_storage` (already a dependency — never in the
Drift DB itself, per the ERD's `Session.secureStorageKeyRef`). Add
`Account`/`Device`/`Session` tables. **Guest checkout stays the default** —
`docs/CHECKOUT_DESIGN.md` already states "no account wall" as a design rule,
and nothing here should override it. Login buys the shopper faster repeat
checkout and order history; it is never required to buy.

**Phase 2 — Real Shopify sync + the backend**
Attach the signed-in customer to the Storefront cart's `buyerIdentity`, pull
saved addresses for delivery prefill, and stand up the Accounts & Orders
Postgres service: `orders/create` + `orders/updated` webhooks into
`orders_mirror`, the three mandatory compliance webhooks into
`webhook_events`, and push-token registration tied to an account instead of
only an anonymous device. Copy `catalog_monitor`'s migration/`pg` pattern
rather than adding a framework.

**Phase 3 — Unify WhatsApp apartado into order history**
Apartado orders are entered by hand in Shopify with an `MN-XXXX` tag and no
app-side record. On `orders/create`, if the order carries an `MN-` tag,
match it to the account by email/phone and write it into `orders_mirror`
alongside real checkout orders, so "Mis pedidos" shows both without the
shopper caring which channel they used.

**Phase 4 — optional, explicitly deferred**
Cross-device taste-profile sync. `reco/README.md` currently states events
"never leave the device" as a stated privacy default under LFPDPPP — don't
reverse that as a side effect of adding accounts. If cross-device
personalization is wanted later, it needs its own opt-in, not inheritance
from "the shopper is logged in."

## 5. Open decisions for you

- **Login methods to expose**: email OTP only, or also social/passkeys? All
  are available from the Customer Account API's hosted UI at no extra
  backend cost — this is a product choice, not an engineering constraint.
- **Where the new Postgres service runs**: alongside `catalog_monitor`'s
  existing Postgres instance (same host, new schema) or fully separate. The
  former is less infra to run; the latter isolates a compliance-bearing
  service from a scraper prototype that's already labeled internal-only.
- **Wishlist/bag scope before login**: the ERD gives both a nullable
  `accountId` — device-scoped until sign-in, then merged. Confirm that
  merge-on-login (rather than discard-on-login) is the wanted behavior.
