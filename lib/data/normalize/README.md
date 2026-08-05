# `data/normalize` — catalog repair

> Pure Dart. No Flutter imports, no codegen. Runs in microseconds per product.

## 1. Purpose

Turns a raw Shopify `Product` into `CanonicalFacets` — a clean, consistent set of
brand / category / silhouette / colour / pattern / price-band values that the rest of the
app can trust.

It exists because **Monetta's Shopify taxonomy is inconsistent enough to break naive
recommendations.** This module is the repair layer between "what the owner typed" and "what
the app reasons about".

**Not responsible for:** fetching data (`data/shopify`), storing it (`data/local`), or
ranking it (`reco/`). It is a pure function: `Product → CanonicalFacets`.

## 2. How it works

```
Product
  ├─ tags[]         ──┐
  ├─ product_type   ──┤
  ├─ title          ──┼──▶  evidence tiers (strongest → weakest)
  ├─ collections[]  ──┤         tag ▸ productType ▸ title ▸ collection
  └─ vendor         ──┘
                          ▼
              fold(): lowercase, strip accents, collapse spaces, trim
                          ▼
              alias match (whole-word, longest alias first)
                          ▼
              precedence + specificity rules
                          ▼
                  CanonicalFacets  +  FacetSource (the evidence)
```

The core loop is **tier-by-tier, not signal-by-signal**. All tags are considered together
before we ever look at the title. A weak-but-correct tag always beats a confident-looking
title keyword, because a tag is the owner's stated intent while a title is prose.

Every resolved value carries a `FacetSource` recording *where* it came from, which sets its
confidence (`tag` 0.9, `productType` 0.75, `title` 0.6, `collection` 0.45) and feeds both
the recommendation vector and the owner's catalog health report.

### Precedence, and why each one is the way it is

| Facet | Order | Reasoning |
|---|---|---|
| **brand** | metafield override ▸ tag ▸ title ▸ **vendor** ▸ collection | `vendor` sits near the *bottom*, which looks wrong until you check the data — see §6 |
| **category** | metafield override ▸ tag ▸ productType ▸ title ▸ collection, then specificity | A wallet sold with a crossbody strap matches both `cartera` and `bolsa`; specificity picks `cartera` |
| **silhouette** | same tiers, only when `category == bolsa` | A watch has no silhouette; scoring one would be noise |
| **colour / pattern** | first tier that yields *anything*, then stop | Don't merge tiers: a product tagged `Negro` shouldn't also absorb `dorado` because the title mentions a gold chain |

## 3. Key decisions and why

**Rules live in JSON, not in Dart.** `assets/rules/normalization_rules.json` is bundled as a
fallback and overridden at runtime by the Firebase Remote Config key `normalization_rules`.
When Monetta starts stocking a brand we've never seen, we fix it in Remote Config in two
minutes rather than shipping a build and waiting on App Store review. This is the single
most important property of the module — it is what keeps the owner unblocked.

**Owner overrides beat everything.** The `app.brand_override` and `app.category_override`
product metafields short-circuit all inference. Rules handle the general case; these handle
the exception, and the owner applies them from the normal Shopify product page.

**Confidence is tracked, not thrown away.** A brand read off a tag and a brand guessed from
the title are both "resolved", but they are not equally trustworthy. Confidence scales the
facet's weight in the recommendation vector, so a guess pulls the feed less than a fact.

**Rejected: a machine-learning classifier.** 271 products with a 174-tag vocabulary is far
too little data to beat hand-written aliases, and an ML model would be unexplainable to the
owner and un-hotfixable without a release. The measured accuracy below shows aliases are
comfortably good enough.

**Rejected: fixing the data in Shopify instead.** We should *also* do that (the health
report exists to drive it), but the app cannot depend on it. The owner will keep adding
products at speed, and the app has to stay correct on the day they typo a tag.

## 4. Data in / data out

**In:** `Product` (`lib/domain/product.dart`) + `NormalizationRules` + `now` (injected, so
`newArrival` is deterministic in tests).

**Out:** `CanonicalFacets` — nullable `brand` / `category` / `silhouette`, lists of `colors`
and `patterns`, a `priceBand` string, and the `onSale` / `inStock` / `newArrival` flags.

`CanonicalFacets.toVector(facetWeights)` produces the namespaced sparse vector that `reco/`
scores against:

```dart
{ 'brand:guess': 0.9, 'silhouette:crossbody': 0.765,
  'category:bolsa': 0.72, 'color:negro': 0.45, 'price_band:medio': 0.6 }
```

Keys are namespaced so `color:negro` can never collide with a hypothetical `pattern:negro`.

## 5. Measured accuracy

Run against the **live 271-product catalog** snapshotted 2026-08-05
(`test/fixtures/catalog_2026_08_05.json`):

| Facet | Resolved | Baseline |
|---|---|---|
| **brand** | **270 / 271 — 99.6%** | 86.7% using `vendor` alone |
| **category** | **271 / 271 — 100%** | ~87% (36 products have empty `product_type`) |
| **silhouette** (bags only) | **175 / 177 — 98.9%** | n/a — `product_type` has 20 spellings |
| **colour** | **267 / 271 — 98.5%** | n/a |

Resolved facet distribution:

```
categories   bolsa 177 · cartera 52 · reloj 19 · accesorio 7 · set 6
             · monedero 4 · tarjetero 3 · cosmetiquera 3
silhouettes  crossbody 125 · tote 24 · shoulder 20 · satchel 5 · mini 1
colours      negro 79 · cafe 65 · blanco 57 · beige 35 · rosa 29 · gris 20
             · dorado 19 · azul 17 · rojo 8 · …
```

The brand jump from 86.7% → 99.6% is the whole point of the module: the title fallback
rescues exactly the 35 products whose `vendor` is the store name.

**The known misses are correct behaviour, not bugs** — each is a genuine gap in the source
data, not a rule failure:

- `Bolsa Tote Blanco Monograma` — no brand anywhere in tags or title.
- `Bolsa Steve Madden CrossbodyBlanco Hueso…` — missing space in the source title, so
  whole-word matching correctly declines to guess.
- `Bolso Guess de Rayas Azul Marino y Crema` — no silhouette word at all.
- Four products with no colour word (`…Serpiente`, `…Rayas Zebra` are patterns, not
  colours; `Marilyn Medium Tote` and `Long Zip Around Wallet` are model names).

Only the **first two reach the health report** (`dart run bin/catalog_report.dart`). The
others are classified confidently enough on brand and category that they still recommend
well, and `needsAttention` is deliberately tuned to surface work that changes outcomes
rather than every imperfection — a report the owner cannot finish is a report they ignore.

## 6. Gotchas

**Never trust `vendor` as the brand.** 35 products carry `'Monetta '` — *with a trailing
space* — and one carries `'Monetta'`. That is the store name, not a brand. If you promote
`vendor` above `title` in the precedence chain, 36 products (13% of the catalog) collapse
into a single meaningless "Monetta" affinity and the recommender quietly degrades for
everyone who touches them. `storeVendorAliases` in the rules file is the guard; the trailing
space is handled by `fold()`.

**`product_type` has 20 spellings for ~8 real categories** and is empty on 36 products:
`Bolsa`, `Bolso`, `Bolso Tote`, `Tote`, `Crossbody`, `Crossbody Bag`, `Bolsa Crossbody`,
`Shoulder`, `Shoulder Bag`, `Bolsa Shoulder Bag`, `Satchel`, `Bolsa Hobo`, `Mini Bag`,
`Clutch`, `Cartera`, `Monedero`, `Reloj`, `Cosmetiquera`, `Set de Regalo`, `''`.

**Folding fixes spelling, not vocabulary.** `fold()` collapses `Café`/`Cafe` and
`Crossbody`/`crossbody` for free. It does **not** collapse gender variants
(`Negro`/`Negra`/`Blanco`/`Blanca`) or language pairs (`Black`/`Negro`) — those must be
listed explicitly as aliases. Forgetting this is the most likely way to add a broken rule.

**Alias order matters and is handled for you.** `NormalizationRules` sorts aliases
longest-first, so `rosa claro` is tried before `rosa`. If you build a vocabulary map by hand
somewhere else, replicate that or pale pink silently becomes plain pink.

**Whole-word matching is deliberate.** `containsWord` prevents `oro` matching inside
`dorado` and `tote` inside `totemico`. The cost is that source-data typos like
`CrossbodyBlanco` won't match — which is the right trade, because guessing through a typo
is how you get confidently wrong classifications.

**Silhouette is single-valued, and some products genuinely have two.**
`Bolsa Guess Negra Tote con monedero` is tagged `Crossbody` but is a tote with a detachable
crossbody strap — both are true, and we currently keep only the tag-tier winner
(`crossbody`). This is a deliberate simplification, not an oversight: a second silhouette
would double that facet's pull in the recommendation vector and skew ranking toward
multi-strap bags. If it ever matters, make `silhouette` a list like `colors` **and** halve
its `facetWeight` so total pull stays constant.

**Collections are the weakest signal for a reason.** The collection handle `guess` is titled
**"Bolsas"** and `guess-1` is titled "Guess"; `carteras`/`carteras-1` and
`relojes`/`relojes-1` are duplicate pairs. Never raise collections above `title`.

## 7. Tests

```bash
make test-core                       # this module + reco, no widget pump
flutter test test/normalize          # just this module
```

- `test/normalize/text_test.dart` — folding and word-boundary edge cases.
- `test/normalize/normalizer_test.dart` — precedence rules, one test per decision in §2,
  including the `'Monetta '` trailing-space case.
- `test/normalize/golden_catalog_test.dart` — runs the real 271-product fixture and
  **fails the build if brand resolution drops below 95% or category below 98%**. This is
  the regression net: it catches a rules edit that helps one product and breaks thirty.

### How to extend

- **New brand:** add it to `brands` in the rules JSON (bundled asset *and* the Remote Config
  value). Include every spelling you have seen, plus the bare surname if the title uses it.
- **New category or silhouette:** add to the vocabulary, and if it is a category, insert it
  into `_categoryPriority` in `normalizer.dart` at the right specificity — more specific
  above `bolsa`.
- **New facet kind entirely:** add the field to `CanonicalFacets`, emit it in `toVector()`,
  add a weight in `facetWeights`, and extend the golden test. `reco/` needs no change — it
  scores whatever keys the vector contains.
