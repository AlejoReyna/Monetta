# Open the Monetta animation lab

No build, installation or Shopify connection is needed. Serve **only this research directory** on localhost:

```sh
python3 -m http.server 8876 --bind 127.0.0.1 --directory /Users/alexis_reyna/MyCode/Monetta/artifacts/animation-research-2026-10-22-motion-lab
```

Open [http://127.0.0.1:8876](http://127.0.0.1:8876). Stop the server with Ctrl+C. If that port is in use, choose another. Use localhost rather than double-clicking: `file:` origin/CSP behavior varies between browsers.

1. Start at **Propuesta animada**, **Usar sistema**, normal token pace. **Base estática** retains the same functions with0ms decoration.
2. Compare forced reduced and full motion. The label reports effective timings and the emulated/system preference. ×2 is for inspecting reversal, not a production suggestion.
3. Panels: open menu/search/filter. Tab and Shift+Tab stay inside. Escape closes. At ×2, close and activate **Reabrir** while it leaves. Resize while open.
4. Gallery: set slow loading, quickly select different silhouettes. Only the last selection appears; a failed load keeps the old labeled image. Retry after changing to normal.
5. Bag: success, slow success and error are local timers. Click repeatedly while pending. Adjust quantity quickly, then test failed quantity updates. Nothing writes to Shopify. The sample has a ten-item cap.
6. Card: compare1.015 and1.045. Use mouse, keyboard focus or the replay signal button on touch. Save toggles only in memory for this page/session.
7. Disclosure: Enter/Space toggles the real summary; content is immediate and only the chevron moves. It also works without JavaScript.
8. Phone composition: scroll **inside the phone frame** or select **Mostrar barra móvil**. Focus its action, return the inner scroll to top, then leave focus: the bar stays while focused and hides afterward. This remains an exploratory replacement for the current static dock, not a shipping recommendation.

Each example has a reset. **Restablecer todo** clears demo states while keeping comparison/preferences for evaluation. The intro and typography are intentionally static. Product names include long text. Spanish storefront copy, sample prices and existing Monetta imagery are used; product-policy copy is explicitly illustrative.

## Files

- `index.html`, `lab.css`, `lab.js`, `assets/`: standalone lab and copied local assets.
- `REPORT.md`, `CANDIDATE_MATRIX.md`, `IMPLEMENTATION_PLAN.md`: research, ranking and handoff.
- `VALIDATION.md`, `evidence/`: recorded checks, images, trace and short screencast.
- `validate.mjs`: reproducible browser interaction checks. Reads existing `design-prototype/node_modules/playwright-core`; installs nothing. It expects the installed Brave executable at `/Applications/Brave Browser.app/Contents/MacOS/Brave Browser`.

With the server running:

```sh
node /Users/alexis_reyna/MyCode/Monetta/artifacts/animation-research-2026-10-22-motion-lab/validate.mjs
```

Use `LAB_URL=http://127.0.0.1:PORT` for another port. The script writes only under `evidence/`. It reruns screenshots/checks and timed recording frames; existing evidence in this new research directory is replaced. It does not edit the project or run production/theme tests.

To encode the recording frames with an already-installed ffmpeg:

```sh
ffmpeg -y -safe 0 -f concat -i /Users/alexis_reyna/MyCode/Monetta/artifacts/animation-research-2026-10-22-motion-lab/evidence/recording.ffconcat -vf 'pad=ceil(iw/2)*2:ceil(ih/2)*2' -r 30 -c:v libx264 -pix_fmt yuv420p /Users/alexis_reyna/MyCode/Monetta/artifacts/animation-research-2026-10-22-motion-lab/evidence/overlay-interaction.mp4
```

The MP4 retains source screenshot timestamps, with frame duplication for encoding. It demonstrates sequence and interruption qualitatively, not refresh-rate or real-device performance.
