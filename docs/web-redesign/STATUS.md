# Monetta web redesign — task ledger

Durable record for the responsive prototype and Shopify handoff described in
[the master prompt](../prompts/MONETTA_WEB_DESIGN_CLAUDE.md). Update this file at
the end of every iteration.

## Independent audit (GPT) corrections — 2026-10-18 (iteration 3)

An independent audit ([`audit-gpt-2026-10-18/AUDITORIA_GPT.md`](audit-gpt-2026-10-18/AUDITORIA_GPT.md))
confirmed H02 and H03, found H01 incomplete and reported six open problems (GPT-01 … GPT-06);
D11 was reopened. Each problem was reproduced on a rebuilt copy of the previous tree, corrected
in place, covered by checks that fail on that copy and pass on the corrected build, and looked at
as images. **D11 is closed again** after the six corrections, the full gate and the visual review.

Per-finding tables (state, change, before/after reproduction, test and capture, remaining
limits), totals and the file map: [`correcciones-auditoria-gpt-2026-10-18/RESULTADO.md`](correcciones-auditoria-gpt-2026-10-18/RESULTADO.md).

| Finding | Status | Evidence |
| --- | --- | --- |
| GPT-01 focus hidden by the dock | ☑ Corrected | The scroll reserve is measured (`src/lib/chrome.js`: `scroll-padding-top/bottom` = real pinned bar + 16 px). Real Tab traversal at 390×844: stops with the control, text or ring hidden 6 / 10 / 6 / 21 / 6 → 0 on collection, product, bag, Home and search; ring painted on 4/4 sides and text visible on every footer stop. 12 checks |
| GPT-02 arrow fallback race | ☑ Corrected | The 500 ms fallback belongs to the click that armed it (`navigationEpoch`, `leaveScreen()` in `router.js`): Forward at 0/150/450 ms after the arrow used to end on the collection, now stays on the restored product; a product reopened at the same address, filters, direct link, reload, lost entries and paused Back/Forward checked. 6 unit + 8 browser checks |
| GPT-03 search without an accessible `h1` | ☑ Corrected | One exposed `h1` in empty, suggestions, results, no results and error at 390 and 1440 (suggestions and error had 0 and an axe `page-has-heading-one`); axe 0. 3 checks |
| GPT-04 reserve for a bar that grows | ☑ Corrected | The top reserve follows the bar: 320 px with a two-line title, bar 97.31 px, reserve 120 → 141.31 px, overlap 5.06 / 5.38 / 5.69 px → 0 (nearest, scrollIntoView, real Shift+Tab); late font, larger text, resize and navigation tracked; the desktop “Ver catálogos” anchor landed 30 px under the header, now clear. 8 checks |
| GPT-05 content covered in a short viewport | ☑ Corrected | Below 1024 px wide and 480 px high nothing stays pinned and the page's own buttons replace the purchase and checkout bars: free viewport 14–246 px → all of it at 320×200, 360×225 and 640×400 (zoom *equivalents*, not the browser's zoom) and at 667×375, 812×375 and 844×390. 11 checks |
| GPT-06 lateral insets ignored | ☑ Corrected (CDP emulation) | 667×375 with 44 px insets: first card x 0 → 44, 327.5 → 283.5 px wide; controls and text outside the safe region 1–5 per page → 0 at 667×375 and 812×375; photographs and bar backgrounds still bleed. 7 checks |
| A1 keyboard focus in horizontal scrollers (found while reproducing) | ☑ Corrected | Rail cards, chips and thumbnails left half outside the screen when focused (“Crossbodys” 280…423 of 390 px); `src/lib/scrollers.js` brings the item in. 2 checks + 8 unit tests |

## Mobile fidelity review and corrections — 2026-10-18

The original prompt and prototype were confirmed as the October 17 delivery. An
independent comparison against freshly rendered current Flutter widgets found three
medium-severity differences (H01 interior-header density and back navigation, H02
product-header actions, H03 recommendation typography and card density). Base
identity matched and the browser suite passed 112/112, which is why D11 was
reopened rather than assumed.

Evidence and findings: [mobile fidelity review](audit-2026-10-18/REVISION_FIDELIDAD_MOBILE.md)
(kept as the record of the previous state). Review/correction task:
[Claude follow-up prompt](../prompts/MONETTA_WEB_MOBILE_FIDELITY_REVIEW_CLAUDE_2026-10-18.md).

