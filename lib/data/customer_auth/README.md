# `data/customer_auth` — Shopify Customer Account API login

Account-side counterpart to `data/shopify/`. See `docs/ACCOUNTS_AND_SYNC_PLAN.md` for the
plan this implements and the investigation behind it.

## 1. Why this exists, and why now

Shopify deprecated classic Liquid-based customer accounts — and Multipass with them — in
February 2026. The Customer Account API's OAuth 2.0 + PKCE flow is not one option among
several for a headless client like this app; it is the only one left.

## 2. The Mobile client, and why there's no hand-rolled crypto here

Shopify's Customer Account API has a client type built for exactly this app's shape: a
**public** OAuth client (no client secret — a compiled app cannot keep one), authenticated by
**PKCE** instead, with a mandated custom-scheme redirect (`shop.{shop_id}.*`) rather than a
web callback URL.

`AppAuthCustomerGateway` hands the entire authorization request — opening the browser,
generating the PKCE `code_verifier`/`code_challenge`, capturing the redirect, exchanging the
code — to AppAuth's native iOS/Android SDKs via `package:flutter_appauth`. That is a
deliberate choice not to reimplement any of it in Dart: PKCE and the browser hand-off are a
solved problem with a widely used, independently audited implementation, and this is real
authentication code, not a place to prefer a hand-written 50 lines over a battle-tested
library the way `data/shopify/`'s GraphQL layer prefers hand-written mappers over codegen.

## 3. Two trust boundaries, two different answers on verification

- **The id token's signature is not verified** (`jwt.dart`). It arrives directly from
  Shopify's token endpoint over TLS in the same exchange that already trusts that channel —
  there is no untrusted party in a position to forge it here. Verifying it would add real
  cryptographic surface for no corresponding gain.
- **The PKCE exchange itself is never hand-rolled** (§ 2) — the opposite conclusion, because
  that *is* the mechanism establishing the trust boundary in the first place.

Both are the same principle — verify what you don't already trust, and don't reimplement
what you do — pointing in opposite directions depending on which side of the exchange you're
looking at.

## 4. Token storage

| What | Where | Why |
|---|---|---|
| Refresh token | `flutter_secure_storage` (Keychain/Keystore), via `SecureTokenStore` | Long-lived; must survive a restart; must never sit in a plain SQLite file |
| Access token | Nowhere — held in memory by the caller for the process lifetime | Short-lived by design; persisting it buys nothing and adds a second thing that can go stale |
| Id token | `flutter_secure_storage` as `id_token_hint` for hosted logout only | Never used as an API credential; deleted on logout |
| Everything else (email, `shopifyCustomerId`, session metadata) | `data/local`'s `Accounts`/`Sessions`/`Devices` tables | Not secret; same Drift database as the catalog cache |

`Sessions.secureStorageKeyRef` is the seam: `data/local` knows a session exists and when its
access token expires, `data/customer_auth` is the only thing that ever reads the token value
itself out of secure storage.

## 5. Login is additive, never a wall

`docs/CHECKOUT_DESIGN.md` states "no account wall" as a design rule for checkout. Nothing in
this module changes that: guest checkout keeps working exactly as before, and login exists to
make repeat checkout faster and enable order history / cross-device wishlist — never as a
requirement to buy.

## 6. Merge on login

A wishlist or bag built while signed out is device-scoped (`accountId IS NULL` in
`WishlistItems`/`BagLines`). `CustomerSessionRepository.login()` attaches every such row to
the newly-signed-in account rather than discarding it or leaving it stranded — see
`WishlistStore.mergeDeviceItemsIntoAccount` / `BagStore.mergeDeviceItemsIntoAccount`. A row
already scoped to a *different* account is left alone; merging it would mean two people
signed into the same device, which this repository does not try to arbitrate.

## 7. What Phase 1 does not do

- **No API calls beyond the token exchange.** Fetching orders or addresses with the access
  token this module produces is Phase 2 (`docs/ACCOUNTS_AND_SYNC_PLAN.md`), once the backend
  that receives Shopify's webhooks exists too.
- **No silent background refresh loop.** `refreshAccessToken` is a method to call, not a
  timer this module starts on its own — the caller (a future account controller) decides
  when a call is about to need a fresh token.
- **No cross-device profile sync.** `reco/`'s event log stays device-only regardless of
  login state — see `docs/ACCOUNTS_AND_SYNC_PLAN.md` § 4, Phase 4, deliberately deferred.

## 8. Setup this module still needs before it runs for real

- A Customer Account API Mobile client registered in the Shopify Partner dashboard, giving a
  `shp_`-prefixed `clientId` and the shop's `shopId` — see `CustomerAccountConfig`.
- The redirect scheme `shop.{shopId}.*` registered as a URL type in
  `ios/Runner/Info.plist` (`CFBundleURLTypes`) and as `appAuthRedirectScheme` in
  `android/app/build.gradle`.

Until then, `CustomerAccountConfig.isUsable` is false and login is unavailable — the same
honest-default pattern as `StorefrontConfig.isUsable`.

## 9. Tests

```bash
flutter test test/data/customer_auth
```

Exercised against a fake `CustomerAuthGateway` and a fake `SecureTokenStore` (defined in the
test file, not shipped in `lib/` — see `test/shopify/catalog_sync_test.dart`'s `FakeTransport`
for the same pattern applied to `data/shopify`), so none of it touches a platform channel:
login creates an account and merges device-scoped wishlist/bag rows; logging in twice with the
same `sub` claim reuses the same `localAccountId` rather than creating a second account;
refresh updates the stored token without creating a second session row; logout clears the
secure-storage entry and detaches the device.
