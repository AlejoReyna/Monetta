# Build-time public configuration

Flutter loads these via:

```bash
make run-staging
```

## Rules

1. **Only public values** belong here: shop domain, public Storefront token,
   Loox public store id, Customer Account mobile client id, shop id, backend
   base URL, feature flags.
2. **Never** put private Storefront tokens, Admin API tokens, app client
   secrets, database URLs, or Firebase service-account keys in these files.
3. Copy an `*.example` file to the matching name without `.example`, fill in
   real values, and leave the real file gitignored.
4. Real production values also belong in CI secret stores / hosting dashboards,
   not only on a laptop.
5. `APP_ENV` is mandatory for staging and production builds. A bare Debug
   launch (for example, the Xcode Run button) uses the bundled catalog in an
   explicit local/offline mode so the app remains usable without pointing at
   a remote environment. Use `make run-staging` for the authoritative staging
   catalog; release builds without an environment still stop on the
   configuration screen.

## Files

| Tracked | Local (gitignored) | Purpose |
|---|---|---|
| `dart_defines.staging.json.example` | `dart_defines.staging.json` | Staging device builds |
| `dart_defines.production.json.example` | `dart_defines.production.json` | Production release builds |

`LOOX_PUBLIC_STORE_ID` is the public Loox widget client id already published
on the Shopify storefront. It is not a secret. The app reads
`https://loox.io/widget/{id}/dynamic-carousel/reviews/` — the same JSON the
live carousel uses. An empty value disables the live fetch and keeps bundled
reviews.

`FIRESTORE_CATALOG_ENABLED` is `true` only for a build whose Firebase client
options point at the validated catalog project. Android and iOS use their own
`FIREBASE_ANDROID_*` and `FIREBASE_IOS_*` API key/app id pairs; the shared
project id, sender id and storage bucket stay common. The older
`FIREBASE_API_KEY` and `FIREBASE_APP_ID` names remain a fallback for existing
builds. Firebase API keys and mobile app ids are public client configuration; a
service-account JSON is not and must never appear in a Dart define. An empty,
invalid, or failing Firestore snapshot leaves the Drift catalog intact and the
Shopify delta sync remains a fallback.

The current staging catalog intentionally mirrors the public live Monetta
catalog into the isolated staging Firebase project. If a matching live
Storefront token is unavailable, leave `SHOPIFY_STOREFRONT_ACCESS_TOKEN` empty;
Firestore remains authoritative and this prevents the old development-store
delta fallback from replacing the live cache.

## Verify nothing private is tracked

```bash
# From repo root
./bin/check_no_secrets.sh
```
