# XL storefront sizing — implementation handoff

## Assignment and review ownership

You are the implementing model. Improve desktop sizing in the Monetta Shopify storefront, prioritizing collection product listings, then the homepage style and collection sections. The originating model will independently audit your implementation and rendered results. Do not mark the work approved on its behalf.

This document is a plan; no implementation has been made. Preserve unrelated work. Read applicable AGENTS.md files and existing theme workflow documentation before editing. Do not publish a theme or modify production. Prepare a reviewable local implementation and preview; use remote staging writes only within the user's authorization and the repository's applicable workflow. Do not ask for approval to perform routine local work.

Workspace: `/Users/alexis_reyna/MyCode/Monetta/.claude/worktrees/home-busqueda`.

## Live baseline and findings

Inspect the actual staging site before implementation, using the existing authenticated browser session where available:

- Home: https://monetta-staging.myshopify.com/
- Carteras: https://monetta-staging.myshopify.com/collections/types?q=Cartera
- Bolsas: https://monetta-staging.myshopify.com/collections/all/bolsa
- Relojes regression: https://monetta-staging.myshopify.com/collections/types?q=Reloj

The originating model directly inspected Home, Carteras, and Bolsas in the user's Brave window. The selected preview was labeled “Monetta buscador predictivo borrador sin public...” and Draft. Do not assume the bare URL in a new browser session selects that same theme. Identify and record the preview/theme being evaluated. Never exit preview as a shortcut.

Observed in the wide desktop presentation:

1. Category banners occupy approximately 420px vertically; the first product cards begin roughly 700px down the viewport. These are visual estimates, not computed-style measurements.
2. Four narrow product cards sit beside a filter sidebar, with large outer margins. Filters currently expose availability and price.
3. Wallets have substantial empty space above and below the object inside portrait media frames. Tall bags use the same space more effectively; some smaller bags still appear much smaller than their neighbors.
4. In the first Bolsas row, “ENVÍO INMEDIATO” pushes the text, prices, buttons, and card bottoms below adjacent cards without that status.
5. Home style icons occupy a short left-aligned row. Home collection cards form a narrow centered group, separated horizontally from the section heading's left edge.

Local code explains likely constraints: a 1440px container including 48px gutters per side, a 240px sidebar plus 40px separation, four columns, and 16px horizontal grid gaps. Home collections have a separate 960px cap including additional gutters. Verify these against the selected live preview rather than treating local code as proof of deployed behavior.

## Scope and design decisions

Keep the warm palette, serif editorial headings, sans-serif commerce text, existing imagery, rounded cards, and current shopping behavior. Focus on sizing, alignment, and vertical efficiency. Do not redesign navigation, search, product detail pages, cart, or mobile layouts. Do not change catalog data, prices, product images, or merchandising order.

Apply the new treatment from 1280px upward. Preserve existing behavior below 1280px. Avoid a global width/token change that unintentionally expands every page or the Flutter app.

### Product listing: implement first

- Use a fluid listing container with a maximum outer width of **1680px including padding**, retaining **48px side gutters** at wide desktop sizes.
- Keep the filter sidebar approximately **232px**, with **32px separation** from products. Preserve its sticky behavior and visibility beneath the header.
- Use **20px column gaps** and **28–32px row gaps**.
- At **1280–1439px**, use **three product columns when the sidebar is present**. At **1440px and above**, use **four**. Keep four on ultrawide screens within the width cap. Listings without a sidebar should retain four columns at XL; do not propagate the sidebar-specific three-column rule globally.
- At 1920px this geometry should yield approximately **315px cards**, compared with roughly 254px currently. These are layout targets, not a requirement to hardcode individual card widths.
- Product names: **17px** with a readable two-line allowance. Prices: **18–19px**. Body padding: approximately **16px**. Preserve visual hierarchy and existing accessible control targets; buttons and badges need no proportional enlargement.
- Align corresponding information and button baselines within each row, including cards with/without delivery text, one/two-line titles, sale prices, and “Desde” prices. Use resilient layout structure and an intentional status slot if needed. Avoid fixed total card heights that clip content, fake visible status text, or JavaScript height measurement.

### Collection banner: improve access to products

- Scope banner changes to collection listings; do not shrink the homepage carousel or unrelated guide banners.
- Target **240–280px desktop banner height**, initially 260px. Preserve readable titles and intentional image composition.
- At the same viewport and scroll position, the first product row should begin at least **120px earlier** than baseline without hiding navigation or filters.
- Do not promise that an entire enlarged card fits above the fold at every viewport height. Balance product size and discovery using real captures.

### Media proportions: evidence-based choice

