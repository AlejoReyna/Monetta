# External product selection and IP-block resilience audit

**Audit date:** 31 August 2026

**Scope:** `services/catalog_monitor`, its admin control path through
`services/accounts_orders`, and the Flutter presentation/cache path for the
external catalog.

## Executive decision

The external catalog monitor is a sound **research-only prototype**, but it is
not ready to act as a live product-selection system and must not be described as
automated dropshipping.

The safest parts are already in place: live crawling is opt-in, the crawler uses
an identifiable user agent, robots failures stop a source, final URLs must stay
on the intended US host, explicit CAPTCHA pages stop a run, and failed or
partial runs do not overwrite the last good product snapshot.

The operational weakness is the path between “a source starts refusing this
server” and “all requests and all current-looking product claims stop.” Today:

- broad 403 blocking is not recognized by the runner;
- 429 and 503 responses are retried before their bodies can be inspected for a
  CAPTCHA or block marker;
- `Retry-After` is discarded;
- a blocked source has no durable circuit breaker or automatic alert;
- the owner-facing source policy does not consistently control crawling,
  serving, health, item limits, or commission rules;
- the app can retain and display an old successful snapshot indefinitely; and
- the planned selection-first engine does not exist, so the crawler discovers
  and fetches a whole allowed catalog before the small serve-time curation step
  chooses a few items.

Changing or rotating the server IP to get around a merchant block is not the
recommended recovery. A block is a stop signal. Durable recovery means pausing
the source, identifying the response class, obtaining permission or an approved
feed/API, and resuming through a small, selected, rate-bounded validation crawl.

## Current production state

Read-only checks of the public service on 31 August 2026 returned:

| Check | Observed result |
|---|---|
| `GET https://catalog.monetta.mx/livez` | `200`, process alive |
| `GET https://catalog.monetta.mx/healthz` | `503 degraded` |
| Coach health | no successful full crawl |
| Michael Kors health | no successful full crawl |
| Served items | 16 total: 8 Coach, 8 Michael Kors |
| Data origin | 100% `curated_us_snapshot`; 0 `live_crawl` |
| Payload timestamp | 12 August 2026 |

This agrees with `docs/OPERATIONS.md`: the 28 August smoke tests produced a
partial Coach run dominated by 4xx responses and an explicit Michael Kors
block. The monitor was then disabled. That was the correct operational choice.

**Verdict:** the API is available, but live product detection is not available.
The current payload is a dated research fallback, not evidence of inventory,
price, or availability.

## What the current system actually selects

There are four distinct stages; calling all of them “product selection” hides
important gaps.

1. **Discovery** walks a sitemap tree, or a bounded set of category pages for GP
   McAllen (`src/discovery`).
2. **URL classification** applies brand-specific product URL patterns and a
   global excluded-path rule (`src/adapters`).
3. **Extraction and snapshot reconciliation** parse product pages, merge color
   variants, and update PostgreSQL only after a successful full crawl
   (`src/crawl/runner.ts`, `src/crawl/snapshotDiff.ts`).
4. **Serve-time curation** rejects out-of-stock, price-less, and obviously
   off-category rows, scores availability/image/variants/live-origin/price
   band, caps each source, and round-robins sources (`src/catalog/curation.ts`).

Stage 4 is a small display-ranking rule, not a business product-selection
model. It does not evaluate landed cost, import eligibility, merchant
authorization, demand, return risk, delivery reliability, competitive price,
or expected contribution margin.

The versioned selection document, Stage A URL filtering, Stage B product
filtering, watch tiers, and selection history described in
`docs/EXTERNAL_CATALOG_PRODUCTION_PLAN.md` remain planned work. No
`src/selection` module or selection migration exists in the current tree.

## Findings

### P0 — Live detection is already unavailable

The production service has never completed a successful full crawl for either
enabled source. Its 16 items are dated fallbacks. This blocks any claim that the
system detects current products.

**Required action:** keep live crawling disabled until the P0/P1 controls below
exist and each authorized source passes the staged resume checklist.

