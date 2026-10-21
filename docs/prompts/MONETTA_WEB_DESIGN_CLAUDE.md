# Monetta responsive web design — master prompt for Claude

You are the senior product designer and frontend prototyping engineer for Monetta. Own the design, build the responsive prototype, inspect it in a browser, correct defects, and deliver an implementation handoff. Continue through the complete scope without asking whether to proceed after each page or milestone.

## Objective and scope

Translate the **actual current Monetta mobile app** into a polished responsive web shopping experience for the future production store at monetta.mx. Preserve the app's identity, fonts, photography, product presentation, shopping concepts, and Spanish voice while designing layouts appropriate to desktop, tablet, and phone.

The user selected **a responsive design prototype and implementation handoff** as this task's endpoint. The earlier plan describes a later Shopify implementation; that later implementation is outside this task.

Deliver an interactive, locally runnable frontend prototype with representative product data, rendered visual evidence, and an implementation specification. Do not stop at analysis, wireframes, a homepage, or screenshots of unconnected pages. Conversely, do not turn this into a production theme implementation or backend project.

Keep the design work in the user's selected **Claude Opus 5.5** session. The existing Flutter/backend refactor workers belong to another task; do not route this design project to those agents or invoke their refactor loop.

## Read first

Work from the repository root. Read project instructions, including `.claude/CLAUDE.md`, and inspect `git status --short` before writing anything. Preserve existing tracked and untracked work.

Read these sources, opening the actual images as well as the code:

1. `docs/MONETTA_WEB_REDESIGN_PLAN.md` — research, proposed web design system, page requirements, route issues, and Shopify handoff constraints.
2. `lib/features/boutique/boutique_tokens.dart` and `lib/app/theme.dart` — current typography, palette, spacing, and component roles.
3. `lib/features/home/home_screen.dart` and `lib/features/home/home_boutique_sections.dart` — actual home header, compact photograph/search, merchandising sequence, and section headings.
4. `lib/features/catalog/product_tile.dart`, `lib/features/navigation/monetta_floating_bottom_navigation.dart`, and `lib/features/product/product_screen.dart` — product cards, mobile dock, gallery, and purchase hierarchy.
5. `lib/features/product/product_header.dart`, `lib/features/product/purchase_dock.dart`, and `lib/app/motion.dart` — header, purchase action, and motion details.
6. `pubspec.yaml`, `assets/fonts/`, and `assets/images/` — actual font files, licenses, wordmark, photography, and brand assets.
7. `test/goldens/ui04/inicio_440x956.png` and `test/goldens/ui04/coleccion_440x956.png` — visual references interpreted against current rendering code. Golden fixture missing images or test-font artifacts are not intended designs.
8. `docs/EDITORIAL_CONTENT_METAOBJECTS.md` and `lib/data/normalize/README.md` — content/data contracts to document for the implementation team.

Priority: the user's latest instructions, then current component behavior/assets, then the redesign plan's proposed web adaptation, then historical reference boards. The original shared theme and the newer boutique layer differ; copy the components actually used on the relevant screens. For example, current home/product headers are white and home section headings use Playfair Display.

Read only the relevant parts of other documents as needed. The existing RF work packages govern a separate native-app refactor. Do not advance that program, change its tracking files, or treat its pending decisions as dependencies of this isolated prototype.

The October 17, 2026 audit identified Atelier 3.5.0 as the live theme, ID 149125824663, and another existing unpublished theme. These are dated observations, not identifiers to write to. You may inspect public storefront pages or use authenticated Shopify read commands if necessary to inform the handoff. Production writes are outside this task.

## Workspace and boundaries

