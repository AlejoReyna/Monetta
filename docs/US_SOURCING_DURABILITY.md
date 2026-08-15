# US sourcing durability

Investigation of the US-catalog prototype against the brief “detect products
available in the United States, sell them in Mexico, take a seller
commission.” Written so the next person inheriting this repo does not
collapse `ownerProcurement` into automated dropshipping.

> If code and this document disagree, one of them is a bug — fix both in the
> same commit. The live product contract remains
> [`ARCHITECTURE.md`](ARCHITECTURE.md); this note is the why behind the
> external-catalog boundary, not a license to delete it.

Reviewed against the tree on 14 August 2026
(`agent/luxury-checkout-us-catalog`).

## The one-paragraph version

There is no technical trick that makes unauthorized luxury dropshipping last.
Buying the piece by hand after the Mexican sale — instead of scripting
checkout on coach.com — does not change that. Tapestry (Coach), Capri
(Michael Kors), GUESS, and Steve Madden already have trademark, storefront
terms, Shopify and app-store IP takedowns, and the habit of cancelling
orders to known US mailboxes. The version of Monetta that survives is the
one this repo already started: **genuine goods, legally imported, sold with
honest lead times, with the US catalog used as research — not advertised as
stock Monetta does not hold.**

## What the app actually is today

Monetta is a Flutter + Shopify storefront for imported handbags, wallets, and
watches sold in Mexico. It is **not** a dropshipping engine.

| Layer | What it does | What it does not do |
|---|---|---|
| Flutter app | Sells Monetta’s own Shopify catalog in MXN; guest checkout; WhatsApp *apartado*; on-device recommendations | Does not let a shopper buy a Coach.com / michaelkors.com / guess.com / stevemadden.com listing |
| `services/catalog_monitor` | Gated daily crawl of those public US catalogs | No order placement, no commissions, no fulfillment |
| `services/accounts_orders` | First-party sessions, Shopify webhooks, GDPR-style redact, order history | No seller accounts, no payouts |

The domain model is explicit. `CatalogItem`
(`lib/domain/catalog_item.dart`) has two live purchase modes:

- Shopify items → `PurchaseMode.monettaCheckout` (MXN, bag, Shopify, WhatsApp).
- US listings → `PurchaseMode.ownerProcurement` (USD, merchant link, **cannot**
  enter the bag, Shopify checkout, or WhatsApp).

The mixed feed (`lib/app/mixed_feed.dart`) dedupes by exact `brand::title`,
never converts USD↔MXN, and the feature is off unless the binary is built
with `--dart-define=ENABLE_EXTERNAL_CATALOG=true`. That boundary is the most
important thing in the external-catalog work. A “dropship US → MX with a
seller commission” brief would destroy it.

`services/catalog_monitor/README.md` states the same limit in one sentence:
this is not an automated dropshipping, affiliate, or fulfillment system.

## What “brands don’t want this” actually means

This is not one regulation. It is four pressure points, and they kill
different parts of the product.

### 1. Trademark and brand control

Tapestry, Capri, GUESS, and Steve Madden run authorized-retailer programs.
They do not have to “allow” a Mexican app to list their catalog. They can
send a cease-and-desist, file IMPI / USPTO complaints, take down Shopify
listings, take down App Store / Play listings, and sue over logos, official
photos, and anything that looks like an official store.

Mexico generally treats **parallel import of genuine goods** as legal under
international trademark exhaustion. Mexican courts have usually refused to
treat authentic gray-market goods as trademark infringement. That is the
legal opening this business sits in.

It is **not** a license to:

- look like the official Coach / Michael Kors store
- use their product photography and logos as the Monetta catalog
- scrape their site and auto-sell “in stock in the United States”
- promise official warranty, official boutique service, or authorized-dealer
  status
- dropship by checking out on the brand site with the customer’s money

Tapestry actively litigates brand control. Authorized-dealer contracts also
let a house cut off anyone they catch feeding the gray market.

