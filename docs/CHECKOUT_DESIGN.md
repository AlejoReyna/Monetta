# Checkout design study

Reviewed on 12 August 2026 against the live purchase funnels for
[Michael Kors México](https://www.michaelkors.global/mx/es/),
[Coach México](https://mx.coach.com/),
[Longchamp US](https://www.longchamp.com/us/en/), and
[Tissot US](https://www.tissotwatches.com/en-us/).

The goal is not to reproduce any one brand. It is to keep the parts that make
an expensive purchase feel calm and trustworthy, then remove the friction and
promotional noise that gets in the shopper's way.

## What the comparison showed

| Brand | Strong pattern | Friction to avoid |
|---|---|---|
| Michael Kors | Immediate add confirmation; clear item, shipping, total and accepted-payment summary; prominent guest checkout | Urgency messages and product recommendations compete with the checkout task; the shipping charge appears relatively late |
| Coach | A useful mini-cart exposes quantity, subtotal and free-shipping qualification; checkout identifies the shopper by email and shows identification, delivery and payment states | Dense legacy layout reveals too much of the downstream checkout at once; promotional payment messages create cognitive load |
| Longchamp | Delivery, click-and-collect, secure payment and free-return reassurance sits close to the committing action | Region switching can interrupt the purchase path; repeated campaign content dilutes the cart's focus |
| Tissot | Product pages build confidence with easy returns, secure payment, free delivery and product authenticity before add-to-cart | Financing and alternate fulfilment can make the decision area busy when they are presented at the same visual weight |

## Monetta's response

The resulting flow uses three visible stages:

1. **Bolsa** — large product image, variant, editable quantity, transparent
   shipping and estimated total.
2. **Entrega** — guest-first contact and Mexican delivery fields, one clear
   shipping method, and a persistent order summary.
3. **Pago** — a compact review with inline edit links, followed by a secure
   Shopify handoff.

Design rules applied:

- One primary action per screen.
- Guest checkout is the default; no account wall or marketing opt-in.
- Costs are visible before commitment, including the free-shipping threshold.
- Reassurance is contextual: originality, delivery, returns and secure payment
  appear beside the decision they support.
- A numbered progress indicator always answers “where am I?” and “what is
  next?”.
- Order details stay visible on wide screens and remain below the task on small
  screens.
- Input labels never disappear, errors are field-specific, and controls carry
  screen-reader labels.
- Black, white, pale neutral surfaces and fine rules preserve the quiet
  storefront language; promotional color is absent from checkout.

## Security and integration boundary

Monetta never renders a card-number field. The UI creates a transient
`CheckoutDraft`; the production launcher should use it to create/update a
Shopify Storefront Cart, prefill buyer identity, attach private attribution,
and open `cart.checkoutUrl`. Shopify then owns payment methods, authentication
and PCI scope.

Until Shopify credentials are connected, the final action intentionally opens
an explicit secure-handoff preview instead of pretending an order was placed.
