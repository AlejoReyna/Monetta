# catalog_monitor

Internal prototype. Monitors the **public US Coach, Michael Kors, GUESS, and
Steve Madden catalogs** once a day and serves them as read-only
owner-procurement candidates for the Monetta
Flutter app's mixed feed — see `docs/ARCHITECTURE.md` at the repo root for how
this fits into the rest of the system.

**This is not an automated dropshipping, affiliate, or fulfillment system.**
There is no supplier-authorization field or supplier approval gate. The owner
can use each listing as a manual procurement candidate: it shows a USD price
and a link to the merchant's own page. Any later Shopify import and fulfillment
decision is owned by Monetta and is outside this monitor.

## Stack

- Node.js 22, TypeScript, ES modules.
- PostgreSQL via `pg`, explicit hand-written SQL migrations (no ORM).
- `cheerio` for HTML/JSON-LD parsing; `playwright` as an opt-in, dynamically-imported
  fallback for pages that need client-side rendering. The runtime container
  image (`Dockerfile`) is built `FROM mcr.microsoft.com/playwright:vX.Y.Z-noble`
  pinned to the exact `playwright` version resolved in `package-lock.json`,
  so the Chromium build baked into the image always matches what the npm
  package expects — see "Container roles" below. Off (`PLAYWRIGHT_FALLBACK_ENABLED=false`)
  by default.
- `express` for the API (`compression` for gzip).
- `node-cron` for the daily schedule.
- `vitest` for tests — all tests run against fixtures and in-memory fakes,
  never real network or a real database (see "No live calls" below).

## Quick start

```bash
cp .env.example .env
docker compose up -d postgres
npm install
npm run migrate
npm run typecheck
npm test
npm start          # API on :8081 (PORT in .env)
```

The scheduler is a separate process, started explicitly:

```bash
npm run monitor
```

It logs `scheduler not started: LIVE_CRAWL_ENABLED is false` and exits its
setup step without registering a cron job unless you set
`LIVE_CRAWL_ENABLED=true` — see "The live-crawl gate" below.

## Container roles

`docker-compose.yml` builds one image (`Dockerfile`) and runs it three ways,
selected purely by command override:

| Service | Command | Role |
|---|---|---|
| `migrate` | `node dist/db/migrate.js` | One-shot: applies pending SQL migrations, then exits. |
| `api` | `node dist/api/server.js` | The HTTP API (`/livez`, `/healthz`, `/v1/external-catalog`). |
| `monitor` | `node dist/monitor/scheduler.js` | Registers the daily cron job — see "Enabling scheduled research crawling" below for why it does nothing by default. |

`api` and `monitor` both declare `depends_on: migrate: condition:
service_completed_successfully`, so neither starts against a database that
hasn't been migrated yet.

```bash
docker compose build
docker compose up -d postgres migrate
docker compose up -d api monitor
```

### Enabling scheduled research crawling

By default `docker-compose.yml` sets `LIVE_CRAWL_ENABLED=false` on the
`monitor` service — it starts, logs that live crawling is disabled, and never
schedules anything. To actually enable the daily scheduled crawl, both of the
following must change, explicitly, in the `monitor` service's environment (or
an env file it loads) — not in `api`, which must stay a passive reader:

```yaml
monitor:
  environment:
    LIVE_CRAWL_ENABLED: "true"
    # The placeholder contact below is rejected at startup once
    # LIVE_CRAWL_ENABLED=true (see src/config.ts) — replace it with a real,
    # monitored address before enabling.
    USER_AGENT: "MonettaCatalogMonitor/0.1 (+https://monetta.mx; internal research prototype; contact: <real-contact>@monetta.mx)"
```

There is no flag, CLI argument, or code path that enables scheduled crawling
without both of these being set explicitly in the deployment environment.

### Concurrency safety

Each source's crawl attempt is wrapped in a Postgres session-level advisory
lock (`src/db/advisoryLock.ts`, `pg_try_advisory_lock`), keyed per source. If
a cron fire overlaps a still-running previous attempt, or a second `monitor`
replica is started, the overlapping attempt skips that source entirely rather
than running it concurrently — the next scheduled fire tries again. A failure
on one source (thrown exception, robots-fetch failure, lock contention) never
prevents the other source from being attempted in the same run.

### Graceful shutdown

`api` and `monitor` both handle `SIGTERM`/`SIGINT`: `api` stops accepting new
connections, lets in-flight requests drain (10s cap), then closes the
Postgres pool before exiting; `monitor` stops the cron schedule and closes the
pool. The Playwright fallback launches and closes its own browser instance
per page render (`try`/`finally` in `crawl/playwrightFallback.ts`), so there
is no long-lived browser process to shut down separately.