Patents are a separate problem: Mexico does **not** exhaust patent rights
the same way as trademarks. Do not assume a bag hardware design or a watch
movement is as free to parallel-import as the word mark.

### 2. Site terms and technical blocks

`catalog_monitor` already documents the operational fact: `coach.com`
geo-redirects a Mexican IP to `mx.coach.com`, live crawls have never been
accepted operationally, and the README says the correct response to a block
is to **stop**, not to work around it. DataDome / PerimeterX / Cloudflare
will keep getting better.

A “forever” crawler that impersonates browsers, rotates residential proxies,
or solves CAPTCHAs is both fragile and out of scope for this codebase. The
live-crawl gate, identifiable `USER_AGENT`, robots.txt check, market-host
guard, and stop-on-CAPTCHA policy in `services/catalog_monitor` are the
correct forever policy. Do not add stealth.

### 3. Checkout on the brand’s own site

If “seller commission” means “when a Mexican customer pays, buy the same SKU
on the US brand site and ship it south,” that dies the first time the brand:

- cancels freight-forwarder / known-dropship addresses
- flags mismatched bill-to / ship-to
- refuses international checkout
- voids the order after Monetta has already charged the customer

That is an operational time bomb, not a product.

### 4. Consumer, tax, and platform rules in Mexico

PROFECO cares about truthful advertising and warranty. SAT cares about
pedimento, IGI, IVA, and DTA if goods are imported for resale. Shopify and
the app stores will remove IP-infringing listings regardless of gray-market
legality.

So: selling a genuine bag the merchant legally bought and imported can last.
Pretending to be a live US Coach warehouse with a commission overlay cannot.

## The clarified path: advertise, then buy, then a US mailbox

Clarified after the first pass of this note. The intended fulfillment is
**not** an automated buy on the brand site. It is:

1. List the US piece in the Mexican app as if Monetta already has it.
2. When a shopper pays, the owner buys it from the US provider by hand.
3. The brand ships to a US postal box.
4. Someone carries or forwards the piece into Mexico.

That is still dropshipping. The buy is manual; the promise to the shopper is
the same: “this is ours, pay now.” Manual versus scripted only changes who
clicks “place order” on coach.com. It does not change inventory, advertising,
mailbox, or import risk.

### Two ways to run this path

| | **D-false: advertise as on-hand** | **D-honest: *pedido / apartado*** |
|---|---|---|
| What the shopper sees | In stock, ships from Monetta, same language as a bag already in Guadalajara | “Lo pedimos a Estados Unidos. Anticipo hoy, entrega en N días, se puede cancelar si el proveedor ya no lo tiene.” |
| What is true | Monetta does not have it | Monetta does not have it |
| PROFECO / chargebacks | False advertising and “no llegó” disputes | Lead time and failure mode were disclosed |
| Already in this repo? | No — and must not be built | Yes: WhatsApp *apartado* (`lib/data/shopify/cart_attribution.dart`) — $400 / $800 MXN deposit, 20 days to settle |

D-false is the part that does not last. D-honest is the same physical
pipeline (buy after the sale, US box, bring to Mexico) with the lie
removed. The app already sells a large share of revenue this way.

### Why “as if I already have them” fails even when the buy is manual

**The US listing is not a warehouse row.**  
`catalog_monitor` has never completed an accepted full live crawl. The API
still pads with `curated_us_snapshot` rows whose availability is `unknown`.
A crawl that says `inStock` at 03:00 UTC is not a promise that Coach will
still sell that SKU, at that price, to that mailbox, twelve hours later
when the owner places the order. Size, color, and outlet-vs-full-price
drift are the normal case, not the edge case.

**The shopper has already paid.**  
If the brand is out, raised the price, or cancelled the mailbox shipment,
Monetta owns a refund, a chargeback, or a “we’ll get you another color”
conversation. *Apartado* exists so that conversation happens *before* the
full amount moves.