**Result: H01, H02 and H03 corrected and D11 closed** — per-finding report with
before/after numbers: [`fidelity-2026-10-18/RESULTADO.md`](fidelity-2026-10-18/RESULTADO.md).
The independent audit above reopened D11 for H01's remaining problems and it was closed again in
iteration 3.

| Finding | Status | Evidence |
| --- | --- | --- |
| H01 interior headers (collection, search, bag) | ☑ Corrected | Phone pages open with one pinned 76 px bar (back · title · actions); first product 323.6 → 140.8 px below the strip on collections (app 88; the remaining 52.8 px is the style-shortcut row), 344.4 → 206 px on search (app 221.5); card width 161.5 → 181.5 px (app); filters, sort, counts, URLs, browser Back and 48 px targets kept; tablet/desktop unchanged. 25 D11 checks + 6 unit tests |
| H02 product header | ☑ Corrected | Back + search · logo · account + bag, logo centred, 4 px insets, 48 px targets; menu no longer takes the search slot. 6 D11 checks |
| H03 recommendations | ☑ Corrected | Headings Inter 600 17 px (20/22 from tablet); rails 52vw (195 px at 375), 4:5 flush photo, two-line names, equal heights; Home's Novedades unchanged. 10 D11 checks |

## Current iteration

**Iteration 3 — 2026-10-18. Complete:** the six audit problems and the rail/chip focus defect
reproduced, fixed in the existing prototype (two new modules, router, search page, four stylesheets),
51 new D11 checks and 18 unit tests added without weakening any existing check (the 153 earlier
checks and 31 earlier tests are untouched), full gate run 2026-10-18 18:48–19:09 CST
(`npm test` **49/49**, `npm run build`, `npm run verify` **204/204**), pixel regression against the
previous build (378/384 identical; 6 differ by 1/255 in ≤ 4 pixels, the previous build shows the same
against itself), 106 review captures plus the standard (58) and fidelity (26) sets opened as images,
documents updated. Evidence folder:
[`correcciones-auditoria-gpt-2026-10-18/`](correcciones-auditoria-gpt-2026-10-18/).

**Iteration 2 — 2026-10-18. Complete:** audit read, the three findings fixed in the
existing prototype, 41 independent D11 checks and 6 unit tests added, full gate
re-run at 16:06 CST (`npm test` 31/31, `npm run build`, `npm run verify` **153/153**),
before/after captures taken at 375×812, 440×956, 768 and 1440 and inspected as
images, documents updated. Evidence folder: [`fidelity-2026-10-18/`](fidelity-2026-10-18/).

**Iteration 1 — 2026-10-17 (Claude Opus 5.5 session). Complete (historical):**
sources read, workspace created, fixtures captured, shared system and all pages
implemented, rendered and corrected in a real browser, unit and browser checks written
and passing, documents and screenshots delivered. Final gate run at 22:29 CST.

Delivery label: **prototype ready for review** (not a production implementation).

## Acceptance gates

