# Catalog dashboard — build instructions

A web console for the extraction system: crawl health, run history, the products
that were extracted, what changed, and the **selection document** that decides
what gets extracted at all. Hosted on Vercel as a static SPA, talking **directly
to the Texas server** over HTTPS — no second backend, no snapshot, no mock data.

> Companion to [`EXTERNAL_CATALOG_PRODUCTION_PLAN.md`](EXTERNAL_CATALOG_PRODUCTION_PLAN.md).
> That plan builds the service; this one builds the window into it. Work
> packages continue the same numbering (WP-60…) and the same rules apply: doc
> and code disagree ⇒ one of them is a bug, fix both in the same commit.

Written 16 August 2026.

---

## 1. Shape of the thing

```
   Vercel (static, HTTPS)                     Texas box
┌──────────────────────────┐            ┌──────────────────────────┐
│ dashboard/  Vite + React │            │ Caddy :443 (TLS)         │
│                          │  fetch()   │   catalog.monetta.mx     │
│  Authorization: Bearer   │───────────►│      │                   │
│  <session token>         │  CORS      │      ▼                   │
│  15–30 s poll + ETag     │◄───────────│ monetta-catalog-api:8081 │
└──────────────────────────┘            │   /admin/*  session-gated│
                                        └──────────┬───────────────┘
   no secret in the bundle                         ▼
   no token in Vercel env               postgres · monetta_catalog
```

Three properties this design is built around:

1. **Direct.** The browser calls the API on the server. Vercel serves static
   files and nothing else — it is a CDN for HTML/JS, not a middle tier.
2. **No long-lived secret in the browser.** The owner logs in with a
   passphrase; the server issues a short-lived session token. Nothing
   sensitive is baked into the bundle or into a Vercel environment variable.
3. **Read-mostly, with one deliberate write path.** Everything is observation
   except the selection console, which is the entire point of having a
   dashboard — changing *which products get extracted* without SSH.

---

## 2. Two blocking prerequisites

**P1 — the API must have a real HTTPS hostname.** A page served from
`https://…vercel.app` cannot call `http://209.23.11.117:8081`; browsers block
mixed content outright, and there is no flag, header or fetch option that gets
around it. The dashboard therefore hard-depends on decision **D1** of the main
plan (DNS + Caddy TLS). Do not start WP-63 before WP-30 has a hostname
answering `https://…/livez`.

**P2 — the API must serve CORS for the dashboard origin.** § 7 of the main plan
originally said *"no CORS headers (this is not a browser API)"*. That is no
longer true and the main plan has been corrected: it **is** a browser API now,
for exactly one allowlisted origin. WP-60 implements this; nothing in the SPA
works until it lands.

---

## 3. Authentication

### 3.1 The model

```
POST /admin/session { passphrase }        → { token, expiresAt }   (256-bit, opaque)
GET  /admin/*       Authorization: Bearer → 200 | 401
DELETE /admin/session                      → revoked
```

Reuse the primitives already in `services/accounts_orders/src/api/server.ts` —
do not write new crypto:

- passphrase verifier stored as `scrypt$<salt>$<hash>` (base64url), verified with
  `timingSafeEqual` on equal-length buffers
- token = `randomBytes(32).toString('base64url')`, stored only as its SHA-256
- session rows in `dashboard_sessions`, TTL `DASHBOARD_SESSION_TTL_HOURS`
  (default 12), revocable individually and in bulk

The SPA keeps the token in **`sessionStorage`** — it dies with the tab, which
bounds the window in which an XSS bug on the dashboard could exfiltrate it.
`localStorage` would survive restarts and is the wrong trade for a tool that
mutates production selection.

### 3.2 Why not the obvious alternatives

