# Accepted interfaces

No new package interfaces accepted yet. Stage 1 A01/A03 must provide tested, backward-compatible primitives and actual capability inventory before dependent screens start. Existing APIs remain authoritative until acceptance.

## A02 selection proposal (accepted design; implementation unverified)

- ProductVariant.selectedOptions: Map<String,String>, defaults empty for legacy callers.
- ProductVariant.imageUrls: List<String>, defaults empty; only authoritative Shopify/producer data, no invented variant photos.
- ProductCard.initialVariantId: String?; onVariantChanged: ValueChanged<String?>?; openDirectly: bool = false.
- Product/quick-view entry adds initialVariantId alongside legacy index args. Resolve by stable ID first, validate membership, preserve old behavior otherwise.
- Featured Home opens PDP directly with selected variant; other cards keep quick view.
- Optional restock callback receives Product and exact exhausted ProductVariant; absent/unsupported callback hides action until A08/A03 real service handoff.
- Carry options and images through query, mapper, cache, reload and producer metadata. A03 owns Firestore producer pass-through/policies; A02 owns product/cache mapping.

Compatibility and live integration remain unverified until A02 handoff/tests and A03 capability acceptance.