| Gate | Status | Evidence |
| --- | --- | --- |
| D01 Runnable delivery | ☑ | Iteration 1: clean `npm ci` with Node 24.21.0. Iteration 3: `npm test` 49/49, `npm run build`, `npm run verify` 204/204 (dependencies unchanged, so `npm ci` was not repeated) — `VERIFICATION.md` § Iteration 3; `design-prototype/README.md` |
| D02 Identity | ☑ | 10/10 identity checks: renderer fonts (Playfair/Inter web fonts), five weights loaded, tokens, wordmark ratio, dock gold (re-run in iteration 2; the D11 checks also confirm that the renderer used Inter for the recommendation headings) — `fidelity-2026-10-18/evidence/verify-report.json` |
| D03 Responsive coverage | ☑ | 35/35 cells (5 pages × 375–1440) + 320 px reflow, re-run in iteration 3; plus the short viewports (320×200, 360×225, 640×400 zoom equivalents and 667×375, 812×375, 844×390 on their side) and the 44 px emulated insets (GPT-05/06 checks); captures at 320, 360, 375, 390, 440, 667, 768, 812, 1024, 1440 — `correcciones-auditoria-gpt-2026-10-18/revision-visual/` |
| D04 Complete pages | ☑ | Principal and supporting views with empty, loading and error states; no broken images; every control acts or explains its handoff |
| D05 Card and product behavior | ☑ | 6/6 journey checks (sale, sold out, sobre pedido, long names, favourites, quick-view variant, blocked storage) |
| D06 Discovery | ☑ | 8/8 journey checks (predictive, Enter, filters/sort/chips/count, Back, empty recovery, load more + scroll, failure, phone drawer) plus the H01 filter-from-the-bar and arrow checks |
| D07 Local shopping journey | ☑ | 5/5 journey checks + cart unit tests; no live cart or order |
| D08 Mobile controls | ☑ | 3/3 checks + bottom-control rule in every layout cell; the pinned bars leave focus visible at their measured size (GPT-01/04 checks) and give way in short viewports (GPT-05) |
| D09 Accessibility | ☑ | 44/44: axe 33 states with zero findings (including the new bars), keyboard, focus, dialogs, radios, reduced motion, reflow; plus, in D11, axe on the five search states at 390 and 1440 and a real Tab traversal of the five pages with the hit-tested, pixel-read focus ring |
| D10 Meaningful validation | ☑ | 49 unit tests + 204 browser checks (of the 51 new ones, 41 fail on the previous build and 10 guard behaviour that had to survive); no console/network errors |
| D11 Visual review | ☑ | Closed 2026-10-18 after being reopened by the independent audit: H01–H03 corrected and inspected against the app captures (iteration 2), then GPT-01 … GPT-06 corrected and 106 review captures + 15 contact sheets + the standard (58) and fidelity (26) sets opened as images at 320, 360, 375, 390, 440, 667×375 and 812×375 (44 px emulated insets), 768, 1024, 1440, the short viewports and the flows (filters, quick view, variants, search, account, menu, keyboard focus on the footer links); 92 D11 checks (41 fidelity + 51 audit-fix). The October 17 and iteration 2 passes remain as history. Intentional differences: `DESIGN_SPEC.md` §9 |
| D12 Implementation handoff | ☑ | `DESIGN_SPEC.md`, `IMPLEMENTATION_HANDOFF.md` (updated for the phone page bar, product header and recommendation rails) |
| D13 Scope integrity | ☑ | Only `design-prototype/` and `docs/web-redesign/` were created or edited; `audit-2026-10-18/`, `audit-gpt-2026-10-18/`, `fidelity-2026-10-18/`, `screenshots/`, `evidence/` and `docs/prompts/` untouched (no file modified after the 16:51 snapshot); `git status --short` identical at the end of iteration 3 to its start; no Shopify writes, purchases, secrets/settings edits, commits or pushes (see note on concurrent changes) |
| D14 Evidence and final delivery | ☑ | `FINAL_REPORT.md`, `correcciones-auditoria-gpt-2026-10-18/RESULTADO.md` and `VERIFICATION.md` match the final run (2026-10-18 18:48–19:09 CST); the logs of every command are in `correcciones-auditoria-gpt-2026-10-18/logs/` |

## Decisions (reversible, recorded)

1. **Data source.** Public `monetta.mx/products.json` (311 products, 20:51 CST) and
   collection memberships (21:03 CST) captured 2026-10-17, instead of the app's
   2026-10-07 bundle: the live catalog changed and carries real “sobre pedido” text
   and “Envío inmediato” tags. 86 products curated; 209 photos stored as 800 px WebP.
2. **Synthetic states.** `bolsa-guess-shoulder-vino-brillante` fully sold out;
   `cartera-guess-compacta-negro` limited to 2. Labelled in the UI and manifest.
