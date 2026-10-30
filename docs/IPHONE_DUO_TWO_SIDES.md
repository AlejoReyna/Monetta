# iPhone Duo: two fixed sides

Status: implemented and covered by widget tests with the geometry measured on the Duo simulator. The native walkthrough (`integration_test/duo_shopping_task_test.dart`) is updated to this behavior and still has to be run on the dedicated simulator; physical hardware remains unverified.

## Why

On the inner display, opened in landscape, most surfaces wrapped their body in `SystemUsableSurface`. When the system reported the crease as active (half folded), that surface kept only the largest usable region: the 455-point left side won over the 371-point right side, which stayed blank. Flat, the same content crossed the crease. Outside collections, a preview covered everything, and the product, bag and account replaced the catalog.

## The layout

`DuoWorkspace` (`lib/features/navigation/duo_workspace.dart`) sits between `AppRouteScopes` and the app's navigator.

| Side | Width on the inner display | What it holds |
|---|---|---|
| Left | 0 → crease (455.5 pt) | The app's navigator: Inicio, categorías, colecciones, búsqueda, marcas, favoritos. Nothing covers it. |
| Gutter | the system's division (40 pt) | A hairline on the crease. Content never crosses it. |
| Right | crease → rail (371.5 pt) | A navigator of its own. Its first page is the bag. |
| Rail | the system bar inset (84 pt) | One rail for both sides. |

The split appears only when the system reports a vertical division (active or flat), each side keeps the app's minimum pane width (320 and 340 points), the window keeps the split height without counting the keyboard, and text is not enlarged. The first-visit welcome keeps the whole window until it closes. Everything else — the outer display, inner portrait, accessibility text sizes, iPad, Android and ordinary iPhones — keeps the single navigator, and the right side is not even built until a window has had two sides.

## What each side shows

| Action | Left | Right |
|---|---|---|
| Open the app | Inicio | The bag. Empty, it only says what will appear there: no recommendations and no «Volver a la tienda». |
| Tap a card | Stays, the piece marked | The preview card, without a veil. Another card replaces it. |
| «Ver producto» | Stays | The product page, replacing the preview. Related pieces open above it. |
| Add to the bag | Stays | The page stays; «Agregado a tu bolsa · VER BOLSA» replaces the mini-cart sheet. |
| Long-press a card and drag it right | Stays | Dropped on the right side, one buyable variant is added and the bag shows; several variants open the preview to choose one. VoiceOver gets «Agregar a la bolsa» as a custom action. |
| Filters | The results update with each change | «Filtrar y ordenar». «Ver N» closes; in a collection, «Cancelar» puts back what was applied on opening. |
| Carrito / Cuenta on the rail | Stays | The bag / the account. Orders and the other account pages open inside the right side. |
| Inicio / Categorías on the rail | Changes | Stays |
| «Continuar al checkout» | Checkout spans both sides: the form left of the crease, «Tu pedido» right of it, each scrolling on its own. «Volver al inicio» after a purchase closes it and returns both sides to their start. |

The rail marks what each side shows: the browsing page's destination and the right side's bag or account. Its handlers are the visible browsing page's own (`DuoRailRegistration`), so Inicio, Categorías, Carrito and Cuenta behave as that page's bar would.

## Closing and opening the phone

- Closing with a preview, product, account or checkout on the right: that page is drawn over the browsing side with its state, and its own back returns to the catalog. Only the bag hides.
- Opening again: the page returns to the right side.
- A piece chosen in a collection on the outer display moves to the right side with its variant, photo and open sections (the product page carries one `GlobalKey`); the results fill the left side again. A product, bag or account page opened on the outer display moves to the right too.

## Tests

`test/features/navigation/duo_workspace_test.dart` uses the measured geometry: 951×669 points, an 84-point right inset, a 34-point bottom inset and a 40-point division at x = 455.5, flat and half folded. It covers the empty bag, both sides filled when half folded, preview and product, adding from the preview, dragging to the bag (one and several variants, and a drop over the catalog), the rail and the account, live filters, the two-sided checkout, closing and opening with state, moving pages opened on the outer display, enlarged text and windows without a division.
