# Guía del cliente — M2

Rama `feat/client-guide-m2`, creada desde `origin/main` en `79dd047` (PR #24 integrado). Trabajo aislado en `/tmp/monetta-client-guide-m2`; se conservó el checkout original y sus cambios locales. Tres commits: bienvenida, pedidos y compra. PR en borrador hacia `main`; sin merge, force push ni despliegue.

La comparación de las páginas 1, 12 y 17 del PDF se comunicó antes de codificar. Referencias ya versionadas: [bienvenida](../style-guideline-migration/content-readiness/evidence/guideline-01.jpg), [pedidos](../style-guideline-migration/content-readiness/evidence/guideline-12.jpg), [compra](../style-guideline-migration/content-readiness/evidence/guideline-17.jpg).

| Pantalla | Cumple | Diferencias pendientes | Evidencia y detalle |
|---|---|---|---|
| Bienvenida | Composición luminosa, textos, logo, botón con flecha, primera visita/onboarding y adaptación de tamaño | Foto de cortinas/Coach y logo metálico exactos: se usan los recursos disponibles | [Captura](screenshots/welcome-390.png) · [comparación](BIENVENIDA.md) |
| Mis pedidos | Marca, título serif centrado, filtros marrones, estados reales con iconos, identidad/fecha/total, detalle, menú/búsqueda/barra inferior | Modelo sin líneas ni fotos; panel de ausencia. “Completos” filtra entregados con evidencia; filtros pertinentes y Apartados se conservan | [Claro](screenshots/orders-390.png) · [oscuro](screenshots/orders-390-dark.png) · [comparación](PEDIDOS.md) |
| Compra | Check, agradecimiento, resumen explícito, acciones, navegación, mini carrito y avisos de retorno armonizados | Faltan líneas, total e identidad autoritativos en el resultado de pago; no se fabrican | [Claro](screenshots/purchase-390.png) · [oscuro](screenshots/purchase-390-dark.png) · [tablet](screenshots/purchase-834.png) · [comparación](COMPRA.md) |

La navegación nueva usa rutas existentes: Categorías abre el catálogo; el menú de estas dos pantallas reúne los cuatro destinos de la barra inferior. Se conserva el regreso del sistema. No replica las demás secciones del menú general de Inicio.

## Verificación contra main

| Control | `origin/main` (79dd047) | M2 |
|---|---|---|
| `flutter analyze` | Sin incidencias | Sin incidencias |
| `flutter test` | 1237 correctas, 5 omitidas | 1254 correctas, 5 omitidas |
| Fallos nuevos pendientes | — | Ninguno con los dos goldens candidatos; aceptación visual pendiente |
| Goldens modificados | — | Solo los dos de Bolsa enumerados abajo |

La primera comparación detectó el cambio visual esperado en los dos goldens y una expectativa de texto antigua de la confirmación; se actualizaron las etiquetas sin quitar comprobaciones de navegación. La suite completa se repitió tras los cambios. No se alteró la tolerancia visual ni se omitieron pruebas nuevas.

Además: regeneración Dart desde `design-system/` y comprobación de salidas/contraste; formato de `lib`, `test` e `integration_test`; snapshot de catálogo; gate de secretos y revisión de `git diff --cached` antes de cada commit. El manifiesto y el archivo generado no requirieron cambios. Los nuevos componentes usan escalas/roles generados y el adaptador de tema existente.

Protección comprobada por comparación con main: bloque `CheckoutFlowScreen`/State idéntico, `order_status.dart`, coordinador, controlador de carrito, política de retorno, lookup y guardia de revisión sin modificaciones. Se preservan transferencia, “Pago en proceso”, correlación y `kCheckoutTokenCorrelationAvailable`. No se agregan archivos de configuración real, `.env`, llaves, builds, datos bancarios, correos o credenciales. Capturas de pedidos con `#DEMO-1/2`; no son pedidos reales.

## Aprobación visual pendiente de Alexis

- [test/goldens/ui04/bolsa_375x812.png](../../test/goldens/ui04/bolsa_375x812.png)
- [test/goldens/ui04/bolsa_440x956.png](../../test/goldens/ui04/bolsa_440x956.png)

Son candidatos incluidos en el PR, no una aprobación visual. Los PNG de `screenshots/` son evidencia de revisión de widgets, no goldens añadidos ni capturas de un dispositivo conectado a la tienda.

## Reproducir

```sh
flutter analyze
flutter test
node design-system/build.mjs --check
MONETTA_M2_CAPTURE_DIR=/tmp/monetta-m2-captures flutter test test/features/welcome/welcome_presentation_test.dart test/features/orders/orders_presentation_test.dart test/features/checkout/purchase_presentation_test.dart
```

El estado actualizado del CI se consulta en Checks del PR y se comunica en la entrega. No se ejecutaron builds, despliegues ni operaciones de Shopify desde esta tarea; el CI puede ejecutar sus compilaciones habituales.
