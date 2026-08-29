# External catalog — production plan

How `services/catalog_monitor` goes from *research prototype that has never run a
live crawl* to a **production, always-live extraction service** whose output the
Monetta app displays, and whose scope the owner can change at any time —
declaratively, without a redeploy — so it extracts **only the products worth
extracting**.

> This document and the per-module `README.md` files are the contract. If code
> and doc disagree, one of them is a bug — fix both in the same commit.
> The commercial boundary in
> [`US_SOURCING_DURABILITY.md`](US_SOURCING_DURABILITY.md) is **not** relaxed by
> anything here: extracted listings stay `PurchaseMode.ownerProcurement`. This
> plan makes the sourcing desk real, live and selective. It does not turn a
> crawl row into stock.

Written 16 August 2026 against `agent/luxury-checkout-us-catalog`.

---

## 0. How to use this document (agents read this first)

The plan is a dependency graph of **work packages** (`WP-nn`). Each one is sized
for a single agent session and states: what it depends on, which files it
touches, the contract it must satisfy, its acceptance criteria, and the exact
command that verifies it.

**Picking up work:**

1. Find the lowest-numbered WP whose dependencies are all `done`.
2. Read §§ 2–8 for the design it must conform to. Do not re-invent the
   selection model, the diff invariants, or the deploy topology — they are
   specified here on purpose.
3. Implement, then run the WP's *Verify* command **and** the global gate below.
4. Update this file's status table (§ 12) and any README the change contradicts,
   **in the same commit**.

**Definition of done — applies to every WP, no exceptions:**

```bash
cd services/catalog_monitor && npm run typecheck && npm test   # services
cd ../..            && flutter analyze && flutter test         # app
```

- No test opens a socket. `vitest.config.ts` forces `LIVE_CRAWL_ENABLED=false`;
  nothing under `test/` may import `crawl/httpFetcher.ts` or
  `crawl/playwrightFallback.ts`.
- No `package:flutter` import lands in `domain/`, `reco/`, `data/normalize/` or
  `data/shopify/` — `test/architecture_test.dart` enforces it.
- No secret, token, cookie or real contact address is committed. `.env.example`
  gets the *name*; the value lives on the server in `0600` files.
- Additive JSON fields do not bump `schemaVersion`. Breaking ones do, and then
  the Flutter client must tolerate both for one release.

---

## 1. What is being built, in one paragraph

Today the monitor discovers **every** product URL in a brand's sitemap, fetches
all of them once a day, and serves whatever survived — behind a gate that has
never been opened, from a laptop that cannot even reach `coach.com` without
being geo-redirected to `mx.coach.com`. After this plan it runs on the
Atlantic.Net server **in Texas** — whose US egress is what makes the US
storefronts answer at all (§ 8.7) — behind Caddy and TLS, crawls **only what a versioned,
owner-editable selection document matches**, refreshes those items on a short
cycle so prices and stock are actually current, records what changed, alerts by
email when a source breaks, and serves an authenticated, ETag-cached feed the
app renders with per-surface placement. The lever that makes all of it
affordable and defensible is the same one: **selection first, fetch second.**

---

## 2. Constraints inherited (do not renegotiate in code)

| Constraint | Source | Consequence for this plan |
|---|---|---|
| Extracted listings never enter cart/checkout/apartado | `US_SOURCING_DURABILITY.md`, `lib/domain/catalog_item.dart` | The feed grows fields; `PurchaseMode.ownerProcurement` stays |
| No stealth: no proxy pools, no UA spoofing, no CAPTCHA bypass | `catalog_monitor/README.md` § live-crawl gate | A block is a **stop**, not a workaround. Blocked run → alert → source disabled |
| Truthful, contactable `USER_AGENT`; `config.ts` rejects placeholders when live | `src/config.ts` | Go-live requires a real, monitored mailbox |
| robots.txt is checked before every fetch; unavailable robots = refuse | `src/robots/`, `guardedCrawl.ts` | Selection filters *within* what robots allows, never around it |
| Crawling is isolated from the phone | `ARCHITECTURE.md` | The app only ever talks to our API |
| No currency conversion; missing price renders `Consultar precio` | `lib/app/theme.dart#formatCatalogMoney` | Serve `null`, never `0` |
| A partial/blocked/failed run must not mutate `products` | `crawl/runner.ts` | Preserved, and extended in § 4 |

---

## 3. Target architecture

```
                    selection.json  ──apply──►  selection_versions (v1..vN)
                    (git, reviewable)                    │
                                                         │ authoritative at runtime
                                                         ▼
  sitemap index ──► classify ──► robots ──► ┌─────────────────────────┐
   (per source)      (adapter)     gate     │  Stage A: URL selection │  ◄── the "avoid
                                            └───────────┬─────────────┘      extracting
                                                        │ only matches            everything"
                                          ┌─────────────▼─────────────┐          lever
                            discovery run │ fetch · extract · Stage B │
                            (daily)       └─────────────┬─────────────┘
                                                        │
                            watch run     ┌─────────────▼─────────────┐
                            (every 3h,    │ price/stock/variant refresh│
                             pinned 1h)   │ never deactivates          │
                                          └─────────────┬─────────────┘
                                                        ▼
                                            products · product_events
                                                        │  Stage C: serve-time
                                                        │  placement + filters
                                          ┌─────────────▼─────────────┐
                                          │ GET /v1/external-catalog   │ bearer + ETag
                                          └─────────────┬─────────────┘
                                                        ▼
                                    Flutter: ExternalCatalogRepository (cache-first)
                                             → mixed_feed → home rail / browse / hidden
```

### Three run kinds, three costs

| Run | Cadence | Walks sitemaps? | Can deactivate? | Cost |
|---|---|---|---|---|
| `discovery` | daily (`DISCOVERY_CRON`, default `17 3 * * *`) | yes | yes (§ 4) | sitemaps + N selected pages |
| `watch` | every 3h (`WATCH_CRON`) | no | **never** | N selected pages |
| `watch` (pinned tier) | hourly (`PINNED_WATCH_CRON`) | no | **never** | few pages |

"Always live" is the `watch` run. It is affordable *because* selection bounds N:
200 selected products at the existing 1 req/s/domain floor is a ~4-minute sweep.
Crawling 8 000 Coach URLs every three hours is not a product, it is an incident.

---

## 4. The selection model — "which products I'd like to see"

### 4.1 One document, three evaluation stages