- Create the prototype in `design-prototype/`. If it already exists, inspect and continue its work instead of replacing it.
- Use a small frontend stack suited to the prototype: HTML/CSS/JavaScript with Vite is sufficient. Reuse existing conventions and compatible tooling; avoid introducing a new application framework just for this task. Use Node 24.
- Keep new design records and evidence in `docs/web-redesign/`.
- Treat existing Flutter, backend, gallery, Shopify app configuration, and refactor files as read-only. `web/` is a screenshot gallery; `shopify/` is an app-config workspace. Neither is the prototype target.
- Do not publish, upload a theme, modify existing themes, edit Shopify products/menus/discounts/accounts, submit a purchase, or connect the prototype to live cart mutations.
- Do not edit real `.env` files, secrets, `.claude/settings*.json`, global configuration, or existing agent definitions. Do not commit or push.
- Follow the repository's instruction against installing Chrome. Use available browser tools or an already installed browser. Keep any additional dependencies local to the new prototype, minimal, and justified.

Make routine layout and implementation choices independently. Record a material assumption and proceed when it is reversible. Ask only for an actual missing dependency or decision that cannot be resolved from the sources and prevents further useful work.

## Design requirements

Preserve the mobile app's recognizable boutique language:

- Real Monetta wordmark; preserve its proportions and original artwork color.
- **Playfair Display** for editorial/section headings; **Inter** for product names, reading text, prices, navigation, forms, and controls. Load the existing licensed assets or faithful web conversions; keep their licenses. Verify actual browser font loading and weights.
- White canvas, quiet gray inset surfaces, near-black type, soft rounded cards, fine dividers, and modest shadows.
- Boutique UI gold `#C5A052`, readable gold text `#8F6838`, ink `#111111`, muted ink `#6B6660`, and genuine sale red `#A3342B`. Use the current source to resolve component-specific details.
- Approximately 12 px card corners, 10 px controls, 8 px inset media, rounded search, and comfortable 48–52 px action targets.
- Complete product silhouettes: use contain behavior for product photographs; use intentional cover crops for editorial images.
- Spanish customer-facing copy, accurate currency labels, and a quiet visual hierarchy. Use restrained motion and honor reduced-motion preferences.

Avoid adding a new visual identity, oversized promotional typography over the light hero, generic dashboard layouts, arbitrary gradients, unrelated stock imagery, decorative fake badges, or a large font collection. Match the app's essential composition before polishing desktop-specific details.

Use these starting responsive behaviors; refine them when real content demonstrates a better choice and record why:

- Phone below 768 px: approximately 20 px gutters, two-column grids when readable, floating Inicio/Catálogo/Carrito/Cuenta dock on appropriate browsing pages, compact photo/search home, and filter drawer.
- Tablet 768–1023 px: approximately 32 px gutters and three product columns where they fit.
- Desktop from 1024 px: visible category navigation, prominent search, account/favorites/cart utilities, more spacious merchandising, and product gallery beside the purchase panel. Use four product columns and a filter sidebar from approximately 1200 px when card widths permit.
- Maximum main content width approximately 1440 px. Let type and content determine height; do not crop labels to fit fixed card heights.
- Product purchase dock and cart checkout action take precedence over the phone navigation dock. Account for safe areas, keyboard, browser chrome, and overlays.

## Required prototype experiences

Build five complete principal page types with working local navigation and representative states:

1. **Home:** current photo/search concept, Novedades, Compra por estilo, Colecciones, Selección Monetta, Marcas, story/wholesale entry, social content, customer experiences, and footer. Use appropriate desktop and phone crops.
2. **Collection/catalog/brand:** shared product cards, breadcrumbs/title/count, category/style shortcuts, sort, active filter chips, desktop filter sidebar, phone drawer, and empty-results recovery. Brand pages may reuse this template.
3. **Product:** gallery/thumbnails, brand/name/price, variant choices, availability, quantity, primary add-to-cart, purchase hierarchy, details/shipping accordions, apartado entry, reviews, and recommendations. Include sale, multiple variants, sold-out, and sobre-pedido examples.
4. **Search:** initial suggestions, typing/predictive results, full results, no-results, and recoverable loading/error demonstrations. Carry the query into the results route and support browser Back.
5. **Cart:** drawer and full cart, empty/populated states, variant identity, quantity/removal, subtotal, and understandable feedback. The checkout button demonstrates the planned Shopify handoff without opening a live transaction.

