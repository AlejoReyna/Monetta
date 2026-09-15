# Monetta current UI references

This is the Vercel-ready reference palette for Monetta's current Flutter UI.
The primary board and its detail viewer use screenshots captured directly from
the running iPhone 17 Pro Max build. Historical SVGs and screenshots may remain
in `public/`, but they are intentionally excluded from the palette navigation.

The palette currently contains 23 real simulator states grouped across:

- Home, side menu, onboarding, notifications and editorial pages
- Search: initial, results and no-results states
- Collection and catalog category/filter states
- Product detail, minicart, populated bag and empty bag
- Checkout delivery and order review (using local demo input; no payment sent)

Account authentication, owner-only administration and hosted Shopify payment
are intentionally excluded because they leave the public in-app flow or require
credentials. Media fallbacks visible in the screenshots are the app's real
runtime behavior for unavailable staging assets.

Select a thumbnail to inspect the full-resolution capture. The canvas supports
fit, zoom, keyboard shortcuts and drag-to-pan in the palette. Detail mode fits
one centered device inside the available viewport without vertical scrolling;
select screens also include restrained leader-line annotations where context is
useful. The sidebar also includes an expandable history row dated with the
current day. Its snapshot cards use the same selection and detail behavior while
remaining separate from the current UI group.

## Local

```bash
npm install
npm run dev
```

## Vercel

The repository root already contains `vercel.json` and is linked to the
`imdrunkasfuck` Vercel project. The config installs and builds the `web/` app
and serves `web/dist`.