```jsonc
{
  "version": 3,                       // set by the apply CLI, never hand-edited
  "note": "Tabby + Brooklyn only; no menswear",
  "sources": {
    "coach_us": {
      "enabled": true,
      "maxSelectedUrls": 400,
      "include": [
        { "id": "coach-tabby",    "kind": "urlPattern", "value": "/products/*tabby*",
          "placements": ["home_rail", "catalog_browse"], "priority": 10 },
        { "id": "coach-brooklyn", "kind": "urlPattern", "value": "/products/*brooklyn*",
          "placements": ["catalog_browse"] },
        { "id": "coach-cu068",    "kind": "externalId", "value": "CU068",
          "tier": "pinned", "placements": ["home_rail"] },
        { "id": "coach-price",    "kind": "priceUsdRange", "value": [150, 600] }
      ],
      "exclude": [
        { "id": "no-mens", "kind": "urlPattern", "value": "/products/*mens*" }
      ]
    },
    "michael_kors_us": { "enabled": true,  "include": [ /* … */ ] },
    "guess_us":        { "enabled": false, "include": [] },
    "steve_madden_us": { "enabled": false, "include": [] }
  }
}
```

| `kind` | Stage | Decided from | Costs a fetch? |
|---|---|---|---|
| `externalId` | A | URL | no |
| `urlExact` | A | URL | no |
| `urlPattern` | A | URL path (glob) | no |
| `all` | A | — (selects the whole source; must be written deliberately) | no |
| `titleKeyword` | B | parsed product | **yes** — page is fetched, then discarded if it fails |
| `category` | B | parsed product | **yes** |
| `priceUsdRange` | B | parsed product | **yes** |
| `availability` | C | stored row | no |
| `placements` / `hidden` | C | stored row | no |

**Stage A is the cost lever.** Stage B rules are legitimate but must be
documented in the CLI output as "costs a fetch per candidate", so an owner never
believes `priceUsdRange` alone narrows the crawl. Stage C changes take effect on
the next API response — no crawl, no deploy, no restart.

### 4.2 Precedence and the fail-closed default

Evaluated in this order, first match wins:

1. an `include` rule with `"tier": "pinned"` → **selected** (the only thing that
   beats an exclude; pins are how the owner keeps one SKU inside a broad exclude)
2. any `exclude` match → **not selected**
3. any `include` match → **selected**, carrying that rule's `placements`,
   `priority` and `tier`
4. otherwise → **not selected**

**A source with zero include rules selects zero products.** Never "everything".
An empty, malformed or unparseable document must abort the run with
`selection_invalid` and leave the previous version in force — it must never
degrade into a full-catalog crawl. There is deliberately no
`SELECTION_ENFORCED=false` escape hatch; crawling a whole source requires
writing `{"kind": "all"}` and meaning it.

**Globs, not regex.** `urlPattern` accepts `*` (any run of non-`/` characters),
`**` (any run including `/`) and nothing else, compiled internally to an
anchored `RegExp` against `URL.pathname`. Owner- and agent-authored regex on a
server that fetches untrusted input is a ReDoS surface for no expressive gain.

### 4.3 Source of truth

| Artifact | Role |
|---|---|
| `services/catalog_monitor/config/selection.json` | **Reviewable seed.** Git-tracked, PR-diffable, validated in CI |
| `selection_versions` table | **Runtime authority.** Every crawl and every API response reads the newest row |
| `npm run selection:apply` / `PUT /admin/selection` | **The only writers.** Both validate, hash, insert a new version, and write the document back to the JSON file so git stays in sync |

Two writers, one shape. The CLI is for agents and deploys; the HTTP endpoint is
for the owner's tooling. Neither mutates a version in place — history is append
only, and a rollback is `selection:apply --version 7`.

### 4.4 The owner's loop

```bash
# 1. What would today's document actually crawl? Sitemaps only — zero product fetches.
npm run selection:preview -- --source coach_us
#    coach_us: 8 431 sitemap URLs → 214 selected (Stage A)
#      coach-tabby      182   coach-brooklyn  27   coach-cu068 1   (excluded: 4)
#    Stage B rules will fetch 214 pages and may discard some: coach-price
#    Budget: 214 / 400 maxSelectedUrls — OK

# 2. Edit config/selection.json (or PUT /admin/selection)

# 3. Apply — validates, bumps the version, records who and why
npm run selection:apply -- --file config/selection.json --by alexis --note "add Brooklyn"

# 4. Stage C changes are live immediately; A/B take effect on the next discovery run
npm run crawl -- --brand coach --kind discovery      # or wait for the cron
```

---

## 5. Diff correctness under a changing selection (the part that breaks silently)

`diffFullSnapshot` marks an item inactive after it is missing from **two
consecutive full snapshots**. Bolt selection onto that naively and the first
narrowed selection reads as "the whole Coach catalog disappeared." These
invariants are mandatory and each one gets a test.

**I1 — `isFullSnapshot` is scoped.** It now means: *every Stage-A-selected,
robots-allowed URL for this source was fetched under selection version V, with
required-field coverage ≥ 98%*. Runs record `selection_version`.

**I2 — the diff's baseline is version-scoped.** "Previously active" is
`products WHERE source_id = S AND is_active AND selection_state = 'selected'
AND selection_version = V`. Rows at another version cannot be counted missing.

**I3 — a version change never deactivates.** On the first full discovery run at
a new V, carried-over rows are stamped `selection_version = V`,
`consecutive_missing_snapshots = 0`, and deactivation is suppressed
(`suppressDeactivation = true`). Normal two-strike deactivation resumes on the
second consecutive full run at V.

**I4 — leaving the selection is not disappearing.** A row that no longer matches
becomes `selection_state = 'deselected'`. It keeps `is_active`, `first_seen_at`
and its history, stops being served, and is restored — not re-created — if it is
re-selected later.

**I5 — watch runs never touch lifecycle.** A `watch` run may update price,
availability, variants, `last_seen_at`, `fingerprint` and append
`product_events`. It may never set `is_active`, never sets
`is_full_snapshot = true`, and never counts toward health freshness.

**I6 — partial means untouched.** Unchanged from today: `blocked`, `partial` and
`failed` discovery runs write nothing to `products`.

---

## 6. Schema changes

```sql
-- src/db/migrations/004_selection.sql
CREATE TABLE IF NOT EXISTS selection_versions (
  version    BIGSERIAL PRIMARY KEY,
  document   JSONB       NOT NULL,
  hash       TEXT        NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  applied_by TEXT        NOT NULL,
  note       TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_selection_versions_hash
  ON selection_versions (hash);

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS selection_state TEXT NOT NULL DEFAULT 'selected'
    CHECK (selection_state IN ('selected', 'deselected')),
  ADD COLUMN IF NOT EXISTS selection_version BIGINT,
  ADD COLUMN IF NOT EXISTS watch_tier TEXT NOT NULL DEFAULT 'standard'
    CHECK (watch_tier IN ('pinned', 'standard')),
  ADD COLUMN IF NOT EXISTS placements JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS matched_rule_id TEXT;

ALTER TABLE products
  ADD CONSTRAINT products_placements_is_array
  CHECK (jsonb_typeof(placements) = 'array');

CREATE INDEX IF NOT EXISTS idx_products_serveable
  ON products (source_id, selection_state, is_active);
CREATE INDEX IF NOT EXISTS idx_products_watch
  ON products (source_id, watch_tier, last_seen_at)
  WHERE selection_state = 'selected' AND is_active;

ALTER TABLE crawl_runs
  ADD COLUMN IF NOT EXISTS run_kind TEXT NOT NULL DEFAULT 'discovery'
    CHECK (run_kind IN ('discovery', 'watch')),
  ADD COLUMN IF NOT EXISTS selection_version BIGINT,
  ADD COLUMN IF NOT EXISTS urls_selected    INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS deselected_items INTEGER NOT NULL DEFAULT 0;
```