| Option | Why not |
|---|---|
| Ship `ADMIN_API_TOKENS` in a Vercel env var | `VITE_*` env vars are compiled into the bundle. Anyone who opens devtools owns the admin API permanently, with no expiry, no revocation, no audit trail, and no signal that it leaked. `ADMIN_API_TOKENS` stays server-side and CLI-only |
| Cookie session | Vercel → `monetta.mx` is a **cross-site** context, so the cookie needs `SameSite=None; Secure` — precisely what Safari's ITP blocks and what Chrome's third-party cookie work partitions. It would work in one browser and fail silently in another. If the dashboard ever moves to `dash.monetta.mx` (same site as the API), a `SameSite=Lax; HttpOnly` cookie becomes strictly better and should replace this |
| A Vercel serverless proxy holding the token | Safer for secrets, but it is a second backend between the browser and the server — the opposite of "connect directly". Noted here as the fallback **if** the passphrase model is ever judged insufficient |
| No auth, read-only | The feed exposes what the owner is sourcing, at what price, and how the business is buying. That is competitive information, and the selection console is a write path |

### 3.3 Abuse controls

- 5 failed passphrase attempts per IP per 15 minutes → `429`, no detail about
  which part failed.
- 10 failures in an hour → one alert email (§ 9 of the main plan, deduped).
- Every selection write records `applied_by` from the session, so the audit
  trail in `selection_versions` stays truthful.
- **The dashboard is never the only way to stop a crawl.** SSH + CLI kill
  switches (§ 14 of the main plan) stay authoritative. If this SPA is down,
  broken, or locked out, operations are unaffected.

---

## 4. CORS — the exact rules

```
Access-Control-Allow-Origin: <echoed, only on exact allowlist match>
Vary: Origin
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type, If-None-Match, X-Applied-By
Access-Control-Expose-Headers: ETag
Access-Control-Max-Age: 600
```

- `DASHBOARD_ORIGINS` is a comma-separated list of **exact** origins.
- **Never `*`. Never `*.vercel.app`.** Anyone with a Vercel account can deploy
  to `*.vercel.app`; a wildcard there hands every one of them a browser context
  against your admin API. Preview deployments get an explicit entry when a
  specific one needs to reach production, or they point at a local API.
- `Access-Control-Expose-Headers: ETag` is not optional — without it the browser
  hides `ETag` from JS and every conditional poll silently degrades into a full
  refetch. This is the single most commonly missed line in this section.
- Credentials mode stays **off** (`Access-Control-Allow-Credentials` absent);
  auth is a bearer header, not a cookie.
- A non-matching `Origin` gets no CORS headers at all — not a `403`. The browser
  blocks it; `curl` and the CLI keep working, which is what you want during
  incident response.

---

## 5. Server endpoints the dashboard needs

All session-gated, all under `/admin`. Aggregates exist on purpose: six
independent polls every 15 s from a few tabs, against a 2-vCPU box that is also
crawling, is a self-inflicted load problem.

| Route | Returns |
|---|---|
| `POST /admin/session` · `DELETE /admin/session` | login / logout |
| `GET /admin/overview` | **one call** for the whole overview screen: per-source health, last discovery + last watch run, freshness, selected/served/deselected/inactive counts, today's page budget, selection version, 5 most recent alerts |
| `GET /admin/runs?source=&kind=&status=&limit=&before=` | run history, newest first, cursor-paged |
| `GET /admin/runs/:id` | one run: full metrics, `errors_by_type` breakdown, duration, selection version |
| `GET /admin/products?source=&q=&state=&tier=&placement=&limit=&cursor=` | product table, server-side filtered and paged |
| `POST /admin/products/:sourceScopedId/pin` · `/hide` | Stage C quick actions — each writes a scoped selection rule, never free-form JSON |
| `GET /admin/events?since=&limit=` | price drops, restocks, new matches, deselections |
| `GET /admin/alerts?limit=` | alert history + dedupe state |
| `GET /admin/selection` · `PUT` | current document; apply a new version |
| `POST /admin/selection/preview` | Stage-A match counts per rule against the last discovered URL set — **zero fetches** |
| `GET /admin/selection/versions` · `POST /admin/selection/rollback` | history and rollback |
| `GET /admin/feed-preview` | byte-for-byte what `/v1/external-catalog` would return, so the browser never needs a second token |

