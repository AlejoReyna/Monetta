# A04 final capture review

Final source: see source-manifest.json. These are deterministic Flutter fixture renders, not provider/device/live-service proof. All 39 final PNGs were reviewed using review-sheet-01.jpg through review-sheet-10.jpg and representative original-size captures. The final sort/filter/taxonomy/sidebar-tail images were reviewed again after explicit sort Apply was added. No golden was updated.

| Matrix | Captures |
| --- | ---: |
| 13 surfaces at 390 px / 100% and 320 px / 200% | 26 |
| Expanded taxonomy, brands, filters and sidebar at 768 and 1440 px / 100% | 8 |
| Filters, sidebar and brands dark at 390 px / 100% | 3 |
| Keyboard filters and sidebar tail at 320 px / 200% | 2 |
| Total | 39 |

At 390 px the taxonomy uses native in-flow expansion and gold owner SVGs; wide brand logos remain legible without overlap. At large text the hierarchy and account/social labels grow and scroll; social labels stack vertically. Filter controls have visible native text, explicit selected semantics, and a reachable apply/cancel footer above the keyboard. Sort labels wrap with explicit Apply and Cancel. Empty/error states remain separate. Tablet/desktop directories are bounded instead of stretching logos across the viewport. Dark captures preserve native readability while the approved white directory/sheet surfaces remain white. Product fallback art is intentional fixture honesty.

Original delivered references inspected: categories.png, categories_open.png, brands_stack.png, filters.png, sort.png, collection.png and menu_account.png under the delivery's 05_maquetas/png directory. Hashes are in evidence-manifest.json. categories-reference-review.jpg, filters-reference-review.jpg and sidebar-reference-review.jpg show proposal/reference and final fixture side by side. Geometry marked proposed is not asserted pixel-identical. The original source art, glyphs, hierarchy, copy and native reflow behavior govern this review.

before-categories-historical.png is copied from the historical audit capture; it is not a recreated pristine pre-edit current-source baseline. Final *-fixture.png files use real supplied banner/logo/icon assets and application widgets/fonts. Inventory, products and balance are fixtures; missing variant photographs are not invented. Runtime account access, Home integration and live provider calls remain outside visual acceptance. Missing gender/newness authority remains gated rather than illustrated as working.
