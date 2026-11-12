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

A01 final local package accepted for integration: 28 focused tests passed; 13 after captures plus labeled before/provenance retained. A00 inspected Contact 320/200%, Wholesale 768/100% and shared assets/opaque controls. Text is readable and grows without scaleDown. These are fixture captures, not installed-app/device or complete-route evidence. Cross-feature regressions and F01/F16 closure remain open. Scoped analysis: zero errors/warnings, 639 informational lint findings retained for cleanup. Generator check passed.

Lock resolution accepted by A00: local Flutter SDK now requires matcher 0.12.20, test_api 0.7.12, meta ^1.18.3, vector_math ^2.4.0 and localization intl ^0.20.3. Solver movement from older lock is therefore compatible with current SDK, not arbitrary upgrades to revert. flutter_svg and its vector/path dependencies are required for supplied SVG icons. No package-resolution command was run by A00 while A02 owns codegen.

## A03 capability proposal v1 — accepted gates, implementation pending

Reviewed immutable copy: evidence/A00/A03-capability-proposal-v1.md. The capability inventory can guide consumers; adapter code, provider permissions/configuration, route wiring and live behavior are not accepted/verified from this proposal. Do not mount dependent actions until implementations and client configuration are accepted.

- First-party credentials and Shopify Customer Account OAuth are separate identities. Existing first-party login/register is real; no native social/first-party OTP may be invented. Shopify shipping/address/order capability requires its actual authenticated token.
- Rewards supports real ledger balance and paged activity. Missing/malformed amounts must fail, not become zero. Tier/progress/benefits have no authoritative source; hide those dependent claims pending authority.
- Order detail and address CRUD are provider-supported, not configured/live-proven: separate typed adapters must preserve authorization, nested pagination, historical address, shipment-vs-payment separation, denied/failed-vs-empty distinction. A03 will supply exact compiling signatures and official API version citations.
- Merchant-published Shopify shop policies are a supported source. A03 owns typed policy transport; A06 owns reader/footer; A00 owns provider wiring. Missing policy hides link; transport error preserves error/retry. No invented shipping/reservation copy.
- Exact-variant restock currently unavailable: FCM registration/storage/trigger are product-level; no email provider exists. A03 will publish explicit versioned config/channel capability with safe default for old servers. UI must hide variant request absent complete support; no product-only success accepted.
- NotificationInbox unread is received local-memory count scoped by owner, not account-wide durable service. A05 may use scoped local count; A00 must wire receipt ownership and account cleanup. Campaign/ad count is not unread.
- Account ad publishing schema/material/destination, secure payment-management capability, and cart wholesale-eligibility source are unavailable. Hide dependent actions/claims.
- Guest/account shipping uses actual provider cart identity, address and rate reconciliation. Email input cannot confer authentication/free shipping. Live rate evidence remains unverified.
- Producer metadata: selectedOptions JSON object and imageUrls string list from actual Shopify Admin variant data; absent -> {}/[]. A02 consumes in Flutter mapping/cache, no product-photo fallback.
