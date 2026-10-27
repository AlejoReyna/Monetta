# Guía del cliente — 1:1

Rama `feat/client-guide-1to1`. Borrador hacia `main`. Sin merge, force push ni despliegue. El pago, los métodos de checkout y `kCheckoutTokenCorrelationAvailable` (sigue en `false`) no se tocaron. Tampoco el backend.

Las capturas son la página completa (alto de scroll), tema claro, `devicePixelRatio` 1. Las fotos de producto del test salen de `test/support/fixture_product.jpg` (un packshot local); en la app siguen siendo las URL de Shopify. Cada página tiene la guía y la app juntas en `comparison-NN.png`.

Las páginas de la guía son los JPG ya versionados (`guide-01.jpg` … `guide-19.jpg`).

## Regresión desde el PR #27

`dc94aeb` (merge del PR #27, client-guide-m4) es el punto de partida. Desde entonces, en `main`, solo cambió `services/accounts_orders`: alias de método de pago (`transferencia_bancaria` y `deposito_bancario` → `bank_deposit`) en los PR #29 y #30. Ningún archivo Flutter de pantalla cambió en git por ese drift. Lo que se veía lejos de la guía era la distancia que m1–m4 había dejado.

## Estado por página

`1:1` es el chrome y el orden de la guía, con datos reales. `near` es esa estructura con una diferencia visible que no se puede cerrar sin inventar. `gap` es una pantalla que la guía pide y el contrato no permite dibujar.

| Pág. | Pantalla | Estado | Motivo de lo que todavía difiere | Guía | App | Comparación |
|---|---|---|---|---|---|---|
| 1 | Bienvenida | near | UI: fondo, wordmark y COMENZAR. No hay bolsa recortada: los packshots son opacos (arte/dato, no un control). | [guía](screenshots/guide-01.jpg) | [app](screenshots/p-01-bienvenida.png) | [lado a lado](screenshots/comparison-01.png) |
| 2 | Personalización | near | UI: «GUARDAR PREFERENCIAS» outlined con chevron. Marcas y categorías salen del catálogo (dato). La nota de mayoreo se conserva porque no cambia precios. | [guía](screenshots/guide-02.jpg) | [app](screenshots/p-02-personalizacion.png) | [lado a lado](screenshots/comparison-02.png) |
| 3 | Inicio | near | UI: header (menú, wordmark, lupa), sin buscador de página, un punto de hero, marcas a 4 columnas, «Nueva colección» en grilla de 2. Un solo punto porque solo hay un still (arte del dueño). El catálogo trae 12 marcas, así que son 3 filas, no las 8 del mock (dato). El tail editorial sigue debajo. | [guía](screenshots/guide-03.jpg) | [app](screenshots/p-03-inicio.png) | [lado a lado](screenshots/comparison-03.png) |
| 4 | Seguimiento | near | La guía parte el home en dos; la app es un solo scroll, y la captura es ese home completo (mismo alto que p-03). Hero de seguimiento, «VER COLECCIÓN» y «Lo más buscado» están. El banner de mayoreo no publica $800, 20 días ni envío gratis (dueño). | [guía](screenshots/guide-04.jpg) | [app](screenshots/p-04-seguimiento.png) | [lado a lado](screenshots/comparison-04.png) |
| 5 | Búsqueda | near | UI: mismo chrome, sin chevron de regreso. Resultados y orden son el catálogo real (dato). La captura se corta en 8000 px si la lista es más larga. | [guía](screenshots/guide-05.jpg) | [app](screenshots/p-05-busqueda.png) | [lado a lado](screenshots/comparison-05.png) |
| 6 | Colección (Coach) | near | UI: chrome, banner de estudio si no hay hero propio, grilla de 2, filtro. Precios y piezas son Shopify (dato). | [guía](screenshots/guide-06.jpg) | [app](screenshots/p-06-coleccion.png) | [lado a lado](screenshots/comparison-06.png) |
| 7 | Vista previa | near | UI: «AGREGAR A BOLSA» y «COMPRAR AHORA» apilados. «VER PRODUCTO» queda debajo para no quitar el salto a la ficha. Sin estrellas. | [guía](screenshots/guide-07.jpg) | [app](screenshots/p-07-preview.png) | [lado a lado](screenshots/comparison-07.png) |
| 8 | Ficha | near | UI: flechas, zoom, corazón, marca, nombre, precio (tachado y pastilla solo con `compare_at` real), badges con subtítulos que ya estaban en home, botones apilados, acordeones, «Productos relacionados», nav. Sin estrellas: el modelo no trae reseñas. | [guía](screenshots/guide-08.jpg) | [app](screenshots/p-08-producto.png) | [lado a lado](screenshots/comparison-08.png) |
| 9 | Colección (Bolsas) | near | Misma estructura que la colección. Título y piezas salen del filtro (dato). Tope de captura 8000 px. | [guía](screenshots/guide-09.jpg) | [app](screenshots/p-09-coleccion.png) | [lado a lado](screenshots/comparison-09.png) |
| 10 | Mayoreo | gap | UI de hero, título y banners hecha. Mínimo, anticipo y envío siguen en `WholesalePresentation` (dueño). No se publican $800, 20 días, $1,999 ni «a partir de 3 piezas». | [guía](screenshots/guide-10.jpg) | [app](screenshots/p-10-mayoreo.png) | [lado a lado](screenshots/comparison-10.png) |
| 11 | Mayoreo, continuación | gap | Los pasos siguen en el copy de contrato, no en las cifras del mock (dueño). «¿Tienes dudas?» usa el banner existente. | [guía](screenshots/guide-11.jpg) | [app](screenshots/p-11-mayoreo-continuidad.png) | [lado a lado](screenshots/comparison-11.png) |
| 12 | Mis pedidos | near | UI de filtros y filas. Fotos de línea y estados solo si el pedido real los trae (dato). | [guía](screenshots/guide-12.jpg) | [app](screenshots/p-12-pedidos.png) | [lado a lado](screenshots/comparison-12.png) |
| 13 | Mi cuenta | near | UI: filas de la guía primero (pedidos, favoritos, notificaciones, contacto); extras debajo, sin borrarlas. Identidad = inicial. Rewards sigue en «Pendiente de contrato» (dueño). | [guía](screenshots/guide-13.jpg) | [app](screenshots/p-13-cuenta.png) | [lado a lado](screenshots/comparison-13.png) |
| 14 | Monetta Rewards | gap | El contrato V1 es saldo en centavos MXN. La guía pide puntos, nivel y tasa. No se inventan (dueño). | [guía](screenshots/guide-14.jpg) | [app](screenshots/p-14-rewards.png) | [lado a lado](screenshots/comparison-14.png) |
| 15 | Comparte y gana | near | UI del mockup con una captura real de Inicio. No hay URL pública de catálogo (dueño). | [guía](screenshots/guide-15.jpg) | [app](screenshots/p-15-rewards-share.png) | [lado a lado](screenshots/comparison-15.png) |
| 16 | Contacto | near | UI: hero y canales ya verificados (WhatsApp, grupos, redes). Horario, correo y teléfono de voz no están en el repo (dueño). | [guía](screenshots/guide-16.jpg) | [app](screenshots/p-16-contacto.png) | [lado a lado](screenshots/comparison-16.png) |
| 17 | Compra | near | UI: palomita vectorial (`GuideSuccessMark`, trazo `#A8763E`). Líneas y totales no se fabrican si el resultado de pago no los trae (dato). Sin cambio de lógica de pago. | [guía](screenshots/guide-17.jpg) | [app](screenshots/p-17-compra.png) | [lado a lado](screenshots/comparison-17.png) |
| 18 | Categorías | near | UI: colecciones a 2 columnas, foto con título encima. Marcas debajo. Las fotos son las siluetas del repo, no un set nuevo (arte/dato). | [guía](screenshots/guide-18.jpg) | [app](screenshots/p-18-categorias.png) | [lado a lado](screenshots/comparison-18.png) |
| 19 | Menú | near | UI: orden de la guía (categorías, compartir, WhatsApp, redes) y extras debajo. «COMPARTIR CATÁLOGO». El tema sigue en el header. Sin la línea de enlace pendiente. | [guía](screenshots/guide-19.jpg) | [app](screenshots/p-19-menu.png) | [lado a lado](screenshots/comparison-19.png) |

Chrome común en las pantallas de compra (inicio, búsqueda, colección, ficha, cuenta y las que usan `ClientGuideScaffold`): hamburguesa, wordmark centrado, lupa, y la barra Inicio / Categorías / Carrito / Cuenta. Bienvenida no lleva esa barra: la guía es una portada a sangre.

## Arte

El brief del PM está en [ART_PROMPTS.md](ART_PROMPTS.md). JPG bajo `assets/images/guide/`, declarados en `pubspec.yaml`.

No se publican `producto_fondo` ni `compra_check`. Logos de marca y el wordmark Monetta salen de `assets/images/brands/` y `assets/images/logo_monetta.png`. En Inicio el wordmark oficial se recorta al centro del archivo cuadrado para que ocupe el tile; no se redibuja.

## Goldens UI-04

`test/goldens/ui04_typography_goldens_test.dart` se omite fuera de macOS y tolera 0.5 %. Esta corrida es Linux, así que **no se regeneraron**. Inicio, colección, ficha, búsqueda y cuenta cambiaron píxeles: CI en macOS va a fallar esos goldens hasta que se regeneren en un Mac.

## Verificación

Corrida en Linux (Flutter 3.44.8), con `libsqlite3.so` en `LD_LIBRARY_PATH`. Capturas a página completa (alto del scroll, tope 8000 px en búsqueda y en la colección de bolsas) y `comparison-01.png` … `comparison-19.png`.

- `dart format --set-exit-if-changed lib test integration_test`: limpio
- `flutter analyze lib test`: sin issues
- `flutter test`: 1293 passed, 15 skipped, 0 failed
- `bash bin/check_no_secrets.sh`: OK
- Goldens UI-04: no regenerados en esta VM (el test se omite fuera de macOS). CI en macOS va a fallar esos goldens hasta regenerarlos allí.