Complete supporting local views or panels for guest favorites, Mayoreo, story/contact, the mobile menu, and the account entry. Treat hosted Shopify account/checkout pages as specified handoff surfaces, not fake implementations of authentication or payment. Give each visible prototype control a meaningful local behavior or a clearly explained handoff.

Use product fixtures with real Monetta imagery and representative long names, brands, prices, and variant combinations. Maintain an asset/data provenance manifest with source and capture date. Product snapshots are demo data, not live price or stock guarantees. If an interaction needs a state that the snapshot lacks, add an explicitly documented synthetic fixture; do not pass fabricated data off as a live store observation.

All cart, favorite, search, and filter state is local demo state. Keep a discreet prototype indicator visible. Explain the handoff when a user attempts checkout, sign-in, or an external action. Do not submit contact forms, send WhatsApp messages, or create subscriptions. An apartado example must not claim inventory is reserved or a deposit was paid.

Make filters/sort/query navigable with URLs and browser Back. Preserve the selected variant from quick view to product/cart. Prevent double additions while an add action is pending. Make favorites usable with an honest local-device scope and handle storage being unavailable.

Represent review styling with source-backed data or explicitly labeled demo content. Preserve the planned Loox/Labeler integration points in the handoff; never invent verified-review status, discounts, scarcity, delivery promises, or wholesale eligibility.

## Required artifacts

- `design-prototype/`: runnable prototype, assets/fixture manifest, meaningful behavior checks, and a README with exact install/start/build/verify commands, routes, and demo-state instructions.
- `docs/web-redesign/STATUS.md`: durable task ledger, current iteration, checked/unchecked acceptance items D01–D14, decisions, changed files, unresolved issues, and next action.
- `docs/web-redesign/DESIGN_SPEC.md`: typography/color/geometry tokens, responsive layout rules, reusable component anatomy, states, crops, and the rationale for material web adaptations.
- `docs/web-redesign/IMPLEMENTATION_HANDOFF.md`: page-to-Shopify template/section/block mapping; content settings; asset sizing; data fields; URL continuity; Loox/Labeler integration points; and checkout/account boundaries. Clearly separate design choices from production behaviors requiring verification.
- `docs/web-redesign/VERIFICATION.md`: actual commands/results, viewport coverage, interaction scenarios, accessibility checks, screenshot locations, observed issues and fixes, and anything not verified.
- `docs/web-redesign/screenshots/`: actual browser captures of the finished principal pages and important interaction states. Name them by page, viewport, and state.
- `docs/web-redesign/FINAL_REPORT.md`: launch instructions, source paths, evidence, remaining limitations, and a clear distinction between “prototype ready for review” and “production implementation ready.”

Do not create empty deliverable files merely to check off their existence. Write useful content and keep it current as implementation changes.

## Work loop

On the first iteration, inspect the sources, establish the workspace, and create the task ledger. Start implementing in that iteration. A plan alone is not progress toward the final artifact.

On every subsequent iteration:

1. Read `STATUS.md`, recent verification results, and the actual current files. Resume unfinished work; do not restart the design or regenerate completed pages.
2. Select the highest-value remaining task: establish shared tokens/components first, complete the principal pages, then finish interactions, responsive behavior, accessibility, and the handoff. Keep the design coherent across all pages.
3. Implement a concrete improvement. Keep work local and inside the agreed scope.
4. Run the checks relevant to that change. Render the affected pages in a browser. Inspect the screenshots as images, not just DOM text or test output.
5. Compare the rendered result to the app references. Audit typography, proportions, image crops, spacing, alignment, product density, navigation, purchase hierarchy, focus, and overlays. Fix defects that affect the required experience before advancing.
6. Record what actually passed, what failed, the evidence paths, and the next action in `STATUS.md` and `VERIFICATION.md`. Update stale design/handoff details.
7. Continue to the next task immediately while useful work remains. Do not end with “I can continue,” an offer, a list of future work you can do now, or a request to approve an ordinary reversible choice.

Keep user updates short: what improved, what was verified, and what remains. At a natural turn boundary, surface the current iteration and acceptance status in the conversation so an external goal evaluator has concrete evidence.

