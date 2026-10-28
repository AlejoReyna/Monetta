# Validation evidence

22 October 2026 · Isolated localhost lab only. No staging storefront, app runtime or real commerce operation was tested.

## Environment and method

Used the repository's already-installed `playwright-core`1.63.0, installed Brave/Chromium155.0.8059.40 in headless mode on macOS, and Python's local HTTP server bound to127.0.0.1. No packages were installed. The in-app browser tool returned **“Browser is not available: iab”**; validation therefore used the installed browser through Playwright. There was no visible interactive browser session or real-device run.

The reproducible [script](validate.mjs) performs real browser click, keyboard and emulated touch input, observes DOM/computed styles and focus, captures images, and records a Chrome DevTools trace and timed screencast. The final [test-results.json](evidence/test-results.json) is authoritative for pass counts, exact browser version, timestamps, request log and tested code hashes.

**Final result: 51 checks passed, 0 failed.** No page/console errors or failed requests were observed in the instrumented primary context. Its12 requests were all local GET reads; the lab's CSP also blocks connect/form writes. Separate touch and JavaScript-disabled contexts are identified below; their request/console logs were not separately instrumented, so the12-request count is not a whole-browser network total.

## Checks actually performed

| Area | Evidence and result |
|---|---|
| Responsive layouts | Actual viewport widths320,390,768,1440px. Root and every specimen had no horizontal overflow; all images decoded. Full-page screenshots at each width. Initial testing found clipped contextual-bar specimen columns at320/390; corrected before final pass. |
| Visual fit | Reviewed real local fonts, wordmark, terracotta image, contained bag assets, warm palette, serif headings and Inter card names. Inspected desktop first viewport/gallery, constrained full page, phone filter and phone purchase exploration. Screenshots establish appearance only. |
| Keyboard | Skip link visibly receives first Tab. Enter opens modal; Tab/Shift+Tab stay inside; Escape closes and restores invoker. Search receives initial focus and its empty state works. Filled native search originally swallowed Escape; an explicit dialog handler fixed it. |
| Modal interruption | At×2 inspection pace, close then activate the focused close/reopen control during exit; reopened panel remains open after stale-close deadline. Resized an open filter panel from390 to1440 and checked bounds. Source review also checked ownership of pending frames/closing timers. |
| Gallery concurrency | Slow loading plus rapid silhouette choices commits latest selection. Re-selecting currently shown image cancels pending choice. Failed load preserves old labeled image; retry succeeds. Source review found and corrected cancellation cleanup of a tracked animation. |
| Cart truth | Pending repeated Enter produces one addition; count waits for simulated success. Failure preserves confirmed count and retry; initiating focus remains. Rapid quantity input resolves to last local sample value; failure restores confirmed value. Reset during pending add prevents later timer success. Ten-item cap explicitly reports no addition; reset updates visible and accessible count. |
| Saved/card/disclosure | Heart works by Space and repeated toggles; label and pressed state agree. Focus outline computed as3px solid. Enter/Space toggle native details. Reduced mode removes card transform. Restrained/expressive image options remain subject to human preference evaluation, not a conversion claim. |
| Emulated touch | Separate390×844 context with `hasTouch`/mobile emulation: tap saved control without hover, tap filters, verify bottom sheet position; capture open sheet. This is not iOS Safari/Android hardware testing. |
| Reduced/static | Forced reduced has0s panel transition; emulated system preference is detected; forced full override works; static baseline has0s decorative transitions. The sample loading timers remain truthful. No OS setting was changed. |
| Purchase exploration | Scroll internal phone frame beyond original action, reveal contextual bar, keep focused action visible while scrolling back, hide after focus leaves. Initial testing exposed skipped observer thresholds; observe the region through the original CTA and recheck geometry at focus boundaries. No continuous scroll handler was introduced. |
| No animation JS | Separate320px context with JavaScript disabled: title/product remain visible and native disclosure operates. Demo search/cart/panel controls intentionally require JavaScript. |

