# Matriz de aceptación — Monetta UI v4.3

Base git: `fix/web-brands-row` @ `967aca1`. Rama de cierre: `cursor/monetta-v43-close-3c47`.

**Leyenda de fuente:** `fixture` = datos locales / Playwright controlado; `shopify` = staging o producción con sesión; `dispositivo` = corrida física pendiente.

## Recorridos v4.3

| Ficha | Caso | Verificación | Resultado | Evidencia | Fuente |
|-------|------|--------------|-----------|-----------|--------|
| WEB-BN-01 | PDP: 200 sin `sections`, read-back falla → sin checkout | `regressions.mjs` `v43-buy-now` | Implementado | Correr con proxy staging | fixture |
| WEB-BN-02 | PDP: un solo POST + read-back OK → bolsa desbloqueada | `v43-buy-now-recover` | Implementado | Correr con proxy | fixture |
| WEB-BN-03 | PDP: doble toque → un POST | `v43-buy-now-double` | Implementado | Correr con proxy | fixture |
| WEB-BN-04 | PDP: 422 stock → sin checkout | `v43-buy-now-stock` | Implementado | Correr con proxy | fixture |
| WEB-BN-05 | Para ti: `Monetta.cart.add` + lock checkout | `monetta-guia.js` | Pass (código) | diff | fixture |
| WEB-BN-06 | Para ti multi-variante: quick view + Comprar ahora | `monetta-home-feed` + `monetta-guia.js` | Pass (código) | diff | fixture |
| WEB-OF-01 | Tarjeta lista: variante con filtros + `compare_at` | `monetta-preferred-variant-pick.liquid` | Pass (código) | diff | fixture |
| WEB-OF-02 | Quick view abre con `data-listing-variant` | `monetta-guia.js` | Pass (código) | diff | fixture |
| WEB-OF-03 | Café/Negro, 2 ofertas, paginación, back-state | Playwright colección piloto | **Bloqueado** | Sin colección `ofertas` en prod | shopify |
| FLT-OF-01 | `preferredMatchingCatalogVariant` | `v41_discovery_test.dart` | Pass | `flutter test` | fixture |
| FLT-BN-01 | `buyNowContinueToCheckout` | `buy_now_checkout_test.dart` | Pass | `flutter test` | fixture |
| FLT-PT-01 | Para ti Comprar ahora → checkout | `home_for_you_section.dart` | Pass (código) | diff | fixture |
| FLT-PT-02 | Quick view Comprar ahora tras elegir opción | `quick_view.dart` `buyNowCheckout` | Pass (código) | diff | fixture |
| FLT-PT-03 | Agregar (+) independiente | `_FeedAddControl` | Sin regresión | diff | fixture |
| ACC-01 | Cajón teclado / Escape / foco / Atrás / 200 % | `keyboard.mjs` + matrix layout | Pendiente corrida | — | fixture |
| UI-04 | 10 goldens históricos | suite completa Flutter | Sin cambio esperado en base | 1820 pass baseline | fixture |

## Bloqueos Shopify Admin

Detalle en [ADMIN_AUDIT.md](./ADMIN_AUDIT.md).

| Bloqueo | Responsable | Insumo | Criterio de cierre |
|---------|-------------|--------|-------------------|
| Colección Ofertas 404 | Comercio | Colección handle `ofertas` + `compare_at` en SKUs piloto (ej. Café solo Negro) | `/collections/ofertas` 200; tarjetas con precio oferta |
| Mayoreo guía en preview | Comercio + Ops | Página `mayoreo` → plantilla `guia-mayoreo`; tema `193754824738` | Sin Atelier; CTA visible en staging autenticado |
| Mayoreo 2→3→4→2 | Comercio | Descuento automático documentado | QA sin cobro real |
| Seis métodos de pago | Pagos + Ops | Pasarelas en staging | Matriz `docs/qa/monetta-payments-test-plan.md` |
| Rewards / crédito / fecha comercial | Comercio | Políticas publicadas | Casos en matriz pagos |
| Envío / recotización / apartados | Ops | Tarifas y reglas | Escenarios E2E sin pedido |

**Temas:** activo `193754824738`, reversión `192672989218`. Conservar `/?view=account`, `/?view=orders`, carrito independiente.

## Comandos de cierre

```bash
git diff --check
flutter analyze
flutter test
# Playwright (proxy theme dev):
node docs/web-redesign/shopify-staging/scripts/e2e/regressions.mjs --only=v43-buy-now,v43-buy-now-recover,v43-buy-now-double,v43-buy-now-stock
make gen && git diff --exit-code
# Theme Check vs baseline 251 hallazgos (shopify CLI)
```

## Pendiente solo con sesión staging

- Validar catálogo real Ofertas/Mayoreo tras publicación comercial.
- Capturas verificadas en matriz (adjuntar a `docs/qa/monetta-v43/evidence/` cuando existan).