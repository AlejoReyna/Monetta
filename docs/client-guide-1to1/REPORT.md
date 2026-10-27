# Guía del cliente — 1:1

Rama `feat/client-guide-1to1`. Borrador hacia `main`. Sin merge, force push ni despliegue. El pago, los métodos de checkout y `kCheckoutTokenCorrelationAvailable` (sigue en `false`) no se tocaron.

Capturas de la app a 390×844, tema claro, `devicePixelRatio` 1, con `pumpClientGuide`. La vista previa (p.7) incluye el sheet: el `RepaintBoundary` de la home no cubre el overlay, así que la captura pinta el render view completo. Las fotos de Shopify no se descargan en el test de widgets (el cliente HTTP de prueba responde 400); la galería de la ficha puede verse vacía en el PNG aunque en la app usa la URL del catálogo.

Las páginas de la guía son los JPG ya versionados (`guide-01.jpg` … `guide-19.jpg`), copiados desde `docs/style-guideline-migration/content-readiness/evidence/`.

## Regresión desde el PR #27

`dc94aeb` (merge del PR #27, client-guide-m4) es el punto de partida. Desde entonces, en `main`, solo cambió `services/accounts_orders`: alias de método de pago (`transferencia_bancaria` y `deposito_bancario` → `bank_deposit`) en los PR #29 y #30. Ningún archivo Flutter de pantalla, copia u orden de secciones cambió en git. Lo que se veía lejos de la guía era la distancia que m1–m4 había dejado, no un drift de layout posterior.

## Estado por página

| Pág. | Pantalla | Estado | Qué cambió | Hueco que queda | Guía | App |
|---|---|---|---|---|---|---|
| 1 | Bienvenida | near | Fondo `bienvenida_fondo.jpg`, velo más claro, wordmark oficial, «COMENZAR» | No se compone una bolsa. Las fotos del catálogo son packshots opacos (alfa mínimo 255), no recortes | [guía](screenshots/guide-01.jpg) | [app](screenshots/p-01-bienvenida.png) |
| 2 | Personalización | near | «Guardar preferencias» con chevron; la opción elegida es un punto | Marcas y categorías salen del catálogo. Se conserva la nota de mayoreo | [guía](screenshots/guide-02.jpg) | [app](screenshots/p-02-personalizacion.png) |
| 3 | Página principal | near | Apertura: Compra por estilo, Tus marcas favoritas, hero «NUEVA / COLECCIÓN» con `home_hero_fondo.jpg` | El buscador de la página sigue arriba del hero (la guía solo lo tiene en el header; el test de home lo exige). Siluetas desde `HomeContent`, no la lista Crossbody/Tote/Shoulder/Satchel/Hobo. «Nueva colección» es un riel de `ProductCard`, no una grilla de dos columnas | [guía](screenshots/guide-03.jpg) | [app](screenshots/p-03-inicio.png) |
| 4 | Seguimiento | near | Hero `seguimiento_hero_fondo.jpg`, «LO MÁS NUEVO DE TUS MODELOS FAVORITOS», «VER COLECCIÓN», luego «Lo más buscado» | El tail editorial (colecciones, about, redes, testimonios) sigue después del footer. El banner de mayoreo no publica $800, 20 días ni envío gratis | [guía](screenshots/guide-04.jpg) | [app](screenshots/p-04-seguimiento.png) |
| 5 | Búsqueda | near | Wordmark centrado y barra Inicio / Categorías / Carrito / Cuenta | Sigue el chevron de regreso; la guía muestra hamburguesa. Resultados del catálogo real | [guía](screenshots/guide-05.jpg) | [app](screenshots/p-05-busqueda.png) |
| 6 | Colección (Coach) | near | Si no hay hero propio, banner `studio_banner_fondo.jpg` | Precios y piezas son el catálogo de Shopify, no un set fijo de la guía | [guía](screenshots/guide-06.jpg) | [app](screenshots/p-06-coleccion.png) |
| 7 | Preview | near | Muelle «Agregar a bolsa». La captura incluye el sheet | `producto_fondo` no se usa (packshots opacos). No hay un segundo botón «Comprar ahora» en el sheet | [guía](screenshots/guide-07.jpg) | [app](screenshots/p-07-preview.png) |
| 8 | Página del producto | near | El muelle dice «Agregar a bolsa». «Comprar ahora» sigue más abajo, sin un camino de pago nuevo | Sin pedestal. La galería es la foto del catálogo. En el PNG de widget la CDN no carga | [guía](screenshots/guide-08.jpg) | [app](screenshots/p-08-producto.png) |
| 9 | Colección (Bolsas) | near | Mismo fallback de estudio | La app muestra precios del catálogo | [guía](screenshots/guide-09.jpg) | [app](screenshots/p-09-coleccion.png) |
| 10 | Mayoreo | near | Hero de estudio, «MAYOREO», «Obtén precios especiales». Banners de categoría con el mismo still | Mínimo, anticipo y envío siguen como pendientes. No se publican $800, 20 días, $1,999 ni «a partir de 3 piezas» | [guía](screenshots/guide-10.jpg) | [app](screenshots/p-10-mayoreo.png) |
| 11 | Mayoreo, continuación | near | «¿Tienes dudas?» sobre `comparte_banner_fondo.jpg` | Los pasos siguen en «Elige tus productos / Consulta el mínimo / Liquida o aparta» con subtítulos de `WholesalePresentation` | [guía](screenshots/guide-11.jpg) | [app](screenshots/p-11-mayoreo-continuidad.png) |
| 12 | Mis pedidos | near | Sin cambio de estructura respecto a m2: filtros, estados reales, identidad | El modelo puede no traer fotos de línea. No se inventan | [guía](screenshots/guide-12.jpg) | [app](screenshots/p-12-pedidos.png) |
| 13 | Mi cuenta | near | Banner «Comparte el catálogo y gana». La identidad es la inicial en un círculo | No es la foto de «Ana». Siguen filas extra (admin, baja, privacidad). Rewards sigue en «Pendiente de contrato» | [guía](screenshots/guide-13.jpg) | [app](screenshots/p-13-cuenta.png) |
| 14 | Monetta Rewards | gap | Nada de puntos, niveles ni tasas inventados | El contrato V1 es saldo en centavos MXN. La guía pide puntos, nivel y tasa; la pantalla dice «Pendiente de contrato» | [guía](screenshots/guide-14.jpg) | [app](screenshots/p-14-rewards.png) |
| 15 | Comparte y gana | near | Mockup con `rewards_app_screen.jpg` (captura real de Inicio) sobre el vidrio | No hay URL pública de catálogo. El vidrio se midió en el PNG 1024×620 (bisel en x=648); el marco está un poco inclinado | [guía](screenshots/guide-15.jpg) | [app](screenshots/p-15-rewards-share.png) |
| 16 | Contacto | near | Hero de estudio, «Tu boutique y proveedor de confianza.» | Los canales siguen siendo los verificados (WhatsApp, grupos, redes). Horario, correo y teléfono de voz siguen pendientes | [guía](screenshots/guide-16.jpg) | [app](screenshots/p-16-contacto.png) |
| 17 | Pantalla de compra | near | Palomita en `GuideSuccessMark` (`CustomPaint`, trazo `#A8763E`). El PNG de referencia no se publica | Líneas y totales no se fabrican si el resultado de pago no los trae | [guía](screenshots/guide-17.jpg) | [app](screenshots/p-17-compra.png) |
| 18 | Categorías | near | Sin inventario falso | Las miniaturas salen del contenido del catálogo, no de una grilla dibujada a mano | [guía](screenshots/guide-18.jpg) | [app](screenshots/p-18-categorias.png) |
| 19 | Menú | near | Tarjeta de compartir con `comparte_banner_fondo.jpg`. Enlace: pendiente de contrato | Siguen destinos extra (tema, belleza, mayoreo, historia). La identidad es el nombre real, no una foto | [guía](screenshots/guide-19.jpg) | [app](screenshots/p-19-menu.png) |

Ninguna página queda en 1:1 estricto: o falta una pieza que no se puede publicar sin inventar datos (rewards, mayoreo, bolsa recortada), o queda un control que los tests y el catálogo ya fijaron (buscador de home, chevron de búsqueda, tail editorial).

## Arte

El brief del PM está en [ART_PROMPTS.md](ART_PROMPTS.md). JPG bajo `assets/images/guide/`, declarados en `pubspec.yaml` (Flutter no hereda subcarpetas). Todos ≤ 400 KB.

| Archivo | Bytes | Uso |
|---|---:|---|
| `bienvenida_fondo.jpg` | 64793 | Bienvenida |
| `home_hero_fondo.jpg` | 64395 | Hero «Nueva colección» |
| `studio_banner_fondo.jpg` | 40829 | Contacto, Mayoreo, banner de mayoreo en Inicio, colección sin foto, «Bolsas y carteras» y Perfumes |
| `seguimiento_hero_fondo.jpg` | 56013 | Hero «Tus modelos favoritos» |
| `rewards_phone_mockup.jpg` | 22694 | Teléfono de «Comparte y gana» |
| `rewards_app_screen.jpg` | 33186 | Captura de Inicio pegada al vidrio |
| `comparte_banner_fondo.jpg` | 8868 | «Comparte el catálogo» y «¿Tienes dudas?» |

No se publican `producto_fondo` ni `compra_check`. Logos de marca y el wordmark Monetta salen de `assets/images/brands/` y `assets/images/logo_monetta.png`.

## Verificación

Los goldens UI-04 (`test/goldens/ui04_typography_goldens_test.dart`) se omiten fuera de macOS y toleran 0.5 %. Esta corrida es Linux, así que no se regeneraron. Inicio, colección, ficha y cuenta cambiaron píxeles: CI en macOS va a pedir regenerarlos.

Corrida en Linux (Flutter 3.44.8), con `libsqlite3.so` en `LD_LIBRARY_PATH`:

| Control | Resultado |
|---|---|
| `flutter analyze` | Sin incidencias |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Sin cambios |
| `flutter test` | 1305 pasaron, 15 omitidas (los goldens UI-04 no corren en Linux), 0 fallos |
| `bash bin/check_no_secrets.sh` | OK. Sin `dart_defines` privados, `.env`, keystore ni tokens en el diff |