```sql
-- src/db/migrations/005_events_and_alerts.sql
CREATE TABLE IF NOT EXISTS product_events (
  id          BIGSERIAL PRIMARY KEY,
  source_id   TEXT        NOT NULL REFERENCES sources(id),
  external_id TEXT        NOT NULL,
  kind        TEXT        NOT NULL CHECK (kind IN (
                'new_match','price_drop','price_rise','back_in_stock',
                'out_of_stock','deselected','inactive')),
  observed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  previous    JSONB,
  current     JSONB
);
CREATE INDEX IF NOT EXISTS idx_product_events_observed
  ON product_events (observed_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_events_item
  ON product_events (source_id, external_id, observed_at DESC);

CREATE TABLE IF NOT EXISTS alert_state (
  key          TEXT PRIMARY KEY,
  last_sent_at TIMESTAMPTZ NOT NULL
);
```

`ADD COLUMN IF NOT EXISTS` + defaults keeps both migrations online-safe on a
table this size; the existing `migrate.ts` runs each file in one transaction.

---

## 7. API surface after this plan

| Route | Auth | Notes |
|---|---|---|
| `GET /livez` | none | process liveness, unchanged |
| `GET /healthz` | none | terse: per-source status + reasons; 503 if any enabled source is unhealthy |
| `GET /v1/external-catalog` | `Bearer` (`CATALOG_API_TOKENS`) | + `placements`, `watchTier`, `matchedRuleId`, `selectionVersion`; ETag/304 kept |
| `GET /v1/external-catalog/changes?since=<iso>` | `Bearer` | `product_events` since a timestamp, capped at 500, newest first |
| `GET /admin/status` | `Bearer` (`ADMIN_API_TOKENS`) | full run metrics, budgets, selection version, per-source counts |
| `GET /admin/selection` | admin | current document + version + hash |
| `PUT /admin/selection` | admin | validate → new version → write-back to `config/selection.json` |
| `POST /admin/selection/preview` | admin | Stage-A dry match against the last discovered URL set; no fetching |
| `POST`/`DELETE /admin/session` + the `/admin/{overview,runs,products,events,alerts,feed-preview}` reads | dashboard session | the browser console's surface — specified in [`CATALOG_DASHBOARD.md`](CATALOG_DASHBOARD.md) § 5 |

**Auth rules.** Tokens are compared with `crypto.timingSafeEqual` on
equal-length buffers only. `CATALOG_API_TOKENS` and `ADMIN_API_TOKENS` are
comma-separated so a rotation can overlap. `API_AUTH_REQUIRED` defaults to
`true`; local development sets it `false`. Failures return `401
{"error":"unauthorized"}` with no hint about which token was wrong.

**Honest limitation to write in the code comment:** a bearer token shipped in a
mobile binary is not a secret against a determined attacker. It stops casual
discovery and scripted scraping of *our* endpoint, and it makes rotation
possible. It is proportionate for an internal-audience build; it is not an
authorization system, and it is not a reason to relax the `ownerProcurement`
boundary.

**Curated floor.** `CURATED_FLOOR_ENABLED` (default `true` locally, **`false` in
production once a live crawl succeeds**). While enabled, floor records pass
through the same Stage A/B/C selection filter as live rows — otherwise a
narrowed selection would still serve ten unselected Coach bags per source.

---

## 8. Deployment on the ArtisanalBrew server

### 8.1 What is already there

| Fact | Value |
|---|---|
| Provider / plan | Atlantic.Net G3.4GB Compute |
| **Location** | **Texas, United States** — see § 8.7, this is load-bearing |
| OS | Ubuntu 26.04 LTS |
| Resources | 2 vCPU · 4 GB RAM · 2 GB swap · 80 GB SSD · 5 TB/period |
| Address | `209.23.11.117`, `cafe.alexisreyna.dev` |
| Ingress | Caddy `:80/:443`, automatic TLS; UFW allows only 22/80/443; fail2ban |
| Runtime | Docker Compose at `/opt/artisanalbrew/compose.yml` |
| Data | PostgreSQL 16 in-container, `/opt/artisanalbrew/data/postgres`, port unpublished |
| Ops | `artisanalbrew-healthcheck.timer` (5 min), `artisanalbrew-backup.timer` (03:15 UTC, 7-day retention) |
| Access | `ssh -i ~/.ssh/artisanalbrew-atlantic-codex artisanalbrew@209.23.11.117` |

Source of truth for those files: `ArtisanalBrew/deployments/atlantic/` and
`ArtisanalBrew/docs/atlantic-migration.md`.

### 8.2 Memory budget — the binding constraint

Committed today: `postgres` 768 + `web` 1024 + `worker` 512 + `gateway` 384 +
`caddy` 128 = **2 816 MB of 4 096 MB**. Headroom ≈ 1 280 MB plus 2 GB swap.

Proposed additions:

| New service | `mem_limit` | `cpus` |
|---|---|---|
| `monetta-catalog-api` | 256m | 0.25 |
| `monetta-catalog-monitor` | 640m | 0.50 |

New total ≈ **3 712 MB**, leaving ~384 MB plus swap. That works **only with
`PLAYWRIGHT_FALLBACK_ENABLED=false`**. Chromium peaks at 0.5–1 GB per render and
would push the box into swap thrash while the café app is serving.

**Decision: Playwright stays off on this box.** If a source genuinely needs
rendering, run it as a separate one-shot compose profile
(`docker compose --profile render run --rm monetta-catalog-render`) on its own
systemd timer at a quiet hour with `mem_limit: 1g`, so the spike never overlaps
the API — or move to the G3.8GB plan. Do not silently flip the flag on the
shared box.

**Postgres: reuse, don't duplicate.** A second Postgres container costs ~500 MB
for no benefit. Create a role and database inside the existing one:

```sql
CREATE ROLE monetta_catalog LOGIN PASSWORD '<generated>';
CREATE DATABASE monetta_catalog OWNER monetta_catalog;
```

### 8.3 Topology

