# App design language on the Shopify staging theme — handoff (interim)

22 October 2026. Store `monetta-staging.myshopify.com`, draft theme `192125304866` (“Monetta Web F1 borrador sin publicar
2026-10-19”), verified `unpublished` with `shopify theme list` before any upload; live theme `189719183394` untouched. Nothing
published, no store settings changed, no orders placed. Status: **implementation complete and synced to the draft; validation
partly complete** (see “Pending”).

## What changed (this pass only; exact diff in `changes-this-pass.diff`)

- Token freshness: `design-system/build.mjs` now emits the hash line in `dart format`'s own layout (the app's SDK floor 3.5
  ignores `// dart format off`); `--check` passes, Dart file and token values unchanged. `port-css.mjs --check` added (Shopify
  token parity, no write; negative control proven).
- Type by role (`assets/monetta-app-alignment.css`): blanket h1–h6 serif rule replaced; product-card labels Inter (documented
  exception to the 22 Oct all-serif decision), panel titles and footer labels Inter as in the app; product name 25/29/32,
  section 23/27/30, phone search heading serif 22, drawer rows 17.
- Card surface as `MonettaProductTile` (canvas card, divider ring, tile photo mat, white-on-red discount badge, bare 48 px heart
  with filled state); 48 px targets everywhere (chips, options, filter rows, footer links, category row, rail arrows, sort
  select, wordmarks, brand and bag-line links); token radii for home modules.
- Fixes: single-photo product gallery collapsed to 72 px on desktop; bag summary/discount input made the page 383 px wide at
  320 and overflowed at 1024; “Quitar códigos” shown with no codes; 4 product columns from 1024; one-column product page
  768–1023; bag summary width at 1024–1279.
- Spanish labels for Shopify's untouched defaults (`snippets/monetta-label.liquid`: menus, sort, filters, policies, option
  names; “Catálogo”, “Noticias”, Spanish `<title>`s); merchant-typed labels kept.
- Secondary templates: new sections `monetta-page`, `-404`, `-collection-list`, `-blog`, `-article` (Monetta layout);
  `layout/theme.liquid` is now the Monetta shell for Atelier-built pages and policies with `snippets/monetta-atelier-bridge.liquid`;
  password and gift-card pages branded through the bridge; shared head in `snippets/monetta-head.liquid`.
- Theme-editor robustness: gallery, discovery rails and search-clear rebind on `shopify:section:load`.
- Spec: `docs/web-redesign/DESIGN_SPEC.md` rewritten as the active contract; prototype spec archived in `history/`.

## Verified

- `build.mjs --check` pass; `port-css.mjs --check` pass; JS syntax; JSON templates; `git diff --check`.
- Theme Check vs fresh baseline: 187 errors / 64 warnings before and after, 0 introduced, 0 removed (inherited issues not claimed resolved).
- `scripts/checks.mjs`: 330/330 at 320/390/768/1024/1440 incl. discount, saved and recent flows (`runs/2026-10-22T22-56-39-216Z-dl-checks`);
  4/4 negative controls detected.
- Theme editor loads the draft with all sections (read-only, nothing saved). Checkout/accounts editor read: checkout still on
  Shopify defaults (no logo, blue), language English; the editor offers logo, palette, Playfair Display and Inter (all plans).
- Contact page: merchant AI blocks overflow at 320/768 with or without Monetta CSS (A/B); the shell clips them, no sideways scroll.

## Pending (not done when the session stopped)

- `scripts/validate.sh` was still running the existing harnesses (journey ×4, axe, motion, nav, keyboard, layout, regressions);
  results land in `validation/` and `../runs/`. One journey failure seen at 390: browser Forward after the page-bar back arrow
  ended on “/” instead of the collection; not yet triaged (regression vs flake).
- After captures (`scripts/capture.mjs --out=.../captures/after`), `scripts/compare.mjs`, `scripts/perf.mjs` (no before
  measurement exists), `scripts/editor-events.mjs`, 200 % zoom run (640×450).
- Final guarded push (`../scripts/theme-push.sh`) and remote pull/compare; the draft already holds this state through
  `shopify theme dev` sync.

## Rollback

- Remote draft before this pass: `baseline/remote-before-192125304866.tgz` (SHA-256 `a4d1f24e…6824`, manifest beside it).
- Local tree before this pass: `baseline/local-before.tgz` (SHA-256 `cc284473…82d7`).
- Restore: extract into a folder and `shopify theme push --store monetta-staging.myshopify.com --theme 192125304866 --path <folder>`.