3. **Desktop hero** is a photo panel + copy panel: the only hero photograph is
   portrait (the live site's file); a landscape crop would upscale it ~1.9×.
4. **No NUEVO badges** (67% of the live catalog would qualify).
5. **Genuine compare-at prices** and “−N%” only when `compare_at_price > price`.
6. **Shopify filter parameter names** in URLs.
7. **Beauty brands** shown as an external-catalog panel (no Shopify products).
8. **Verification browser:** installed Brave (Chromium 155) through
   `playwright-core`; Chrome not installed.
9. **No shipping threshold or progress** (the app's $1,499 constant is not a real
   rule).
10. **Category from the title noun** in fixture normalization (tag-first matching
    files “Jet Set” bags under “set”).
11. **Capture-only gallery pinning** for full-page screenshots (Chromium resets
    horizontal scrollers during full-page capture).
12. **Phone page bar lives inside `main`,** not in the global header: the `h1` stays
    the visible title (one heading, focus after navigation lands on it), the bar is
    sticky across the whole page, and the global header is hidden on those phone
    pages. Tablet and desktop keep the global header and breadcrumbs.
13. **The bar's arrow leaves the screen.** Filters and sort push history entries (so
    the browser's Back restores them); the arrow skips them and returns to the
    previous screen of the visit, or to the parent (Home; Bolsas for a style) when the
    visit began there. History state carries `idx`/`entry` to know the difference.
14. **Search icon in the collection bar.** The web has no other one-tap way into
    search from a listing (the app reaches it from Home); it costs no height.
15. **Style shortcuts stay** as one scrolling row (+52.8 px over the app's collection):
    they are the web navigation to style collections. Counts stay visible (the app
    shows them to administrators only).
16. **Listing grids are edge to edge on phones** with 12 px gaps (app
    `ProductCardSliverGrid`); other grids keep the 20 px gutter.
17. **Product-section heading role** (Inter 600; 17 phone, 20 tablet, 22 desktop) for
    “Más de {marca}”, “Vistas hace un momento” and, for coherence inside the product
    page, “Reseñas”. Playfair stays on Home's editorial sections.
18. **Recommendation rails:** tiles 52vw capped at 260 px, photo flush on white
    (`photoInset: 0`), equal heights, five across from 1200 px.
19. **Product-header account** opens the prototype's `/account` entry (the Shopify
    handoff); search opens `/search` with its field focused.
20. **Focus bug fixed:** the router moved focus to the heading right after an empty
    search had focused its field (the app's behaviour); pages can now keep focus they
    placed.
21. **Pinned chrome is measured, not assumed** (iteration 3): `src/lib/chrome.js` publishes
    `--pinned-top` / `--pinned-bottom` and `scroll-padding` is that plus 16 px, so the reserve
    follows a bar that wraps its title, a late font, larger text and the home indicator. Only
    `sticky`/`fixed` elements count; the observer uses the border box.
22. **The arrow's fallback belongs to its click:** a navigation counter (link, `popstate`, changed
    address, `pageshow` from the cache) retires it, instead of comparing addresses.
23. **One `h1` in every search state:** the bar title is the `h1` with no query or when the results
    failed; the results heading otherwise; while suggestions replace the results the bar title takes
    `role="heading"` (visually hidden from tablet up).
24. **Nothing pinned below 1024 px wide and 480 px high:** header, page bar and dock scroll with the
    page, the dock follows the footer, the purchase and checkout bars give way to the inline add
    button and the bag summary. The 1024 px limit keeps the desktop sticky columns as designed.
25. **Safe region:** `--edge-l/r = max(gutter, inset)`; text and controls stay inside, photographs and bar
    backgrounds bleed; the edge-to-edge grid starts at the inset.
26. **Keyboard focus brings its item into view in horizontal scrollers** (rails, chips, thumbnails, tablet
    category row), by snap position where the scroller snaps.
27. **Left as it was, on purpose:** a double tap on the arrow still leaves two screens (a product decision the
    audit did not raise); the cache-restore case of the fallback is covered by a unit test only.

## Files changed by this task

Iteration 1:

- `design-prototype/` (new): source, fixtures, fonts, media, scripts, checks,
  README, PROVENANCE. `node_modules/`, `dist/`, `verify/output/` are ignored by
  `design-prototype/.gitignore`.
- `docs/web-redesign/` (new): `STATUS.md`, `DESIGN_SPEC.md`,
  `IMPLEMENTATION_HANDOFF.md`, `VERIFICATION.md`, `FINAL_REPORT.md`,
  `evidence/verify-report.json`, `screenshots/` (56 JPEG + `index.json`; the October
  17 set, kept as history).

Iteration 2:

- `design-prototype/src/`: `components/page-bar.js` (new), `components/shell.js`,
  `components/ui.js`, `lib/router.js`, `main.js`, `pages/{listing,collection,search,cart,product}.js`,
  `styles/components.css`, `styles/pages.css`.
- `design-prototype/tests/unit/navigation.test.mjs` (new), `verify/check-fidelity.mjs`
  and `verify/capture-fidelity.mjs` (new), `verify/run-all.mjs`, `verify/capture.mjs`
  (+2 captures), `package.json` (`capture:fidelity`), `README.md`.
- `docs/web-redesign/`: this ledger, `DESIGN_SPEC.md`, `VERIFICATION.md`,
  `IMPLEMENTATION_HANDOFF.md`, `FINAL_REPORT.md`, and the new
  [`fidelity-2026-10-18/`](fidelity-2026-10-18/) (`RESULTADO.md`, `comparacion.html`,
  `web/` 26 captures + `metrics.json`, `screenshots/` 58 captures + `index.json`,
  `evidence/verify-report.json`).
- **Not touched:** `audit-2026-10-18/` (state before the corrections),
  `docs/prompts/` (including the October 17 prompt), Flutter, backend, `.claude/`.

Iteration 3:

- `design-prototype/src/`: `lib/chrome.js`, `lib/scrollers.js` (new); `lib/router.js`, `main.js`,
  `pages/search.js`, `styles/{tokens,base,components,pages}.css`.
- `design-prototype/tests/unit/chrome.test.mjs` (new), `tests/unit/navigation.test.mjs` (+6 tests),
  `verify/check-audit-fixes.mjs` and `verify/probes.mjs` (new), `verify/run-all.mjs` (`--only=fixes`),
  `verify/capture-fidelity.mjs` (the comparator it writes links to the audit folder relative to `--out`; identical
  output for the default folder), `README.md`. The earlier checks, `capture.mjs`, `package.json` and the dependencies
  are unchanged.
- `docs/web-redesign/`: this ledger, `DESIGN_SPEC.md`, `VERIFICATION.md`, `IMPLEMENTATION_HANDOFF.md`,
  `FINAL_REPORT.md`, and the new
  [`correcciones-auditoria-gpt-2026-10-18/`](correcciones-auditoria-gpt-2026-10-18/) (`RESULTADO.md`, `antes/`,
  `despues/`, `revision-visual/`, `capturas-estandar/`, `capturas-fidelidad/`, `comparacion-pixeles/`, `evidence/`,
  `logs/`, the three scripts and the hashed snapshot of the previous tree).
- **Not touched:** `audit-2026-10-18/`, `audit-gpt-2026-10-18/`, `fidelity-2026-10-18/`, `screenshots/`,
  `evidence/`, `docs/prompts/` (including the October 17 prompt), Flutter, backend, `.claude/`.

**Concurrent changes not made by this task:** ten tracked app files
(`Makefile`, `config/README.md`, five `lib/` files, three `test/` files) were modified
by other sessions on 2026-10-17 and were still modified, unchanged by this task, when
iteration 2 started (`git status --short` identical). They were left untouched.

## Unresolved issues

- Disk space on the machine was low (~0.17–1.1 GB free); screenshots are JPEG.
- Not verified: real devices, Safari/Firefox, screen readers, Shopify behaviours,
  performance (see `VERIFICATION.md` § Not verified).
- Other interior views on phones (Favoritos, Cuenta, Mayoreo, Historia, Contacto,
  políticas, 404) still use the global phone header. The app gives every interior
  page the same header; `pageBar` makes the extension mechanical, but it was outside
  H01–H03.
- The October 17 `screenshots/` set is stale for the changed phone views; the current
  set is in `fidelity-2026-10-18/screenshots/`.
- The screen-level back arrow assumes a single-page router; a multi-page Shopify theme
  needs its own implementation (`IMPLEMENTATION_HANDOFF.md` §4, §11).
- Iteration 3 was measured in Chromium 155 only. The side insets are Chromium's emulation (44 px, not a real
  notch); 320×200, 360×225 and 640×400 are CSS-pixel equivalents of 400 % / 200 % zoom, not the browser's zoom
  control; no Safari, Firefox, physical device or screen reader. A control taller than the space the pinned bars
  leave (a one-column product card at 320×568) cannot show both edges. A double tap on the arrow still leaves two
  screens.
- Business confirmations listed in `FINAL_REPORT.md` § Remaining limitations.

## Next action

Review `correcciones-auditoria-gpt-2026-10-18/RESULTADO.md` (and its contact sheets in
`revision-visual/hojas/`) and `fidelity-2026-10-18/comparacion.html`. If the review accepts the intentional
differences (style-shortcut row, visible counts, search icon in the collection bar), extend the page bar to the
remaining interior views, run the audit-fix checks on a real device (notch, browser zoom) and start production work
with the theme baseline described in `IMPLEMENTATION_HANDOFF.md` §1, porting `verify/check-audit-fixes.mjs`
(`IMPLEMENTATION_HANDOFF.md` §4 “Pinned chrome, short viewports and the safe region”, §10).