- Compare wider cards with existing **4:5 media** against **1:1 media for the Carteras collection**, retaining `object-fit: contain` in both.
- Prefer square Carteras media if it visibly reduces wasted height while preserving complete wallets, chains, and keyrings. Scope any category treatment reliably across filtering, sorting, and pagination. Retain portrait frames for bags initially and inspect watches before extending the rule.
- Do not claim a shorter frame alone enlarges the object. Widening the card supplies extra image width; source-image whitespace may still limit product prominence.
- Do not use blanket image zoom, `cover`, asset replacement, or cropping to force uniform object size. Record any remaining source-image limitation.
- Update responsive `sizes` and image width candidates to match the final slots and high-density displays. Check both the shared snippet defaults and call-site overrides. Avoid increasing image downloads for unrelated compact rails or mobile cards.

### Homepage: implement second

- Target **1120–1200px usable collection-row width**, excluding outer padding, with three cards around **350–380px** and **24–32px gaps**.
- Remove duplicated horizontal padding where it constrains the row. Align the collections heading with the left edge of the card group.
- Target a **900–1000px style row**, **96–104px icon boxes**, and **15–16px labels**. Keep the row's left edge aligned with its heading; leave intentional breathing room rather than stretching five icons across the whole viewport.
- Section titles may rise modestly to **32–34px**. Preserve the existing mobile collection carousel and style layout.

## Relevant implementation surfaces

- `storefront-theme/assets/monetta-guia.css`: guide/collection banners, homepage style and collection groups, product view buttons.
- `storefront-theme/assets/monetta-app-alignment.css`: product grid override and shared card appearance.
- `storefront-theme/sections/monetta-collection.liquid`: listing context and category identity.
- `storefront-theme/sections/monetta-guia-home.liquid`: homepage groups.
- `storefront-theme/snippets/monetta-card.liquid`: card structure and image slot defaults.
- `storefront-theme/snippets/monetta-head.liquid`: stylesheet load order.
- `docs/web-redesign/shopify-staging/README.md`: preview and validation workflow.
- `docs/web-redesign/DESIGN_SPEC.md`: document the final scoped desktop exceptions.

The theme's `monetta-tokens.css`, `monetta-base.css`, `monetta-components.css`, and `monetta-pages.css` are generated/ported. Do not hand-edit them. Prefer coherent scoped rules in the appropriate maintained layer. If a source change is necessary, update the source and regenerate through its documented workflow. Avoid repeated competing overrides and broad changes to shared `.card`, `.container`, or `.guide-hero` selectors.

## Execution and verification

1. Record git status, baseline commit, preview identity, viewport dimensions, browser zoom, and device scale. Capture Home, Carteras, and Bolsas before changing code. Inspect computed geometry where tooling permits.
2. Implement listing width/columns and banner sizing, then card alignment and media comparison. Inspect rendered results before tuning typography.
3. Implement the homepage adjustments and image delivery changes. Document final decisions, including the media comparison outcome.
4. Run appropriate existing theme validation and generated-file parity checks. `node tools/style-guideline-theme/port-css.mjs --check` is read-only; inspect prerequisites before running. Record pre-existing failures separately from new ones. Do not run deployment or catalog-mutation scripts just because they appear in a validation directory.
5. Capture matching before/after desktop views at **1280×900, 1440×900, 1536×960, and 1920×1080**. Check **2560×1440** for the width cap. Include both page-top and grid-focused views on Carteras and Bolsas.
6. Check **375×812, 768×1024, and 1024×768** for regressions, including mobile carousel behavior. Inspect breakpoint edges at 1279/1280 and 1439/1440. Use viewport resizing, not browser zoom, to test responsive behavior. Hide the Shopify preview bar consistently for comparisons.
7. Verify no horizontal overflow, clipped products, overlapping badges/actions, or obscured keyboard focus. Confirm card destinations, category navigation, sorting, filter application/removal, pagination, and quick-view opening remain correct. Do not place orders or perform persistent shopping actions to validate visual changes.

## Handoff evidence and independent audit

Provide a concise completion report with:

- Commit or exact changed-file list and a summary of implementation decisions.
- Exact local/staging preview URL and theme identity; state whether any staging upload occurred.
- Before/after screenshots labeled with page, viewport, and scroll position, stored in a dedicated artifact directory.
- Measured container/card/media/banner dimensions at 1440px and 1920px, with measurement method. Clearly label estimates.
- Check commands and results, existing failures, untested behavior, and any deviations from targets with rationale.
- The Carteras 4:5 versus square comparison and selected outcome.

The originating model will audit the diff, inspect the actual rendered preview, reproduce representative checks, and report findings by severity. Acceptance requires visibly larger products on wide desktops, earlier product discovery, aligned cards with mixed metadata, improved home scale/alignment, intact product imagery, and no new mobile or shopping-flow regressions. Passing automated checks alone is insufficient. Leave the implementation available for review; do not publish or claim independent approval.