Every list endpoint is `ETag`-able and capped (`limit ≤ 200`). No endpoint ever
returns fingerprints, raw HTML, stack traces or connection details — the
existing `{"error":"internal_error"}` catch-all stands.

---

## 6. Screens

### 6.1 Overview — "is it working right now?"

- A single connection banner: **reachable / degraded / unreachable**, with the
  time of the last successful poll. An unreachable API must say so loudly; a
  blank dashboard that looks healthy is worse than no dashboard.
- Per-source cards: status, reasons (`watch_stale`, `low_parse_coverage`,
  `selection_empty`, `budget_exhausted`…), freshness clocks for discovery and
  watch **separately** — "live" is the watch clock, and conflating them hides
  the thing you most want to see.
- Counts: selected · served · deselected · inactive, per source.
- Today's page budget as a bar against `DAILY_PAGE_BUDGET`.
- Current selection version + who applied it + when.
- Last 5 alerts.

### 6.2 Runs — "what happened, and why did it stop?"

Table: started, source, kind (`discovery`/`watch`), status, selection version,
discovered → selected → fetched → parsed, coverage %, new/changed/missing/
inactive/deselected, duration. Filter by source, kind, status. Row opens a
drawer with the `errors_by_type` breakdown.

A `blocked` run renders with the stop instruction spelled out — *disable this
source in the selection; do not work around the block* — because a dashboard is
exactly where someone would otherwise reach for a retry button. **There is no
retry button for a blocked source.**

Sparkline of coverage % over the last 30 discovery runs, inline SVG, no chart
library.

### 6.3 Selection console — the reason this dashboard exists

- Current document: version, hash, `applied_by`, note, applied at.
- JSON editor with client-side validation that mirrors WP-11's validator
  (import the same pure module — do not fork the rules into TypeScript twice;
  see § 7.2).
- **Preview** button → `POST /admin/selection/preview` → per-rule match counts,
  totals per source, budget check against `MAX_SELECTED_URLS_PER_SOURCE`, and an
  explicit note on which rules are Stage B ("costs a fetch per candidate").
- Diff against the current version before applying.
- Apply: confirmation dialog naming the sources whose selection changes, a
  required note, `X-Applied-By` from the session.
- Version history with rollback.

Guard rails in the UI, not just the API: applying a document that selects zero
products for an enabled source, or that crosses a budget, requires a second
confirmation that states the consequence in words.

### 6.4 Products — "what did we actually get?"

Searchable, server-paged table: thumbnail, source, title, USD price (or
`Consultar precio` — never `$0`, matching `formatCatalogMoney`), availability,
watch tier, placements, matched rule, last seen, merchant link. Row actions:
**pin** (promote to hourly watch) and **hide** (Stage C, disappears from the app
feed on the next response — no crawl, no deploy).

### 6.5 Events — "what changed since yesterday?"

Timeline of `product_events`: price drops and rises, restocks, new matches,
deselections. This is the screen that makes "always live" visible; if it is
empty for a day, the watch tier is not running.

### 6.6 Feed preview — "what will the app show?"

Renders `/admin/feed-preview` grouped by placement (`home_rail`,
`catalog_browse`, `collection:<slug>`, `hidden`), so the owner sees the app's
rails before opening the app. Closes the loop between the selection document and
the phone.

---

## 7. Client design rules

### 7.1 Polling

- Overview 15 s, other screens 30 s, always with `If-None-Match`.
- **Pause when `document.hidden`.** A forgotten tab must not poll a crawler box
  all night.
- On failure: exponential backoff to a 2-minute ceiling, banner goes
  `unreachable`, last-known data stays on screen with its timestamp — same
  philosophy as the Flutter client's cache-first contract. Never blank the
  screen on a failed refresh.
