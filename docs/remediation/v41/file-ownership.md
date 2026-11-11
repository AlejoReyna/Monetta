# File ownership

A00 alone: tracker.csv, interfaces.md, decisions.md, file-ownership.md, integration-log.md; main.dart, CatalogStore/global providers, cross-package wiring and lock/codegen coordination.

Stage 1 leases:
- A01: design-system tokens/build, generated tokens, theme, pubspec assets/fonts, boutique guide_art/tokens/client_guide_components/client_guide_sections foundation, guide_chrome, own tests/handoff/evidence. No bottom nav or business data.
- A03: services/accounts_orders, lib/data/customer_auth, accounts_orders, notifications, Shopify editorial data, rewards_api/models, app/notification_controller transport only, own tests/handoff/evidence. No feature layouts or checkout orchestration.

Workers use isolated checkouts and task-scoped commits, no nested agents. Later stages remain unleased until foundation acceptance.
