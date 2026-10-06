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
it's a public OAuth client talking to Shopify directly. This service owns the customer-scoped
mirror and the two things a phone structurally cannot do:

- **Serve mirrored order history safely.** `GET /customers/me/orders` accepts a bearer
  credential, resolves its owner server-side through Shopify's Customer Account API (or an
  explicitly linked Monetta session), and only then reads that customer's rows. There is no
  caller-controlled customer id in the route.

- **Receive webhooks.** `orders/create` and `orders/updated` are how the app ever learns an
  order happened — nothing calls out from the phone to ask.
- **Hold the three mandatory compliance webhooks.** Registering *any* Shopify app brings
  `customers/data_request`, `customers/redact` and `shop/redact` — Shopify requires a
  same-app endpoint that acknowledges each within 30 days (redact topics: acts on it
  immediately). See `src/webhooks/handlers.ts`.

It does not become a general API layer in front of Shopify. The Storefront API and Customer
Account API stay directly reachable from the app; this service uses the latter only to verify
the owner of credentials presented to customer-scoped endpoints.

## 3. Shopify credentials are optional

| | Customer Account API "Mobile" client | This app's own Shopify app |
|---|---|---|
| Used by | `lib/data/customer_auth/` (the phone) | This service only |
| Secret? | **No** — a public OAuth client, PKCE instead | **Yes** — the API secret key |
| Used for | Login and bearer identity | Verifying `X-Shopify-Hmac-Sha256` on every webhook |
| Config | `CustomerAccountConfig` (Dart, `--dart-define`) and `SHOPIFY_STORE_DOMAIN` (service) | `SHOPIFY_APP_CLIENT_SECRET` (this service's `.env`) |

`SHOPIFY_STORE_DOMAIN` is public configuration, not a secret. It is required for validating
Shopify customer tokens on `GET /customers/me/orders` and `POST /push-tokens`; verification
fails closed if it is absent or Shopify is unavailable. The first-party account flow needs
neither credential. With
`SHOPIFY_APP_CLIENT_SECRET` empty, webhook verification fails closed while `/accounts/*`
continues to work. A Shopify client secret must never end up in the Flutter app or binary.

## 4. Local development

### Application database with Docker

```bash
cd services/accounts_orders
cp .env.example .env
docker compose up -d postgres
npm install && npm run migrate
npm test                 # PostgreSQL tests are optional outside CI; see G7 below
npm start                # API on :8082
```

This Compose database uses `localhost:5434`, user/password `accounts_orders`, and
database `accounts_orders`, matching `.env.example`.

Without `SHOPIFY_APP_CLIENT_SECRET` set, every Shopify webhook 401s while account
registration remains available.

### PostgreSQL 16 on macOS for G7

G7 runs the backend suite with PostgreSQL persistence tests required, matching CI.
It uses `localhost:5432`, user `postgres`, password `postgres`, and administrative
database `postgres`. Node 24 and Homebrew are prerequisites for these instructions.

Install PostgreSQL 16 and start it now and automatically at login:

```bash
brew install postgresql@16
export PATH="$(brew --prefix postgresql@16)/bin:$PATH"
brew services start postgresql@16
```

The `export` makes `psql` available in the current shell; add it to your shell profile
if the PostgreSQL commands are not already on your PATH.

On the default Homebrew cluster, configure the local test administrator once:

```bash
psql -d postgres -X -v ON_ERROR_STOP=1 <<'SQL'
SELECT 'CREATE ROLE postgres WITH LOGIN SUPERUSER'
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'postgres')
\gexec
SET password_encryption = 'scram-sha-256';
ALTER ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'postgres';
SQL
```

Homebrew initially uses `trust` for local connections. To require the password over
TCP, back up the authentication file, update its localhost `host` rules, and reload:

```bash
g7_pg_data="$(brew --prefix)/var/postgresql@16"
cp -p "$g7_pg_data/pg_hba.conf" "$g7_pg_data/pg_hba.conf.before-g7"
perl -i -pe 's/^(host\s+\S+\s+\S+\s+(?:127\.0\.0\.1\/32|::1\/128)\s+)trust\b/${1}scram-sha-256/' "$g7_pg_data/pg_hba.conf"
psql -d postgres -X -v ON_ERROR_STOP=1 -c 'SELECT pg_reload_conf();'
```

Verify the connection and run G7 from the repository root:

```bash
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d postgres -X -v ON_ERROR_STOP=1 -c 'SELECT version(), current_user;'
npm --prefix services/accounts_orders ci
REQUIRE_POSTGRES_TESTS=1 WP01_PG_ADMIN_URL=postgres://postgres:postgres@localhost:5432/postgres npm --prefix services/accounts_orders test
```

The tests create their own temporary databases, apply all SQL migrations, and delete
the databases afterward. The `postgres` role needs administrative privileges for
these fixtures. No application `.env` or manual migration is needed for G7.
`REQUIRE_POSTGRES_TESTS=1` makes an unavailable database fail the run; G7 passes only
with zero failures and zero skipped tests.

To start the service again, use `brew services start postgresql@16`. To stop it and
disable automatic startup, use `brew services stop postgresql@16`.

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

- Customer-facing routes require a bearer credential and derive the Shopify customer id on
  the server. `POST /push-tokens` ignores any caller-supplied `customerId`, and a device token
  already owned by a different customer cannot be reassigned through that endpoint.
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
  signing, plus customer authorization, ID-spoofing and device-token takeover boundaries,
  matching `services/catalog_monitor/test/api.test.ts`'s pattern.
- `test/customerTokenVerifier.test.ts` — Customer Account API discovery, identity lookup,
  invalid-token handling, response bounds and unsafe endpoint rejection.
- `test/webhookRoutes.test.ts` — drift guard: every `uri` in every `shopify/shopify.app*.toml`
  must resolve to a route this server registers. Shopify POSTs to whatever absolute path the
  deployed config names, and a path with no route 404s silently — for the three mandatory
  compliance topics that is a compliance failure, not a missing feature. The test POSTs a
  deliberately wrong signature to each configured path: a real route answers 401, a missing
  one answers 404.

The tests listed above use in-memory repositories (`test/support/inMemoryRepositories.ts`)
and local HTTP fixtures. The `*.pg.test.ts` suites exercise real PostgreSQL persistence
for account security, webhook recovery, and the rewards ledger. Outside CI, they are
skipped when PostgreSQL is unavailable unless `REQUIRE_POSTGRES_TESTS=1` is set. Use
[G7](#postgresql-16-on-macos-for-g7) to require all PostgreSQL tests.

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

# Public store hostname used to verify Customer Account API bearer tokens.
fly secrets set SHOPIFY_STORE_DOMAIN='monetta-staging.myshopify.com'

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

## 12. Engagement y notificaciones

La implementación completa vive en `src/engagement`: instalaciones anónimas
atestadas con App Check, registros FCM cifrados, preferencias por finalidad,
perfil compacto, campañas, cola Postgres, worker HTTP v1, rutas internas y panel
del dueño. También procesa `products/create` / `products/update` para detectar
regresos y bajas de precio. Está apagada salvo que
`NOTIFICATIONS_ENABLED=true`.

La lista exacta de secretos, procesos, dart-defines y la secuencia de activación
está en `../../docs/PUSH_NOTIFICATIONS_RUNBOOK.md`. En Fly hay que mantener un proceso
`app` y uno `worker`; sólo el primero recibe HTTP.

## 13. PostgreSQL in production

Provision a managed **PostgreSQL 16** database for production; Neon is the provider
used by the staging deployment above. Keep production infrastructure and credentials
separate from staging and local G7 fixtures. The checked-in `fly.toml` targets
`monetta-accounts-staging`; a production release needs its own Fly app and configuration.

### Required settings

| Setting | Production requirement |
|---|---|
| Database | Dedicated production database with a writable primary endpoint; use the `public` schema for the current unqualified SQL migrations. |
| Role | Dedicated login with a generated password; database `CONNECT`, schema `USAGE`/`CREATE`, and ownership of the objects created by migrations. No PostgreSQL superuser, role-management, or database-creation privileges are required. |
| Connection | Provider's remote hostname and port, reachable from the backend. Use a direct endpoint as the baseline for this service. |
| TLS | `sslmode=verify-full`, with a valid hostname and a trusted server certificate. The application passes this URL to `pg.Pool`; retain certificate verification. |
| Secrets | Store `DATABASE_URL` in the production hosting application's secret vault. Keep its value out of Git, documentation, logs, shell history, Docker images, and Flutter configuration. |
| Runtime | Set `NODE_ENV=production`; configure the production Shopify domain and its own server-side secrets for enabled integrations. |
| Recovery | Configure backup retention and recovery targets with the provider, and verify restoration into a separate database before launch. |

Connection-string shape, with placeholders only:

```text
DATABASE_URL=postgresql://<app-role>:<url-encoded-password>@<direct-production-db-host>:5432/<production-db>?sslmode=verify-full
```

Use the provider's actual port if it differs from `5432`. Encode special characters in
the role/password components as URL components. TLS handling is documented by
[node-postgres](https://node-postgres.com/features/ssl).

The current code uses the same `DATABASE_URL` for the API and the release migration
command. That role therefore needs migration ownership/DDL permissions as well as
application reads, writes, and sequence access. Separate migration and runtime roles
require explicit deployment wiring; there is currently no separate migration URL setting.

The Rewards maintenance worker uses session advisory locks, which are incompatible
with transaction pooling ([PgBouncer compatibility](https://www.pgbouncer.org/features.html)).
A direct endpoint avoids that pooler limitation. The current worker also acquires and
releases its session lock through `pool.query`, which can select different connections;
before enabling it in production, pin acquisition, maintenance, and release to the same
checked-out client. A direct URL alone does not resolve that code limitation.

### Injecting the secret without exposing it

Use a trusted terminal with shell tracing disabled. The following Bash/zsh example
reads the URL without echoing it and sends it through standard input to the production
Fly app. Replace only the app-name placeholder in the command; enter the URL at the prompt:

```bash
set +x
printf 'Production DATABASE_URL (hidden): ' >&2
IFS= read -r -s monetta_prod_database_url
printf '\n' >&2
printf 'DATABASE_URL=%s\n' "$monetta_prod_database_url" | fly secrets import --app '<production-fly-app>' --stage
unset monetta_prod_database_url
```

`--stage` stores the secret for the next deployment. Inspect secret names and status
with `fly secrets list --app '<production-fly-app>'`; it does not return their values.
See [Fly secrets](https://docs.fly.io/apps/secrets) and
[`fly secrets import`](https://docs.fly.io/flyctl/cmd/fly_secrets_import).

### Migrations and verification

Use the service Dockerfile, which includes the SQL files in the runtime image, and
configure the production release command as `node dist/db/migrate.js`. Run one
migration process at a time before the new API receives traffic. `schema_migrations`
tracks applied files, and each new migration runs in a transaction. Preserve existing
migrations and add new files for schema changes.

After a production release, verify the API's database readiness:

```bash
curl -fsS 'https://<production-api-host>/readyz'
```

Expect `{"status":"ok","database":"up"}`. `/livez` and `/healthz` confirm only that
the HTTP service is alive. Run G7 against the local test instance; its fixtures create
and delete databases.

The base application pool currently allows 10 connections, and the webhook claim pool
adds up to 4 per API process. Budget for every API replica, worker, release process,
and administrative session within the provider's connection limit. Monitor readiness,
connection exhaustion, failed migrations, and backup/restore health. When rotating the
database password, update the hosting secret and restart the affected processes before
revoking the previous credential.