- `401` → drop the session, return to login, preserve the current route so the
  user lands back where they were.

### 7.2 One validator, not two

The selection rules are already specified once, as a pure TypeScript module in
`services/catalog_monitor/src/selection/` (WP-11) with no I/O and no Node-only
imports. The dashboard imports that module directly rather than reimplementing
the rules in the browser — a second copy will drift, and the drift will show up
as "the dashboard said it was valid and the server rejected it".

Wire it as a path alias in `dashboard/vite.config.ts`:

```ts
resolve: { alias: { '@selection': '../services/catalog_monitor/src/selection' } }
```

If that cross-package import ever becomes awkward (it will, the day the service
is deployed from its own repo), the correct fix is to publish the module, not to
duplicate it.

### 7.3 Stack

Vite + React + TypeScript. Dependencies: `react`, `react-dom`,
`react-router-dom`; dev: `vite`, `@vitejs/plugin-react`, `typescript`, `vitest`,
`@testing-library/react`. No UI kit, no chart library, no state library — this
repo's taste is explicitly low-dependency (`catalog_monitor` uses no ORM and no
codegen; `web/` is vanilla Vite), and a monitoring console is tables, numbers
and one editor.

Visual language: dense and neutral. Tabular numerals for metrics. Status is
never colour alone — every state carries a label or glyph as well, so a
red/green-blind operator reads it correctly, and so a screenshot pasted into
WhatsApp still means something.

### 7.4 Layout

```
dashboard/
  package.json  vite.config.ts  tsconfig.json  vercel.json  index.html
  src/
    main.tsx  routes.tsx
    api/{client.ts,types.ts,poll.ts}
    auth/{session.ts,LoginScreen.tsx}
    screens/{Overview,Runs,Selection,Products,Events,FeedPreview}.tsx
    components/{StatusBadge,MetricCard,DataTable,Sparkline,JsonEditor,Diff}.tsx
  test/
```

`api/types.ts` is generated from nothing and hand-written on purpose, mirroring
`src/api/schema.ts` — the same decision, for the same reason, as the repo's
hand-written GraphQL mappers.

---

## 8. Vercel deployment

The repo root already has a `vercel.json` that builds `web/` (the Figma UI
atlas). Do not touch it. Create a **second Vercel project** from the same
repository with **Root Directory = `dashboard`**; Vercel then reads
`dashboard/vercel.json` and ignores the root one.

```json
{
  "framework": "vite",
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "rewrites": [{ "source": "/(.*)", "destination": "/" }],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Content-Security-Policy",
          "value": "default-src 'self'; connect-src 'self' https://catalog.monetta.mx; img-src 'self' https: data:; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" }
      ]
    }
  ]
}
```

- `connect-src` pins the browser to exactly one API host — a second line of
  defence against an injected script phoning elsewhere.
- `img-src https:` is deliberately broad: product thumbnails come from four
  merchant CDNs whose hostnames change. Narrow it to those four hosts if you
  prefer; do not narrow it to `'self'` or the table loses its images.
- Environment variable, public and non-secret:
  `VITE_CATALOG_API_BASE_URL=https://catalog.monetta.mx`.
- **Nothing else goes in Vercel env.** If a value would be a problem in a
  `view-source`, it does not belong in this project.

Then add the resulting production origin to `DASHBOARD_ORIGINS` on the server
and restart the API. Both sides must agree; a missing entry shows up as an
opaque browser CORS error with a perfectly healthy `curl`.

---

## 9. Server-side changes to the main plan

These land in `services/catalog_monitor` and are already reflected in
`EXTERNAL_CATALOG_PRODUCTION_PLAN.md`:

- § 7 — CORS reversed from "never" to "exact allowlist", and the dashboard
  endpoints added to the route table.
- § 8.3 — Caddy no longer `respond 404`s `/admin/*`; it proxies them. Note that
  the stock `caddy:2-alpine` image has **no** `rate_limit` directive (that is a
  third-party module needing a custom build), so throttling lives in the Node
  app — which is where WP-22's limiter already is.