### P0 — A source policy is not an effective kill switch

The durable `external_source_policies.enabled` value is consulted by the
scheduler, but the API and health endpoint use `ENABLED_SOURCE_IDS` from the
process environment. Consequently, pausing a source in the owner UI can stop a
future scheduled crawl while the API continues serving that source and health
continues evaluating it.

The same policy table stores `itemLimit`, base commission, high-value
commission, and threshold, but production curation and pricing are constructed
from environment variables. Those owner edits therefore do not affect the
catalog response.

This contradicts the UI confirmation “Fuente actualizada en el monitor y la
app” and the intended source-level kill switch.

**Required action:** resolve one effective policy per request/run and apply it
to scheduler inclusion, API serving, health aggregation, per-source limit, and
pricing. A disabled source must be absent from all five.

### P0 — 429/503 block pages bypass block detection

In `crawl/runner.ts`, any 429 or 5xx result is converted to a retry exception
before `looksLikeCaptchaOrBlock()` sees the body. A 429 or 503 page containing a
CAPTCHA marker is retried up to three times and finally counted as an HTTP
error, not `captcha_or_block`.

The 429 standard says it means too many requests and may carry `Retry-After`.
The client should honor that signal rather than apply its own short retry loop
([RFC 6585, section 4](https://www.rfc-editor.org/rfc/rfc6585.html#section-4)).

**Required action:** inspect status, headers, final URL, and bounded body markers
before deciding whether a response is retryable. A marker-bearing 403/429/503
must open the source circuit immediately. An unmarked 429 must pause the source
until `Retry-After`, or a conservative configured cooldown if it is absent.

### P0 — Broad IP blocking is implemented but disconnected

`isWidespreadBlocking()` defines a useful threshold—at least five responses and
50% forbidden/block responses—but it is never called. A source returning plain
403 pages without a known marker can therefore be requested one URL at a time
across the entire discovered catalog. This is both diagnostically wrong and
likely to make the refusal worse.

**Required action:** maintain a run-level status histogram and open the circuit
at a small bounded sample. Recommended initial rule: stop after 5 attempted
product URLs when at least 3 are 401/403/429, or immediately on an explicit
challenge marker. Make thresholds source-configurable only within conservative
upper bounds.

### P1 — No durable circuit breaker or resume gate

A blocked run is stored, but there is no source runtime state such as
`active`, `cooldown`, `blocked`, or `manual_only`. The daily scheduler will try
the same source again at the next cron fire unless an operator changes policy or
deployment configuration.

**Required action:** persist source runtime state with `blockedAt`, reason,
`resumeNotBefore`, evidence summary, operator decision, and authorization
reference. Scheduler entry must fail closed unless both policy and runtime state
allow a crawl. Only an audited owner action may clear `blocked`.

### P1 — Response headers and useful evidence are lost

`liveFetch()` collects headers, but the scheduler maps page and sitemap results
to `{status, body, finalUrl}` or `{status, body}`. The runner therefore cannot
honor `Retry-After`, record a request/correlation ID, distinguish CDN/WAF
responses, or use cache validators.

HTTP defines `Retry-After` as either a date or a delay in seconds
([RFC 9110, section 10.2.3](https://www.rfc-editor.org/rfc/rfc9110.html#section-10.2.3)).

**Required action:** preserve a safe header allow-list through the fetch ports:
`retry-after`, `content-type`, `date`, `etag`, `last-modified`, `server`, and
provider request IDs. Store hashes and short marker classifications, not full
challenge HTML or cookies.

### P1 — Block alerts do not exist

The notification outbox handles product-created, restocked, and price-dropped
events. It does not emit crawl-block or source-health events. The host
healthcheck probes `/livez` and container processes, not data health, so a
perfectly alive but permanently blocked monitor does not page anyone.

**Required action:** add deduplicated operational alerts for `source.blocked`,
`source.rate_limited`, `source.wrong_market`, `source.stale`, and
`source.recovered`. One incident should produce one alert plus state changes,
not an alert on every scheduled tick.

### P1 — Whole-catalog fetching raises the probability of a ban

Serve-time curation returns only a handful of items, but the runner fetches
every classified, robots-allowed product URL to obtain a full snapshot. The
production smoke run found 3,197 Coach URLs. A one-second delay still turns a
full source scan into thousands of requests and a long-lived, recognizable
traffic pattern.

**Required action:** implement selection first, fetch second. A discovery pass
may inspect sitemaps, but Stage A must reduce product pages to a reviewed,
versioned URL set before page fetches. Watch only selected products on the
short cadence; run broad discovery much less often and within a per-source daily
budget.

### P1 — Stale data can still look current in the app

The backend keeps last-good active rows when a crawl is blocked, which is good
for data preservation. Presentation does not complete the safety story:

- the API continues returning active rows even when source health is degraded;
- the API source projection omits an explicit health/block state;
- Flutter parses source freshness but the shopper-facing section does not use
  it;
- Flutter discards each item's `dataOrigin`;
- cache refresh failures are swallowed and the cache has no expiry; and
- a formerly live item can keep an `inStock` label indefinitely.

The existing “precio y disponibilidad por confirmar” disclosure helps, but it
does not neutralize a prominent “Disponible” label.

**Required action:** preserve provenance and source state end to end. When a
source is stale, paused, or blocked, either suppress its items or downgrade all
availability to `unknown`, label the last observation time, and disable any
notification based on current stock. For an internal research surface, retaining
the last-good record is acceptable; presenting it as current is not.

### P1 — The public API is broader than the stated internal audience

`/v1/external-catalog` is publicly readable at the production hostname even
though repository documentation describes the feature as an internal owner
prototype. The response includes merchant URLs, images, observed price, and
curated ranking.

**Required action:** decide the audience explicitly. For the recommended
internal-only phase, require authenticated access at the API or a trusted
server-mediated path. Do not rely only on the Flutter build flag to protect a
public endpoint.

### P2 — Business selection is too shallow for dropshipping

The current score is suitable for choosing visually usable research cards. It
is not enough to decide what Monetta should sell. In particular, the suggested
retail calculation is source price plus commission; it is not landed cost and
does not include US sales tax, inbound shipping, customs/duty/IVA, brokerage,
loss allowance, returns, Mexico fulfillment, payment fees, or FX buffer.

**Required action:** keep external rows as `ownerProcurement`. Any future saleable
offer must be a separately approved Shopify record with a documented landed
cost, fulfillment class, lead time, cancellation/refund terms, and seller of
record.

### P2 — Test coverage misses the real ban modes

The suite covers one marker-bearing 403 and correctly proves that the products
table is not mutated. It lacks behavioral tests for:

- plain widespread 403 responses;
- marker-bearing 429 and 503 responses;
- `Retry-After` as seconds and HTTP date;
- circuit persistence and audited resume;
- a policy-disabled source being excluded from crawl, serve, and health;
- policy item-limit and commission changes reaching the public response;
- stale/blocked rows being downgraded in the API and Flutter UI; and
- one blocked source not affecting healthy sources.

## How to determine whether the server IP is banned

Do not diagnose from one status code. Classify a small, non-repeating sample and
stop as soon as the evidence is sufficient.

| Observation | Likely class | Response |
|---|---|---|
| 429, especially with `Retry-After` | rate limit | pause until the stated time; reduce budget/cadence |
| 403/401 with CAPTCHA, WAF, “unusual traffic,” or access-denied marker | explicit block | disable source; contact merchant; do not retry |
| plain 403 on most of 5 distinct allowed product URLs | probable IP/client block | open circuit; preserve evidence; request permission |
| US URL redirects to another country/host | wrong market/egress geography | disable; do not relabel regional data as US data |
| 5xx/timeouts for one merchant only | merchant/CDN outage or possible soft block | conservative cooldown; one later probe |
| DNS/TLS/timeouts across several unrelated merchants | server egress/DNS/network incident | fix infrastructure; this is not evidence of a merchant ban |
| browser works from an operator device but the server fails | egress/client-specific refusal is plausible | do not move automation to the device; contact the source |

Robots remains an independent gate. The Robots Exclusion Protocol says a
crawler must follow successfully fetched rules, and on network/5xx
unreachability must assume complete disallow
([RFC 9309, sections 2.3.1 and 2.4](https://www.rfc-editor.org/rfc/rfc9309.html#section-2.3.1)).
The current code is intentionally stricter and stops on every non-200 robots
response; retaining that fail-closed policy is appropriate here.

## Incident runbook: server IP blocked

### 1. Contain — immediately

1. Stop automated requests for the affected source. If the source-level policy
   cannot be trusted to affect the active deployment, set
   `LIVE_CRAWL_ENABLED=false` for the monitor and recreate only the monitor
   container.
2. Do not run another smoke crawl, enable Playwright, change the user agent,
   rotate IPs, or send requests through customer devices.
3. Keep the API and PostgreSQL online if the internal research surface still
   needs last-known data, but mark the affected source `blocked` and its
   availability `unknown`.
4. Suppress stock/restock/price notifications from that source.

### 2. Preserve evidence — within 30 minutes

Record one incident with:

- source and run ID;
- UTC first/last failure time;
- crawler version and selection version;
- public egress identity and hosting region;
- requested path class, final host, status histogram, and redirect chain;
- safe response headers including `Retry-After` and provider request ID;
- detected marker class and a body hash/short sanitized excerpt;
- whether robots loaded and allowed the attempted path; and
- the exact stop action taken.

Never store response cookies, tokens, full challenge pages, or data unrelated to
diagnosis.

### 3. Triage — same business day

Determine whether the event is rate limiting, explicit denial, wrong market,
merchant outage, or local infrastructure failure. Compare with the immediately
previous successful run and with one unrelated source. Do not use a second IP
as a diagnostic probe unless the merchant has authorized it.

### 4. Choose an approved continuity path

Use these options in order:

1. merchant/supplier API, inventory feed, affiliate feed, CSV/SFTP export, or
   webhook supplied for this use;
2. written permission plus a fixed, identified egress IP the merchant can
   allow-list;
3. an operator-reviewed manual import into the research queue, with provenance
   and timestamp, but no automated polling;
4. last-known research data with availability downgraded to unknown and a clear
   stale label; or
5. disable the source completely.

A new server IP is acceptable for an ordinary infrastructure migration or an
approved allow-listed integration. Using replacement or rotating IPs for the
purpose of escaping a block is not a continuity strategy.

### 5. Resume — only after authorization or a resolved temporary limit

1. Record the approval, feed contract, or cooldown expiry.
2. Re-fetch `robots.txt` with the real crawler identity.
3. Fetch one selected product URL, once.
4. Confirm HTTPS, intended US host, expected content type, no challenge marker,
   and correct price/currency.
5. Run a capped, selection-first smoke test.
6. Complete two successful authorized discovery/watch cycles with at least 98%
   required-field coverage.
7. Clear the circuit through an audited owner action.
8. Restore live labels and notifications only after the successful cycles.

## Target design

```text
approved API/feed ───────────────┐
                                │
authorized web source            ├─> normalized candidate record
  -> robots                     │      -> hard eligibility gates
  -> source circuit breaker     │      -> business score
  -> bounded discovery          │      -> owner approval
  -> versioned URL selection    │      -> Shopify saleable record
  -> selected-page fetch ───────┘

manual reviewed import ─────────────> research-only candidate

Every path -> provenance -> freshness policy -> atomic publish -> app
```

### Source state

Add one durable runtime state per source:

```text
active -> cooldown -> active
   |         |
   +-------> blocked -> manual_only
                  \-> active (audited resume only)
```

Suggested fields:

- `crawl_state`: `active | cooldown | blocked | manual_only`;
- `blocked_at`, `block_reason`, `resume_not_before`;
- `last_status_histogram`, `last_retry_after`, `last_final_host`;
- `authorization_kind`, `authorization_reference`, `reviewed_at`;
- `selection_version`, daily request budget, and requests used; and
- `operator_note`, `updated_by`, `updated_at`.

### Selection model

Apply hard gates before scoring:

- source enabled, authorized for the selected access method, and circuit active;
- robots and source terms reviewed for the exact path;
- approved host, market, currency, category, and provenance;
- fresh enough for the intended surface;
- valid identifier, price, image, and product URL;
- import/safety restrictions reviewed; and
- no duplicate approved Monetta/Shopify product.

Rank only eligible research candidates. A practical first score is:

| Dimension | Weight | Evidence required |
|---|---:|---|
| expected contribution margin | 30% | full landed cost, fees, returns allowance |
| observed shopper demand | 25% | Monetta search, views, wishlist/interest events |
| supply reliability | 20% | stock history, cancellation rate, lead-time variance |
| price competitiveness | 10% | approved comparable data, not cross-currency guessing |
| content/data quality | 10% | image, variants, identifiers, parse confidence |
| portfolio diversity | 5% | brand/category/color concentration controls |

The score recommends items for owner review. It must not auto-publish external
rows, auto-check out on a merchant site, or turn research availability into
Monetta inventory.

### Freshness behavior

| Source/item state | Internal research surface | Shopper-facing surface |
|---|---|---|
| fresh + healthy | show observation normally | only after separate business/legal approval |
| stale | show with age and `unknown` availability | hide |
| cooldown | show last-known with warning | hide |
| blocked | show incident link to owner only | hide |
| curated snapshot | clearly label historical reference | hide |

## Implementation order

### P0 — make stopping truthful

1. Make the database source policy authoritative for crawl, serve, health,
   limits, and pricing.
2. Inspect block markers before retry classification.
3. Propagate safe response headers and honor `Retry-After`.
4. Wire the widespread-block threshold into the runner.
5. Add a durable source circuit and audited manual resume.
6. Add operational block/stale alerts.
7. Downgrade or hide stale/blocked availability end to end.

### P1 — reduce request volume and improve continuity

1. Implement the versioned selection engine and Stage A URL filtering.
2. Separate low-frequency discovery from selected-item watch runs.
3. Enforce daily request budgets and per-source cooldowns.
4. Add official-feed and manual-reviewed ingestion ports.
5. Add source state/provenance/freshness to the API and Flutter models.
6. Authenticate the internal catalog response.

### P2 — make recommendations commercially meaningful

1. Model landed cost and contribution margin.
2. Add owner approval and Shopify publication as a separate workflow.
3. Feed first-party demand signals into candidate ranking.
4. Measure source reliability and use it in scoring.

## Acceptance tests

The IP-block work is complete only when automated tests prove all of the
following:

- a marker-bearing 403, 429, or 503 stops after the first response;
- a plain widespread 403 pattern stops within the configured sample bound;
- 429 `Retry-After` prevents requests until the parsed time;
- a blocked run never mutates products or publishes current availability;
- a blocked source is excluded from future scheduling until audited resume;
- a disabled source is absent from crawl, API, health, and notifications;
- owner item-limit and commission edits change the next API response;
- stale cached items render as unknown/historical or are hidden;
- a healthy source continues when another source is blocked;
- block alerts deduplicate and recovery emits one resolution event; and
- the existing full test suite remains green.

## Verification performed for this audit

- `npm run typecheck`: passed.
- `npm test`: 20 files, 183 tests passed. The suite was rerun with localhost
  socket permission because the API tests bind a temporary loopback port.
- Public service read-only checks: `/livez` passed, `/healthz` returned the
  expected degraded state, and the external catalog contained only dated
  curated snapshots.

## Bottom line

If the server IP is blocked, Monetta should **stop that source, preserve the last
known record as non-current research, and switch to an approved data path**.
The immediate engineering priority is not acquiring another IP. It is making
the stop automatic and durable, making stale state visible end to end, and
fetching only a reviewed selection once the source permits access.
