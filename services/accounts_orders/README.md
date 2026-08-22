# accounts_orders

Owns first-party Monetta accounts and, when Shopify is linked later, receives its webhooks
and mirrors order/customer state. Sibling service to
`services/catalog_monitor`, same conventions (plain SQL migrations tracked in
`schema_migrations`, `pg` directly, no ORM, structured JSON logging, `createApp(deps)`
dependency injection so the whole HTTP layer is testable without a database).

## 1. First-party accounts

`POST /accounts/register` creates an email/password account, and `POST /accounts/login`
starts a session for a returning user. Passwords are stored as salted scrypt verifiers.
Both endpoints return an opaque 256-bit session token; only its SHA-256 hash is stored in
`app_sessions`, while Flutter keeps the token in Keychain/Keystore. `GET /accounts/me`
validates it and `POST /accounts/logout` revokes it.

Email is deliberately unverified metadata in this interim flow. It does not prove ownership
and cannot yet recover an account on another device. Email verification or passkeys are the
next identity layer; Shopify linkage remains nullable and independent.

## 2. Why the Shopify mirror exists

The Flutter app's Customer Account API login (`lib/data/customer_auth/`) needs no backend —
it's a public OAuth client talking to Shopify directly. This service exists only for the two
things a phone structurally cannot do:

- **Receive webhooks.** `orders/create` and `orders/updated` are how the app ever learns an
  order happened — nothing calls out from the phone to ask.
- **Hold the three mandatory compliance webhooks.** Registering *any* Shopify app brings
  `customers/data_request`, `customers/redact` and `shop/redact` — Shopify requires a
  same-app endpoint that acknowledges each within 30 days (redact topics: acts on it
  immediately). See `src/webhooks/handlers.ts`.

It does not become a general API layer in front of Shopify. The Storefront API and Customer
Account API stay directly reachable from the app, unchanged.

## 3. Shopify credentials are optional

| | Customer Account API "Mobile" client | This app's own Shopify app |
|---|---|---|
| Used by | `lib/data/customer_auth/` (the phone) | This service only |
| Secret? | **No** — a public OAuth client, PKCE instead | **Yes** — the API secret key |
| Used for | Login | Verifying `X-Shopify-Hmac-Sha256` on every webhook |
| Config | `CustomerAccountConfig` (Dart, `--dart-define`) | `SHOPIFY_APP_CLIENT_SECRET` (this service's `.env`) |

The first-party account flow needs neither credential. With
`SHOPIFY_APP_CLIENT_SECRET` empty, webhook verification fails closed while `/accounts/*`
continues to work. A Shopify client secret must never end up in the Flutter app or binary.

## 4. Local development

```bash
cd services/accounts_orders
cp .env.example .env
docker compose up -d postgres
npm install && npm run migrate
npm test                # in-memory repositories, no network, no database
npm start                # API on :8082
```

Without `SHOPIFY_APP_CLIENT_SECRET` set, every Shopify webhook 401s while account
registration remains available.

## 5. Registering the webhooks in Shopify

Each topic gets its own callback URL under this service's public address:

| Topic | URL |
|---|---|
| `orders/create` | `/webhooks/orders/create` |
| `orders/updated` | `/webhooks/orders/updated` |
| `customers/data_request` | `/webhooks/customers/data_request` |
| `customers/redact` | `/webhooks/customers/redact` |
| `shop/redact` | `/webhooks/shop/redact` |

Configure these as this app's webhook subscriptions in the Partner dashboard (or
`shopify.app.toml`, if this app moves to the CLI-managed config flow later).

## 6. Idempotency

Every webhook carries `X-Shopify-Webhook-Id`, stable across Shopify's retries of the *same*
delivery. `webhook_events` is keyed by it: a retried delivery is a harmless duplicate insert
attempt (`ON CONFLICT DO NOTHING`), never double-processed — see
`src/webhooks/handlers.ts#claimDelivery`.

## 7. Compliance topics: what actually happens

