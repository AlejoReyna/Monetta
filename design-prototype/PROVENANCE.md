# Asset and data provenance

Everything the prototype shows comes from one of the sources below. Product data is
demo data: a dated snapshot, not a live price, stock or delivery guarantee.

## Catalog data

| Item | Source | Captured | Notes |
| --- | --- | --- | --- |
| Products (311) | `https://monetta.mx/products.json?limit=250&page=1` and `page=2` (public storefront JSON) | 2026-10-17 20:51 CST (`-06:00`) | Raw copy: `fixtures/source/monetta-public-catalog-2026-10-17.json` |
| Collections (21) | `https://monetta.mx/collections.json?limit=250` | 2026-10-17 20:51 CST | Same file, `collections` |
| Collection membership (13 collections) | `https://monetta.mx/collections/{handle}/products.json?limit=250` | 2026-10-17 21:03 CST | Same file, `collection_membership`; keeps Shopify's collection order for “Destacados” |
| Facet vocabulary | `assets/rules/normalization_rules.json` in this repository (app) | copied 2026-10-17 | `fixtures/source/normalization_rules.json` |

`scripts/build-fixtures.mjs` turns the snapshot into `src/data/catalog.json`:

- **Curation (86 products).** Twenty named products that carry required states
  (long names, partly sold-out variants, genuine compare-at prices, “sobre pedido”,
  “Envío inmediato”, watches), then the newest products per brand, rotating
  category and style: Guess 22, Steve Madden 16, Coach 16, Michael Kors 16,
  Tommy Hilfiger 12, Juicy Couture 3, Calvin Klein 1.
- **Facets.** Brand, category, bag style, colours and patterns follow the app's
  normalizer (folded, whole-word aliases; tags ▸ product type ▸ title). One
  deviation: the noun that opens a title (“Cartera…”, “Bolso…”) decides the
  category, because tag-first matching files “Jet Set” bags under `set`.
- **States read from real data.** `onSale`: a variant with
  `compare_at_price > price`. `sobrePedido`: the description contains “ESTE MODELO
  ES SOBRE PEDIDO” (the sentence is removed from the copy). `envioInmediato`: tag
  “Envío inmediato”. Variant availability as published.
- **Synthetic states (documented, labelled in the UI):**
  - `bolsa-guess-shoulder-vino-brillante` is marked fully sold out — no product was
    fully sold out in the snapshot.
  - `cartera-guess-compacta-negro` has an inventory limit of 2 — the public API does
    not expose quantities.
- Collection counts in the prototype are the curated subset; `liveCount` keeps the
  live number of products per collection.

## Product photographs

209 images from `cdn.shopify.com/s/files/1/0723/9165/5575/files/…`, requested at
`width=800` with `Accept: image/webp` and stored as
`public/media/products/{handle}/{n}.webp`. Each file's exact source URL is listed in
`fixtures/manifest.json` (`images`). Variant photos come first so a selected colour
always has its own picture.

## Brand and editorial assets (from this repository)

| Prototype file | Repository source |
| --- | --- |
| `public/media/brand/logo-monetta.png`, `@2x`, `@3x` | `assets/images/logo_monetta.png`, `assets/images/2.0x/…`, `assets/images/3.0x/…` (the app's wordmark) |
| `public/media/brand/favicon-32.png`, `favicon-96.png` | `assets/images/monetta_favicon.png`, `assets/images/3.0x/monetta_favicon.png` |
| `public/media/editorial/home_banner.jpg` | `assets/images/home_banner.jpg` (same file the live home hero uses) |
| `public/media/editorial/home_collection_{bags,wallets,watches}.webp` | `assets/images/…` (home “Colecciones”) |
| `public/media/editorial/home_bag_{tote,crossbody,shoulder}.webp` | `assets/images/…` (home “Compra por estilo”) |
| `public/media/editorial/home_about.webp` | `assets/images/home_about.webp` |
| `public/media/editorial/home_social_{instagram,tiktok,facebook}.webp` | `assets/images/…` |
| `public/media/editorial/home_review_{monse,gaby,guadalupe}.jpg` | `assets/images/…` (review photos of the app's fallback testimonials) |
| `public/media/brands/*.webp` | `assets/images/brands/*.webp`; crop bounds from `lib/features/home/home_screen.dart` |

Not used: `campaign_*.jpg` (the app's offer cards promise “20% en bolsos
seleccionados”, an unverified offer) and `hero_poster.jpg`.

## Fonts

| File | Source | Conversion |
| --- | --- | --- |
| `public/fonts/inter/Inter-{Regular,Medium,SemiBold,Bold}.woff2` | `assets/fonts/inter/*.ttf` | `wawoff2` 2.0.1 (Google woff2, lossless), 2026-10-17 |
| `public/fonts/playfair/PlayfairDisplay-Regular.woff2` | `assets/fonts/playfair_display/PlayfairDisplay-Regular.ttf` | same |

Both families are SIL Open Font License 1.1; the licence files are copied next to
the fonts (`OFL.txt`). WOFF2 is a lossless container change of the unmodified
fonts. Only the weights the design uses are shipped (Inter 400/500/600/700,
Playfair Display 400).

Source checksums (sha256, first 16 hex): Inter-Regular `40d692fce188e447`,
Inter-Medium `97ad806f526e4154`, Inter-SemiBold `78a843fade9d4612`,
Inter-Bold `288316099b1e0a47`, PlayfairDisplay-Regular `861f838d481d28cb`.

## Copy

Every block in `src/data/content.js` names its source. Summary:

- App code: search prompts (`search_screen.dart`), style and collection cards
  (`home_content.dart`), about and partner copy (`editorial_content.dart`),
  wholesale FAQ (`partner_hub_screen.dart`), apartado message
  (`cart_attribution.dart`), labels (`shopper_copy.dart`).
- Live site, 2026-10-17: contact intro (`/pages/contact`), FAQ wording and the
  $400 / $800 deposits and 20-day window (`/pages/mayoreo`), the “Ahora” milestone.
- Reviews: the app's bundled fallback testimonials, which mirror the live Loox
  carousel. They are labelled “muestra” everywhere; no verified badges, ratings
  summary or counts are shown.