```
Internet
  │
  ▼
Caddy :80/:443  ─── cafe.alexisreyna.dev ──────► web:8080 · gateway:4022   (existing)
  └──────────────── catalog.monetta.mx ────────► monetta-catalog-api:8081  (new)

monetta-catalog-api      ──┐
monetta-catalog-monitor  ──┴──► postgres:5432 / monetta_catalog   (existing container)
```

Two compose projects, one shared external network, so a Monetta deploy can never
rebuild or restart the café app:

```bash
docker network create edge      # once
```

- Add `networks: [default, edge]` to the **existing** `postgres` and `caddy`
  services (a one-line-per-service edit to `/opt/artisanalbrew/compose.yml`,
  mirrored into `ArtisanalBrew/deployments/atlantic/compose.yml`).
- The Monetta project joins `edge` only. Service names are network-wide DNS
  aliases, so both new services carry a `monetta-catalog-` prefix — a bare `api`
  would collide with anything else on `edge`.

Server layout, mirroring the ArtisanalBrew convention:

| Path | Purpose |
|---|---|
| `/opt/monetta-catalog/repo` | checkout of `monetta-app` |
| `/opt/monetta-catalog/compose.yml` | active compose (installed from the repo) |
| `/opt/monetta-catalog/*.env` | `root:root`, mode `0600` |
| `/opt/monetta-catalog/backups/` | daily `pg_dump` + `selection.json` export |
| `/opt/monetta-catalog/selection/` | last applied selection document (write-back target) |

Caddy site block (appended to `/opt/artisanalbrew/Caddyfile`):

```caddyfile
catalog.monetta.mx {
    encode zstd gzip
    header {
        X-Content-Type-Options nosniff
        Referrer-Policy strict-origin-when-cross-origin
        Strict-Transport-Security "max-age=31536000"
    }
    reverse_proxy monetta-catalog-api:8081
}
```

`/admin/*` is reachable, because the Vercel-hosted dashboard
([`CATALOG_DASHBOARD.md`](CATALOG_DASHBOARD.md)) is a browser calling this host
directly. It is protected by a passphrase-issued session token, an exact CORS
origin allowlist, a failed-login lockout and a short TTL — not by being
unroutable. Until WP-60 lands, keep `respond @admin 404` here.

Note for whoever reaches for a Caddy directive: the stock `caddy:2-alpine`
image has **no** `rate_limit` — it is a third-party module requiring a custom
build. Throttling therefore lives in the Node app (WP-22), not the proxy.

### 8.4 DNS

`catalog.monetta.mx` needs an `A` record → `209.23.11.117` in whatever manages
`monetta.mx` DNS (Shopify, if the storefront domain is Shopify-managed).
If that is blocked or slow, ship on `monetta-catalog.alexisreyna.dev` — the same
zone that already resolves `cafe` — and cut over later. The hostname appears in
exactly two places (`Caddyfile`, `EXTERNAL_CATALOG_BASE_URL`), so the cutover is
cheap. No `AAAA` record, matching the existing setup.

### 8.5 Environment matrix

| Variable | Local | Production | Notes |
|---|---|---|---|
| `DATABASE_URL` | localhost:5433 | `postgres:5432/monetta_catalog` | over `edge` |
| `PORT` | 8081 | 8081 | never published to the host |
| `LIVE_CRAWL_ENABLED` | `false` | `true` **after § 11** | `monitor` only; `api` stays a passive reader |
| `USER_AGENT` | placeholder | real, monitored contact | startup fails otherwise |
| `DISCOVERY_CRON` | — | `17 3 * * *` | accepts `CATALOG_CRON` as a legacy alias |
| `WATCH_CRON` | — | `7 */3 * * *` | the "always live" cycle |
| `PINNED_WATCH_CRON` | — | `27 * * * *` | pinned tier only |
| `REQUEST_DELAY_MS` | 1000 | 1500 | ≥1000 enforced in `config.ts` |
| `MAX_SELECTED_URLS_PER_SOURCE` | 400 | 400 | exceeded → run aborts `partial`, alert |
| `MAX_PAGES_PER_RUN` | 500 | 500 | per source per run |
| `DAILY_PAGE_BUDGET` | 3000 | 3000 | summed from `crawl_runs` over 24 h |
| `PLAYWRIGHT_FALLBACK_ENABLED` | `false` | `false` | see § 8.2 |
| `CURATED_FLOOR_ENABLED` | `true` | `false` once live | selection-filtered while on |
| `API_AUTH_REQUIRED` | `false` | `true` | |
| `CATALOG_API_TOKENS` | — | rotating list | app-facing |
| `ADMIN_API_TOKENS` | — | separate list | CLI/server-side only — never in the app **or the dashboard bundle** |
| `DASHBOARD_ORIGINS` | `http://localhost:5173` | the exact Vercel production origin | comma-separated, exact match only |
| `DASHBOARD_PASSPHRASE_VERIFIER` | — | `scrypt$…` from `npm run dashboard:passphrase` | the passphrase itself is never stored |
| `DASHBOARD_SESSION_TTL_HOURS` | 12 | 12 | browser session lifetime |
| `RESEND_API_KEY` | — | own copy in `alerts.env` | reuses the ArtisanalBrew Resend account |
| `ALERT_EMAIL_TO` / `_FROM` | — | monitored mailbox | same address as `USER_AGENT` contact |
| `ALERT_MIN_INTERVAL_HOURS` | 6 | 6 | per key dedupe via `alert_state` |
| `WATCH_STALE_MINUTES` | 360 | 360 | health reason `watch_stale` |

### 8.6 Operations

```bash
# Deploy an approved revision
cd /opt/monetta-catalog/repo && git pull --ff-only
sudo install -m 0644 services/catalog_monitor/deploy/atlantic/compose.yml \
  /opt/monetta-catalog/compose.yml
sudo docker compose -f /opt/monetta-catalog/compose.yml build
sudo docker compose -f /opt/monetta-catalog/compose.yml up -d
sudo docker compose -f /opt/monetta-catalog/compose.yml ps

# Verify
curl -fsS https://catalog.monetta.mx/livez
curl -fsS -H "Authorization: Bearer $TOKEN" https://catalog.monetta.mx/healthz | jq
sudo docker compose -f /opt/monetta-catalog/compose.yml logs --tail=200 monetta-catalog-monitor

# Change what is extracted (no deploy)
sudo docker compose -f /opt/monetta-catalog/compose.yml exec monetta-catalog-api \
  node dist/cli/selection.js preview --source coach_us
```

Backups: `monetta-catalog-backup.timer` at 03:45 UTC (after ArtisanalBrew's
03:15, never concurrent) → `pg_dump --format=custom` of `monetta_catalog`,
14-day retention, plus a copy of the current selection document. Crawl rows are
re-derivable by crawling; **the selection document is not** — that is the row
that matters, which is why it is also in git.