The final automated checks use a single main journey across widths, not a full interaction suite independently repeated at every width. Keyboard and most async scenarios run at1440; reduced/static and recording use390. Visual layout checks cover all four. This is useful coverage, not exhaustive accessibility certification.

## Screenshot and interaction artifacts

- Full layouts: [320](evidence/lab-320.png), [390](evidence/lab-390.png), [768](evidence/lab-768.png), [1440](evidence/lab-1440.png).
- Detail captures: [desktop first viewport](evidence/desktop-first-viewport.png), [desktop gallery](evidence/desktop-gallery.png), [phone filter](evidence/mobile-filter-open.png), [phone purchase exploration](evidence/mobile-purchase-exploration.png), [keyboard focus](evidence/keyboard-focus.png).
- Comparison: [static baseline](evidence/static-baseline-390.png), [reduced gallery](evidence/reduced-gallery-390.png).
- Interaction: [short MP4](evidence/overlay-interaction.mp4) shows menu opening, mid-close reversal and dismissal. It was assembled from timestamped CDP screencast frames, encoded with installed ffmpeg. JPEG sampling and30fps encoding duplicate/drop frames; **this is qualitative sequence evidence, not FPS measurement**. [Contact sheet](evidence/recording-contact-sheet.png) is only a static index to that recording.
- [Interaction log and assertions](evidence/test-results.json) provide state/input evidence separate from still images. [Raw frames and timestamp sequence](evidence/recording.ffconcat) allow reproduction.

## Rendering and layout observations

A [DevTools trace](evidence/overlay-cpu6-trace.json) records menu opening/closing with6× DevTools CPU slowdown. This emulates CPU pressure on this computer; it is not a slow-phone test. The result JSON summarizes actual `Layout`, `Paint`, `UpdateLayoutTree` and related events. The trace includes layout and paint work; the lab does **not** establish compositor-only animation or “zero reflow.” Modal setup, focus, state text and dismissal have real rendering costs. The short sample is insufficient for a60fps, INP, LCP or field-performance claim.

The main journey collects layout-shift and long-task entries. The final run reported one110ms long task starting at48.9ms in the initial document lifecycle; this was not investigated as a storefront performance result. It deliberately changes viewport widths, toggles disclosures, changes text and moves focus, so adding all shift entries would be an invalid storefront CLS score. A small initial non-input shift (~0.00378 in the recorded runs) was observed; its cause was not isolated. Stable media frames and fixed control placement prevent image-load collapse; some text/status reflow remains possible for unusually long localized messages. Status regions reserve extra height for tested narrow copy. No blanket zero-layout-shift claim is made.

The resulting performance strategy is bounded CSS transform/opacity, finite effects, no persistent `will-change`, no animation library, no scroll loop, and static essential text. Whether a particular effect composites cheaply on target hardware still requires real-engine/device traces. The card scale's image memory and the gallery's second decoded image remain costs to evaluate.

## Workspace preservation and limits

[Before inventory](evidence/workspace-before.json) records3,703 existing tracked/nonignored untracked files and initial dirty Git state. [Final comparison](evidence/workspace-preservation.json) detected15 existing files changed plus one new nonignored file outside this directory during concurrent workspace activity. **This task wrote only inside the research directory and did not revert those external changes.** File/line evidence reflects the inspected snapshot; it does not certify a concurrently edited storefront's final state. Ignored dependencies/build caches were not part of this content inventory.

No app runtime, Shopify staging preview, checkout, account, analytics, live network mutation, screen reader, 200% zoom, browser virtual keyboard, Safari, Firefox, real touchscreen, high-refresh display or low-memory hardware was tested. The lab does not establish WCAG conformance, production Shopify compatibility, real-world responsiveness or purchasing correctness. The implementation plan lists those future acceptance checks.