**PROFECO cares about the listing, not the procurement method.**  
Showing “disponible” / an add-to-bag / a 2–5 day Mexican ship estimate on
a piece that is still on a US product page is a consumer-protection fact
pattern, not a branding preference. Independent importer is legal.
Independent importer who claims to hold stock they will buy later is how
complaints get written.

**Trademark still applies to the storefront, not only to auto-buy.**  
Official packshots, Coach wordmarks as chrome, and a grid that looks like
the US catalog are the takedown surface. Whether the owner later clicks
buy on coach.com is irrelevant to Shopify, Apple, and Google.

### The US postal box is the other kill switch

Luxury DTC stores treat commercial mailboxes and freight-forwarder
addresses as dropshipping. They cancel, require signature to a named
resident, or stop selling to the address after a few orders. A single
shared box that receives Coach, MK, GUESS, and Steve Madden packages for
resale is exactly the pattern their risk teams look for.

This note will not describe how to disguise a mailbox as a residence. If
the box starts getting cancelled, the durable responses are: buy fewer
SKUs and hold them in Mexico before listing; use a supplier who will
invoice and ship to a real warehouse; or keep the piece as *pedido* and
accept that some orders will fail.

A mailbox can still be a **consolidation point** for pieces the owner
already decided to inventory — buy first, receive at the box, import,
*then* list. That is model A with a US receiving address. The order of
operations is what makes it durable.

### Import for resale is not “take them to Mexico”

Goods bought to sell in the app are commercial merchandise. SAT expects a
pedimento and the usual IGI / DTA / IVA on a commercial entry — not a
personal-use exemption on luggage or a courier label that under-declares
a bag as a gift. This codebase should assume every public `Offer` has an
import path that can produce papers. It should not grow features whose
only purpose is to hide a commercial entry.

Counsel, not this repo, owns the specific SAT treatment. Engineering’s
job is to keep landed-cost, lead time, and seller-of-record fields on
the offer so the honest path is the easy path.

### What the product should show instead

Do not put a crawl row in the bag. If a US piece is offered to shoppers
at all, it is an `Offer` with an explicit fulfillment class:

| `fulfillmentClass` | Meaning | Checkout |
|---|---|---|
| `onHandMx` | Physically in a Mexican location Monetta controls | Full pay; short ship estimate |
| `pedidoUs` | Will be bought after this sale; US box; then Mexico | *Apartado* / deposit only; N-day range; cancel-if-unavailable |
| `researchOnly` | Sourcing desk; current `ownerProcurement` | No checkout |

`pedidoUs` is the clarified path, named. It is allowed only when the
listing says so in the title area, the price, and the primary button
(“Apartar · 15–25 días”, not “Agregar a la bolsa”). The deposit and the
20-day window already in `ApartadoRequest` are the commercial terms;
wire them to this class instead of pretending it is `onHandMx`.

A `pedidoUs` offer still needs a landed MXN price (US price + tax +
US ship to the box + Mexico entry + last-mile + margin), a quoted range
that includes mailbox dwell and border time, and a documented out: if
the provider cancels, the deposit is refunded. None of that lives on
the crawl schema. It lives on the Shopify product the owner publishes
after looking at the sourcing desk.

## Audit of the current implementation

### What is already durable

Keep all of the following.

- **Shopify is source of truth for things Monetta actually sells.** The owner
  adds a product in Admin; the app picks it up. That is the right model for a
  single merchant of imported goods.
- **US listings are a separate type.** `Product` stays a Shopify entity.
  `CatalogItem` is presentation-only. Two mappers
  (`data/shopify/catalog_item_mapper.dart`,
  `data/external_catalog/external_catalog_mapper.dart`), no shared path into
  checkout. An external row cannot silently become a bag line.