## Local preview without Docker

If you have a native Postgres install (Homebrew's `postgresql@16`, say) and
prefer Apple's `container` CLI over Docker, here's the exact alternative
setup used to smoke-test this locally on 2026-08-10. It skips
`docker-compose.yml` entirely — Postgres runs as your normal local service,
the API runs as a normal Node process talking to it over `localhost`, and
`container build`/`container run` stand in for `docker build`/`docker run`
only where a container is actually needed (validating the `Dockerfile`).

**1. Database** — create a role/db in your existing Postgres, no container:

```bash
psql -U "$(whoami)" -d postgres -c "CREATE ROLE catalog_monitor LOGIN PASSWORD 'catalog_monitor';"
psql -U "$(whoami)" -d postgres -c "CREATE DATABASE catalog_monitor OWNER catalog_monitor;"
```

**2. `.env`** — point at your local Postgres port (5432, not the
docker-compose file's 5433):

```
DATABASE_URL=postgres://catalog_monitor:catalog_monitor@localhost:5432/catalog_monitor
```

(`npm run migrate`/`start`/`monitor`/`crawl` all load `.env` automatically
via Node's `--env-file-if-exists` flag — see `package.json`. A shell-exported
env var still takes precedence over `.env`, same as `docker-compose`'s
`environment:` block would.)

**3. Migrate and run** — no seed command is required. If a source has fewer
than 10 active live records, the API fills only that shortfall from the dated
US catalog in `src/catalog/curatedUsCatalog.ts`:

```bash
npm run migrate
npm start            # API on :8081, talking to your local Postgres directly
```

The built-in floor contains 10 Coach US and 10 Michael Kors US listings,
checked against the public US storefronts on 2026-08-12. Its records are
served as `dataOrigin: "curated_us_snapshot"`, use USD, and deliberately set
availability to `unknown`. Live crawl rows are `dataOrigin: "live_crawl"`
and always replace a matching fallback record. The floor does not create a
successful crawl run, so `/healthz` remains truthfully degraded until a real
US crawl succeeds.

**4. Building/running the container image with Apple's `container` instead
of Docker** — validates `Dockerfile` the same way `docker build`/`docker run`
would:

```bash
container system start        # first time only
container build -t catalog-monitor:local .
container run -d --name catalog-monitor-smoke -p 8082:8081 \
  -e PORT=8081 -e DATABASE_URL=postgres://... \
  catalog-monitor:local
container logs catalog-monitor-smoke
container stop catalog-monitor-smoke && container rm catalog-monitor-smoke
```

**What this deliberately does *not* do**: connect the *containerized* API to
the host Postgres. Apple's `container` runs each container in its own
lightweight VM on a private subnet (`192.168.64.0/24` in this environment);
reaching a host-native Postgres from inside it would require changing
Postgres's `listen_addresses` from `localhost` to `*` and adding a
`pg_hba.conf` rule for that subnet — i.e., opening your local database
server to a wider network than "just this machine." That's a real change to
shared infrastructure, not scoped to this repo, so it wasn't made
automatically. The `container run` above is a build/runtime smoke test only
(it uses a bogus `DATABASE_URL` and never queries it, since `getPool()` is
lazy — see `src/db/pool.ts`); the actual demo server that the Flutter app
talks to is the plain `npm start` process from step 3, connected over
`localhost` the normal way. If you want the containerized API to be the one
serving real traffic, either point it at a Postgres that already listens on
the container subnet, or make that `listen_addresses`/`pg_hba.conf` change
yourself and revert it afterward.

**5. Point the Flutter app at it**:

```bash
flutter run \
  --dart-define=ENABLE_EXTERNAL_CATALOG=true \
  --dart-define=EXTERNAL_CATALOG_BASE_URL=http://localhost:8081
```

The iOS Simulator shares the host's network stack, so `localhost` resolves
correctly with no special IP (unlike the Android emulator, which would need
`10.0.2.2`).

## Manual crawl CLI

```bash
npm run crawl -- --brand coach --limit 5 --dry-run
npm run crawl -- --brand michael_kors --limit 5 --dry-run
npm run crawl -- --brand guess --limit 5 --dry-run
npm run crawl -- --brand steve_madden --limit 5 --dry-run
npm run crawl -- --brand all
```

- `--brand coach|michael_kors|guess|steve_madden|all`
- `--limit N` — caps the number of product pages fetched. Also forces
  `isFullSnapshot: false` for that run, so a capped run can never trigger the
  "item missing → inactive" logic against a catalog it only partially saw.
- `--dry-run` — skips the database entirely (no read, no write, including the
  `crawl_runs` row). It still makes real HTTP requests if live crawling is
  enabled, but reports only raw extraction stats — no new/changed/missing/
  inactive counts, since those require comparing against stored state. This
  is what makes `--dry-run --limit N` usable as a capped live smoke test
  with no database running at all.

## The live-crawl gate

Nothing in this codebase opens a socket to coach.com or michaelkors.com
unless **both**:

1. `LIVE_CRAWL_ENABLED=true` is set in the environment, and
2. something explicitly invokes the scheduler or the manual CLI.

The gate lives in one place — `src/crawl/httpFetcher.ts#liveFetch` — which
every live-network code path funnels through. `vitest.config.ts` additionally
forces `LIVE_CRAWL_ENABLED=false` for the whole test run as a second,
independent guard. `npm install` and `npm run migrate` never touch it at all.

`USER_AGENT` must identify this project and a contact — `config.ts` refuses
to start if it looks like a browser-impersonation string. This crawler does
not bypass CAPTCHAs, rate limits, or robots.txt; if either site starts
blocking it, the correct next step is to stop and review the site's terms and
permission, not to work around the block (see `crawl/blockDetection.ts` and
the `blocked` crawl-run status).

## How a crawl works

1. **Discovery** (`discovery/sitemap.ts`) recursively walks the site's
   `sitemap_index.xml`, following nested `<sitemapindex>` entries and
   collecting every `<urlset>` URL.
2. **Classification** (`adapters/coach.ts`, `adapters/michaelKors.ts`)
   filters that list down to actual product-detail pages, and separately
   excludes search/checkout/account/cart/wishlist/private-API paths
   regardless of what the sitemap lists.
3. **Robots** (`robots/robotsTxt.ts`) — every classified URL is checked
   against the site's own `robots.txt` before it is fetched.
4. **Fetch** goes through a per-domain rate limiter (one in-flight request
   per domain, ≥`REQUEST_DELAY_MS` between requests) and a retry policy (up
   to 3 attempts, exponential backoff + jitter, only for 429/5xx/network
   errors). The final response URL is retained and must still be an HTTPS
   product URL on the source's US host; redirects to a regional storefront are
   recorded as `wrong_market` and never parsed or persisted.
5. **Extraction** (`parsing/productExtractor.ts`) tries, in order: JSON-LD →
   Open Graph/product metadata → adapter CSS selectors → (if
   `PLAYWRIGHT_FALLBACK_ENABLED=true` and the first three all failed to
   produce every required field) a headless-browser render.
6. **Block detection** (`crawl/blockDetection.ts`) — a CAPTCHA marker or a
   403/429/503 carrying one stops the run immediately with status
   `blocked`. The run is reported, not silently retried into a wall.
7. **Snapshot diffing** (`crawl/snapshotDiff.ts`) only runs when the crawl
   visited every classified, robots-allowed URL for that source without an
   early abort (`isFullSnapshot: true`). An item is marked inactive only
   after being absent from **two consecutive** such runs — see
   `CONSECUTIVE_MISSES_BEFORE_INACTIVE`. A failed or partial run touches the
   `products` table not at all, which is what preserves the last known-good
   catalog when a run goes wrong.

## Health and metrics

Every run writes one row to `crawl_runs` (`src/db/migrations/001_init.sql`):
URLs discovered, pages fetched, successful parses, new/changed/missing/inactive
item counts, and errors grouped by type.

`GET /healthz` (and `src/monitor/health.ts` if you want it outside HTTP)
evaluates, per source:

| Reason | Threshold |
|---|---|
| `no_recent_successful_run` | no successful full run within `STALE_RUN_HOURS` (36h) |
| `low_parse_coverage` | last successful run's `successfulParses / pagesFetched` < 98% |
| `product_count_drop` | `successfulParses` fell more than 20% vs. the previous successful run |
| `widespread_failures` | the most recent run was `blocked`, or failed with errors across ≥50% of discovered URLs |

`GET /healthz` returns HTTP 503 when any source is unhealthy and 200 otherwise.
It is a **data-readiness/freshness** signal, not process liveness: while only
the curated floor is present it correctly remains degraded. Use `GET /livez`
for an orchestrator liveness probe; it returns 200 whenever the API process is
running.

Inspect a specific run's numbers directly in Postgres:

```sql
SELECT source_id, started_at, status, is_full_snapshot,
       urls_discovered, pages_fetched, successful_parses,
       new_items, changed_items, missing_items, inactive_items, errors_by_type
FROM crawl_runs ORDER BY started_at DESC LIMIT 10;
```

## API

- `GET /livez` — process liveness; independent of crawl freshness.
- `GET /healthz` — crawl/data health; see above.
- `GET /v1/external-catalog` — active live listings, filled to a minimum of
  10 per source from the dated curated US snapshot when needed. Versioned
  response (`schemaVersion: 1`, see `src/api/schema.ts`), gzip-compressed,
  ETag + `If-None-Match` (304 when unchanged). Never exposes raw HTML, stack
  traces, or database details — every error path returns
  `{"error": "internal_error"}`.

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-08-10T09:00:00.000Z",
  "sources": [
    { "source": "coach_us", "merchant": "Coach", "lastSuccessfulRunAt": "2026-08-10T03:20:00.000Z", "freshnessHours": 5.7, "itemCount": 812, "liveItemCount": 812, "snapshotItemCount": 0 }
  ],
  "items": [
    {
      "sourceScopedId": "coach_us:C8879",
      "source": "coach_us",
      "merchant": "Coach",
      "title": "Tabby Shoulder Bag 26",
      "brand": "Coach",
      "category": "Handbags",
      "imageUrl": "https://coach.com/images/c8879.jpg",
      "price": { "amount": 350.0, "currency": "USD" },
      "availability": "inStock",
      "detailUrl": "https://www.coach.com/products/tabby-shoulder-bag-26/CEN52.html",
      "lastObservedAt": "2026-08-10T03:19:41.000Z",
      "dataOrigin": "live_crawl"
    }
  ]
}
```

## Disabling the external feed

- **Backend**: set `LIVE_CRAWL_ENABLED=false` (the default) and stop the
  `npm run monitor` process. The API continues serving active database rows
  plus the curated floor while it is running; stop the API too to disable the
  backend feed entirely.
- **App**: build without `--dart-define=ENABLE_EXTERNAL_CATALOG=true`. The
  Flutter app never calls this service at all in that configuration — see
  `lib/data/external_catalog/README.md`.

## No live calls in tests

Every test imports fixtures from `test/fixtures/` and injects fetchers
(`test/support/fixtures.ts`) or in-memory repositories
(`test/support/inMemoryRepositories.ts`). Nothing under `test/` imports
`crawl/httpFetcher.ts` or `crawl/playwrightFallback.ts`. `vitest.config.ts`
also forces `LIVE_CRAWL_ENABLED=false` for the whole run as a belt-and-braces
guard.

## Known limitations (read before relying on this operationally)

- The product-URL patterns in `src/adapters/*.ts` are
  based on sanitized captures of each site's product sitemap (see
  `test/fixtures/coach/` and `test/fixtures/michael_kors/`) — Coach:
  `/products/{slug}/{identifier}.html`; Michael Kors: both
  `/{slug}/{style}.html` and `/product/{slug}/_/R-US_{style}`. `robots.txt`
  for michaelkors.com was fetched and inspected during implementation
  (fixture in `test/fixtures/michael_kors/robots.txt`); coach.com could not
  be reached from the implementation environment — every request
  geo-redirected to a regional licensee site (`mx.coach.com`) rather than the
  US Tapestry storefront. **Validate both adapters' URL patterns and CSS
  selectors against one real capped crawl before any operational use.**
- GUESS accepts only `/en-us/` and legacy `/us/en/` product pages ending in a
  style/color `.html` identifier; Steve Madden accepts only Shopify
  `/products/{handle}` pages. Their curated records were checked against the
  public US storefronts, but their sitemap discovery and CSS selectors still
  require the same capped live-crawl validation before operational use.
- CSS selectors in the "selectors" extraction tier are similarly unverified
  against live markup — they exist as the documented third tier and are
  covered by unit tests against synthetic fixtures, not real pages.
- Operational acceptance (per the spec this was built against) requires two
  later full daily runs with ≥98% required-field coverage. That has not
  happened — this prototype has run zero live full crawls.
- Because of the geo-redirect above, the API includes a 10-per-source
  presentation floor checked against official US product pages on
  2026-08-12. It is **not live inventory**: records are explicitly marked
  `curated_us_snapshot`, availability is `unknown`, and `/healthz` does not
  become healthy because fallback records are present. A successful live US
  crawl replaces matching records and fills beyond the floor.