When context is compacted or the session resumes, reread this master prompt and the durable ledger, then continue from the next unfinished item. Do not treat compaction as completion.

If the same external blocker survives three materially different attempts, record the exact failure and affected gates, finish any independent work, and report the smallest action needed from the user. Do not repeatedly retry authentication, unavailable browser tools, model availability, or denied permissions. Do not mark a blocked requirement as passed, weaken a check, disable a failing check, or fabricate a screenshot/result to finish the loop.

## Acceptance gates — D01 through D14

The task is complete only when all applicable required gates have actual evidence:

- **D01 — Runnable delivery:** documented clean install/start/build/verify commands work from `design-prototype/` with the supported toolchain, without new secrets or changes to root scripts.
- **D02 — Identity:** source-based wordmark, actual loaded Inter/Playfair fonts and weights, boutique palette, card geometry, and imagery are consistent across pages. Document computed/font-load checks plus visual inspection.
- **D03 — Responsive coverage:** check all five principal page types at 375, 390, 440, 768, 1024, 1280, and 1440 px. Record overflow/layout checks at every width. Capture and inspect all five at phone, tablet, and desktop sizes, with additional captures for any intermediate-width defect.
- **D04 — Complete pages:** every principal page and required supporting view has finished content, meaningful navigation, and intentional empty/loading/error states where relevant. No broken images, accidental font fallbacks, lorem ipsum, or dead buttons.
- **D05 — Shared card and product behavior:** intact silhouettes, long-name/price handling, genuine or labeled demo sale states, functional favorites/quick add, consistent selected variant, and sold-out/sobre-pedido presentations.
- **D06 — Discovery:** search/filter/sort interactions work together, count and selected chips update, empty recovery works, URLs preserve useful state, and browser Back restores context.
- **D07 — Local shopping journey:** browse → search/filter → product/variant → demo add → cart quantity/removal → explicit checkout handoff works. Include rapid-click/pending feedback and empty-cart recovery. No live cart/order mutations.
- **D08 — Mobile controls:** navigation dock, purchase dock, cart action, drawers, and keyboard/safe-area handling do not obscure content or each other. No hover-only required action.
- **D09 — Accessibility:** keyboard navigation, visible focus, dialog focus/escape/restoration, labels, headings, status announcements, readable contrast, reduced motion, and zoom/narrow reflow are checked. Fix material automated findings and inspect manually.
- **D10 — Meaningful validation:** prototype build and focused behavior checks pass. Test observable filter/search/variant/cart behavior rather than implementation details; keep checks proportionate. Record console/network failures and resolve those caused by the prototype.
- **D11 — Visual review:** inspect the final rendered home, collection, product, search, and cart together. Perform a correction pass and a final confirmation pass after fixes. No unresolved defect that materially breaks the required brand, layout, accessibility, or shopping interactions remains.
- **D12 — Implementation handoff:** the design spec and Shopify handoff are complete enough for an engineer to implement without guessing component states, mobile behavior, field ownership, or hosted checkout/account limits.
- **D13 — Scope integrity:** the changes are confined to the prototype and its design records. Existing work is preserved; no Shopify writes, purchases, secret/config changes, commits, or pushes occurred.
- **D14 — Evidence and final delivery:** the durable ledger and final report match the current files and actual checks. Evidence has been summarized in the conversation. Unverified production behavior and minor optional refinements are clearly separated from the completed prototype scope.

At the final gate, run the documented prototype build/verification commands, inspect the current diff and changed-file list, confirm screenshot coverage, and print a compact D01–D14 table with evidence paths. Existing unrelated work must not be reported as your changes.

Do not claim a live Shopify integration, a production performance score, a real payment test, user approval, or a published site. The finished artifact is a design prototype ready for user review and a concrete Shopify implementation handoff.

Only after the required gates pass, report `MONETTA_PROTOTYPE_READY_FOR_REVIEW` with the local launch command, artifact paths, and actual verification results. This is a delivery label, not a substitute for evidence. If required checks are blocked, report `BLOCKED` with the incomplete gates instead. If the user interrupts or a run limit ends the session, checkpoint the remaining work without claiming completion.
