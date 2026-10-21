# Monetta web redesign — final report

**Status: prototype ready for review.** This is a responsive design prototype with
local demo data and a Shopify implementation handoff. It is **not** a production
implementation: no theme was built or uploaded, nothing was published, and no
Shopify data, order, payment or message was created.

**Update — 2026-10-18 (iteration 2).** A review against the current app found three
phone differences (interior headers, product header, recommendations). They were
corrected and D11 was closed again: see
[`fidelity-2026-10-18/RESULTADO.md`](fidelity-2026-10-18/RESULTADO.md) (before/after
numbers per finding), [`STATUS.md`](STATUS.md) and `VERIFICATION.md` § Iteration 2.


**Update — 2026-10-18 (iteration 3).** An independent audit found six open problems
(focus hidden by the dock, a race in the back arrow's fallback, no accessible `h1` in some
search states, a scroll reserve that did not follow a growing bar, content covered in short
viewports, side insets ignored). All six were reproduced on a rebuilt copy of the previous tree,
corrected, covered by 51 new checks that fail there (10/51 pass) and pass on the corrected build
(51/51), and reviewed as images; D11 is closed again. Per-finding tables with before/after
numbers: [`correcciones-auditoria-gpt-2026-10-18/RESULTADO.md`](correcciones-auditoria-gpt-2026-10-18/RESULTADO.md);
`VERIFICATION.md` § Iteration 3. Counts below are the current ones (49 unit tests, 204 browser
checks); the earlier figures (25 and 112; 31 and 153) are kept in `VERIFICATION.md`.

## Launch

```bash
cd design-prototype
npm ci            # Node 24
npm run dev       # http://localhost:5173
```

