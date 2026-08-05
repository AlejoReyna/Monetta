# `reco` — the recommendation engine

> Pure Dart. No Flutter imports, no codegen, no I/O, no clock access. Everything
> that varies (`now`, weights, context) is injected, so every result is
> reproducible in a test.

## 1. Purpose

Learns what a shopper likes from how they browse, then ranks the catalog for them and
explains *why* each product is being shown.

Runs entirely **on the device**. In Phase 1 nothing about a user's behaviour is uploaded
anywhere — that is a privacy decision, but it is also what lets the app launch with no
backend and personalize correctly for user #1 on install day.

**Not responsible for:** fetching or caching the catalog (`data/shopify`, `data/local`),
classifying products (`data/normalize`), or rendering anything. It takes facets and events
in, and returns a ranked list with reasons out.

## 2. How it works

```
event log (drift)          catalog facets (data/normalize)
      │                              │
      ▼                              │
 ProfileBuilder                      │
  ├ time decay  0.5^(age/14d)        │
  ├ dwell scaling  0.5×–2.0×         │
  ├ impression cap  20/session       │
  ├ drop negatives, then L2-normalize│
      │                              │
      ▼                              ▼
  TasteProfile  ──── cosine ────▶ Recommender
  {brand:guess 0.71,                 ├ × confidence floor
   silhouette:crossbody 0.55,        ├ × stock / sale / new / restock
   color:negro 0.31}                 ├ × already-seen penalty
                                     ├ sort (stable, id tie-break)
                                     └ diversity re-rank (max 2 same brand)
                                             │
                                             ▼
                                     Explainer → "Porque te gustan
                                                  las bolsas crossbody
                                                  de Guess"
```

### Step 1 — events become a profile

Each event has an ordinal weight. What matters is the ratio between them, not the absolute
numbers:

| Event | Weight | Why |
|---|---:|---|
| `impression` | 0.1 | Capped at 20/session, or one long scroll drowns out every deliberate act |
| `productView` | 1.0 | × dwell multiplier (0.5–2.0, saturating at 60 s) |
| `galleryInteraction` | 1.5 | People seriously considering a bag look at it closely |
| `searchOrFilter` | 2.0 | A *stated* preference beats an inferred one |
| `wishlistAdd` | 4.0 | |
| `addToCart` | 6.0 | |
| `whatsappApartado` | 8.0 | Just below purchase — on this store the layaway usually *is* the purchase |
| `purchase` | 10.0 | |
| `wishlistRemove` | −4.0 | Evidence of a rejected preference; rarer, so valuable |

Each event's weight is multiplied by `0.5 ^ (ageDays / 14)` and its product's facet vector
is accumulated. The result is clamped at zero and L2-normalized, so cosine similarity is a
plain dot product.

### Step 2 — profile scores the catalog

```
score = cosine(profile, productFacets)
      × (0.35 + 0.65 × classificationConfidence)   ← a guess ranks below a fact
      × 0.25  if out of stock
      × 1.20  if recently restocked
      × 1.08  if on sale
      × 1.05  if new arrival
      × 0.6   if already viewed
      × 0.5   if already wishlisted
```

Purchased products are excluded outright.

### Step 3 — diversity re-rank

Greedy pass allowing at most **2 consecutive products of the same brand**.

## 3. Key decisions and why

