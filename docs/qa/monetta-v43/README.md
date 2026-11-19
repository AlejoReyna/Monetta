# Matriz de aceptación — Monetta UI v4.3

Actualizada tras la rama `cursor/monetta-v43-close-3c47` (base `967aca1` / `fix/web-brands-row`).

Leyenda de **fuente**: `fixture` = datos de prueba locales; `shopify` = staging autorizado; `dispositivo` = pendiente de corrida física.

| Ficha / área | Caso | Archivo / prueba | Resultado | Evidencia | Fuente |
|--------------|------|------------------|-----------|-----------|--------|
| Compra inmediata web | 200 sin secciones + read-back falla → checkout bloqueado | `regressions.mjs` `v43-buy-now` | Implementado; ejecutar con proxy | Log Playwright cuando corre | fixture / shopify |
| Compra inmediata web | PDP no redirige si bolsa no confirmada | `monetta-product.js` | Pass (código) | Revisión diff | fixture |
| Compra inmediata web | Para ti usa `Monetta.cart.add` | `monetta-guia.js` | Pass (código) | Revisión diff | fixture |
| Compra inmediata Flutter | Add + hand-off checkout | `buy_now_checkout_test.dart` | Pass (CI local) | `flutter test` | fixture |
| Ofertas Flutter | Variante única cumple color+oferta+precio | `v41_discovery_test.dart` | Pass | `flutter test` | fixture |
| Ofertas Flutter | Tarjeta `initialVariantId` estable | `catalog_query.dart` + `collection_screen.dart` | Pass (código) | Revisión diff | fixture |
| Para ti Flutter | Comprar ahora → checkout (líneas conservadas) | `home_for_you_section.dart` | Pass (código) | Revisión diff | fixture |
| Para ti Flutter | Agregar (+) independiente | `home_for_you_section.dart` `_FeedAddControl` | Sin regresión | Revisión diff | fixture |
| Ofertas web | Colección publicada staging | — | **Bloqueado** | 404 / 0 resultados colecciones | shopify |
| Mayoreo web | Página y menú | — | **Bloqueado** | 404 staging | shopify |
| UI-04 goldens | 10 fallos históricos | suite completa | Sin cambio esperado | Comparar vs base antes de actualizar refs | fixture |
| Pagos / Rewards / crédito | Seis métodos, bonos, apartados | plan QA pagos | **Pendiente insumo** | Ver `docs/qa/monetta-payments-test-plan.md` | shopify |

## Responsables bloqueos Ofertas / Mayoreo

- **Dueño comercial Monetta**: crear o publicar colección Ofertas y página Mayoreo en Admin; enlazar en menú del tema 193754824738.
- **Criterio**: mismas rutas que en app (`/?view=` conservado en comparación tema); vistas previas autenticadas sin 404.

## Comandos de cierre

```bash
git diff --check
flutter analyze
flutter test
make gen && git diff --exit-code  # generadores
# Theme Check vs HEAD en storefront-theme (cuando shopify CLI disponible)
```