Or build and preview: `npm run build && npm run preview` (http://localhost:4173).
Checks: `npm test` and `npm run verify` (needs an already-installed Chromium-based
browser; set `BROWSER_PATH` if it is not Chrome, Brave, Edge or Chromium in the
usual location). Screenshots: `npm run capture`; the app · before · after set:
`npm run capture:fidelity`.

Suggested review path: open the prototype on a phone-sized window and on a
desktop window, then use **“Detalles”** in the prototype strip for the guided list
of states (sale, sold-out variants, sobre pedido, envío inmediato, inventory
limit, combined filters, no results) and the failure switches.

## What was delivered

| Artifact | Path |
| --- | --- |
| Prototype (Vite, HTML/CSS/JS) | [`design-prototype/`](../../design-prototype/) — README with commands, routes and demo-state instructions |
| Asset and data provenance | [`design-prototype/PROVENANCE.md`](../../design-prototype/PROVENANCE.md), [`fixtures/manifest.json`](../../design-prototype/fixtures/manifest.json) |
| Behaviour checks | `design-prototype/tests/unit/` (49 tests), `design-prototype/verify/` (204 browser checks: 41 phone-fidelity checks of iteration 2 and 51 audit-fix checks of iteration 3 in `check-audit-fixes.mjs`) |
| Design specification | [`DESIGN_SPEC.md`](DESIGN_SPEC.md) |
| Shopify implementation handoff | [`IMPLEMENTATION_HANDOFF.md`](IMPLEMENTATION_HANDOFF.md) |
| Verification record | [`VERIFICATION.md`](VERIFICATION.md), current [`correcciones-auditoria-gpt-2026-10-18/evidence/verify-report.json`](correcciones-auditoria-gpt-2026-10-18/evidence/verify-report.json) and the logs of every command in [`correcciones-auditoria-gpt-2026-10-18/logs/`](correcciones-auditoria-gpt-2026-10-18/logs/) (iteration 2: [`fidelity-2026-10-18/evidence/verify-report.json`](fidelity-2026-10-18/evidence/verify-report.json); iteration 1: [`evidence/verify-report.json`](evidence/verify-report.json)) |
| Screenshots | Current (iteration 3, `--out` explicit): 58 in [`correcciones-auditoria-gpt-2026-10-18/capturas-estandar/`](correcciones-auditoria-gpt-2026-10-18/capturas-estandar/), 26 side-by-side in [`capturas-fidelidad/`](correcciones-auditoria-gpt-2026-10-18/capturas-fidelidad/) and 106 review captures (320 → 1440, phones on their side with emulated insets, short viewports, flows) with 15 contact sheets in [`revision-visual/`](correcciones-auditoria-gpt-2026-10-18/revision-visual/). Iteration 2 set (history): 58 in [`fidelity-2026-10-18/screenshots/`](fidelity-2026-10-18/screenshots/) and 26 in [`fidelity-2026-10-18/web/`](fidelity-2026-10-18/web/) with [`comparacion.html`](fidelity-2026-10-18/comparacion.html). October 17 set (56, history): [`screenshots/`](screenshots/) |
| Fidelity review result | [`fidelity-2026-10-18/RESULTADO.md`](fidelity-2026-10-18/RESULTADO.md); the audit it answers: [`audit-2026-10-18/`](audit-2026-10-18/REVISION_FIDELIDAD_MOBILE.md) |
| Audit corrections result | [`correcciones-auditoria-gpt-2026-10-18/RESULTADO.md`](correcciones-auditoria-gpt-2026-10-18/RESULTADO.md) (a table per GPT-01 … GPT-06); the audit it answers: [`audit-gpt-2026-10-18/`](audit-gpt-2026-10-18/AUDITORIA_GPT.md) |
| Task ledger | [`STATUS.md`](STATUS.md) |

### Prototype scope

- **Home:** photo + search (phone) / photo + copy panel (tablet, desktop),
  Novedades, Compra por estilo, Colecciones, Selección Monetta, Marcas with an
  external beauty catalog panel, Más sobre Monetta with the wholesale entry,
  Nuestras redes, Experiencias de clientes (labelled samples), footer.
- **Collections and brands:** shared cards, breadcrumbs, title and count,
  shortcuts, sort, active chips, sidebar from 1200 px and drawer below, load more,
  empty recovery; Shopify filter URLs; Back restores state and scroll. On phones the
  title row is the app's pinned page bar (back · title and count · search · filters)
  and the grid runs edge to edge.
- **Product:** gallery with thumbnails, brand, name, price with genuine
  compare-at, variant chips/swatches with sold-out options, availability (in
  stock, envío inmediato, sobre pedido, sold out), quantity, add to cart with
  pending/error states, Comprar ahora, WhatsApp apartado (no reservation),
  service facts, accordions, Loox slot, recommendations, recently viewed. On phones
  the header is back + search · logo · account + bag (the app's), and the
  recommendation rails use the app's anatomy (52vw tiles, 4:5 photo, two-line names).
- **Search:** suggestions, predictive results, loading skeleton, recoverable
  errors, full results with filters, no-results recovery, query in the URL.
- **Cart:** drawer, phone “En tu bolsa” sheet, full page, exact variants, quantity,
  removal with undo, inventory limit, subtotal and estimated total in MXN,
  checkout handoff explaining Shopify Checkout.
- **Supporting:** guest favourites (device-only, storage-blocked and unavailable
  states), Mayoreo, Nuestra historia, Contacto, account entry (Shopify customer
  accounts handoff), menu drawer, policies, 404.

## Evidence summary

- `npm test` (49/49), `npm run build` and `npm run verify` (**204/204**, run
  2026-10-18 18:48–19:09 CST) pass with Node 24.21.0 in Brave/Chromium 155; a clean
  `npm ci` was run in iteration 1 and not repeated (dependencies unchanged).
- Audit corrections: 51 checks run a real browser (Tab and the painted stacking, the history stack, the
  accessibility tree and axe, the geometry of the pinned bars, the safe region) and pass 10/51 on the previous
  tree and 51/51 on this one; Tab traversal of the five pages at 390×844 went from 6 / 10 / 6 / 21 / 6 hidden
  stops to 0; a two-line title bar at 320 px no longer leaves 5 px of a focused link under it; the free viewport
  at 320×200 went from 14–46 px to all 200; with 44 px emulated insets the first card moved from x = 0 to 44;
  pixel regression 378/384 identical (the other 6 differ by 1/255 in ≤ 4 pixels, as the previous build does
  against itself).
- Fidelity with the app: 41 checks read facts from the Flutter source (controls and
  their order, type roles, tile width/ratio/lines, chrome above the first product) and
  fail when the old behaviour is reintroduced (shown by deliberate reversions). First
  product on a phone collection: 323.6 → 140.8 px below the strip (app 88).
- Fonts: the renderer reports Playfair Display and Inter web fonts for headings,
  card text, navigation and buttons; all five weights load.
- 5 principal pages × 7 widths (375–1440) with no horizontal scrolling and the
  right bottom control; 320 px reflow passes.
- 33 accessibility states with zero axe findings; keyboard, focus, dialog and
  reduced-motion checks pass.
- No console errors or failed requests during the checks.

## Acceptance gates

| Gate | Result | Evidence |
| --- | --- | --- |
| D01 Runnable delivery | Pass | Clean `npm ci` → `npm test` → `npm run build` → `npm run verify` from `design-prototype/` (VERIFICATION “Commands”); README commands; no root scripts or secrets changed |
| D02 Identity | Pass | 10/10 identity checks (fonts in use, tokens, wordmark, dock gold); captures |
| D03 Responsive coverage | Pass | 35/35 layout cells + 5 reflow checks; phone/tablet/desktop captures of all five pages; 1024/1280/375 extras |
| D04 Complete pages | Pass | All principal and supporting views with empty/loading/error states (captures); no broken images (layout checks), no lorem ipsum; every control acts or explains a handoff |
| D05 Cards and product behaviour | Pass | 6/6 checks (sale, sold out, sobre pedido, long names, favourites, quick-view variant continuity, storage blocked) |
| D06 Discovery | Pass | 8/8 checks (predictive, Enter, filters + sort + chips + count, Back, empty recovery, load more + Back scroll, suggestion failure, phone drawer) |
| D07 Local shopping journey | Pass | 5/5 checks (double click → 1 unit, quantity/removal/undo, checkout handoff, empty recovery, failure feedback); unit tests for cart math |
| D08 Mobile controls | Pass | 3/3 checks + layout cells (single bottom control, purchase dock, checkout bar, dock hidden while typing, inert page under sheets) |
| D09 Accessibility | Pass | 44/44 (axe 33 states, keyboard, focus, dialogs, radios, reduced motion, reflow) |
| D10 Meaningful validation | Pass | 49 unit tests + 204 browser checks (of the 51 new ones, 41 fail on the previous tree and 10 guard behaviour that had to survive); console/network check clean |
| D11 Visual review | Pass | Iteration 1: correction and confirmation passes. Iteration 2 (2026-10-18): H01–H03 corrected, captures inspected against the app at 375×812 and 440×956 and at 768/1440, 41 fidelity checks — `fidelity-2026-10-18/RESULTADO.md`. Reopened by the independent audit and closed again in iteration 3 (2026-10-18): GPT-01 … GPT-06 corrected, 106 review captures, contact sheets and the standard and fidelity sets opened as images at 320 → 1440, on their side with emulated insets and in short viewports; 92 D11 checks — `correcciones-auditoria-gpt-2026-10-18/RESULTADO.md`, `VERIFICATION.md` |
| D12 Implementation handoff | Pass | `DESIGN_SPEC.md`, `IMPLEMENTATION_HANDOFF.md` (templates, settings, assets, data, URLs, Loox/Labeler, checkout/account limits, items to verify) |
| D13 Scope integrity | Pass for this task | Only `design-prototype/` and `docs/web-redesign/` were created or edited; the earlier evidence sets and `docs/prompts/` untouched; `git status --short` identical at the end of iteration 3 to its start. No Shopify writes, purchases, secrets/settings changes, commits or pushes. See the note below about concurrent changes by another process |
| D14 Evidence and delivery | Pass | This report, `STATUS.md`, `VERIFICATION.md` and the evidence files match the final run |

## Note on other changes in the working tree

During this session, ten tracked app files changed at 21:25–21:26 CST
(`Makefile`, `config/README.md`, `lib/app/runtime_config.dart`,
`lib/app/shopify_checkout_coordinator.dart`, `lib/data/shopify/storefront_config.dart`,
`lib/main.dart`, `lib/tooling/dart_defines_validation.dart` and three tests).
Other agent sessions (Codex and OpenCode) were running in the same checkout at the
time. This task never edited those paths and did not touch or revert them. The
untracked files present at the start (`artifacts/`, `docs/MONETTA_WEB_*.md`,
`docs/prompts/`, `test/goldens/failures/`) are also unchanged by this task.

## Remaining limitations

- Demo data is the 2026-10-17 public snapshot (86 of 311 products); two demo states
  are synthetic and labelled.
- The desktop hero uses the only available hero photograph (portrait); a dedicated
  landscape image is recommended before launch.
- Phone interior views other than collections, search and bag (favourites, account,
  Mayoreo, story, contact, policies, 404) still use the global phone header; the app
  uses its page header on all of them.
- Differences from the app that remain by design are listed in `DESIGN_SPEC.md` §9
  (style-shortcut row, visible counts, hearts and genuine discounts on cards, search
  icon in the collection bar).
- Not checked on real iOS/Android devices, Safari, Firefox or with screen readers. The side insets used for
  GPT-06 are Chromium's emulation (44 px), and 320×200, 360×225 and 640×400 are CSS-pixel equivalents of 400 % and
  200 % zoom, not the browser's zoom control.
- A double tap on the screen arrow still leaves two screens, and a control taller than the space between the pinned
  bars (a one-column product card at 320×568) cannot show both edges; the first is a product decision, the second a
  limit of the viewport.
- No performance measurement; the prototype is client-rendered and bundles its
  catalog, unlike the server-rendered theme.
- Shopify behaviours (cart API errors, wholesale discounts, Search & Discovery,
  Loox, Labeler, checkout/account branding, plan features) are specified, not
  exercised — listed in `IMPLEMENTATION_HANDOFF.md` §11.
- Business confirmations needed: deposit amounts and apartado terms, external
  catalog URLs, story page handle, badge precedence (sale vs. Labeler), web cart
  attribution.

## Prototype ready for review vs. production ready

**Prototype ready for review (now):** the design, interactions and states can be
reviewed in a browser, and an engineer has the specification to build them.

**Production implementation ready (not yet):** requires the Atelier-based theme in
`storefront-theme/`, metafield/filter configuration, Loox/Labeler integration,
checkout/account branding, an unpublished preview theme, device and commerce
testing against the real store, and performance measurement — the milestones in
the redesign plan.