- **The crawler is isolated from the phone.** No user device talks to
  coach.com. One identifiable user agent, robots.txt, per-domain rate limit,
  `marketGuard` (HTTPS + US host after redirects), stop-on-CAPTCHA. That is
  the only crawl posture that is defensible.
- **Payments stay out of the app.** Checkout is designed to hand off to
  Shopify (`docs/CHECKOUT_DESIGN.md`). PCI scope stays where it belongs.
- **Attribution exists** (`_channel`, `_device_id`, `_rec_source`, WhatsApp
  `MN-XXXX` in `lib/data/shopify/cart_attribution.dart`). That is the right
  primitive for *this repo’s* revenue share with the client — not yet for a
  multi-seller marketplace, but the codebase already thinks in auditable
  money.
- **External CTAs re-validate HTTPS + source host**
  (`kAllowedExternalDetailHosts`, `isValidExternalDetailUrl`) before
  `LaunchMode.externalApplication`. A bad API response cannot open an
  arbitrary URL.
- **No currency fiction.** A missing USD price is “Consultar precio”, never
  `$0`. MXN and USD are never sorted against each other by raw amount.
- **Kill switches already exist.** Rebuild without
  `ENABLE_EXTERNAL_CATALOG=true`; set `LIVE_CRAWL_ENABLED=false` (the
  default). A store that can operate with the external rail dark is a store
  that lasts.

### What will not survive a dropshipping rewrite

**The crawler is a research prototype, not inventory.**  
Zero successful full live crawls at the time of this note. CSS selectors and
sitemaps are fixture-tested, not production-accepted. Coach already
geo-redirects. The API pads with a dated 10-item curated floor marked
`curated_us_snapshot` and `availability: unknown`. `/healthz` correctly stays
degraded until a real US crawl succeeds. Listing those rows as buyable
Mexican stock means selling things Monetta does not have, at prices that
ignore shipping, duties, and cancellation risk.

**There is no seller, no inventory ledger, no commission.**  
`accounts_orders` now has first-party shopper accounts. There is no `Seller`,
no SKU ownership, no landed-cost ledger, no payout, no authenticity packet,
no pedimento. Cart attribution is for app-vs-web revenue share, not
marketplace commissions. “Seller commission” cannot be bolted onto
`ownerProcurement` without a new domain.

**Checkout is not a real order path yet.**  
`CheckoutDraft` is still a pre-Shopify handoff. Storefront `cartCreate` is
not wired. A large share of revenue is still WhatsApp *apartado* typed into
Shopify by hand. Automating US procurement on top of a checkout that does
not even place a Monetta order is building the riskiest layer on the
unfinished one.

**Showing US brand pages inside a Mexican shopping app is a trademark
surface.**  
The rail is labeled “Investigación · Estados Unidos”
(`lib/features/home/external_catalog_section.dart`), which is the right
framing — for an **internal** owner tool. The moment that rail is on in a
public App Store build, the app is displaying Coach / MK / GUESS / Steve
Madden marks and (almost certainly) their CDN images to shoppers. That is
how takedowns start, even if the tap only opens the merchant site.

**Single-merchant Shopify will not be the source of truth for a
marketplace.**  
If the product becomes “many sellers, each earning a commission on
US-sourced goods,” Shopify-as-only-catalog breaks. Seller catalog, offer,
and payout have to become first-class data, with Shopify (or another PSP)
as the payment rail — not the inventory brain.

**Root `README.md` is stale versus the tree.**  
It still describes Phase 0 and missing `data/local` / features. Those exist.
Treat `docs/ARCHITECTURE.md` as the contract until the root README is
brought current.

## The solution that can last

Not “hide from brands.” Change the product so brand hostility does not kill
it.

### Rule

**Never sell a US listing. Only sell a Mexican offer that a real merchant
can fulfill.**

```
US public catalog          owner / seller research
(crawl, affiliate,         ──────────────────────►  landed cost, lead time,
wholesale feed)                                     authenticity docs

                                                    ▼
Mexican offer              shopper buys this
(Shopify or marketplace)   ──────────────────────►  inventory the merchant
                                                    holds, or a contracted
                                                    supplier who ships to MX
```

