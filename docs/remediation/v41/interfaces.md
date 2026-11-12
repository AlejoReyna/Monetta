# Accepted interfaces

A01 early source interfaces accepted for consumption as documented below; final package/visual acceptance remains pending. A03 capability inventory is unaccepted. Existing service APIs remain authoritative until acceptance.

## A02 selection proposal (accepted design; implementation unverified)

- ProductVariant.selectedOptions: Map<String,String>, defaults empty for legacy callers.
- ProductVariant.imageUrls: List<String>, defaults empty; only authoritative Shopify/producer data, no invented variant photos.
- ProductCard.initialVariantId: String?; onVariantChanged: ValueChanged<String?>?; openDirectly: bool = false.
- Product/quick-view entry adds initialVariantId alongside legacy index args. Resolve by stable ID first, validate membership, preserve old behavior otherwise.
- Featured Home opens PDP directly with selected variant; other cards keep quick view.
- Optional restock callback receives Product and exact exhausted ProductVariant; absent/unsupported callback hides action until A08/A03 real service handoff.
- Carry options and images through query, mapper, cache, reload and producer metadata. A03 owns Firestore producer pass-through/policies; A02 owns product/cache mapping.

Compatibility and live integration remain unverified until A02 handoff/tests and A03 capability acceptance.

## A01 early source interface acceptance

Reviewed source and handoff A01.md. guideAsset uses namespace IDs (banner:B01, homePhoto:F01, icon:<id>); home photos require forHome:true. GuideBanner uses bare banner ID (B01, B04-editorial), not the namespace prefix. Unknown IDs return null/hidden art, so feature owners must use known bindings. GuideSemanticImage is decorative unless explicitly labeled; avoid duplicate parent announcements. GuideGlassSurface supports explicit opaque mode and system high-contrast/accessibility-navigation fallback. GuideGlassIconButton preserves native focus/disabled semantics. GuideHero, GuidePillButton and ClientGuideButton old signatures retained.

client_guide_sections.dart foundation diff reviewed: three-line B04-editorial mapping preserves action. A01 released file; exclusive future composition owner A06. No A06 resume until stage lease. Current foundation-only six reflow checks passed; complete feature imports/regressions remain blocked by in-flight cache/codegen and Home test constructor changes. No final device or 50-contract acceptance inferred.

Assets: packaged banners 1280×533 differ from source manifest 1920×800; provenance/dimension distinction retained in A01 handoff. No assertion of pixel-identical export dimensions.

Dependency review: flutter_svg 2.3.4 plus vector_graphics/path_parsing support added. Solver also updated intl/matcher/meta/test/test_api/test_core/vector_math. A00 will review/preserve compatible lock resolution after active tests; no further worker lock edits.
