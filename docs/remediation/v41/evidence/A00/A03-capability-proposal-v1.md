# A03 — authoritative capabilities, proposal v1

Base: `df3c9c258d74a6c32f197adba0d34d9d3eb17ee6`. Isolated checkout, Sol/xhigh. No applicable AGENTS.md found in checkout or ancestors. No production calls, secrets, messages, migrations or financial actions. Implementation in progress; none of the following is a live verification.

## Early interface proposal (A00 acceptance required)

| Capability | Actual source and consumer contract | Gate / authority |
|---|---|---|
| Identity | Existing first-party `/accounts/register`, `/accounts/login`, `/accounts/me`, signed bearer + local account; separate Shopify Customer Account OAuth/PKCE/discovery for Shopify identity. | First-party credentials do not authenticate Shopify checkout. No native Google/Apple or first-party email OTP/reset endpoint exists; Shopify handles its own hosted challenge. Never invent native social providers. |
| Balance | Existing authenticated `/customers/me/rewards`, ledger cents and `asOf`; paged activity. Add strict parsing (absent/malformed balance fails, never becomes zero), stale-session guard and optional membership authority. | Existing redemption/incentive flags only. No tier thresholds/progress/benefits source exists. Optional membership absent => hide tier/progress/benefits; do not infer from ledger or mockup. Preserve real balance read. |
| Order summaries/detail | Existing Customer Account `customer.orders` is Shopify history, server mirror enriches apartados. Add separate `CustomerOrderDetailsService.fetchOrderDetails(accessToken, orderId)` using Customer Account `order` query: line items, historical shipping address, fulfillment shipment state and tracking. | Shopify token/ownership enforced by provider; no admin-by-email lookup. Null detail => unavailable. Paginate nested connections; payment never supplies shipment stage. Mirror-only apartados have no authoritative line/address/tracking yet. A08/A00 own domain/repository/cache wiring. |
| Address CRUD | Shopify Customer Account API documents customer addresses and customerAddressCreate/Update/Delete with authenticated account. Add a separate `CustomerAddressService` over that API, no local PII cache. | Requires configured Shopify customer login/token and provider permissions; first-party account alone does not unlock it. Provider denied/failed reads are errors, not empty lists. No first-party address database/service exists. |
| Payment management | No configured secure management-link resolver or payment-management API in current app/service. | Unavailable. Hide action; checkout can still expose provider-supported payment choices. Do not construct a URL from shop domain or claim vaulted-card support. |
| Restock | Current backend is device-authenticated FCM push, product-level key; no email delivery platform. Catalog automation also detects whole-product availability, not exact variants. | Exact-variant request capability is **unavailable** until variant-scoped storage, authoritative exhausted check and variant stock trigger exist end to end. Add explicit notification-config capability version + channels; default/old server missing exact-variant support => hidden. Reject legacy product-only restock submission rather than claim selected-variant success. No email collection/subscription. Independent alert safety/producer work can proceed. |
| Account ads | Existing Shopify editorial metaobjects support About/Partner/catalogs; no approved account-ad definition, binding, assets or version fields configured. | Explicit unavailable result, hide slot. Do not add ad network or repurpose fixed Mayoreo. Owner must approve editorial schema/content/destination before enabling. |
| Policies | Existing Shopify Storefront `shop` policies are a supported approved merchant content source. Add `ShopPolicyRepository.fetch()` returning published title/body/url by semantic kind (shipping/refund/privacy/terms); empty/absent policies unavailable, transport errors remain errors. | No generated copy or inferred free shipping/reservation policy. A02 can consume typed content through injected repository; A00 wires provider and A06 owns reader UI. |
| Unread | Existing `NotificationInbox.unreadCountFor(ownerId)` counts actually received local messages, in-memory, scoped to owner; clearOwner on logout/account change. | Supported local-session count only. No account-wide durable unread API; device delivery/open telemetry is not a synchronized account inbox. A05 can use inbox count, never campaign/ad count. A00 must wire actual received envelope to correct owner and cleanup. |
| Wholesale eligibility | Rewards backend has post-order wholesale detection, but no cart eligibility endpoint/approved thresholds for UI. | Unavailable for cart gold state. Product count, entered email, ledger flag or promotional copy are not eligibility. A00 decision: authoritative cart/provider eligibility response and rule approval. |
| Authenticated rate evidence | Existing Storefront cart buyer identity and actual delivery options, Shopify checkout reconciliation; first-party email is not Shopify authenticated identity. | Rates must come from provider after authenticated Shopify identity + address/cart reconciliation. No local free-shipping entitlement. Requires authorized live/test-service guest/account quotes and return/cancel checks; not verifiable from fixtures. |

## Leased producer seam for A02

`functions/src/catalog.ts` will pass through only authoritative Admin variant `selectedOptions` -> `Map<String,String>` and optional image URL(s) -> `List<String>`, absent => `{}`/`[]`, without product-photo fallback. Existing Admin query/types omit these inputs; A00 lease needed for `functions/src/types.ts`, `functions/src/shopifyAdmin.ts` (actual filename confirmed below) and focused producer fixtures if not already covered. Flutter Firestore variant mapper should read `selectedOptions` object and `imageUrls` string list, default empty for old docs; A02 owns this mapping/cache.

## Reproduction and evidence

F08: controller sends only productKey; route/repository and catalog restock trigger are product-level. F09/F10: RewardsSummary has no membership source and defaults missing cents/time to zero/now. F11: local inbox has scoped unread count, no durable account inbox API. F12: CustomerAccountOrder contains summary totals/status but no line/address/tracking. F17: first-party and Shopify login tokens are distinct. Config inventory: checkout has only example/CI define JSON, no `services/accounts_orders/.env` or root `.env`; CI provider values empty. No installed/runtime environment capability was inferred from examples.

Assigned contracts: UI:G12, G15, G15-A, G17, G17-A, G18, G19, G20, G21, G23, G27, G28, G39. Assigned findings F08–F12/F17.

## Precise decision queue for A00

1. Approve authoritative program membership/tier/next tier/purchase-count/progress/benefits contract and source; keep missing now. No cashback/bonus/reservation rule changes.
2. Exact-variant restock: approve device push channel or provide existing email provider/consent authority, then implement authoritative variant stock registration + trigger. Current product-level FCM cannot satisfy G12; hidden exact-variant action is required now.
3. Account-ad CMS definition, published assets, destinations and version/visibility fields; unavailable until supplied.
4. Secure payment management provider capability/link; absent now.
5. Cart wholesale eligibility source/rules plus authenticated shipping evidence in authorized provider environment; live verification pending.

Final implementation, test logs, captures and exact commit list will be appended here. No feature-screen layout changes planned; visual before/after for those surfaces remains with consuming agents.
