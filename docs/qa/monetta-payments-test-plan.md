# Monetta: Payments Test Plan (DRAFT v0.3, 2026-10-14)
Status: **every case is Not Executed.** I built this plan by reading the code in AlejoReyna/Monetta. I have not run anything. Statuses are Not Executed or Blocked only; nothing has passed.

**Test surface: the running app only** (Android debug APK against staging, later the TestFlight build). The Vercel web version is NOT a test surface.

## 1. Stack summary (from reading the code)
- App: Flutter (iOS/Android/web). Native checkout bridges: `ios/Runner/ShopifyCheckoutBridge.swift`, `android/.../ShopifyCheckoutBridge.kt`.
- Payment provider: **Shopify hosted checkout** through Shopify Checkout Sheet Kit (iOS 3.8.1 / Android 3.6.1 per `docs/SHOPIFY_CHECKOUT_PHASE_0_DECISION.md`). The cart is built with Storefront API `2026-07` (`lib/data/shopify/cart/storefront_cart_api.dart`). The app never sees card data.
- Methods on live monetta.mx checkout: card (Visa/Mastercard/Maestro; Amex unclear), PayPal, Mercado Pago, bank transfer/deposit (manual; the order stays pending until confirmed). Express buttons are probably Shop Pay, Apple Pay and Google Pay (unconfirmed). **No OXXO.** The gateway is unknown until Alexis sends the Shopify Payments screenshot. Staging may be set up differently from live.
- Currency: **v1 is MXN only.**
- Allowed env: staging `monetta-staging.myshopify.com`. Production is out of scope (Phase 0 doc).
- Order mirror: `services/accounts_orders` (Fly.io, Postgres) receives `orders/create` and `orders/updated` webhooks (`shopify/shopify.app.staging.toml`).
- Catalog/inventory: Firebase function `shopifyCatalogWebhook` plus a Vercel copy in `server/catalog` (products/*, inventory_levels/update).
- Refunds/returns: **no app code exists.** They are handled in Shopify admin and appear only through `orders/updated` `financial_status`. No `refunds/create` or `orders/cancelled` subscription.

## 2. Scope / out of scope
In scope: bag → Shopify cart reconciliation → checkout presentation (sheet and external fallback) → completion, cancel, and failure results → local bag clearing → order mirror via webhooks → order status display (incl. refund/cancel labels) → discounts/rewards effect on totals (if enabled) → mobile widths.
Out of scope: Shopify's own checkout internals and PCI scope (hosted by Shopify), production store, apartado/WhatsApp manual orders except labeling, rewards redemption (flag `REWARDS_REDEMPTION_ENABLED=false`), exploit or penetration testing.

## 3. Environments & methods under test
| Item | Value |
|---|---|
| Store | monetta-staging.myshopify.com (needs PM/Eng confirmation) |
| Backend | monetta-accounts-staging.fly.dev |
| Builds | iOS staging scheme, Android debug/staging (build IDs: TBD) |
| Test surface | Android debug APK against staging; later TestFlight. NOT Vercel web |
| Payment gateway in test mode | [payment provider], TBD (needs gateway screenshot; staging may differ from live) |
| Methods | Card (Visa/MC/Maestro; Amex TBD), PayPal, Mercado Pago, bank transfer/deposit (manual), express [Shop Pay/Apple Pay/Google Pay] unconfirmed |
| Currency | MXN only |
| Devices | iPhone small (375pt), Android 360dp, plus one tablet if in scope (web is not a test surface) |

## 4. Test cases (all Not Executed / Blocked)
Shared preconditions **P0** apply unless a case says otherwise: staging debug APK connected to staging (see blocker B0), staging store with the gateway in test mode, an in-stock published test variant priced at MXN $500.00, backend webhooks reachable, and tester access to Shopify staging admin and the `orders_mirror` / `webhook_events` tables. Steps run in the app unless they say "admin" (Shopify staging admin) or "DB" (read-only query by Engineer). Status for every case: **Not Executed** (Blocked by B0 until it is resolved).

### 4.1 Happy path
| ID | Steps | Expected |
|---|---|---|
| PAY-001 Guest card | 1. Log out. 2. Add the test variant (qty 1) to the bag. 3. Tap Checkout. 4. Enter test-approve Visa, a test address and the email qa+001@… 5. Tap Pay. 6. Wait for the sheet to close. | Sheet closes with a completion result. Confirmation screen shows. Bag shows 0 items. Admin: 1 order, `paid`, total MXN $500.00 + shipping. DB: 1 `orders_mirror` row with the same total and `currency_code=MXN` within 60 s; `webhook_events` row `completed`. |
| PAY-002 Logged-in card | 1. Log in as test customer C1. 2. Repeat PAY-001 steps 2–6. 3. Open Orders. | As PAY-001, and the order is linked to C1 in admin. Orders list shows it with status "Confirmado". |
| PAY-003 Multi-line | 1. Add variant A size S qty 2 and variant B size M qty 1. 2. Checkout. 3. Pay with test Visa. | Admin order has exactly 2 line items (A×2 S, B×1 M). Charged total = the app bag total shown before step 2. |
| PAY-004 Discount code | 1. Add the test variant. 2. Enter staging code QA10 (10%) in the bag. 3. Checkout. 4. Pay. | App summary shows −MXN $50.00. Shopify checkout shows the same discount. Admin order total = $450.00 + shipping. |
| PAY-005 Express wallet | 1. Add item. 2. Checkout. 3. Tap the express button (Shop Pay / Google Pay). 4. Approve with a test account. | As PAY-001. **Blocked**: express buttons unconfirmed. |
| PAY-006 Bank transfer | 1. Add item. 2. Checkout. 3. Choose bank transfer/deposit. 4. Complete the order without paying. 5. Open Orders. | Admin order `pending`. App order status "Esperando tu transferencia". Bag cleared. Never "Confirmado". |
| PAY-007 ~~OXXO~~ | n/a | **OUT OF SCOPE**: OXXO is not offered. Not counted. |
| PAY-008 Amex | 1. Add item. 2. Checkout. 3. Enter an Amex test card. 4. Tap Pay. | Either a `paid` order (as PAY-001) or Shopify's card-not-accepted message with no order. Record which. **Blocked**: Amex support unclear. |
| PAY-009 Mastercard / Maestro | 1. Repeat PAY-001 with a Mastercard test card. 2. Repeat with a Maestro test card. | Each produces exactly 1 `paid` order, as PAY-001. |

### 4.2 Declines & failures
| ID | Steps | Expected |
|---|---|---|
| PAY-010 Declined card (inside Shopify checkout) | 1. Add item. 2. Checkout. 3. Enter the gateway's generic-decline test card. 4. Tap Pay. | Shopify checkout shows its decline message and stays open. Pay can be retried with another card. No `paid` order in admin. App banner is **not** shown while the sheet is still open. |
| PAY-011 Specific decline reasons | 1. Repeat PAY-010 with the insufficient-funds, incorrect-CVV and expired-card test cards (one per run). | Each run: decline message inside checkout, no `paid` order, bag unchanged. |
| PAY-012 3DS | 1. Add item. 2. Checkout. 3. Enter the 3DS test card. 4. Fail the challenge. 5. Retry and pass the challenge. | After step 4: no `paid` order, checkout still open. After step 5: exactly 1 `paid` order. |
| PAY-013 Cancel sheet | 1. Add item. 2. Checkout. 3. Close the sheet without paying. | Sheet closes with a cancel result. Bag still has 1 item. No order in admin. No error banner. |
| PAY-014 Expired cart | 1. Add item. 2. Engineer expires/completes the stored cart ID on staging. 3. Tap Checkout. | Message about the bag needing an update (cartExpired/cartCompleted code). No checkout opens on the dead cart. Tapping Checkout again opens a new valid checkout. |
| PAY-015 Unsafe checkout URL | 1. Engineer runs `test/data/shopify/cart/checkout_url_policy_test.dart` plus a build where the cart returns a non-allowlisted host. 2. Tap Checkout. | Banner "No pudimos abrir el pago" (MON-UX-03-B). No sheet. Unit tests green. |
| PAY-016 Double tap | 1. Add item. 2. Tap Checkout twice within 300 ms. | Exactly one sheet opens. The second tap has no effect, or shows "Ya hay un checkout abierto." |

### 4.3 Timeouts / network
| ID | Steps | Expected |
|---|---|---|
| PAY-020 Offline before checkout | 1. Add item. 2. Turn on airplane mode. 3. Tap Checkout. | Banner "No pudimos abrir el pago". No sheet. Bag has 1 item. |
| PAY-021 Network drop mid-payment | 1. Add item. 2. Checkout, enter test Visa. 3. Tap Pay, then turn on airplane mode within 1 s. 4. Wait 30 s, turn the network back on. | No more than 1 `paid` order in admin. App shows the real outcome (completed, or MON-UX-03-DUP behaviour). No second charge. |
| PAY-022 Completion with post-processing failure | 1. Engineer enables fault injection on the bag-clear step. 2. Complete PAY-001. 3. Tap the retry the app offers. | After step 2: message "Shopify confirmó tu compra. Reintenta para actualizar tu bolsa sin volver a pagar." After step 3: bag 0 items, no checkout opens, still 1 order. |
| PAY-023 App killed after Pay | 1. Add item. 2. Checkout, test Visa. 3. Tap Pay and force-quit the app within 1 s. 4. Relaunch. | Covered by MON-UX-03-DUP-1: 1 order, real status shown, bag cleared, no payment reopened. |
| PAY-024 External browser fallback | 1. Add item. 2. Open checkout with the browser fallback. 3. Pay in the browser. 4. Return to the app. | Opening the fallback does not count as completion. After step 4 the app finds the order (DUP logic) and shows its real status. Exactly 1 order. |

### 4.4 MON-PAY-03: PayPal / Mercado Pago handoff
Extra preconditions: PayPal and Mercado Pago sandbox buyer accounts on staging (blocker B5).
| ID | Steps | Expected |
|---|---|---|
| MON-PAY-03-PP1 Return paid | 1. Add item. 2. Checkout → PayPal. 3. Log in to the sandbox and approve. 4. Return to checkout and finish. | Exactly 1 order; financial status recorded in OST-11. Bag 0 items. Status label follows OST rules ("Confirmado" only if `paid`). |
| MON-PAY-03-PP2 Return without paying | 1. Add item. 2. Checkout → PayPal. 3. Tap cancel / return to the store. 4. Close the checkout. | No `paid` order. Bag 1 item. App shows "No se completó tu pago" (MON-UX-03-A), or nothing if the user just closed the sheet. Whether an order exists is recorded in MON-PAY-03-ORD. |
| MON-PAY-03-PP3 Drop off mid-flow | 1. Add item. 2. Checkout → PayPal. 3. On the PayPal login page, press Android Back until checkout closes. | No charge. Bag 1 item. Checkout can be reopened and paid (1 order total). |
| MON-PAY-03-PP4 App killed during handoff | Run A: 1. Start PP1 and approve in PayPal. 2. Force-quit before returning. 3. Relaunch. Run B: 1. Start PP2 but force-quit on the PayPal page. 2. Relaunch. | A: as MON-UX-03-DUP-1 (1 order, real status, bag cleared, no reopen). B: no order, bag 1 item, no "Estamos revisando" banner left stuck after 30 s. |
| MON-PAY-03-MP1 | Steps as PP1 with Mercado Pago | As PP1 |
| MON-PAY-03-MP2 | Steps as PP2 with Mercado Pago | As PP2 |
| MON-PAY-03-MP3 | Steps as PP3 with Mercado Pago | As PP3 |
| MON-PAY-03-MP4 | Steps as PP4 with Mercado Pago | As PP4 |
| MON-PAY-03-ORD Is an order created for failed payments? | 1. Run PAY-010, PP2 and MP2. 2. After each one, check admin → Orders and admin → Abandoned checkouts. 3. DB: check `orders_mirror` for a new row. | Record a table: method → order created (Y/N) → financial_status. If Y, "Pago rechazado"/"Pago no completado" belong in order history (OST-07/OST-03). If N, they belong in the cart banner (MON-UX-03-A). Hand to Designer/PM. |

### 4.5 Order status (per PR #14)
Shared steps for OST-01..10: 1. Create or move a test order to the state given (admin, or via the payment method). 2. Wait for the `orders/updated` mirror (≤60 s, check DB). 3. Open Orders list in the app, then order detail. 4. Record the label, detail text and style.
Global expectations for every OST case: no status text contains "Te avisaremos"; "Con ajuste" never appears; payment state overrides shipping state.
| ID | Order state | Expected label / detail |
|---|---|---|
| OST-01 | `pending` + bank transfer | "Esperando tu transferencia" |
| OST-02 | `pending`, not a transfer (only if OST-11 shows this exists) | "Pago en proceso". "Pago en revisión" / "Lo verás aquí cuando se confirme." only if OST-11 confirms non-transfer pending exists. Otherwise Not Applicable. |
| OST-03 | `authorized` | "Pago en proceso" |
| OST-04 | `paid`, unfulfilled | "Confirmado", detail exactly "Aquí verás cuando tu pedido salga." |
| OST-05 | `partially_paid`; `expired`; unknown value (Engineer test fixture); empty/null | Each shows "Pago en proceso", never "Confirmado". |
| OST-06 | `paid` + fulfilled / in transit | "En camino" |
| OST-07 | `paid` + delivered | "Entregado" |
| OST-08 | `voided`; cancelled order | Each shows "Cancelado" |
| OST-09 | `partially_refunded`; refund in progress | "Reembolso en proceso", detail "Lo verás aquí cuando se complete." |
| OST-10 | `refunded` | "Reembolsado", neutral (non-error) style, detail "Te devolvimos [monto] a tu método de pago." with the real MXN amount, or "Te devolvimos tu pago." when the amount is unknown. |
| OST-12 | Precedence: 1. Fulfil a `paid` order (shows "En camino"). 2. Refund it fully. 3. Separately: fulfil, then cancel and refund another order. | Order 1 shows "Reembolsado". Order 2 shows "Cancelado". Neither shows "En camino" after step 2/3. |
| OST-13 | Copy sweep: open every order produced by OST-01..12 | Zero occurrences of "Te avisaremos" or "Con ajuste" across list and detail. |
| OST-11 | Status per method: 1. Complete one order each with bank transfer (unpaid), Mercado Pago, PayPal and card. 2. In admin and DB, read `financial_status` immediately and again after 10 min. | Table of method → financial_status (t0, t+10m) → app label. Feeds OST-02 and MON-PAY-03-ORD. |
"Pago no completado" and "Pago rechazado" (from the Designer's sheet) are added to order history only if MON-PAY-03-ORD shows Shopify creates orders for them.

### 4.6 MON-UX: banners & prefill
| ID | Steps | Expected |
|---|---|---|
| MON-UX-02 Prefill | 1. Log in as C1 (email and phone set). 2. Add item. 3. Checkout. 4. Log out, add item as guest, checkout. | Step 3: Shopify shows C1's email and phone already filled in. Step 4: no C1 data shown. |
| MON-UX-03-A "No se completó tu pago" | 1. Add item. 2. Checkout → PayPal or Mercado Pago. 3. Return without paying (as PP2/MP2). | Back in the bag: banner "No se completó tu pago" with a retry action. Retry opens checkout. Bag 1 item. A declined card is tested inside Shopify checkout (PAY-010), not in this banner. |
| MON-UX-03-B "No pudimos abrir el pago" | 1. Add item. 2. Turn on airplane mode. 3. Tap Checkout. | Banner "No pudimos abrir el pago" with retry. No sheet. Retry with network on opens checkout. |
| MON-UX-03-C "Estamos revisando tu pago" | 1. Trigger DUP-1 with Shopify unreachable (DUP-4). | Banner "Estamos revisando tu pago". **No retry/pay button.** Bag not re-chargeable. |

### 4.7 MON-UX-03-DUP: missed completion event (release requirement; S1 if any fails)
Proposed behaviour (still to confirm with Engineer): after an interrupted checkout, the app asks Shopify whether an order exists for that checkout, every 3 s for up to 30 s.
| ID | Steps | Expected |
|---|---|---|
| DUP-1 Paid, event missed | 1. Add item. 2. Checkout, test Visa. 3. Tap Pay and force-quit within 1 s (or Engineer suppresses the completion event). 4. Relaunch and open the bag. | Within 30 s: app finds the order and shows its real status ("Confirmado" if `paid`). Bag 0 items. Payment is never reopened. Admin: exactly 1 order. |
| DUP-2 Pending transfer, event missed | 1. As DUP-1 but choose bank transfer. 2. Relaunch. | Shows "Esperando tu transferencia". Bag cleared. Payment never reopened, no pay button. |
| DUP-3 No double charge | 1. After DUP-1 step 4, try to add the same items and check out again within 30 s. | The previous cart cannot be charged again. Any new checkout is a new cart created deliberately by the user. Admin shows no unintended 2nd order from the original checkout. |
| DUP-4 Shopify unreachable | 1. As DUP-1, but block network to Shopify before relaunch. 2. Wait 60 s. 3. Restore the network. | Steps 1–2: "Estamos revisando tu pago", no retry/pay button. Step 3: resolves to the real status as DUP-1. |
| DUP-5 Latency measurement | 1. Complete 10 card orders and 5 PayPal/MP orders on staging. 2. For each, record the time from Pay tap to the order appearing via the Storefront/Customer API. | Report min/median/p95. If p95 > 25 s, recommend tuning the 30 s window. Data only (no pass/fail). |

### 4.8 Webhooks / async confirmation
| ID | Steps | Expected |
|---|---|---|
| WH-001 orders/create mirrored | 1. Complete PAY-001. 2. DB: query `webhook_events` and `orders_mirror` for the order ID. | 1 `webhook_events` row with status `completed`. Mirror row: financial_status `paid`, currency `MXN`, total matches admin. |
| WH-002 Invalid HMAC | 1. Engineer runs `services/accounts_orders/test/verifyHmac.test.ts` and `webhookRoutes.test.ts`. 2. Engineer sends one staging delivery with a wrong signature through the test harness. | Tests green. HTTP 401. No new DB row. |
| WH-003 Duplicate delivery | 1. Complete PAY-001. 2. Admin/CLI: resend the same `orders/create` delivery. 3. DB check. | Second delivery returns 2xx. Still 1 mirror row and 1 `webhook_events` row (`completed`). No duplicate effects. |
| WH-004 Same ID, different body | 1. Engineer replays a webhook ID with a changed body (harness). | Non-2xx ("identity conflicts"). Mirror unchanged. |
| WH-005 Out of order | 1. Engineer sends an `orders/updated` with an older `updated_at` after a newer one. | Mirror keeps the newer state. |
| WH-006 Concurrent duplicate | 1. Engineer sends 2 deliveries with the same ID at once. | One processes. The other gets a retryable non-2xx. 1 mirror row. |
| WH-007 Backend down | 1. Stop the accounts service. 2. Complete PAY-001. 3. Restart after 5 min. | Shopify retries and the order is mirrored exactly once within 15 min of the restart. |
| WH-008 Wrong shop domain | 1. Engineer sends a signed delivery with a different `X-Shopify-Shop-Domain` (harness). | Catalog function: 400. Accounts service: rejected (behaviour recorded). No DB effect. |

### 4.9 Refunds / cancellations
| ID | Steps | Expected |
|---|---|---|
| REF-001 Full refund | 1. Complete PAY-001. 2. Admin: refund the full amount. 3. Wait ≤60 s. 4. Open the order in the app. | Mirror `refunded`. App: "Reembolsado", "Te devolvimos MXN $[total] a tu método de pago." (OST-10). |
| REF-002 Partial refund | 1. Complete PAY-003. 2. Admin: refund line B only. 3. Open the order. | Mirror `partially_refunded`, total = current_total_price. App: "Reembolso en proceso" (OST-09). |
| REF-003 Cancel unfulfilled | 1. Complete PAY-001. 2. Admin: cancel and refund. 3. Open the order. | "Cancelado". Mirror updated through `orders/updated`. |
| REF-004 Refund after fulfilment | 1. Complete PAY-001. 2. Admin: fulfil. 3. Admin: refund fully. 4. Open the order. | "Reembolsado", never "En camino" (OST-12). |
| REF-005 Void authorization | 1. Engineer sets manual capture (if used). 2. Place a card order. 3. Admin: void. | Mirror `voided`. App "Cancelado". No charge. **Blocked** until capture mode is known. |
| REF-006 Partial capture | 1. Manual capture on. 2. Place a $500 order. 3. Admin: capture $300. | Mirror and app reflect the captured amount; label per OST rules. **Blocked** until capture mode is known. |
| REF-007 Refund PayPal / Mercado Pago | 1. Complete PP1 and MP1. 2. Admin: refund each fully. | Each shows "Reembolsado". Sandbox account shows the refund. |

### 4.10 Inventory / order state
| ID | Steps | Expected |
|---|---|---|
| INV-001 Last unit | 1. Admin: set stock = 1. 2. Buy it (PAY-001). 3. Wait ≤60 s, refresh the product in the app. | Order ok. Product shows sold out / not addable. |
| INV-002 Race on last unit | 1. Stock = 1. 2. Two devices add it to the bag. 3. Both tap Pay within 2 s. | Exactly 1 order. The other device gets Shopify's out-of-stock message and is not charged. |
| INV-003 Goes out of stock in bag | 1. Add item. 2. Admin: stock = 0. 3. Tap Checkout. | The app shows the item unavailable before checkout, or Shopify blocks it. No order. Clear Spanish copy. |
| INV-004 Price change in bag | 1. Add item ($500). 2. Admin: change to $600. 3. Tap Checkout. | App bag summary refreshes to $600 before the sheet. Charged $600. |
| INV-005 Unpublished in bag | 1. Add item. 2. Admin: archive the product. 3. Tap Checkout. | Line flagged or removed. Checkout is not opened with the archived item. |
| INV-006 Shipped ≠ delivered | 1. Admin: fulfil an order without a delivered event. 2. Open the order. | "En camino", not "Entregado". |

### 4.11 Mobile width / UX trust
| ID | Steps | Expected |
|---|---|---|
| MOB-001 360dp | 1. Android emulator 360×640 dp. 2. Run PAY-001. 3. Screenshot bag, sheet and confirmation. | No clipped totals or CTAs. The Pay button is visible with the keyboard open. |
| MOB-002 Large font | 1. Device font size largest. 2. Run PAY-001 and PAY-010. | Bag summary, banners and error copy fully readable without overlap. |
| MOB-003 Error copy review | 1. Run PAY-013, PAY-020, MON-UX-03-A/B/C. 2. Screenshot each. | Copy matches the Designer's sheet exactly. Each has a clear next action (except C, which has no retry). |
| MOB-004 Background mid-checkout | 1. Open checkout. 2. Switch to another app for 30 s. 3. Return and pay. | Sheet state kept. Exactly 1 terminal result and 1 order. |

### 4.12 Account deletion (PR #13)
Extra precondition: PR #13 build on staging.
| ID | Steps | Expected |
|---|---|---|
| DEL-01 Unpaid order blocks | 1. C2 has an unpaid order. 2. Account → Delete account → confirm. | Deletion blocked with an explanation. C2 can still log in. |
| DEL-02 Delete, no open orders | 1. C3 has only completed orders. 2. Delete account → confirm. 3. Log out and try to log in as C3. | Copy exactly "Tu cuenta fue eliminada. Tus datos de compra se borrarán en un proceso que puede tardar hasta 6 meses." Login fails. |
| DEL-03 Idempotent | 1. Trigger deletion for C3 again (second device or retry). | No error. No duplicate audit rows or requests. Same final state. |
| DEL-04 Admin state | 1. After DEL-02, admin: open C3. | Customer erasure requested. Orders retained. |
| DEL-05 Pending transfer blocks | 1. C4 has a pending bank-transfer order. 2. Delete account → confirm. | Deletion blocked. **S1 if deletion goes through.** |
| DEL-06 Refund after erasure request | 1. After DEL-04, admin: refund one of C3's orders. | Refund succeeds. Mirror updates without errors. |
| DEL-07 No PII left | 1. Engineer runs a read-only query of the audit log and C3's anonymized Postgres rows. | No email, phone, address or payment data; only opaque IDs. |

### 4.13 PCI / data hygiene (checks only, no attacks)
| ID | Steps | Expected |
|---|---|---|
| SEC-001 Device logs | 1. `adb logcat` during PAY-001 and PP1. 2. Search for the checkout URL host + path, the email, and card digits. | No matches. |
| SEC-002 Backend logs | 1. Pull staging logs for the PAY-001 window. 2. Search for the email, phone and address. | Only IDs/topics present. |
| SEC-003 Secrets in build | 1. Run `bin/check_no_secrets.sh`. 2. Search the APK strings for `shpat_`/`shpss_`. | Script passes. No matches. |
| SEC-004 WebView permissions | 1. During checkout, trigger any camera/mic/location prompt that exists. | Denied. No system prompt shown. |

### 4.14 Known issue to retest
| ID | Steps | Expected |
|---|---|---|
| KI-01 Add-to-cart (seen on live web, unconfirmed) | 1. In the APK, open 3 products (one per size type). 2. Select size. 3. Tap add-to-cart. | The bag count goes up each time. Only file a bug if it reproduces in the app. |

## 4b. Blockers
| # | Blocker | Blocks | Owner |
|---|---|---|---|
| **B0 (top)** | `config/dart_defines.staging.json` missing; the current APK runs offline on the local catalog only. Alexis to send it to Engineer privately (never in chat or git). | **Everything** | Alexis → Engineer |
| B1 | Staging Android debug APK built with B0 (later TestFlight) | All app cases | Engineer |
| B2 | Shopify staging admin access | REF, OST, MON-PAY-03-ORD, DEL-04/06, WH-003 | PM / Alexis |
| B3 | Backend log + Postgres read access (staging) | WH, SEC-002, DEL-07, mirror checks | Engineer |
| B4 | Shopify Payments / gateway screenshot | Gateway, Amex, express, staging-vs-live parity | Alexis |
| B5 | Test cards + PayPal/Mercado Pago sandbox accounts | PAY, MON-PAY-03, DUP, declines, 3DS | Engineer / PM |

## 5. Risks not covered
- Shopify checkout internals, fraud analysis, chargebacks/disputes (no app code).
- Gateway-specific behavior until the gateway is confirmed; differences between staging and live config.
- OXXO (not offered). Vercel web checkout (not a test surface).
- Production config (`shopify.app.production.toml`) and live payments.
- Non-MXN currencies / Markets (v1 is MXN only), taxes, shipping rate accuracy (unless PM adds them).
- Rewards redemption (disabled), apartado/WhatsApp orders paid outside checkout.
- Returns as a workflow: no in-app returns feature was found.

## MON-PAY-05 (added v0.3.1) — all Blocked (B0 staging config, Shopify staging admin)
| ID | Steps | Expected | Status |
|---|---|---|---|
| PAY05-01 | Run backfill script in default dry-run on staging | Lists only pending orders missing payment method; writes nothing (verify DB unchanged) | Blocked |
| PAY05-02 | Run in write mode on staging; open affected orders in app (list + detail) | Pending transfer orders show "Esperando tu transferencia" + "Pedir datos de pago por WhatsApp" (WhatsApp icon, opens chat with order number; no dead text "Ver datos de pago"); card and paid orders unchanged | Blocked |
| PAY05-03 | Run script a second time | 0 orders changed | Blocked |
| PAY05-04 | Open a "Pago en proceso" order with no method, then after method saved | WhatsApp line only in detail, message includes order number; disappears once method saved | Blocked |
| PAY05-05 | Same transfer order loaded via app vs via webhook | Same label and action in list and detail | Blocked |

## PR #15 payment logos (added v0.3.2) — Blocked (B0)
| ID | Steps | Expected | Status |
|---|---|---|---|
| LOGO-01 | On iPhone and Android staging builds, compare Home footer logos with methods shown in in-app Shopify checkout | Every logo matches a method actually offered; Apple Pay/Google Pay hidden while flag off; when on, only Apple Pay on iOS and only Google Pay on Android | Blocked |
| PAY05-06 | Pending order with unrecognized gateway (stored as "otro", e.g. PayPal/Mercado Pago pending) | "Pago en proceso"; no bank details, no "¿Elegiste transferencia?"; detail shows "¿Dudas con tu pago? Escríbenos por WhatsApp." with order number | Blocked |
| PAY05-07 | Pending order with known non-transfer method (card/shopify_payments) | "Pago en proceso" + "¿Dudas con tu pago?" line; no bank details | Blocked |
| PAY05-08 | Backfill script on order with gateway it can't recognize | Stores "otro", never bank_deposit/manual | Blocked |

## v0.4 updates (PR #16 round 2)
- PAY05-06 / PAY05-08 updated: unrecognized gateway is stored as `other:<nombre>` (not "otro"). Expected: "Pago en proceso" + "¿Dudas con tu pago?", no bank details.
- Normalization expectations: PayPal variants -> `paypal`; Mercado Pago -> `mercadopago`; `shopify_payments` -> `card` (webhook and backfill); empty or numeric-only gateway -> null ("sin método", shows "¿Elegiste transferencia?…", not a Fail).
- PAY05-09 (new): pending card order (`card`) shows "Pago en proceso" and "¿Dudas con tu pago?", no bank details. Status: Blocked (staging build).
- Dry-run check (new): every real gateway name maps to paypal / mercadopago / card / bank_deposit / manual / other:<x> / null(empty or numeric). Any wrong mapping = Fail, blocks production run. Status: Blocked (Admin token).
- Dry-run tokens kept as-is: gift_card, shop_pay, apple_pay, google_pay, manual; COD -> cash_on_delivery. Any cash_on_delivery, apple_pay or google_pay order in dry-run = separate finding (COD not offered; wallets flagged off), not a mapping Fail.
- PAY05-10 (new): pending order with cash_on_delivery / gift_card / shop_pay shows "Pago en proceso" + "¿Dudas con tu pago?", never transfer copy or bank details. Blocked (staging build).

## v0.5 static review findings (2026-10-15) — STATIC REVIEW ONLY, NOT A PASS

Read-only review of PR diffs #13–#16 (current heads on 2026-10-15) against this plan. No case changes status: everything stays Blocked until the staging build. Line numbers are in the PR head version of each file (approx. where computed from the diff).

| # | PR | File:line | Finding | Sev | Covered by |
|---|---|---|---|---|---|
| F1 | #16 | services/accounts_orders/src/orders/paymentMethod.ts:~66-82 (KNOWN_METHOD_TOKENS) + lib/features/orders/order_status.dart (orderPaymentMethodIsBankTransfer) | A custom manual payment method whose name is Spanish (e.g. "Transferencia bancaria", "Depósito") is stored as `other:transferencia_bancaria`. #16 removed the old fuzzy `transferencia`/`deposito` match, so that order shows "Pago en proceso" + "¿Dudas con tu pago?" instead of "Esperando tu transferencia". Only the literal tokens `bank_deposit`/`manual` show transfer copy. Correct per spec *if* Shopify sends `manual`/`bank_deposit`; depends on how the staging/prod manual method is named (need screenshot). | S1 (if store uses custom name) | Partly: dry-run check (wrong-method = Fail). New PAY05-11 added |
| F2 | #16 | lib/features/orders/order_detail_screen.dart:~163 and order_status.dart:~131 (actionLabel) | "Ver datos de pago" is still plain `Text` with no onTap in the diff read; label not yet "Pedir datos de pago por WhatsApp". Engineer says fix in progress. | S1 | PAY05-02 (updated), PAY05-12 new |
| F3 | #16 | order_detail_screen.dart:~82-95 | For `awaiting_transfer` neither WhatsApp help line shows (missing-method line needs null; question line excludes transfer), so the only path to bank details is the F2 action. If F2 is not wired, transfer customers have no way to get the CLABE. | S1 (resolved once F2 is fixed) | PAY05-12 |
| F4 | #16 | backfillPaymentMethod.ts:~154-178 vs webhooks/handlers.ts:~166-170 | Webhook normalizes `payment_gateway_names` + order `gateway` + `transactions` (incl. `type`); backfill queries `paymentGatewayNames` + `transactions{gateway,kind,formattedGateway}` only (no order gateway, no type). Same normalizer, so same result in the usual case, but a payload where only `gateway`/`type` carries the method would differ. | S3 | PAY05-05 (partial) |
| F5 | #16 | pgOrdersRepository.ts:~72 (`COALESCE(EXCLUDED.payment_method, orders_mirror.payment_method)`) | Once stored, a method is never replaced (e.g. a later webhook with a different/more precise gateway). Prevents null-wipe (good) but a wrong first value sticks. | S3 | Not covered (note for dry-run review) |
| F6 | #16 | paymentMethod.ts:~51-60 (METHOD_ALIASES) | Card aliases only `shopify_payments`/`card`; names like "Credit Card", "Tarjeta de crédito", "Stripe", "Conekta", "Openpay" become `other:…`. Not wrong per spec (shows "¿Dudas con tu pago?"), but dry-run reviewer must check each `other:` name. `cash_on_delivery_cod` alias covers "Cash on Delivery (COD)" ✓. | S3 | Dry-run check |
| F7 | #16 | normalizer | Verified by reading: case/spacing variants of `shopify_payments`/`card` → `card`; PayPal/Mercado Pago variants → `paypal`/`mercadopago`; digits/empty/emails/processing kinds → dropped → null; unknown → `other:`. Multi-token lists (e.g. `gift_card,card`) are not transfer because `every` token must be bank_deposit/manual. Matches plan. | — | PAY05-06..10 |
| F8 | #14 | lib/features/orders/order_status.dart:~105-111 | `partially_refunded` maps to "Reembolso en proceso", but a partial refund in Shopify is a completed refund of part of the order. Copy may mislead. | S2 | Partly (4.5 refund cases) — confirm with designer |
| F9 | #14 | order_status.dart (payment switch) | Cancellation only detected via financial status `voided/cancelled`; Shopify cancel is `cancelled_at`, not a financial status. A cancelled order that is still `paid` (refund pending) or `pending` shows "Confirmado"/"Pago en proceso", not "Cancelado". | S2 | 4.9 cancel cases (verify on device) |
| F10 | #14 | order_status.dart | Verified: "Confirmado" only for `paid`; unknown/empty/pending/authorized → "Pago en proceso"; "En camino"/"Entregado" require `paid` (payment overrides shipping); `refunded` → "Reembolsado" with amount. Matches plan. | — | 4.5 |
| F11 | #14 | lib/data/customer_auth/customer_orders.dart:~380-392 | Customer Account path only lowercases/trims `transactions.type`; it does not apply the server normalizer (no `shopify_payments`→`card`, no `other:`). Harmless for transfer detection (exact tokens), but app and mirror may store different strings for the same order. | S3 | PAY05-05 |
| F12 | #13 | services/accounts_orders/src/privacy/openOrderBlock.ts:~58-90 | Pending/authorized/unknown financial status blocks deletion ✓ (covers pending transfer). Cancellation is detected only by tag (`cancelled/cancelado`) or voided/refunded; a Shopify-cancelled order without that tag and still unfulfilled blocks deletion indefinitely. | S2 | 4.12 (add cancelled-no-tag case) |
| F13 | #13 | accountDeletionService.ts (findBlockingOrder) | Block uses only `orders_mirror` rows. An order whose webhook never arrived is invisible, so deletion could proceed with an open pending-transfer order. | S2 | Not covered — new case DEL-x needed |
| F14 | #15 | lib/features/home/home_payment_methods.dart:~1453-1457 vs HomePaymentMethodsLine | Line text matches spec; Apple/Google Pay gated by `kExpressPayLogosEnabled=false`, logo row by `kPaymentLogoRowEnabled=false` ✓. The widget hardcodes the tail string instead of using the constant (drift risk), and `maxLines: 2` + ellipsis can cut "transferencia." at large text sizes. | S3 | LOGO cases / 4.11 large text |

### PAY05 case updates (v0.5)
- PAY05-02 updated: transfer action is "Pedir datos de pago por WhatsApp" with WhatsApp icon (replaces "Ver datos de pago").
| ID | Steps | Expected | Status |
|---|---|---|---|
| PAY05-11 | Pending order paid with the store's real manual/transfer method (exact gateway name from Settings > Payments) | Stored as `manual` or `bank_deposit` and shows "Esperando tu transferencia"; if stored as `other:<nombre>` → Fail (S1), report gateway name | Blocked |
| PAY05-12 | Open pending transfer order, list and detail; tap "Pedir datos de pago por WhatsApp" | Label exact, WhatsApp icon, opens wa.me with "Hola, quiero los datos de pago de mi pedido #…"; no bank details in app; "Ver datos de pago" appears nowhere | Blocked |
| PAY05-13 | Account deletion with a pending order that is not in orders_mirror (webhook missed) | Deletion blocked; if it proceeds → S1 finding | Blocked |

## v0.6 updates (priorities from PM, copy from Designer)
- OST-12 (new, F8): partially_refunded shows "Reembolso parcial" (neutral style) + "Te devolvimos [monto] de [total] a tu método de pago."; if amount missing, "Te devolvimos una parte de tu pago a tu método de pago."; shipping status shown as secondary info. Blocked (staging).
- OST-13 (new, F9): order cancelled in Shopify shows "Cancelado" regardless of financial_status (paid/pending). Blocked.
- PAY05-11 (F1): real manual-method name from 5 pm capture must map to transfer via alias list. Blocked (capture).
- DEL-08 (F12): cancelled unfulfilled order without tag must not block deletion. DEL-09 (F13): open order whose webhook never arrived must block deletion. Blocking for merge of #13.
- LOGO-01 addendum (F14): at 200% text the methods line may wrap to 3+ lines, never ellipsis, all four methods visible.
- PAY05-14 (new, F1 x F5): order previously stored as other:<alias> is corrected to bank_deposit by backfill once alias added; shows "Esperando tu transferencia" + "Pedir datos de pago por WhatsApp". If not corrected, F5 escalates to S1. Blocked (Admin token).
- PAY05-02/12 updated: transfer orders show "Pedir datos de pago por WhatsApp" with icon, opens chat with order number (code in #16, not device-tested).
- OST-13 split: (a) cancelled + paid -> "Cancelado" + "Si ya pagaste y tienes dudas sobre tu reembolso, escríbenos por WhatsApp." with order-number link; (b) cancelled + pending -> only "Cancelado"; (c) cancelled + refunded -> "Reembolsado". Blocked (staging).
- OST-12 fallback: amount missing, 0, or > total -> "Te devolvimos una parte de tu pago a tu método de pago."; shipped/delivered secondary line "En camino"/"Entregado".
- OST-13d (new): cancelled + partially_refunded -> main "Reembolso parcial" + amount (or fallback), secondary "Cancelado" (overrides shipping line), plus WhatsApp refund-doubt line with order number. Blocked (staging). #14 scope frozen after this.
- MON-UX-03 banners per Designer: "Confirmando tu pago…" (30 s, retry disabled); banner 1 "No se completó tu pago" behind flag OFF until tokens ticket; banner 2 only when checkout fails to open; banner 3 "Estamos revisando tu pago" on timeout or lookup failure (no retry; "Ver mis pedidos" + WhatsApp).
- DUP-02 (new, S1): with banner 3 active, tapping pay from cart opens sheet "Es posible que ya hayas pagado" ("Ver mis pedidos" primary, "Pagar de todos modos" secondary). Fail if checkout opens directly. Residual double-charge risk remains until checkout_token/cart_token ticket (S1, release blocker) lands. Blocked (staging).
- PAY05-02 revised (MON-PAY-05 criterion change): list card for pending transfer shows only "Esperando tu transferencia", no action text, tap opens detail; "Pedir datos de pago por WhatsApp" only in detail. Blocked (staging).
- DEL-10 (new, approved): refund in process (status, tag, or cancelled+charged not refunded) blocks deletion with "Tienes un reembolso en proceso. Podrás eliminar tu cuenta cuando se complete." Released only by refunded / voided / cancelled without charge. Sub-case: cancelled + partially_refunded must stay blocked. Blocked (staging).
- DEL-11: 503 Shopify down -> "No pudimos revisar tus pedidos" / "No se eliminó nada. Inténtalo más tarde." + Reintentar; nothing deleted. DEL-12: legacy Monetta session -> re-login screen, returns straight to "Eliminar mi cuenta". DEL-13: >2000 orders -> WhatsApp help screen, nothing deleted.
- DUP-03 (approved): warning persisted on device (flag + time, no token), lasts 24 h or until order appears; survives app restart. DUP-04: only empty cart, completed checkout, or order appearing clears it; quantity change does not. Blocked (staging).
- DEL-10b: cancelled + partially_refunded -> "Necesitamos revisar un reembolso de tu pedido [número] antes de eliminar tu cuenta." + WhatsApp; released by tag `monetta-reembolso-revisado` unless a real refund is still in process. DEL-14: email mismatch after re-login (checked in backend) -> "Entraste con otra cuenta", masked email, nothing deleted, old session kept. Blocked (staging).
- MON-UX-03-DUP: flag stays OFF; banner 1 never on timeout. Expected Pass. Measure real webhook latency in staging; report if typically >30 s.
- TOK-01 (new): webhook order without checkout_token/cart_token -> log `order_webhook_missing_checkout_tokens` with order number + missing field, never token value; new orders arriving without tokens = Fail. Blocked (staging + migration 015).
- Merge order (PM): #14 -> #16 -> #18 -> #17; #13/#15 anytime; all stay draft until Payments Pass on staging.
- TOK-02 (new): token match must be to the current attempt only; an older order sharing the same cart_token (reused cart) must not open/clear the warning. Empty tokens never match. Blocked (staging + 015).
- DEL-10b confirmed: tag `monetta-reembolso-revisado` releases cancelled+partially_refunded only. DEL-10c (new): cancelled + paid/partially_paid without refund stays blocked even with tag; text "Necesitamos revisar el pago de tu pedido [número] antes de eliminar tu cuenta. Escríbenos y lo resolvemos." + WhatsApp; released once refunded/voided. Refund pending keeps DEL-10 text. Blocked (staging).

## Web theme (MON-WEB-02) - WEB-PAY (new 2026-10-16)
Env: unpublished duplicate theme on monetta-staging (preview link only, never production). Checkout = Shopify. No real charges. All Blocked until preview link exists.
- WEB-PAY-01 (S1): cart -> Shopify checkout keeps items, qty, variant and total in MXN; subtotal on theme = checkout subtotal.
- WEB-PAY-02 (S2): no payment logos shown; line "Pagos seguros con…" names only methods active in staging Settings > Payments. Any inactive method named = Fail.
- WEB-PAY-03 (S1): test-mode card order from web lands in orders_mirror like app orders (same total, MXN, payment method normalized per #16) within 60 s.
- WEB-PAY-04 (S2): if classic customer accounts, order list/detail on theme follows app copy rules ("Esperando tu transferencia" only for bank_deposit/manual, else "Pago en proceso"; WhatsApp only in detail). If new customer accounts, test on Shopify pages instead and note as N/A for theme.
- WEB-PAY-05 (S2): agotado variant cannot be added to cart or reach checkout.
- WEB-PAY-06 (S3): theme preview cart and app cart do not mix or clear each other for same customer (record behavior).
