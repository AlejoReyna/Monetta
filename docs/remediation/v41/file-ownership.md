# File ownership

A00 alone: tracker.csv, interfaces.md, decisions.md, file-ownership.md, integration-log.md; main.dart, CatalogStore/global providers, cross-package wiring and lock/codegen coordination.

Stage 1 leases:
- A01: design-system tokens/build, generated tokens, theme, pubspec assets/fonts, boutique guide_art/tokens/client_guide_components/client_guide_sections foundation, guide_chrome, own tests/handoff/evidence. No bottom nav or business data.
- A03: services/accounts_orders, lib/data/customer_auth, accounts_orders, notifications, Shopify editorial data, rewards_api/models, app/notification_controller transport only, own tests/handoff/evidence. No feature layouts or checkout orchestration.

Workers use isolated checkouts and task-scoped commits, no nested agents. Later stages remain unleased until foundation acceptance.

## Direct-launch coordination update

User independently launched A01/A02/A04/A05/A06/A07/A08 in top-level threads. The duplicate delegated A01 has been cancelled; its isolated diff is retained. An assumed duplicate A03 was also cancelled before confirming there was no direct A03; its worktree is retained for recovery. No package is accepted from these unfinished edits.

A02 exclusive shared-root lease (user-approved scope extension):
- lib/features/catalog/product_card.dart, product_tile.dart, product-owned helpers
- lib/features/product/ except external product flows
- lib/domain/product.dart
- lib/data/shopify/queries.dart, mappers.dart, catalog_item_mapper.dart and product catalog repository mapping (exclude editorial-content APIs owned A03)
- lib/data/local/tables.dart, database.dart, database.g.dart, catalog_cache_store.dart; product/cache tests
- docs/remediation/v41/handoffs/A02.md and evidence/A02/

A02 alone may change the local cache schema and run one scoped codegen pass after notifying A00 that inputs are ready; no other worker may touch local database/generated outputs or dependency locks. Preserve old cache data and test old-schema upgrade plus cold-load roundtrip. No Git/index operations in shared root.

Root Flutter test/codegen slot: A01 finishes current focused foundation checks first; then A02 codegen and focused tests after handoff. Other root checks wait for a grant; no shared build-folder concurrency. No codegen while a root test/build is active. A00 will not start a root Flutter process during these slots.

A04/A05/A06/A07/A08: preserve existing edits, stop dependent integration and root test/codegen until foundation gate and renewed stage lease. A06 isolated edits must await A01 release of client_guide_sections.dart. A08 has no product_screen.dart lease until A02 releases it.

A01 early release acknowledged: client_guide_sections.dart now belongs exclusively to A06 for registration/footer/editorial composition; no A01 rewrites. A06 remains stage-held until renewed work lease. A01 retains current root test slot pending explicit release. A02 next for codegen. A00 took a bounded repair lease for home_v41_catalog.dart missing foundation import and Favorites void navigation expression; fixes completed without changing feature behavior. These files return to A07, which remains stage-held.

A01 final release: no active Flutter process; A02 now exclusively owns root codegen/test slot. A01 implementation files frozen for A00 integration review. A06 retains released sections composition lease but remains stage-held pending A03 capabilities.

A03 exclusive producer lease expanded: functions/src/types.ts and functions/src/shopifyAdmin.ts plus focused functions/test/shopifyAdmin.test.ts (new or equivalent existing fixture) alongside catalog.ts/catalog.test.ts. Scope is only upstream authoritative selectedOptions/image fields and compatible serialization. No other producer owner active. A02 retains Flutter product/Firestore mapping and cache.

Bounded A07 compile repair granted to A02: home_new_collection_section.dart/home_for_you_section.dart only, use actual MonettaImage(url:, fit:), valid nullable-image branching and imports for existing brandLabel/formatShopperPrice. No layout/business behavior redesign. A00 observed fixes already present and did not overwrite concurrently; authorship confirmation requested. A07 must not concurrently edit this seam until A02 finishes compile repair. Root test/codegen slot remains A02.

Bounded Home repair CLOSED: A07 applied fixes and ended; A02 need not rewrite them. Home files return to A07 stage-held ownership. A02 alone reruns affected widget flow in its existing root slot; further compile blockers go to A00 before cross-owner edits.

A00 bounded restock adapter safety lease: rejected A08's unverified product-endpoint-as-variant mapping in restock_push_adapter.dart, preserved original as evidence/A00/rejected-restock-push-adapter.dart.txt, and removed the legacy submit/success path. File returns to A08 stage-held ownership. No product_screen.dart edits; A02 retains PDP lease.

Stage2 renewed leases after A03 interface acceptance:
- A02: current product/cache/PDP ownership and exclusive root test slot unchanged until final release.
- A04: taxonomy/discovery/catalog_query/categories/brands/collection/brand/sidebar/guide_drawer; existing shared-root diff retained. Own tests/evidence/handoff, no root tests until A02 releases; no common product widgets or service/global wiring.
- A06: plan-assigned Terra/high new isolated worker; earlier user-launched A06 paused before product edits, only local dependency setup/handoff retained outside integration. Own Contact/Wholesale/home_account_invitation/client_guide_sections/footer/help/policy-reader/purchase_notices UI and own tests; consume integrated A01/A03, no second policy transport/provider model. No main/global wiring.
- A03: finished package retired from active slots; retains API/service ownership for sequential later follow-up. No A05/A07/A08 feature integration before Stage2 acceptance.

A06 continuation: retain existing isolated checkout and partial commit, same Terra/high model/effort and same owned files. No source integration acceptance yet. Complete missing policy reader/footer/Contact/Wholesale/captures and correct token/primitives drift. A02 retains root check slot; A06 only uses its own checkout/build outputs.

A00 bounded BrandScreen import repair completed: brand_screen.dart now directly imports existing reco/explainer.dart show brandLabel. No feature behavior changed or root checks started. Temporary lease closed; A04 owns file again and must retain import. A02 retains root slot for affected rerun.
