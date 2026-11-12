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