Health: `monetta-catalog-healthcheck.timer` every 5 minutes checks both
containers are running and `/livez` answers. Three consecutive failures →
restart the container once and send one alert; keep the state in
`/var/lib/monetta-catalog/healthcheck.state`.

### 8.7 Why hosting in Texas is the thing that unblocks this

The prototype has run **zero** successful live crawls, and the stated reason is
not a code defect: `coach.com` geo-redirected every request from the
implementation environment to `mx.coach.com`, the regional licensee site.
`crawl/marketGuard.ts` correctly refuses to parse that — the final URL after
redirects must still be an HTTPS product URL on the source's US host — so every
attempt ended as `wrong_market` before a single product was extracted.

The server is in **Texas**. Requests leave it from a US IP, so the US
storefronts are the ones that answer, and `marketGuard` should pass instead of
rejecting the response. That is the single environmental change that makes the
existing crawler viable, and it is why the deployment target is not a detail
that can be swapped casually.

Consequences to hold onto:

- **Do not run discovery or watch crawls from anywhere else.** A laptop in
  Mexico, a CI runner in an EU region, or a future migration to a non-US host
  reintroduces `wrong_market` on every fetch. If the box ever moves, § 11's
  robots and market checks must be re-run before crawling resumes.
- **`marketGuard` stays exactly as strict as it is.** Being in the US means the
  guard should now pass honestly. It is not permission to loosen the host
  allow-list "because we're in the right country" — a redirect to a licensee
  site still means the page is not the US catalog.
- **Texas fixes geography, not consent.** A datacenter IP is still trivially
  identifiable as non-residential, and Coach, Michael Kors, GUESS and Steve
  Madden all sit behind commercial bot management. Being in the right country
  removes the geo-redirect; it does not remove rate limits, robots.txt, site
  terms, or the possibility of a hard block. The no-stealth policy in § 2 is
  unchanged: a block is a **stop**, and the response is to disable that source
  in `selection.json`, not to look more like a browser.
- **The prices are the right prices.** A US-origin crawl reads the US
  storefront's USD prices and availability — which is what a sourcing desk needs
  in order to be worth anything. A crawl that silently read `mx.coach.com` would
  be reporting Mexican licensee pricing while labelled `coach_us`.

The `USER_AGENT` continues to declare `+https://monetta.mx` and a Mexican
contact. That is truthful and stays: a Mexican company running an identified
research crawler from a US host is exactly what is happening, and the point of
the user agent is to be reachable, not to be geographically flattering.

---

## 9. Observability and alerting

`crawl_runs` already records discovered/fetched/parsed/new/changed/missing/
inactive and errors by type. Add `run_kind`, `selection_version`,
`urls_selected`, `deselected_items`.

`/healthz` reasons, extended:

| Reason | Threshold |
|---|---|
| `no_recent_successful_run` | no successful full **discovery** run in `STALE_RUN_HOURS` (36 h) |
| `low_parse_coverage` | last successful run's `successfulParses / pagesFetched` < 98% |
| `product_count_drop` | `successfulParses` fell > 20% vs. the previous successful run |
| `widespread_failures` | most recent run `blocked`, or errors across ≥ 50% of discovered URLs |
| **`watch_stale`** *(new)* | no successful **watch** run in `WATCH_STALE_MINUTES` |
| **`selection_empty`** *(new)* | source `enabled` but Stage A selects 0 URLs |
| **`budget_exhausted`** *(new)* | `DAILY_PAGE_BUDGET` hit before the run completed |

Only `enabled` sources count toward the overall status — a source the owner
turned off must not hold `/healthz` at 503 forever.

Email alerts via Resend (`src/alerts/`), deduped per key through `alert_state`:
`blocked` run, source unhealthy on two consecutive checks, coverage below 98%,
budget exhausted, selection apply rejected, `wrong_market` on > 10% of fetches.
A `blocked` alert says explicitly: *stop this source, review the site's terms —
do not work around it.*

---

## 10. Work packages

Status legend: `todo` · `doing` · `done` · `blocked`.

### Phase 0 — Validate before anything goes live

#### WP-00 · Egress and market check from the server
**Depends on** — · **Touches** `docs/runbooks/us-egress-check.md` (new)

**Run this first, and run it from the Texas box — nowhere else** (§ 8.7). The
expected result is that the US storefronts answer directly, because the
geo-redirect to `mx.coach.com` that defeated every previous attempt was an
artifact of crawling from Mexico. This WP turns that expectation into recorded
evidence before any code is written on top of it.

For each of `coach.com`, `michaelkors.com`, `guess.com`, `stevemadden.com`:
fetch `robots.txt`, fetch the sitemap index, fetch one product URL with the real
`USER_AGENT`, and record the final URL after redirects, the status, and whether
the body carries block/CAPTCHA markers.

**Acceptance** · A committed table: source × {robots reachable, robots allows
the product paths the selection will match, sitemap reachable, product page
still on the US host after redirects, block markers present}. No adapter changes
yet. A source that still redirects or that blocks is marked `enabled: false` in
`selection.json`, with the observed behavior written down — not retried from a
different address.
**Verify**
```bash
curl -sS -A "$USER_AGENT" -o /dev/null -L \
  -w 'status=%{http_code} final=%{url_effective}\n' https://www.coach.com/…
```
Any `final=` on a non-US host is a `wrong_market` result and must be recorded as
such, even if the status is 200.

#### WP-01 · Capped live smoke crawls and adapter validation
**Depends on** WP-00 · **Touches** `src/adapters/*.ts`, `src/parsing/selectors.ts`, `test/fixtures/**`

Per reachable source: `npm run crawl -- --brand <b> --limit 5 --dry-run`. Capture
sanitized fixtures from the real pages, fix URL patterns and selectors against
them, and record required-field coverage. This retires the README's "validate
both adapters against one real capped crawl before any operational use".

**Acceptance** · ≥ 98% required-field coverage on a 25-page capped run per
enabled source, with fixtures committed and unit tests updated.
**Verify** `npm test && npm run crawl -- --brand coach --limit 25 --dry-run`

#### WP-02 · Prefer structured endpoints where the merchant publishes one
**Depends on** WP-00 · **Touches** `src/adapters/steveMadden.ts`, `src/discovery/`

Steve Madden runs on Shopify, which publishes `/products.json?limit=250&page=N`.
Where robots.txt allows it, a documented JSON endpoint beats HTML scraping on
every axis: stable shape, variants included, one request per 250 products, and
no CSS selector to rot. Add a `structuredFeed` capability to `BrandAdapter`, and
use it when present. **If robots.txt disallows the path, do not fetch it** — this
is not a loophole, it is a cheaper front door where one is offered.

**Acceptance** · Adapter reports `structuredFeed` support; runner prefers it;
robots gate applies identically; fixture-based tests cover paging and a
disallowed-path refusal.
**Verify** `npm test -- adapters`