- § 8.5 — new env vars: `DASHBOARD_ORIGINS`,
  `DASHBOARD_PASSPHRASE_VERIFIER`, `DASHBOARD_SESSION_TTL_HOURS`.
- Migration `006_dashboard_sessions.sql`.

```sql
CREATE TABLE IF NOT EXISTS dashboard_sessions (
  token_sha256 TEXT PRIMARY KEY,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at   TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  label        TEXT
);
CREATE INDEX IF NOT EXISTS idx_dashboard_sessions_expiry
  ON dashboard_sessions (expires_at);
```

Expired rows are deleted by the daily backup timer, not by a separate job.

---

## 10. Work packages

### WP-60 · Session auth + CORS
**Depends on** WP-22 · **Touches** `src/api/{auth,session,cors}.ts`, `src/db/migrations/006_dashboard_sessions.sql`, `src/db/pgSessionRepository.ts`, `src/cli/dashboardPassphrase.ts`, `test/{auth,cors}.test.ts`

Session issue/verify/revoke reusing the `accounts_orders` scrypt + SHA-256
pattern. CORS middleware per § 4. A `npm run dashboard:passphrase` CLI that
prints a verifier string to paste into the env file (and never writes a
passphrase anywhere).

**Acceptance** · Wrong passphrase → 401 and no timing signal; 6th attempt inside
15 min → 429; expired token → 401; revoked token → 401; an allowlisted origin
gets `Access-Control-Allow-Origin` **and** `Access-Control-Expose-Headers: ETag`;
a non-allowlisted origin gets no CORS headers; `OPTIONS` preflight answers 204.
**Verify** `npm test -- auth cors`

### WP-61 · Read endpoints
**Depends on** WP-60, WP-20 · **Touches** `src/api/admin/{overview,runs,products,events,alerts}.ts`, `test/api.admin.read.test.ts`

Per § 5, cursor-paged, ETag'd, capped. `/admin/overview` is one query batch, not
six round trips.

**Acceptance** · Overview answers in one request with every field the Overview
screen needs; `limit` above the cap is clamped, not errored; no fingerprint or
internal id leaks into any payload.
**Verify** `npm test -- api.admin.read`

### WP-62 · Selection console endpoints
**Depends on** WP-15 · **Touches** `src/api/admin/selection.ts`, `src/api/admin/feedPreview.ts`, `test/api.admin.selection.test.ts`

Versions list, rollback, preview, `/admin/feed-preview`, and the scoped
`pin`/`hide` actions that write Stage C rules without accepting arbitrary JSON.

**Acceptance** · Rollback creates a **new** version whose document equals the
old one (history is append-only, never rewritten); `pin`/`hide` are idempotent;
`feed-preview` output is byte-identical to `/v1/external-catalog` for the same
state.
**Verify** `npm test -- api.admin.selection`

### WP-63 · Dashboard scaffold, API client, login
**Depends on** WP-60, WP-30 (hostname exists) · **Touches** `dashboard/**`

Vite + React + TS skeleton, routing, `api/client.ts` (bearer, ETag, backoff,
`document.hidden` pause), session storage, login screen, connection banner.

**Acceptance** · Against a fake fetch: 401 clears the session and routes to
login preserving the target route; a failed poll keeps the last data and flips
the banner; polling stops when the document is hidden; ETag round-trips.
**Verify** `cd dashboard && npm test`

### WP-64 · Overview + Runs screens
**Depends on** WP-61, WP-63 · **Touches** `dashboard/src/screens/{Overview,Runs}.tsx`, `components/*`

Per § 6.1–6.2, including the separate discovery/watch freshness clocks, the
budget bar, the coverage sparkline, and the blocked-run stop message with **no
retry control**.