The US feed answers “what exists and roughly what it costs.” It must never
be the thing in the bag.

### Three models, only two of which survive

| Model | Lasts? | Why |
|---|---|---|
| **A. Owner-operated import (what Monetta is)** | Yes, if done cleanly | Buy genuine goods, import them, list them in MXN with Monetta photos and Monetta terms. Brands dislike gray market; Mexican trademark exhaustion is on this side if the store does not impersonate them. A US mailbox used *as a receiving dock before listing* is just A with a US address. |
| **B. Multi-seller marketplace** | Yes, if sellers own stock | Sellers list goods they hold (or have a written wholesale contract for). The platform takes a commission. Mercado Libre / StockX-shaped, not a Coach.com proxy. |
| **C. Automated dropship from brand DTC** | No | Uses Coach as an unpaid warehouse. Out of scope for this repo. |
| **D-false. Advertise as on-hand, buy after pay, US mailbox** | No | Same warehouse lie as C, only the click is human. False stock, mailbox cancels, and undeclared entry are how this dies. |
| **D-honest. *Pedido / apartado* after a sourcing look** | Yes, as a secondary path | Shopper is told it will be ordered. Deposit, lead time, cancel-if-unavailable. Already how Mayoreo sells. Must not be the whole catalog, or mailbox and refund rate will dominate. |

If a client said “detect US products, list them, buy once sold, box in
the US,” they described D. Sell them D-honest, not D-false. Keep A as
the default for anything that should feel like a normal add-to-bag.

### Target architecture

**1. Keep `catalog_monitor` as a sourcing desk, permanently internal.**

The build flag stays off in public releases. Owner / seller tools may see US
availability, USD, color, and merchant URL. Add — do not remove — fields the
current schema lacks: estimated freight, duty/IVA, days-to-land, cancellation
risk, “do we already carry this SKU.” Never auto-create a Shopify product
from a crawl row.

If a brand blocks the crawl, stop that source. Replace it with a licensed
feed, a wholesale price list, or manual research. Do not add Playwright
stealth, proxy pools, or CAPTCHA solving.

**2. Introduce a real Offer, not a scraped Product.**

The same split `CatalogItem` / `Product` already encodes, made commercial:

| Type | Meaning | May enter checkout? |
|---|---|---|
| `SourcingSignal` | What the monitor saw (USD, US URL, last seen) | No |
| `Offer` | What Monetta sells (MXN, seller id, qty on hand or firm PO, photos the merchant took or licensed, warranty text, import status) | Yes |

Checkout may only reference an `Offer`.

**3. If there is a seller commission, add a seller domain.**

Minimum that is real:

- KYC (RFC, legal name, address)
- inventory attestation or inbound receipt
- authenticity packet (purchase invoice, serial / creed id where the brand
  uses one, photos)
- commission %, reserve for refunds, payout calendar
- PROFECO-facing seller of record (who the customer sues)

Do not invent this inside `catalog_monitor`. It belongs next to
`accounts_orders`, or as a third sibling. Shopper accounts and seller
accounts are different legal objects.

**4. Sell like an independent importer, not a brand boutique.**

This is what actually keeps the app in stores:

- Monetta branding, not Coach wordmarks as the store identity
- Monetta’s own photos, or licensed packshots — not hotlinked brand CDN
- copy that says *importado original, vendedor independiente, no tienda
  oficial*
- no official-boutique warranty unless Monetta can honor one
- prices in MXN that include the real landed cost (product + US tax +
  freight + seguro + IGI + DTA + IVA + margin)
- lead times that are honest when the piece is not in a Mexican warehouse
  yet (*apartado* already matches how this business sells)

Nominative use (“bolso Coach Tabby 26”) is usually fine. Looking like
`mx.coach.com` is not.