### Phase 1 — Selection

#### WP-10 · Migration 004
**Depends on** WP-01 · **Touches** `src/db/migrations/004_selection.sql`

Exactly the DDL in § 6. Defaults chosen so existing rows keep serving.
**Acceptance** · `npm run migrate` applies once and is a no-op on re-run; a
second `npm run migrate` prints `applied: []`.
**Verify** `npm run migrate && npm run migrate`

#### WP-11 · Selection engine (pure, no I/O)
**Depends on** WP-10 · **Touches** `src/selection/{types,document,glob,engine}.ts`, `test/selection.test.ts`

Zod-free hand-written validation (the repo has no schema library and does not
need one): `parseSelectionDocument(json)` → `SelectionDocument | SelectionError`.
`compileSelection(doc)` → `{ matchUrl(sourceId, url), matchProduct(sourceId,
product), hash, version }`. Glob compiler per § 4.2. Precedence per § 4.2, with
the fail-closed default. No database, no HTTP, no Flutter — same testability
posture as `data/normalize`.

**Acceptance** · Tests cover: pinned beats exclude; exclude beats include; zero
includes selects nothing; `all` selects everything; malformed document returns a
typed error and never throws; glob `*` does not cross `/` and `**` does;
identical documents hash identically regardless of key order.
**Verify** `npm test -- selection`

#### WP-12 · Stage A filtering in discovery
**Depends on** WP-11 · **Touches** `src/crawl/runner.ts`, `test/runner.test.ts`

Between classification and the robots gate, filter the URL list through
`matchUrl`. Record `urlsSelected`. Enforce `MAX_SELECTED_URLS_PER_SOURCE` and
`MAX_PAGES_PER_RUN` — exceeding either aborts the run as `partial` with a new
`selection_over_budget` error type, writing nothing to `products`.

**Acceptance** · A run over a fixture sitemap of 1 000 URLs with a 3-match
selection fetches exactly 3 pages; an over-budget selection fetches **zero**
pages and leaves `products` untouched.
**Verify** `npm test -- runner`

#### WP-13 · Stage B filtering and selection-aware diff
**Depends on** WP-12 · **Touches** `src/crawl/runner.ts`, `src/crawl/snapshotDiff.ts`, `src/crawl/ports.ts`, `src/db/pgProductRepository.ts`, `test/snapshot.test.ts`

Apply `matchProduct` after extraction (drop non-matching, count them). Implement
invariants **I1–I6** from § 5, including `suppressDeactivation` on a version
change and the `deselected` state transition. `ProductRepository` grows
`getSelectedActiveProducts(sourceId, selectionVersion)` and
`markDeselected(records)`; the in-memory fake keeps parity.

**Acceptance** · A test proves narrowing the selection from 100 to 5 items
deactivates **nothing** and deselects 95; a second run at the same version still
deactivates nothing; an item genuinely missing for two full runs at a stable
version does go inactive.
**Verify** `npm test -- snapshot runner`

#### WP-14 · Selection persistence, seed file and CLI
**Depends on** WP-11 · **Touches** `src/db/pgSelectionRepository.ts`, `src/cli/selection.ts`, `config/selection.json`, `package.json`, `test/selection.cli.test.ts`

`npm run selection:{list,show,apply,preview,rollback}`. `apply` validates →
hashes → inserts a version → writes the canonical document back to the JSON
file. `preview` uses the **last discovered URL set** (cache the previous run's
`robotsAllowed` list in a `discovered_urls` table or a JSON column on
`crawl_runs`) so it can answer "how many would this crawl?" with zero requests;
if no set is cached it says so rather than silently crawling.

**Acceptance** · Applying an identical document is a no-op (same hash, no new
version). Applying an invalid document exits non-zero, changes nothing, and
prints the failing rule id. `preview` makes zero network calls in tests.
**Verify** `npm test -- selection.cli`

#### WP-15 · Admin API for selection
**Depends on** WP-14, WP-22 · **Touches** `src/api/admin.ts`, `src/api/auth.ts`, `test/api.admin.test.ts`

`GET /admin/selection`, `PUT /admin/selection`, `POST /admin/selection/preview`,
`GET /admin/status`. Admin token, constant-time compare, `applied_by` taken from
a required `X-Applied-By` header, body capped at 256 KB.

**Acceptance** · No admin route answers without a valid admin token; an
app-facing `CATALOG_API_TOKENS` value is rejected on `/admin/*`; a rejected `PUT`
leaves the current version in force.
**Verify** `npm test -- api.admin`

#### WP-16 · Stage C: serve-time selection and placements
**Depends on** WP-13 · **Touches** `src/api/server.ts`, `src/api/schema.ts`, `src/catalog/curatedUsCatalog.ts`, `test/api.test.ts`

`/v1/external-catalog` serves only `selection_state = 'selected' AND is_active`,
adds `placements`, `watchTier`, `matchedRuleId` and `selectionVersion`
(additive — no `schemaVersion` bump), and filters the curated floor through the
same selection. `CURATED_FLOOR_ENABLED=false` removes the floor entirely.

**Acceptance** · A deselected row never appears in the response; ETag changes
when the selection version changes; the floor respects both the flag and the
selection.
**Verify** `npm test -- api`

### Phase 2 — Always live

#### WP-20 · Two-tier scheduler
**Depends on** WP-13 · **Touches** `src/monitor/scheduler.ts`, `src/crawl/watchRun.ts`, `src/db/advisoryLock.ts`, `test/watchRun.test.ts`

Register three cron jobs (discovery, watch, pinned watch). Watch runs read
selected active rows ordered by `watch_tier, last_seen_at ASC`, fetch up to the
per-run budget, update mutable fields, append `product_events`, and obey **I5**.
Advisory lock keys become per source **per kind**, so a long discovery run never
blocks a watch run on another source — and never overlaps itself.

**Acceptance** · A watch run over fixtures updates price/availability and writes
events without touching `is_active` or `consecutive_missing_snapshots`; lock
contention skips that source-kind pair and logs it; each tier's budget is
enforced independently.
**Verify** `npm test -- watchRun scheduler`

#### WP-21 · Change events endpoint
**Depends on** WP-20 · **Touches** `src/api/server.ts`, `src/db/pgEventRepository.ts`, `test/api.events.test.ts`

`GET /v1/external-catalog/changes?since=<iso>&limit=<n≤500>`. Invalid or missing
`since` defaults to 24 h ago; the response carries `nextSince` so a client can
page without gaps.

**Acceptance** · Events are newest-first, bounded, and never leak internal ids
or fingerprints.
**Verify** `npm test -- api.events`

#### WP-22 · API authentication and hardening
**Depends on** WP-10 · **Touches** `src/api/auth.ts`, `src/api/server.ts`, `src/config.ts`, `test/auth.test.ts`

