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

## A03 additive signatures — compiling proposal, tests/integration pending

- CustomerGraphqlClient(config: CustomerAccountConfig, client?: http.Client) uses existing Shopify discovery/raw Shopify token.
- ShopifyCustomerAddressService(client): fetchAddresses(String accessToken) -> Future<CustomerAddressBook>; create(String accessToken, CustomerAddressInput, {bool defaultAddress=false}) -> Future<CustomerAddress>; update(String accessToken, String addressId, CustomerAddressInput, {bool? defaultAddress}) -> Future<CustomerAddress>; delete(String accessToken, String addressId) -> Future<void>. Provider input names: territoryCode, zoneCode, phoneNumber.
- ShopifyCustomerOrderDetailsService(client).fetchOrderDetails(String accessToken, String orderGid) -> Future<CustomerOrderDetails?>. Paginated lines/fulfillments; null historical address/variant retained; HTTPS tracking only; shipment independent of payment.
- ShopPolicyRepository(StorefrontClient).fetch() -> Future<Map<ShopPolicyKind, CapabilityRead<ShopPolicyContent>>>; kinds shipping/refund/privacy/terms, content id/title/bodyHtml/url. Missing/empty published policy returns unavailable; transport/provider failure throws, preserving failure versus missing content. Callers must handle thrown errors for retry, not turn them into unpublished content.

A00 checked pinned 2026-07 provider reference: [address create](https://shopify.dev/docs/api/customer/2026-07/mutations/customerAddressCreate) requires customer_write_customers; [Order](https://shopify.dev/docs/api/customer/2026-07/objects/Order) requires customer_read_orders and distinguishes line/fulfillment/address fields; [Shop policies](https://shopify.dev/docs/api/storefront/2026-07/objects/Shop) provides merchant privacy/refund/shipping/terms. This documents API existence, not configured app permissions or live proof. No UI/global provider wiring until code/tests integrated.

A03 final restock consumer name: NotificationController.variantRestockAvailable -> false until a complete exact-variant pipeline exists. createRestockAlert also returns false without requesting permission/recording consent/subscription. A02/A08 production callback must be absent while capability false; old controller.available is not a restock capability. A08's initial push adapter was rejected: passing variant ID into product-only createRestockAlert cannot satisfy G12, and collecting email does not create email-channel authority. A00 bounded fix makes that adapter explicitly unavailable without side effects pending final A08 integration. No production restock form will be mounted through this adapter.

## A03 integrated interface acceptance

Source 9f425bf integrated as 6900cf6; evidence/handoff b760d2a integrated as 4a45e82. Source and leased files inspected, additive contracts accepted for consumers. Exact signatures in handoffs/A03.md are now available in integration branch. 16 producer +214 service tests, 161 Flutter regressions and 31 final focused checks passed in the isolated package; clean 12-file analysis and diff check. PostgreSQL 12 optional tests skipped because admin/local PostgreSQL connection unavailable (not merely a missing DATABASE_URL); Node26 used while functions targets Node22, so target runtime CI still pending. No configured/live Shopify/FCM/rate/address/order/policy verification.

A00 must bind AccountReadScope to verified Shopify account, clear on identity/logout and call RewardsApi.clearSession; feature adapters are not automatically wired by their existence. Address mutations with mutationMayHaveSucceeded must reconcile via read before retry. Policy failure throws; safe reader belongs A06. New producer fields and strict Rewards parsing must be rechecked against integrated consumers. A02 notified to recheck affected seams after cherry-pick. Stage2 A02/A04/A06 source work now unblocked; unsupported business/service controls stay gated.

## A02 integrated local package acceptance

Source integrated as 3f2c4c31acaefc071a34a5d24312efebf5bd48a2 from600437c. All34 source/test asset hashes matched frozen A02 manifest. Reviewed mapping/schema9→10 preservation, ID/options resolution, card→quick→PDP purchase guards and representative card320/200%, dark quick view and PDP320/200% captures. 125 final checks and 44 post-A03 flow/seam checks passed; 32-path scoped analyzer clean. Evidence/handoff describe deterministic fixtures and historical-labeled baseline captures; no device/live/provider claim.

Published ProductVariant.selectedOptions/imageUrls, imagesForVariant, ProductCard(initialVariantId,onVariantChanged,openDirectly), openProduct/showProductQuickView(initialVariantId alongside legacy index), and ProductScreen optional shippingPolicy/returnsPolicy/endSectionsBuilder accepted for consumers. Missing IDs/combinations remain unavailable and do not substitute variants. Sync cursor reset on local schema upgrade forces full metadata backfill while preserving catalog/bag/private rows. Old docs default empty metadata. No live migration/backfill authorized/performed.

Remaining A00 seams: BrowseDetailScope must carry stable ID through deferred tablet pane creation; attach A06 endSectionsBuilder and safe published A03 shipping/refund text with loading/error/unavailable handling. Current exact-variant restock callback remains absent; false capability cannot use generic notification.available. No F06/F07/full-contract closure from local tests alone.

## A06 integrated local interface acceptance

Reviewed combined original6a999a1+7fa271e; integrated sequentially as f2d4b33 then65360a9. Initial partial commit alone remains superseded.34focused+50render/interaction checks passed isolated; scoped analysis zeroerrors/warnings,207informational lints. A00 inspected registration320/200%, policy320/200%, Contact community320/200% and Wholesale middle-step320/200% captures. Full app source/access/routes/bindings and device/live verification remain pending.

Accepted: HomeAccountInvitation onEmailRegister Future<String?> Function(String trimmedValidatedEmail) optional; error string preserves email, null means return/cancel without fake success. Existing onRegister callback remains. PolicyController(PolicyLoader=repository.fetch), PolicyScope, openPolicy(kind), openHelp(approvedQuestions,onContact), safe text/HTTPS policy reader; A00 owns controller lifetime/initial refresh/disposal and global injection. ClientGuideFooter adds optional onWholesale; ContactScreen/openContact/WholesaleScreen use explicit group/social bindings and launcher callbacks, no default guessed invitation URLs or automatic send/join. Wholesale recommendations retain up to40unique real IDs.

A00 must attach real registration access, published policy source, approved groups/socials and shared endSectionsBuilder via central routes. Missing/unpublished links remain hidden; failed policy fetch preserves retry. Source community illustration and gated received wholesale benefit claims remain unresolved design/authority items, not VERIFIED. Earlier Wholesale regressions predate final footer/recommendation changes; relevant root regression rerun required after integration. Stale Home B04/footer tests belong A07/A00.