**5. Fulfillment that does not depend on coach.com checkout.**

Durable sources, in order:

1. Stock already in Mexico.
2. Mexican / LATAM authorized wholesale, if obtainable.
3. US liquidators, off-price, or wholesalers who will sell and invoice.
4. Manual owner buy on a US site **to the US box or warehouse**, import,
   *then* list as `onHandMx`.
5. `pedidoUs` / *apartado* for a thin tail of pieces the owner is willing
   to miss — never as the default add-to-bag, never labelled as on-hand.

The US box belongs in (4) as a dock, or in (5) as a disclosed wait. It
does not belong behind a listing that looks like (1).

**6. Make takedowns a feature, not an outage.**

Assume a brand or Shopify will remove a listing.

- every public SKU maps to an `Offer` Monetta controls
- removing Coach images / marks must not empty the app
- diversify brands and categories so four DTC adapters are not the catalog
- keep the kill switches (`ENABLE_EXTERNAL_CATALOG`, `LIVE_CRAWL_ENABLED`)

**7. Finish the real revenue path before adding sellers.**

Wire `CheckoutDraft` → Storefront cart → Shopify payment. Keep guest
checkout. Keep *apartado*. Put landed-cost and authenticity on the Shopify
product, not in a spreadsheet. Then, and only then, add a second seller.

## Out of scope for this codebase

Do not design or implement:

- residential proxies, UA spoofing, or CAPTCHA bypass so the crawl “survives”
- auto-checkout against Coach / Michael Kors / GUESS / Steve Madden
- cloaking so brand counsel sees a different catalog than shoppers
- a public feed of scraped official photos presented as Monetta stock
- in-stock / short-ship chrome on a piece Monetta will only buy after pay
- features whose purpose is to hide a US mailbox from a brand, or a
  commercial import from SAT
- anything that claims authorized-dealer status Monetta does not have

Those are how these apps die.

## Recommended next build

Ship **A as the default**, **D-honest as the exception**, a sourcing desk
for the owner, and only add **B** if the product truly needs multiple
sellers. Do not ship D-false.

1. Keep crawl rows out of checkout. Do not remove
   `PurchaseMode.ownerProcurement`.
2. Public app: external catalog **off**. Internal owner build: on, as a
   buying desk.
3. On the Shopify product — not the crawl schema — add `fulfillmentClass`
   (`onHandMx` | `pedidoUs`), landed MXN cost, and a lead-time range.
4. `pedidoUs` uses the existing *apartado* terms (deposit, 20 days,
   cancel-if-unavailable). It must never reuse the on-hand bag CTA.
5. Finish Shopify checkout + *apartado* unification
   (`docs/ACCOUNTS_AND_SYNC_PLAN.md`, `docs/CHECKOUT_DESIGN.md`).
6. If commissions are still required: seller KYC + `Offer` + payouts. The
   crawl stays research.

The first useful slice is `fulfillmentClass` + landed cost on the current
Shopify catalog, with the US monitor remaining a desk the owner reads
before publishing an offer — not a pipe into the bag.

## Related docs

- [`ARCHITECTURE.md`](ARCHITECTURE.md) — module map; external-catalog
  prototype; why scraping is isolated outside the mobile client
- [`CHECKOUT_DESIGN.md`](CHECKOUT_DESIGN.md) — guest-first MX checkout;
  Shopify owns payment
- [`ACCOUNTS_AND_SYNC_PLAN.md`](ACCOUNTS_AND_SYNC_PLAN.md) — shopper
  accounts, webhooks, *apartado* unification (not sellers)
- [`../services/catalog_monitor/README.md`](../services/catalog_monitor/README.md)
  — live-crawl gate, robots, block detection, known limitations
- `lib/domain/catalog_item.dart` — `PurchaseMode`, host allow-list
- `lib/data/shopify/cart_attribution.dart` — app revenue-share attributes
  and WhatsApp *apartado* codes