**Acceptance** · Fixture-driven tests for healthy, degraded, blocked and
unreachable states; status conveyed by label as well as colour.
**Verify** `cd dashboard && npm test -- Overview Runs`

### WP-65 · Selection console screen
**Depends on** WP-62, WP-63 · **Touches** `dashboard/src/screens/Selection.tsx`, `components/{JsonEditor,Diff}.tsx`, `vite.config.ts` (alias)

Per § 6.3, importing the server's selection validator per § 7.2.

**Acceptance** · An invalid document cannot be applied and names the failing
rule id; preview shows per-rule counts and flags Stage B rules as fetch-costing;
apply requires a note and shows a diff first; a zero-selection or over-budget
apply requires a second, worded confirmation.
**Verify** `cd dashboard && npm test -- Selection`

### WP-66 · Products, Events, Feed preview
**Depends on** WP-61, WP-62, WP-63 · **Touches** `dashboard/src/screens/{Products,Events,FeedPreview}.tsx`

Per § 6.4–6.6. Money rendering matches the app: currency code always shown, a
missing price is `Consultar precio`, USD and MXN are never mixed.

**Acceptance** · A null price never renders as `$0`; pin/hide reflect optimistically and reconcile on the next poll; feed preview groups by placement and marks `hidden`.
**Verify** `cd dashboard && npm test -- Products Events FeedPreview`

### WP-67 · Deploy and wire the origin
**Depends on** WP-63 · **Touches** `dashboard/vercel.json`, `docs/OPERATIONS.md`

Second Vercel project with Root Directory `dashboard`, CSP and headers per § 8,
`DASHBOARD_ORIGINS` set on the server, restart, verify from a real browser.

**Acceptance** · The production origin loads, logs in, and polls with 304s
visible in the network tab; a preview deployment is *blocked* by CORS, proving
the allowlist is exact; the runbook documents adding an origin.
**Verify** browser devtools network tab + `curl -H 'Origin: https://evil.example' -i https://catalog.monetta.mx/admin/overview`

### WP-68 · CI
**Depends on** WP-63 · **Touches** `.github/workflows/dashboard.yml`

`npm ci && npm run build && npm test` for `dashboard/`, plus a typecheck that
covers the shared selection module import.

**Acceptance** · Green on the branch; a type error in the shared selection
module fails the dashboard job too (that coupling is the point).
**Verify** push

---

## 11. Adding other services later

`accounts_orders` runs on the same box and will want the same treatment. Design
the client's service list as configuration from day one:

```ts
const SERVICES = [
  { id: 'catalog',  label: 'Catálogo US', baseUrl: import.meta.env.VITE_CATALOG_API_BASE_URL },
  // { id: 'accounts', label: 'Cuentas', baseUrl: … },
];
```

Overview iterates services and renders whatever each one's `/livez` and
`/healthz` report. Anything richer (runs, selection) stays catalog-specific
until a second service actually needs it — a generic monitoring framework built
for one service is a framework built for zero.

---

## 12. Status

| WP | Title | Status |
|---|---|---|
| WP-60 | Session auth + CORS | todo |
| WP-61 | Read endpoints | todo |
| WP-62 | Selection console endpoints | todo |
| WP-63 | Scaffold, client, login | todo |
| WP-64 | Overview + Runs | todo |
| WP-65 | Selection console | todo |
| WP-66 | Products, Events, Feed preview | todo |
| WP-67 | Deploy + origin wiring | todo |
| WP-68 | CI | todo |

## 13. Non-goals

- No retry/force-crawl button for a blocked source. A block is a stop (§ 2 of
  the main plan).
- No editing of product data. The dashboard observes what was extracted; it does
  not correct a merchant's catalog.
- No path from the dashboard into Shopify, cart, or checkout. `ownerProcurement`
  is unchanged, and creating a Shopify product stays a deliberate manual act.
- No public or shared read-only link. One passphrase, one owner, an audit trail.
- Not an ops dependency: every kill switch remains reachable over SSH without
  this SPA.
