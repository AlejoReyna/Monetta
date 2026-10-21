# Guía del cliente — M3

Cuatro pantallas de la guía: Seguimiento (p. 4), Mayoreo y continuidad (pp. 10–11), Contacto (p. 16) y Categorías (p. 18). La comparación de cada mockup con el código se comunicó antes de codificar; los detalles se enlazan abajo. Referencias ya versionadas: [Seguimiento](../style-guideline-migration/content-readiness/evidence/guideline-04.jpg), [Mayoreo](../style-guideline-migration/content-readiness/evidence/guideline-10.jpg), [continuidad](../style-guideline-migration/content-readiness/evidence/guideline-11.jpg), [Contacto](../style-guideline-migration/content-readiness/evidence/guideline-16.jpg), [Categorías](../style-guideline-migration/content-readiness/evidence/guideline-18.jpg).

Rama `feat/client-guide-m3` desde `origin/main` `6bf862c`, que ya incluía #24 y #25. Se trabajó en `/tmp/monetta-client-guide-m3`, conservando los cambios locales del checkout original. Cuatro commits, uno por pantalla. PR en borrador hacia `main`.

| Pantalla | Implementado | Falta respecto de la guía | Evidencia |
|---|---|---|---|
| Seguimiento | Banner claro de mayoreo, cuatro servicios, registro a Cuenta, pie funcional; se conservan catálogo y contenido configurado | Arte exacto, densidad/orden literal, newsletter, oferta de envío gratis y políticas aprobadas | [Comparación](SEGUIMIENTO.md) · [Captura](screenshots/home-followup-390-light.png) |
| Mayoreo + continuidad | Portada, tres pasos, Bolsas/Carteras y Perfumes, servicios, WhatsApp, recomendaciones del catálogo o estado vacío, registro y pie | Arte exacto y foto de perfumes; mínimos, precios, anticipo, plazo y envío con marcadores visibles; newsletter/beneficios pendientes | [Comparación](MAYOREO.md) · [Portada](screenshots/wholesale-390-light.png) · [Continuidad](screenshots/wholesale-continuity-390-light.png) |
| Contacto | Portada, WhatsApp, dos grupos existentes, comunidad de Facebook, redes configuradas y ayuda anterior; menú de Inicio conectado | Arte exacto; horario, correo y línea de voz pendientes de confirmación | [Comparación](CONTACTO.md) · [Captura](screenshots/contact-390-light.png) |
| Categorías | Pantalla propia, ocho colecciones, marcas y «Ver todo», menú y barras conectados, filtros/rutas anteriores conservados | Fotografías exactas y assets de perfumes/accesorios; marcas según configuración, no una lista inventada | [Comparación y rutas](CATEGORIAS.md) · [Captura](screenshots/categories-390-light.png) |

## Capturas

Son evidencias de widgets a 390 y 834 px, con fuentes empaquetadas, modo claro y oscuro; no son capturas conectadas a una tienda o un dispositivo de producción. Las pruebas cubren además 320 px con texto al 200%. Inicio usa mercancía DEMO; Mayoreo muestra el estado sin catálogo ni sesión. Los canales públicos son los ya configurados; las aperturas externas se sustituyen por funciones de prueba. No se importaron datos de clientes, pedidos, cuentas reales ni configuraciones privadas.

| Vista | Teléfono claro | Teléfono oscuro | Tablet |
|---|---|---|---|
| Seguimiento | [390](screenshots/home-followup-390-light.png) | [390 oscuro](screenshots/home-followup-390-dark.png) | [834](screenshots/home-followup-834-light.png) |
| Pie de Inicio | [390](screenshots/home-footer-390-light.png) | [390 oscuro](screenshots/home-footer-390-dark.png) | [834](screenshots/home-footer-834-light.png) |
| Mayoreo | [390](screenshots/wholesale-390-light.png) | [390 oscuro](screenshots/wholesale-390-dark.png) | [834](screenshots/wholesale-834-light.png) |
| Continuidad | [390](screenshots/wholesale-continuity-390-light.png) | [390 oscuro](screenshots/wholesale-continuity-390-dark.png) | [834](screenshots/wholesale-continuity-834-light.png) |
| Contacto | [390](screenshots/contact-390-light.png) | [390 oscuro](screenshots/contact-390-dark.png) | [834](screenshots/contact-834-light.png) |
| Categorías | [390](screenshots/categories-390-light.png) | [390 oscuro](screenshots/categories-390-dark.png) | [834](screenshots/categories-834-light.png) |

## Comparación con main

| Control | `origin/main` (`6bf862c`) | M3 |
|---|---|---|
| `flutter analyze` | Sin incidencias | Sin incidencias |
| `flutter test` | 1,254 correctas, 5 omitidas | 1,272 correctas, 5 omitidas |
| Fallos nuevos pendientes | — | Ninguno |
| Goldens modificados | — | Cuatro candidatos, aprobación visual pendiente |

Se regeneró Dart con `node design-system/build.mjs --only=dart` y se comprobó con `--check`; tokens y manifiesto quedaron idénticos. Los componentes nuevos usan roles, escalas y colores generados mediante el adaptador de tema. Pasan formato de `lib`, `test` e `integration_test`, snapshot del catálogo y gate de secretos. Se revisó `git diff --cached` antes de cada commit; no se incluyeron configs reales, `.env`, llaves ni builds.

La comparación con main confirma que no hay cambios en `features/checkout`, `features/orders`, `features/rewards`, controladores de carrito/pago, router de retorno, `main.dart`, datos Shopify, servicios ni configuración. Solo se cambió presentación y navegación. Se comparten los enlaces públicos de comunidades que ya usaba la pantalla de socios.

## Goldens por aprobar

- [inicio_375x812.png](../../test/goldens/ui04/inicio_375x812.png)
- [inicio_440x956.png](../../test/goldens/ui04/inicio_440x956.png)
- [coleccion_375x812.png](../../test/goldens/ui04/coleccion_375x812.png)
- [coleccion_440x956.png](../../test/goldens/ui04/coleccion_440x956.png)

Los cambios de píxeles frente a main se limitan a la barra inferior: «Inicio», «Categorías» e icono de cuadrícula. Cambia entre 0.1962% y 0.2839% de los píxeles, dentro de la tolerancia existente de 0.5%; la suite inicial ya pasaba con las referencias anteriores. Se actualizaron los cuatro candidatos intencionadamente, sin modificar la tolerancia ni aprobarlos en nombre del propietario. Los otros seis goldens de UI04 no cambian.

## Reproducir y CI

```sh
flutter analyze
flutter test
node design-system/build.mjs --check
dart format --output=none --set-exit-if-changed lib test integration_test
dart run bin/verify_catalog_snapshot.dart
bash bin/check_no_secrets.sh
MONETTA_M3_CAPTURE_DIR=/tmp/monetta-m3-captures flutter test test/features/home/home_followup_presentation_test.dart test/features/wholesale/wholesale_screen_test.dart test/features/contact/contact_presentation_test.dart test/features/catalog/categories_screen_test.dart
```

El estado remoto vigente está en Checks del PR y en [GitHub Actions](https://github.com/AlejoReyna/Monetta/actions); se informa también al entregar. El workflow Quality existente comprueba Flutter, servicios y compilaciones. No se añadieron workflows ni se ejecutaron despliegues, merge, force push o operaciones de Shopify/producción desde esta tarea.
