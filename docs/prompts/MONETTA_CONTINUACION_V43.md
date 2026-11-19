# Monetta UI v4.3 — continuación (Cloud Agent)

Base de trabajo: rama `fix/web-brands-row`, commit `967aca1`. Tema Shopify activo **193754824738**; borrador de reversión **192672989218**.

## Correcciones implementadas en esta sesión

### 1. Compra inmediata (web)

- `storefront-theme/assets/monetta-cart.js`: un `cart/add` HTTP 200 sin secciones usables dispara solo lectura (`recoverFromServer`); si falla, `confirmed: false` y checkout bloqueado; la UI conserva la última bolsa confirmada.
- `storefront-theme/assets/monetta-product.js`: «Comprar ahora» no redirige si `confirmed === false` o la bolsa está bloqueada.
- `storefront-theme/assets/monetta-guia.js`: Para ti usa `Monetta.cart.add` (antes `Monetta.add` inexistente); mismas reglas de confirmación y doble toque con `data-pending`.

### 2. Ofertas (Flutter)

- `lib/features/catalog/catalog_query.dart`: `preferredMatchingCatalogVariant` — intersección color / oferta / precio / disponibilidad, estable por precio e id.
- `collection_screen.dart` y `catalog_browse_screen.dart`: las tarjetas usan la variante preferida para alinear tarjeta, vista rápida y ficha.

### 3. Para ti y ficha (Flutter)

- `buyNowContinueToCheckout` en `product_selection.dart` + `continueLiveBagToCheckout` compartido en `checkout_screen.dart`.
- `product_screen.dart` y `home_for_you_section.dart`: Comprar ahora continúa al checkout conservando líneas; Agregar (+) sigue independiente.

## Regresiones

- `test/features/catalog/v41_discovery_test.dart` — variante preferida en oferta.
- `test/features/product/buy_now_checkout_test.dart` — compra inmediata Flutter.
- `docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs` — paso `v43-buy-now`.

## Verificación local

```bash
flutter test test/features/catalog/v41_discovery_test.dart test/features/product/buy_now_checkout_test.dart test/features/product/product_selection_purchase_test.dart
flutter analyze
# con proxy del tema en :9292
node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --base-url=http://127.0.0.1:9292 --only=v43-buy-now
```

## Bloqueos comerciales / catálogo (sin cambio en Shopify)

| Destino | Responsable | Dato requerido | Criterio de aceptación |
|---------|-------------|----------------|-------------------------|
| Ofertas | Comercio / Shopify Admin | Colección o Search & Discovery con piezas con `compare_at` > precio | Ruta publicada sin 404; búsqueda «ofertas» en Colecciones > 0 en staging |
| Mayoreo | Comercio / Shopify Admin | Página publicada + enlace de navegación acordado | `/pages/mayoreo` o vista tema sin 404; prueba 2→3→4→2 unidades elegibles en app |

No se realizaron pedidos ni cobros reales en esta corrida.