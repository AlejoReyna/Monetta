# Monetta current UI references

This is the Vercel-ready reference palette for Monetta's current Flutter UI.
The primary board and its detail viewer use screenshots captured directly from
the running iPhone 17 Pro Max build. Historical SVGs and screenshots may remain
in `public/`, but they are intentionally excluded from the palette navigation.

Current references:

- Home hero
- Compact catalog with search and sections
- Product detail and purchase actions
- Empty bag state

Select a thumbnail to inspect the full-resolution capture. The canvas supports
fit, zoom, keyboard shortcuts and drag-to-pan.

## Local

```bash
npm install
npm run dev
```

## Vercel

The repository root already contains `vercel.json` and is linked to the
`imdrunkasfuck` Vercel project. The config installs and builds the `web/` app
and serves `web/dist`.
