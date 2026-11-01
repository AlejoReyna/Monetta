# XL storefront sizing — review handoff

Implemented in `/Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/home-busqueda`, based on commit `231cc8c66ca4b45f95c1935c4f81fee67af57380`. No commit made. Initial status contained only the untracked `docs/web-redesign/XL_STOREFRONT_HANDOFF_2026-10-29.md`, which is preserved. No applicable `AGENTS.md` was found in the worktree or its ancestors. Read the staging README, delivery notes, guarded upload/dev scripts, CSS port instructions and design specification before editing.

Implementation is available for **independent review; approval is pending**.

**Preview and staging writes.** [Local preview](http://127.0.0.1:9292/) remains running, serving this worktree through Shopify CLI. [Explicit staging preview](https://monetta-staging.myshopify.com/?preview_theme_id=192576585762&pb=0) selects theme **192576585762**, **Monetta buscador predictivo borrador sin public...**, role **unpublished**. The authenticated Brave session showed the matching name and Draft before implementation. CLI confirmed the role before development and again afterward ([identity](theme-identity.json)). Never exited preview.

Staging upload **did occur** through `shopify theme dev`, restricted to six allowed paths: the five modified theme files below plus unchanged `sections/monetta-guia-home.liquid`. The explicit theme path is this worktree; `THEME.env` still points to another worktree and was not edited or used blindly. No theme was published, no production theme was written, and no catalog content was changed. A final read-only theme pull matches all six local files byte for byte ([comparison](remote-match.json)).

| Changed file | Decision |
| --- | --- |
| `storefront-theme/assets/monetta-app-alignment.css` | Collection-only XL container, sidebar, grid, flexible card stretch, optional metadata slots, 17px names, 19px prices, 16px body padding. |
| `storefront-theme/assets/monetta-guia.css` | Collection banners at 260px; slightly less empty heading reserve; larger, aligned home styles and collection cards from 1280px. |
| `storefront-theme/sections/monetta-collection.liquid` | Contextual image slot sizes, XL candidates, category identity, and automatic type/vendor query preservation in forms. |
| `storefront-theme/snippets/monetta-card.liquid` | Empty, aria-hidden status/brand slots; XL-only picture source. Existing default image candidates remain for smaller screens and rails. |
| `storefront-theme/snippets/monetta-results.liquid` | Pass collection-specific card/image arguments; search retains its defaults. |
| `docs/web-redesign/DESIGN_SPEC.md` | Scoped desktop exceptions in §9a, including the media decision. |

Generated CSS, global tokens, the Flutter app and homepage Liquid structure were not edited. Exact changed-file hashes, branch and worktree are in [implementation.json](implementation.json).

**Measured geometry.** Values below are CSS pixels from `getBoundingClientRect()` and computed styles in the actual authenticated Shopify preview proxy, at page-top scrollY=0 after fonts/images decode. They are measured, not visual estimates. Carteras, Bolsas and Relojes share these dimensions. “Media” is the inset frame. Container width includes 48px padding on each side.

| Viewport | Container before → after | Card before → after | Media before → after | Banner before → after | First card document y before → after |
| --- | --- | --- | --- | --- | --- |
| 1440×900 | 1440 → 1440 | 254 → 255 | 238×297.5 → 239×298.75 | 420 → 260 | 698 → 526 |
| 1920×1080 | 1440 → 1680 | 254 → 315 | 238×297.5 → 299×373.75 | 420 → 260 | 698 → 526 |

The final sidebar border box is **232px**, separation **32px**, grid gaps **20px / 30px**. At 1280px the three cards are **293.33px** wide and discovery advances **128.47px**. At 1536px cards are **279px**. At 2560px the container remains **1680px** and cards **315px**. Four columns at 1440px yield only a 1px card-width increase there; the larger gains appear at 1280–1439 and wider desktops, as the requested geometry implies. Rows grow with content and align names, price starts, pills and bottoms; there is no fixed total card height or height-measuring JavaScript.

Home at both 1440px and 1920px: collection row **1168px usable**, cards **370.66–370.67px**, gaps **28px**; heading and cards share x=136 / x=376 respectively. Styles: **960px** row, **104px** icons, **16px** labels, aligned with their heading. Both section titles are **34px**. Raw geometry: [before](measurements-before.json), [after](measurements-after.json).

**Carteras media comparison.** Selected **4:5**, retaining `contain` for Carteras, bags and watches. Compared the same 315px cards at 1920×1080 with only the media/actions aspect ratio changed: [portrait first row](media-comparison/carteras-1920x1080-portrait-y350.png), [square first row](media-comparison/carteras-1920x1080-square-y350.png), [portrait chains/keyring](media-comparison/carteras-1920x1080-portrait-y850.png), [square chains/keyring](media-comparison/carteras-1920x1080-square-y850.png).

Square reduces the frame from 373.75px to 299px high and preserves the complete image, but also shrinks these portrait source bitmaps by 20%. For the first source, 1054×1492, the rendered bitmap is approximately 264×373.75 in portrait and 211×299 in square; the old bitmap was approximately 210×297.5. Thus square gives up nearly all the visible wallet enlargement. Portrait retains about a 25.6% linear image-size increase at 1920px. These calculations describe the full source bitmap, not a detected product boundary. Whitespace within source photographs still limits some wallets and smaller bags; there is no crop, zoom or replacement. [Source dimensions](carteras-source-dimensions.json).

**Captures and visual review.** [Listings comparison](compare-listings-1920.png), [Home comparison](compare-home-1440.png), [breakpoint comparison](compare-breakpoints.png), [smaller-screen comparison](compare-mobile.png), and [complete screenshot gallery](gallery.html). Originals are in [before/](before/) and [after/](after/): **76 captures per phase**. Names encode page, viewport, view and exact scrollY. All three primary pages were captured at **1280×900, 1440×900, 1536×960, 1920×1080, 2560×1440, 375×812, 768×1024, 1024×768, 1279×900 and 1439×900**. Relojes was captured at 375×812, 1440×900 and 1920×1080. Collection pages include page-top and grid scrollY=350; Home includes page-top, styles and collections using identical before/after scroll offsets ([offsets](scrolls.json)).

Controlled captures used installed Brave via Playwright, viewport resizing, **100% zoom / visualViewport.scale=1**, **DPR=1** and reduced motion for stable captures. Separate fresh contexts tested DPR2 XL and DPR3 mobile image delivery. The existing native Brave window supplied supplementary baseline/final visual inspection; its zoom/device scale were not used for measurements. Preview bar was consistently hidden with `pb=0`; the capture harness also hides its iframe without exiting preview. Before editing, all six sampled staging files matched local files exactly.

Visual inspection covered the comparison sheets, full-size listing grids and top banners, Home modules, breakpoint transitions, mobile cards/carousel, and watch imagery. Enlarged portrait cards do not fit entirely above the fold at every page-top viewport; grid-focused captures show the complete first row. Original 2560px Home measurement briefly counted responsive image requests still loading after resize; rechecked with the exact original CSS snapshots and full decode before capture ([method](baseline-ultrawide-recheck.json), [initial evidence](measurements-before-initial.json)). Final capture waits for decode at each viewport.

**Commands and results.** Commands ran from this worktree; browser scripts use already-installed dependencies via `NODE_PATH=/Users/alexis_reyna/MyCode/Monetta/design-prototype/node_modules`.

| Check | Result |
| --- | --- |
| `node artifacts/xl-storefront-2026-10-29/capture.mjs before` / `after` | Matching captures and computed geometry; all final captures have zero horizontal overflow and no broken images. `before` was run before edits; do not rerun it against the final draft. |
| `node artifacts/xl-storefront-2026-10-29/verify.mjs` | **233/233 pass**: requested geometry, breakpoint columns, unchanged geometry below 1280, mixed metadata rows, sort/filter/remove, pagination, destinations, navigation, sticky sidebar, keyboard focus, watch quick view, mobile carousel, density candidates, compact rail ceiling, zero cart requests and no page JS errors. [Results](verification.json). |
| `node artifacts/xl-storefront-2026-10-29/extra-checks.mjs` | **8/8 pass**: baseline ultrawide decode, mobile image ceiling, mobile drawer sort/filter/clear-all URL and removal, tagged Bolsas pagination, Coach vendor context. [Results](extra-checks.json). |
| `shopify theme check --path storefront-theme --output json` before/after | Exit 1 both times, **187 errors / 64 warnings inherited**. Complete findings JSON is identical; **zero introduced findings**. [Comparison](theme-check-result.json). |
| Existing `theme-check-compare.mjs --out=...` | Could not complete because the worktree lacks its historical `baseline/theme-check-baseline.json`. Used the saved immediate pre-edit run for exact finding-by-finding comparison instead. [Diagnostic](theme-check-compare.log). |
| `node tools/style-guideline-theme/port-css.mjs --check` | Pass: all four generated theme files match a fresh port. [Output](parity.txt). |
| `node design-system/build.mjs --check` | Pass: generated tokens current and all 22 contrast pairs pass. [Output](tokens-check.txt). |
| `git diff --check` | Pass. |
| Read-only final theme pull | Six allowed paths match locally; role remains unpublished. |

The initial interaction run exposed the inherited missing `q` bug: sort form action named `?q=Cartera` but supplied no hidden query, and the existing handler rebuilt the URL without it. Passing the automatic collection title into the existing forms fixes sort/filter/pagination identity, including mobile and vendor listings. The sorted “Limpiar todo” URL also now joins its query with `&` when a product type/vendor query is already present. This behavior correction applies below 1280 too. [Initial run](verification-initial.json). The “Desde”/very long price row is a clearly labeled **DOM-only synthetic stress check**, with no catalog writes ([capture](synthetic-mixed-metadata-1920x1080.png)); production status text is never fabricated.

**Limits.** Browser validation used Brave/Chromium, not Safari or Firefox, and viewport emulation rather than physical devices. The no-sidebar four-column rule was checked by removing the sidebar class in the DOM because staging's populated collections expose filters. Quick view opening/closing was tested; orders, checkout, cart mutations, persistent favorites and purchases were not exercised. Proxy-only Shopify telemetry CORS/CSP diagnostics were observed; no application JavaScript exceptions occurred. This implementation has not been independently audited or approved.