**14-day half-life.** Handbag *taste* is stable over months, but *intent* ("I want a black
crossbody right now") turns over in weeks. A longer half-life leaves the feed stale after a
purchase; a much shorter one makes it thrash on a single browsing session.

**Diversity re-ranking is not optional here.** 147 of 271 products are Guess. Without the
cap, a user who likes Guess sees nothing else and the app reads as *broken* rather than
personalized. This is the clearest case in the codebase of a business fact driving an
algorithm choice.

**Out-of-stock is penalized, not filtered.** 21% of variants are unavailable at any moment.
Hiding them would gut the feed — and seeing a sold-out bag you love is exactly what makes
someone tap "avísame", which becomes the highest-converting notification we can send.

**Confidence scales the score.** `data/normalize` reports how it classified each product. A
brand read off a tag and a brand guessed from a title are both "resolved" but are not
equally trustworthy, so the guess is floored at 0.35 of its potential contribution. This is
the seam that stops the catalog's data-quality problems leaking into visibly wrong
recommendations.

**Negative affinities are dropped, not kept negative.** "Removed from wishlist" should stop
us pushing that facet — it should not make the *opposite* facet attractive, which is what a
negative component in a cosine would do. (Disliking black bags does not mean liking white
ones.)

**Content-based, not collaborative — in Phase 1.** A brand-new store with no traffic has no
co-view matrix to learn from. Content-based scoring works for the first user on day one.
Collaborative filtering arrives in Phase 2 as a *blend*, once there is data to justify it.

**Rejected: an embedding model / vector DB.** With ~271 products and 6 facet kinds, a sparse
hand-built vector is faster, explainable in one screen, tunable by a human, and runs offline
on a mid-range Android phone. Embeddings would buy accuracy we cannot measure yet and cost
us the reason chips, which are half the product value.

**Rejected: server-side ranking in Phase 1.** It would need a backend before launch, add
latency to every scroll, and put behavioural data on a server we would then have to disclose
under LFPDPPP. On-device is faster, cheaper and more private.

## 4. Data in / data out

**In**
- `List<InteractionEvent>` — from `data/local` (drift), device-only
- `Map<String, CanonicalFacets>` — from `data/normalize`
- `Map<String, double> facetWeights` — from the rules file / Remote Config
- `ScoringContext` — viewed / purchased / wishlisted ids, discounts, restocked ids
- `DateTime now` — always injected

**Out**
- `TasteProfile` — sparse normalized vector + `topOf('brand')` helpers
- `List<ScoredProduct>` — id, score, facets, and which signals fired
- `RecoReason` — a `ReasonKind` plus display text in es-MX

## 5. Cold start

The engine must work before it knows anything.

1. **Onboarding seed** — a 3-tap optional flow ("¿Qué marcas te gustan?" / "¿Bolsa, cartera
   o reloj?" / price comfort) builds a synthetic profile via `seedProfileFromOnboarding`.
   It is deliberately given exactly `minEventsForPersonalization` weight, so it works
   immediately but yields to real behaviour the moment any arrives.
2. **Below 5 events** — `TasteProfile.isConfident` is false; the feed falls back to trending
   / new arrivals rather than pretending to personalize.
3. **Skipped onboarding, no events** — pure trending. Never an empty screen.

## 6. Gotchas

**Never call `DateTime.now()` in this module.** Every entry point takes `now`. Decay and
`newArrival` both depend on it, and a hidden clock read makes tests flaky and results
irreproducible.

**The profile is L2-normalized; product vectors are not.** `similarityTo` normalizes the
product side only. If you build a profile by hand in a test, normalize it or the scores will
look wrong.

**Facet keys are namespaced (`brand:guess`).** Never construct a bare key — `color:negro`
and a hypothetical `pattern:negro` must not collide.

**Impression capping is per *build*, not per session, today.** `ProfileBuilder` counts
impressions across the event list it is handed. If you ever pass a multi-session log, cap
upstream. This is fine now because `data/local` hands over a bounded recent window.

**Ordering is stable by design.** Ties break on `productId`. Do not "optimize" that away —
several tests and the diversity pass depend on determinism.

**Weights are ordinal, not calibrated.** They encode judgment about this category, not
measured truth. Once real CTR data exists, `ScoringWeights` is built to be moved to Remote
Config and A/B tested. Do not treat the current numbers as sacred.

## 7. Tests

```bash
make test-core                  # normalize + reco, milliseconds, no widget pump
flutter test test/reco          # just this module
```

- `test/reco/profile_test.dart` — decay maths, dwell scaling, impression cap, negative
  clamping, L2 normalization.
- `test/reco/scorer_test.dart` — a user who views only Guess crossbodies gets Guess
  crossbodies first; out-of-stock ranks below in-stock at equal affinity; purchased items
  are absent; **no more than 2 consecutive same-brand items**; cold start returns a full
  feed from zero events.
- `test/reco/explainer_test.dart` — reason priority (restock ▸ price drop ▸ new ▸ taste ▸
  trending) and Spanish agreement (`las bolsas` vs `los relojes`).

### How to extend

- **New event type:** add to `EventType` with a weight relative to the existing scale, and
  record it where it happens. `ProfileBuilder` needs no change.
- **New facet kind:** add it in `data/normalize` and give it a `facetWeights` entry. The
  scorer picks it up automatically — it scores whatever keys the vector contains.
- **Tune ranking:** change `ScoringWeights`, not the algorithm. Every multiplier is a named
  field for exactly this reason.
- **Add collaborative filtering (Phase 2):** blend a server-supplied co-view score with
  `cosine` inside `Recommender.rank`, keeping the on-device score as the fallback when the
  network is unavailable.