- **`customers/data_request`** — Shopify does not require a synchronous data export in the
  webhook response, only an acknowledgment and action within 30 days. This logs the request
  at `warn` level (so it's impossible to miss in the logs) for manual fulfillment; it does not
  attempt to assemble and return a data export inline.
- **`customers/redact`** — actually deletes the mirrored customer row, detaches their orders
  (the order is a business record and survives; only the PII link drops — enforced at the
  schema level too, `ON DELETE SET NULL` in `001_init.sql`, not only in application code),
  and removes their push tokens.
- **`shop/redact`** — this service is single-tenant (one shop), so this wipes every mirrored
  row. Fires ~48h after app uninstall.

## 8. Apartado orders

A large share of this store's revenue is WhatsApp *apartado* (layaway), never touching
Shopify checkout — see `lib/data/shopify/cart_attribution.dart`. When the owner manually
enters that order in Shopify, it arrives through the same `orders/create` webhook as any
other order; `handleOrdersWebhook` detects the `MN-XXXX` attribution code among the order's
tags (matched against `AttributionCodeGenerator`'s actual alphabet, not just a `MN-` prefix)
and mirrors it with `source = 'whatsapp_apartado'` instead of `'shopify_checkout'` — see
`docs/ACCOUNTS_AND_SYNC_PLAN.md` Phase 3.

## 9. Known limitations

- Email is not verified and password recovery is not implemented yet, so UI copy must not
  promise either.
- Deployments should rate-limit `POST /accounts/register` and `POST /accounts/login` at the
  edge before public launch.

- **`POST /push-tokens` has no request authentication yet.** It's internal/prototype status
  only, the same posture `services/catalog_monitor` ships its live-crawl gate with. Before
  this leaves prototype status, requests should carry the Customer Account API access token
  the app already holds after login, verified here (e.g. by calling the Customer Account API
  with it) rather than trusting an unauthenticated `customerId` field.
- **No `customers/update` webhook subscribed yet.** `customers_mirror.marketing_consent`
  therefore never becomes `true` here — only what a webhook actually carries is ever written,
  never a fabricated default. Order webhooks are enough to seed a customer row but not to keep
  full profile fields current.
- **The Flutter side of "real Shopify sync"** — attaching the signed-in customer to a
  Storefront cart's `buyerIdentity`, pulling saved addresses for delivery prefill — needs
  actual Storefront `cartCreate`/`cartLinesAdd` mutations to attach to, and those don't exist
  in this codebase yet independent of accounts: checkout currently ends at `CheckoutDraft`
  (`lib/features/checkout/checkout_screen.dart`), explicitly not yet wired to a real Shopify
  cart (see `docs/CHECKOUT_DESIGN.md` § "Security and integration boundary"). That gap predates
  this plan and is out of scope here.

## 10. Tests

```bash
npm test
```

- `test/verifyHmac.test.ts` — correct/incorrect/tampered signatures, missing header, empty
  secret fails closed, malformed base64 and wrong-length signatures don't throw.
- `test/handlers.test.ts` — order mirroring, apartado tag detection (including the
  false-positive guard against an `MN-` tag outside the real alphabet), idempotent retries,
  the three compliance topics' actual effects on mirrored data.
- `test/api.test.ts` — the same, over real HTTP against an ephemeral server with real HMAC
  signing, matching `services/catalog_monitor/test/api.test.ts`'s pattern.
- `test/webhookRoutes.test.ts` — drift guard: every `uri` in every `shopify/shopify.app*.toml`
  must resolve to a route this server registers. Shopify POSTs to whatever absolute path the
  deployed config names, and a path with no route 404s silently — for the three mandatory
  compliance topics that is a compliance failure, not a missing feature. The test POSTs a
  deliberately wrong signature to each configured path: a real route answers 401, a missing
  one answers 404.

All of them run against in-memory repositories (`test/support/inMemoryRepositories.ts`) — no
database, no network.

## 11. Deploy (staging)

**Postgres: Neon.** Managed, TLS required by default, and `src/db/pool.ts` hands the
connection string straight to `pg.Pool`, which honours `?sslmode=require` — no code change.

**App: Fly.io** (`fly.toml`). Migrations only reach `dist/` through the Dockerfile's explicit
`COPY src/db/migrations ./dist/db/migrations`; `tsc` does not copy `.sql`, and `npm run migrate`
shells out to `tsx`, a devDependency the runtime stage omits. Fly builds this Dockerfile
unchanged, so the deployed image is the one `docker-compose` already runs. A buildpack platform
would produce a container that cannot migrate.

Inside the container the release path is therefore `node dist/db/migrate.js` (wired as Fly's
`release_command`) and `node dist/api/server.js` — **not** `npm run migrate` / `npm start`,
which are the local-dev, tsx-on-`src` path.

```bash
# One-time, by a human with the accounts:
brew install flyctl
fly auth login
fly launch --no-deploy --copy-config --name monetta-accounts-staging   # in this directory

# Neon: create a project, copy its pooled connection string.
fly secrets set DATABASE_URL='postgres://…@…neon.tech/…?sslmode=require'

# The Shopify app secret. Dev Dashboard → monetta-staging → Configuración →
# Credenciales → Secreto. Paste it yourself; it belongs in no file and no chat.
fly secrets set SHOPIFY_APP_CLIENT_SECRET='shpss_…'

fly deploy
fly status                       # confirm the release_command ran and checks are passing
curl -fsS https://monetta-accounts-staging.fly.dev/livez
```

An empty `SHOPIFY_APP_CLIENT_SECRET` is not a crash — `config.ts` keeps the service up and
every webhook route fails closed with 401 (see § 3). That is the correct posture, and it
means the app boots fine before the secret is set.

Then point Shopify at it: replace `REPLACE_STAGING_BACKEND_HOST` in
`shopify/shopify.app.staging.toml`, and from `shopify/`:

```bash
npm_config_cache=../.npm-cache npx shopify app config validate --config staging
npm_config_cache=../.npm-cache npx shopify app deploy --config staging --no-release
```

Review the diff, release, then install the app on `monetta-staging.myshopify.com` only —
never on the production store (`monetta.mx` / `fakcei-n9` / admin handle `monetta-2`).