Bearer middleware per § 7; `API_AUTH_REQUIRED` default `true`; CORS restricted
to the exact origins in `DASHBOARD_ORIGINS` — never `*`, never `*.vercel.app`,
and `Access-Control-Expose-Headers: ETag` is mandatory or conditional polling
silently breaks ([`CATALOG_DASHBOARD.md`](CATALOG_DASHBOARD.md) § 4);
`Cache-Control: private` once authenticated;
request body limits; per-IP rate limit on `/admin/*` (in-process token bucket is
sufficient behind Caddy). Keep the existing catch-all that returns
`{"error":"internal_error"}` and never leaks internals.

**Acceptance** · Every `/v1/*` and `/admin/*` route rejects a missing, wrong, or
truncated token; `/livez` stays open; timing-safe compare is unit-tested against
equal- and different-length inputs.
**Verify** `npm test -- auth api`

#### WP-23 · Alerting and extended health
**Depends on** WP-20 · **Touches** `src/alerts/{resend,dedupe}.ts`, `src/monitor/health.ts`, `test/health.test.ts`, `test/alerts.test.ts`

Resend HTTP client injected as a port (tests use a fake — no network). New
health reasons per § 9; disabled sources excluded from the overall verdict.

**Acceptance** · A `blocked` run sends exactly one alert, and a second `blocked`
run inside `ALERT_MIN_INTERVAL_HOURS` sends none; the alert body names the
source, the reason and the stop-don't-work-around instruction.
**Verify** `npm test -- alerts health`

### Phase 3 — Deploy

#### WP-30 · Deployment assets
**Depends on** WP-16, WP-22 · **Touches** `services/catalog_monitor/deploy/atlantic/{compose.yml,Caddyfile.snippet,monetta-catalog-*.{service,timer},monetta-catalog-backup,monetta-catalog-healthcheck}`, `.env.example`

Compose per § 8.2–8.3 (limits, `restart: unless-stopped`, `edge` network,
`migrate` one-shot with `service_completed_successfully`, no published ports),
Caddy snippet, systemd units, backup and healthcheck scripts. Mirror the
ArtisanalBrew file layout so one operator learns one pattern.

**Acceptance** · `docker compose -f deploy/atlantic/compose.yml config` parses;
every new env var appears in `.env.example` with a comment; no secret values.
**Verify** `docker compose -f services/catalog_monitor/deploy/atlantic/compose.yml config >/dev/null`

#### WP-31 · Operations runbook
**Depends on** WP-30 · **Touches** `docs/OPERATIONS.md` (new), `services/catalog_monitor/README.md`

`src/monitor/scheduler.ts` already points at `docs/OPERATIONS.md`, which does
not exist — this WP makes that reference true. Contents: first-time provisioning
(role/db, network, env files, DNS), deploy, rollback, the four kill switches,
backup/restore drill, log locations, what to do when a source is blocked.

**Acceptance** · Every command in the runbook was actually executed on the
server, and its real output (redacted) is pasted in.
**Verify** manual, then `grep -r "docs/OPERATIONS.md" services/` resolves.

#### WP-32 · CI
**Depends on** WP-14 · **Touches** `.github/workflows/{services,flutter}.yml`

Node 22 matrix over `services/catalog_monitor` and `services/accounts_orders`
(`npm ci && npm run typecheck && npm test`), a Flutter job
(`flutter analyze && flutter test`), and a `selection-validate` job that parses
`config/selection.json` through WP-11's validator so a broken rule can never
reach the server.

**Acceptance** · CI is green on the branch; a deliberately malformed
`selection.json` fails the job.
**Verify** `gh workflow run services.yml` (or push)

### Phase 4 — App integration

#### WP-40 · Client config, auth and periodic refresh
**Depends on** WP-16 · **Touches** `lib/app/external_catalog_config.dart`, `lib/data/external_catalog/{external_catalog_client,external_catalog_repository}.dart`, `lib/app/external_catalog_controller.dart`, `test/external_catalog/*`

Add `EXTERNAL_CATALOG_TOKEN` and `EXTERNAL_CATALOG_REFRESH_MINUTES` (default 30)
as `--dart-define`s. Send `Authorization` when the token is non-empty. Add
`refreshIfStale()` and a foreground-resume trigger. The cache-first contract is
unchanged and non-negotiable: a failed refresh never clears the cache, so a
backend outage degrades to "slightly stale" instead of "empty screen".

**Acceptance** · Fake-client tests: header present when a token is configured and
absent when it is not; a 401 leaves the cache intact; refresh is skipped inside
the interval; 304 is still a no-op.
**Verify** `flutter test test/external_catalog`

#### WP-41 · Placements → surfaces
**Depends on** WP-40 · **Touches** `lib/data/external_catalog/external_catalog_mapper.dart`, `lib/domain/catalog_item.dart`, `lib/app/mixed_feed.dart`, `lib/features/home/external_catalog_section.dart`, `lib/features/catalog/catalog_browse_screen.dart`, `test/mixed_feed_test.dart`

Map `placements` to surfaces: `home_rail`, `catalog_browse`, `collection:<slug>`,
`hidden`. An item with no placements keeps today's behavior (both surfaces) so
older payloads and the curated floor still render. `hidden` wins over everything.
Dedupe, no-currency-conversion and price-band ranking rules are unchanged.

**Acceptance** · `hidden` items appear nowhere; a `home_rail`-only item is absent
from browse; an item with no `placements` behaves exactly as it does today.
**Verify** `flutter test test/mixed_feed_test.dart`

#### WP-42 · Freshness surfacing
**Depends on** WP-40 · **Touches** `lib/features/home/external_catalog_section.dart`, `lib/app/theme.dart`, `test/widget/*`

Show the source freshness the API already reports: *"Investigación · Estados
Unidos · actualizado hace 2 h"*. `curated_us_snapshot` rows keep their dated
labelling. Never hide stale data silently — an owner reading a three-day-old
price must be able to see that it is three days old.

**Acceptance** · Widget tests for fresh, stale and snapshot-origin states.
**Verify** `flutter test test/widget`

### Phase 5 — Go live

#### WP-50 · Acceptance run and sign-off
**Depends on** all · **Touches** this file (§ 11 checklist), `docs/OPERATIONS.md`

Execute § 11 end to end, record the evidence, then flip
`LIVE_CRAWL_ENABLED=true` on the `monitor` service only.

---

## 11. Go-live checklist (every box, in order)

- [ ] **Legal posture re-read.** `US_SOURCING_DURABILITY.md` § "What brands don't
      want" still describes what we are doing. Items remain `ownerProcurement`.
- [ ] **Audience decided** (§ 13, D2) and recorded here with a date.
- [ ] **robots.txt re-checked on the day**, per enabled source, for the exact
      paths the selection matches.
