# Build-time public configuration

Flutter loads these via:

```bash
flutter run --dart-define-from-file=config/dart_defines.staging.json
```

## Rules

1. **Only public values** belong here: shop domain, public Storefront token,
   Customer Account mobile client id, shop id, backend base URL, feature flags.
2. **Never** put private Storefront tokens, Admin API tokens, app client
   secrets, database URLs, or Firebase service-account keys in these files.
3. Copy an `*.example` file to the matching name without `.example`, fill in
   real values, and leave the real file gitignored.
4. Real production values also belong in CI secret stores / hosting dashboards,
   not only on a laptop.

## Files

| Tracked | Local (gitignored) | Purpose |
|---|---|---|
| `dart_defines.staging.json.example` | `dart_defines.staging.json` | Staging device builds |
| `dart_defines.production.json.example` | `dart_defines.production.json` | Production release builds |

## Verify nothing private is tracked

```bash
# From repo root
./bin/check_no_secrets.sh
```
