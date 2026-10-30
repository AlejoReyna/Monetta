# Monetta web — responsive design prototype

Interactive prototype of the monetta.mx redesign: home, collections and brands,
product, search and cart, plus favourites, Mayoreo, story, contact and the account
entry. It translates the current iOS/Android app (boutique tokens, Inter and
Playfair Display, the real wordmark and photography) to phone, tablet and desktop.

**It is a design prototype, not the store.** Products are a dated snapshot of the
public catalog. Cart, favourites and searches live only in this browser. Checkout,
sign-in, WhatsApp, social networks and external catalogs open an explanation of the
Shopify handoff instead of the real destination. Nothing is bought, reserved or sent.

The migration plan is in [`docs/MONETTA_STYLE_GUIDELINE_MIGRATION_PLAN.md`](../docs/MONETTA_STYLE_GUIDELINE_MIGRATION_PLAN.md). Heavy web audit evidence is excluded from this PR.

## Requirements

- Node 24 (checked with 24.21.0) and npm 11.
- For `verify` and `capture` only: a Chromium-based browser that is **already
  installed** (Chrome, Brave, Edge or Chromium). The scripts use `playwright-core`,
  which never downloads a browser. Set `BROWSER_PATH` to pick one explicitly.

## Commands

Run everything from this directory.

| Task | Command | Result |
| --- | --- | --- |
| Clean install | `npm ci` | Installs Vite 6.4.3, playwright-core 1.63.0 and axe-core 4.13.0 locally. |
| Start (development) | `npm run dev` | http://localhost:5173 |
| Build | `npm run build` | Static site in `dist/` |
| Preview the build | `npm run preview` | http://localhost:4173 |
| Unit checks | `npm test` | Money, cart, filters/URL state, search, fixtures, screen-level back navigation and the arrow's fallback, the pinned-chrome reserve and focus scrolling of horizontal scrollers, including the end padding a faded row needs (`node --test`). |
| Browser checks | `npm run verify` | Builds, serves `dist/`, runs identity, 7-width layout, journeys, axe, phone-fidelity, audit-fix and reaudit-fix checks; writes `verify/output/verify-report.json`. Exit code 1 on any failure. |
| Screenshots | `npm run capture` | Builds, serves and writes JPEG captures to `../docs/web-redesign/screenshots/` (the October 17 set). Pass `-- --out=<folder>` to write a new set instead: the run replaces the `.jpg` files of its output folder. |
| Fidelity captures | `npm run capture:fidelity` | Builds, serves and writes the review's side-by-side set (375×812, 440×956, 768, 1440), `metrics.json` and `comparacion.html` to `../docs/web-redesign/fidelity-2026-10-18/`. Reads, never writes, `audit-2026-10-18/`. |
| Rebuild fixtures | `npm run fixtures` | Regenerates `src/data/catalog.json` and `fixtures/manifest.json` from the committed snapshot. Add `-- --download` to fetch missing photos (network). |

Useful flags: `npm run verify -- --skip-build`, `npm run verify -- --only=journeys`
(`identity`, `layout`, `journeys`, `a11y`, `fidelity`, `fixes`, `reaudit`), `npm run capture -- --only=product`.
`node verify/check-audit-fixes.mjs --url=<served build>` and `node verify/check-reaudit-fixes.mjs --url=<served build>`
run the audit-fix and reaudit-fix checks alone against any served build (that is how they were shown to fail on
the build before each correction); the second takes `--grep=RE-02` to run only the checks whose name contains it.
Both capture commands take an explicit `--out`: their defaults point at evidence sets that are kept.
`--skip-build` reuses `dist/`: rebuild after editing sources, or the checks run
against the previous build. `fetch` refuses some ports (4045, 4190, …): keep
`--port` to an ordinary one (the defaults are fine).

If npm cannot write its default cache (seen in sandboxed shells), prefix the
command with `npm_config_cache="$TMPDIR/npm-cache"`. npm 11 may report that
esbuild's install script is not in `allowScripts`; Vite still builds, because the
platform binary ships as an optional dependency.

## Routes

Paths mirror the Shopify storefront so links and filters map onto the theme.

| Route | View |
| --- | --- |
| `/` | Home |
| `/collections/all` | Full catalog (`?sort_by=created-descending` is “Novedades”) |
| `/collections/guess` | Bolsas (the live bags handle) |
| `/collections/totes`, `/collections/crossbodys`, `/collections/hombro` | Bag styles |
| `/collections/carteras-1`, `/collections/carteras` | Carteras (both live handles) |
| `/collections/relojes`, `/collections/relojes-1` | Relojes (both live handles) |
| `/collections/coach`, `/collections/michael-kors`, `/collections/guess-1`, `/collections/steve-madden`, `/collections/tommy-hilfiger` | Brand pages |
| `/products/{handle}?variant={id}` | Product with the selected variant |
| `/search?q={query}&type=product` | Search results (filters and sort apply here too) |
| `/cart` | Mi bolsa |
| `/pages/favoritos` | Guest favourites |
| `/pages/mayoreo` | Vende con Monetta |
| `/pages/nuestra-historia` | Story (handle to be confirmed for production) |
| `/pages/contact` | Contact and FAQ |
| `/account` | Account entry (Shopify customer accounts handoff) |
| `/policies/{handle}` | Policy summaries (Shopify-hosted in production) |

Filters use Shopify's parameter names, for example
`/collections/guess?filter.p.m.custom.estilo=Satchel&filter.p.m.custom.marca=Guess&filter.v.price.lte=2000&sort_by=price-ascending`.

## Demo state

- **Prototype strip → “Detalles”** opens the prototype panel: data source and date,
  storage status, switches for failure states (next add fails, slow network,
  suggestion error, results error, blocked storage), “add an unavailable favourite”,
  a reset, and a suggested tour of real states (sale, sold-out variants, sobre
  pedido, envío inmediato, inventory limit, combined filters, no results).
- Cart, favourites, recent searches and recently viewed are stored in
  `localStorage` under `monetta-proto:v1:*`; switches live in `sessionStorage`.
  “Restablecer datos de demostración” clears them. When storage is unavailable the
  prototype keeps state in memory and says so on the favourites page.
- Two states are **synthetic** and labelled on their pages: a fully sold-out bag and
  a variant with a 2-piece limit (see `PROVENANCE.md`).

## Structure

```
index.html              App shell (landmarks, live regions, font preloads)
src/main.js             Routes, global interactions, state wiring
src/lib/                Pure logic (money, cart, filters, search, facets), router, pinned-chrome measurement (chrome.js), scroller focus (scrollers.js), storage, store, icons
src/components/         Shell, page bar (phone interior header), product card, overlays, cart UI, quick view, search, filters, handoffs
src/pages/              Home, listing (collections + search), product, cart, supporting views
src/styles/             tokens.css, base.css, components.css, pages.css
src/data/               catalog.json (generated), content.js (editorial copy with sources)
public/                 Fonts (WOFF2 + OFL), media (brand, editorial, brands, products)
fixtures/               Dated public catalog snapshot, rules copy, manifest
scripts/                build-fixtures.mjs
tests/unit/             node --test suites
verify/                 Browser checks, shared probes (probes.mjs) and capture scripts
```

Provenance of every asset and data point: [`PROVENANCE.md`](PROVENANCE.md).
