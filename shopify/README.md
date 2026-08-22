# Shopify CLI workspace (Monetta)

Configuration-only directory for the **CLI-managed Shopify app** that owns
webhooks and compliance for `services/accounts_orders/`.

This is **not** the Flutter project root. Never run `shopify app init` from the
repo root — it will try to restructure the Flutter tree.

Companion plan: [`docs/SHOPIFY_PRODUCTION_IMPLEMENTATION_PLAN.md`](../docs/SHOPIFY_PRODUCTION_IMPLEMENTATION_PLAN.md).

## Three separate Shopify identities

| Identity | Where created | Mobile-safe | Backend-only |
|---|---|---|---|
| Headless storefront | Admin → Sales channels → Headless | shop domain, public Storefront token | private Storefront token (usually unused) |
| Customer Account mobile client | Headless → Customer Account API | shop ID, public client ID, callback | none (public PKCE client) |
| This CLI app | Dev Dashboard / `shopify app config link` | none | client ID (public in TOML) + **client secret** on the server as `SHOPIFY_APP_CLIENT_SECRET` |

Do not put Headless tokens or Customer Account values into these TOML files.

## Install CLI (this machine)

Global `npm install -g @shopify/cli` may fail if `~/.npm` has root-owned cache
entries. Prefer the local install already in this directory:

```bash
cd shopify
npm_config_cache=../.npm-cache npm install
npx shopify version   # expected: 4.6.1 or newer
```

## Owner-only: authenticate and link

Auth can be done by the agent; **app config link is interactive** (Ink UI with
arrow keys) and must be run in your own terminal:

```bash
cd /Users/alexis/develop/monetta-app/shopify
npm_config_cache=../.npm-cache npx shopify auth login   # if needed
npm_config_cache=../.npm-cache npx shopify organization list
# expect: Monetta (211167120)
npm_config_cache=../.npm-cache npx shopify store list
# expect: fakcei-n9  Monetta

# Link / create the staging app (writes client_id into the staging TOML)
npm_config_cache=../.npm-cache npx shopify app config link --config staging
```

When prompted:

1. **Create this project as a new app?** → **Yes** if no Monetta Staging app
   exists yet; **No** then pick the existing app if you already created one in
   the Dev Dashboard.
2. Organization → **Monetta**.
3. App name → `Monetta Staging` (if creating).
4. Allow overwrite of `shopify.app.staging.toml` if asked.

Then:

```bash
# After REPLACE_STAGING_BACKEND_HOST is a real HTTPS URL in the TOML:
npm_config_cache=../.npm-cache npx shopify app config validate --config staging
```

If you already know the app **client ID** (public, from Dev Dashboard), the
agent can link non-interactively:

```bash
npm_config_cache=../.npm-cache npx shopify app config link \
  --config staging \
  --client-id YOUR_CLIENT_ID
```

Production linkage is later, only after staging acceptance:

```bash
npx shopify app config link --config production
npx shopify app config validate --config production
```

Every mutating command must pass `--config staging` or `--config production`.

## Headless + Customer Account (Admin UI, not CLI)

On the **staging** store:

1. Install / open the **Headless** sales channel.
2. Create a storefront; publish representative products to it.
3. Copy the **public** Storefront API token and the store domain
   (`something.myshopify.com` or the branded domain used for checkout).
4. Enable **Customer Accounts** (new customer accounts).
5. Create a **Mobile** Customer Account client with callback:

   ```text
   shop.<SHOP_ID>.oauth://callback
   ```

   where `<SHOP_ID>` is the numeric shop id Shopify shows for that store.
6. Approve protected customer data access for the fields the app actually
   renders (profile, addresses, orders).

Put the public values only into a gitignored dart-define file (see
`config/dart_defines.staging.json.example` at the repo root).

## Backend secret

On the host that runs `services/accounts_orders`:

```bash
# Paste the CLI app client secret yourself — never paste it into chat or git.
export SHOPIFY_APP_CLIENT_SECRET=shpss_...
```

Webhook HMAC verification uses this secret. Without it, every webhook returns 401.

## Deploy webhooks (staging only until Phase 7)

```bash
cd shopify
npx shopify app config validate --config staging
npx shopify app deploy --config staging --no-release
# Review the unreleased version in the Dev Dashboard, then release.
```

Trigger a sample webhook only after the staging host is live:

```bash
npx shopify app webhook trigger \
  --api-version=2026-07 \
  --address=https://STAGING_HOST/webhooks/orders/create \
  --topic=orders/create
```

## Scopes

CLI app (`[access_scopes]`): `read_orders,read_customers` only, until a write
path is implemented and justified.

Headless Customer Account (Admin): `customer_read_customers`,
`customer_write_customers`, `customer_read_orders`, and `customer_read_markets`
only if market data is rendered.

## What the agent still needs from the owner

See the Phase 0 checklist in the implementation plan. Minimum to unblock live
staging work:

1. Interactive `npx shopify auth login` completed on this machine.
2. Staging store + Headless public token + domain.
3. Customer Account mobile client id + numeric shop id.
4. Staging backend HTTPS URL + Postgres (or authorization to provision).
5. CLI app client secret entered on the backend host only.
6. Answer: do any real Monetta email/password accounts already exist?
7. Permission for staging test orders/refunds.