- [ ] **`USER_AGENT` carries a real, monitored mailbox** — and someone reads it.
- [ ] **Selection applied and previewed**: every enabled source selects > 0 and
      < `MAX_SELECTED_URLS_PER_SOURCE` URLs.
- [ ] **Two consecutive discovery runs** per source: `status=success`,
      `is_full_snapshot=true`, coverage ≥ 98%.
- [ ] **One full watch cycle**: 0 `captcha_or_block`, 0 `wrong_market`.
- [ ] **`/healthz` returns 200** for all enabled sources.
- [ ] **Alert path proven**: a forced failure delivered one email; a repeat
      inside the dedupe window delivered none.
- [ ] **Backup restored once** into a scratch database and row-counted.
- [ ] **App verified against production**: items render, `ownerProcurement`
      holds (no add-to-bag, no WhatsApp apartado, no cart), merchant CTA
      re-validates HTTPS + allowed host.
- [ ] **Kill switches rehearsed** (§ 14) — each one, once, before it is needed.

---

## 12. Status

| WP | Title | Status | Owner | Notes |
|---|---|---|---|---|
| WP-00 | Egress and market check | todo | | blocks everything |
| WP-01 | Capped smoke crawls | todo | | |
| WP-02 | Structured endpoints | todo | | optional per source |
| WP-10 | Migration 004 | todo | | |
| WP-11 | Selection engine | todo | | |
| WP-12 | Stage A filtering | todo | | |
| WP-13 | Stage B + diff invariants | todo | | highest-risk WP |
| WP-14 | Persistence, seed, CLI | todo | | |
| WP-15 | Admin API | todo | | |
| WP-16 | Serve-time + placements | todo | | |
| WP-20 | Two-tier scheduler | todo | | |
| WP-21 | Change events | todo | | |
| WP-22 | API auth | todo | | |
| WP-23 | Alerting + health | todo | | |
| WP-30 | Deployment assets | todo | | |
| WP-31 | Operations runbook | todo | | creates `docs/OPERATIONS.md` |
| WP-32 | CI | todo | | |
| WP-40 | Client config + refresh | todo | | |
| WP-41 | Placements → surfaces | todo | | |
| WP-42 | Freshness surfacing | todo | | |
| WP-50 | Go live | todo | | |
| WP-60…68 | Monitoring dashboard | todo | | [`CATALOG_DASHBOARD.md`](CATALOG_DASHBOARD.md); WP-60 blocks the rest, and the SPA blocks on WP-30's hostname |

---

## 13. Decisions the owner has to make

| # | Decision | Recommendation | Cost of changing later |
|---|---|---|---|
| D1 | Hostname | `catalog.monetta.mx`; fall back to `monetta-catalog.alexisreyna.dev` if the `monetta.mx` zone is slow to change | Low — two config lines |
| D2 | Audience: internal owner build, or public App Store build | **Internal**, until § 11 has run twice and the trademark surface in `US_SOURCING_DURABILITY.md` § 1 has been reviewed with counsel | High — a public build showing brand marks and CDN images is the takedown surface |
| D3 | Sources to enable first | Coach + Michael Kors (they have fixtures and validated URL shapes) | Low |
| D4 | Watch cadence | 3 h standard, 1 h pinned | Low — cron env |
| D5 | Playwright on the shared box | **Off.** Revisit with a G3.8GB upgrade or a one-shot render profile | Medium |
| D6 | Image handling | Hotlink merchant CDN for the internal build; add a caching proxy only if D2 goes public — and read § 1 of the durability note first | Medium |
| D7 | Selection breadth | Start narrow (one or two model families per brand). A narrow selection is cheaper, faster, more defensible, and easier to verify | Low — that is the entire point of the design |
| D8 | Dashboard auth | Owner passphrase → short-lived session token, per [`CATALOG_DASHBOARD.md`](CATALOG_DASHBOARD.md) § 3. A static admin token in a Vercel env var is compiled into the bundle and is therefore public | Medium — changing the model later means re-issuing credentials |

---

## 14. Kill switches

| Switch | Effect | Blast radius |
|---|---|---|
| `selection.json` → `"enabled": false` on a source, then `selection:apply` | that source stops being crawled **and** stops being served | one source, seconds, no deploy |
| `LIVE_CRAWL_ENABLED=false` + restart `monetta-catalog-monitor` | all crawling stops; the API keeps serving stored rows | all sources, one restart |
| `docker compose stop monetta-catalog-api` | the feed goes away; the app falls back to its local cache | app shows slightly stale data, never a blank screen |
| Rebuild the app without `--dart-define=ENABLE_EXTERNAL_CATALOG=true` | the app never calls the service at all | requires a release |
| Remove the Caddy site block | endpoint unreachable from the internet; the box keeps running | café app unaffected |

---

## 15. Non-goals

Unchanged from `US_SOURCING_DURABILITY.md` § "Out of scope", and none of them
become in-scope because the system is now production-grade:

- residential proxies, UA spoofing, CAPTCHA bypass, or any other measure whose
  purpose is to survive a block
- automated checkout on a brand's site
- auto-creating Shopify products from crawl rows
- listing an extracted item as on-hand Mexican stock, or letting one into the
  cart, Shopify checkout, or the WhatsApp *apartado* flow
- a seller/commission/payout domain — that is a different service next to
  `accounts_orders`, not an extension of this one
- cloaking, or any feature whose purpose is to hide the crawl, the US mailbox,
  or a commercial import

---

## 16. Related documents

- [`CATALOG_DASHBOARD.md`](CATALOG_DASHBOARD.md) — the Vercel-hosted monitoring
  console for everything in this plan: health, runs, products, events, and the
  selection editor. Adds WP-60…68 and the CORS/session surface on this service
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — module map; why scraping is isolated
  outside the mobile client; the two rules
- [`US_SOURCING_DURABILITY.md`](US_SOURCING_DURABILITY.md) — the commercial and
  legal boundary this plan operates inside
- [`ACCOUNTS_AND_SYNC_PLAN.md`](ACCOUNTS_AND_SYNC_PLAN.md) — the sibling
  service's phased plan; same conventions
- [`SHOPIFY_PRODUCTION_IMPLEMENTATION_PLAN.md`](SHOPIFY_PRODUCTION_IMPLEMENTATION_PLAN.md)
  — the *other* half of production readiness: Shopify as the commerce owner. Its
  decision 9 ("keep the external catalog disabled in public builds") is the same
  position as D2 here. The two plans are independent and can run in parallel;
  they meet only at `lib/app/mixed_feed.dart`, which both must leave working
- [`../services/catalog_monitor/README.md`](../services/catalog_monitor/README.md)
  — live-crawl gate, robots, block detection, known limitations
- `ArtisanalBrew/docs/atlantic-migration.md` and
  `ArtisanalBrew/deployments/atlantic/` — the server this deploys onto, and the
  file layout being mirrored
