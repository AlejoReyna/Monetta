# Guía del cliente — M4

Cuatro pantallas de la guía: Personalización (p. 2), Búsqueda (p. 5), Monetta Rewards y continuidad (pp. 14–15) y Menú (p. 19). Rama `feat/client-guide-m4` desde `origin/main` `c390964` (PR #26 / M3). Un commit por pantalla, más este registro. PR en borrador hacia `main`.

Las cifras de la guía (320 puntos, Nivel Plata, 1 pt / $300, `https://monetta.com/catalogo/...`) no se publican como hechos. El saldo de Rewards sale del lector existente, en MXN. Donde no hay contrato, el texto es `Pendiente de contrato`. Mayoreo se guarda como preferencia y no cambia precios.

| Pantalla | Implementado | Falta respecto de la guía | Evidencia |
|---|---|---|---|
| Personalización | Marcas del catálogo, las ocho categorías ya definidas, Menudeo/Mayoreo, guardar, restaurar y editar por cuenta | Arte y rejilla literal de marcas de la guía; Handbags no tiene silueta propia | [Captura](screenshots/personalization-390-light.png) |
| Búsqueda | Resultados en vivo al escribir, consultas de varias palabras, «Ver todo» y estado vacío, por `CatalogStore` | Cromo de la guía (hamburguesa y barra inferior); esta ruta conserva el buscador existente | [Captura](screenshots/search-390-light.png) |
| Rewards | Anillo con el saldo del contrato, nivel y reglas marcados, formas de ganar y canjear, tarjetas para copiar o compartir catálogos | Puntos, niveles, tasas y URLs públicas: no hay contrato | [Resumen](screenshots/rewards-390-light.png) · [Compartir](screenshots/rewards-share-390-light.png) |
| Menú | Identidad, notificaciones, accesos con icono, tarjeta de compartir, WhatsApp, redes configuradas y Categorías | Arte exacto y enlace público de catálogo | [Captura](screenshots/menu-390-light.png) |

## Personalización

Qué se construyó: pantalla en Cuenta para elegir marcas que ya existen en el catálogo, las ocho categorías de `clientGuideCategories` (Crossbody, Tote, Shoulder, Handbags, Carteras, Perfumes, Accesorios, Relojes) y el tipo de compra Menudeo («Una a dos piezas») o Mayoreo («Más de tres piezas»). Guardar, volver a abrir y editar usa la cuenta (`localAccountId`, o invitado). Marcas y estilos siembran el perfil de gusto existente. Mayoreo no entra al perfil, al precio ni al carrito.

Archivos:

- `lib/features/personalization/personalization_screen.dart`
- `lib/features/personalization/shopper_preferences.dart`
- `lib/features/account/account_screen.dart`
- `lib/app/catalog_store.dart`
- `lib/reco/profile.dart`
- `test/features/personalization/personalization_screen_test.dart`

Marcadores: `Mayoreo se guarda solo como preferencia. No cambia los precios.` Las marcas que no están en el catálogo no se inventan.

Preguntas abiertas: Handbags solo siembra la categoría `bolsa`, porque no tiene faceta de silueta. Vaciar marcas y estilos no borra un perfil aprendido por navegación. La guía muestra una rejilla fija (Coach, Michael Kors, Guess y otras); aquí la lista es `CatalogStore.availableBrands`.

## Búsqueda

Qué se construyó: mientras se escribe, la pantalla reutilizada muestra historial coincidente, sugerencias y un carril de productos del `CatalogStore`. Varias palabras exigen que todas aparezcan en la ficha (no hace falta que vayan juntas). «Ver todo» abre la colección con la misma consulta. Sin coincidencias se muestra el estado vacío y no se escribe el historial hasta enviar.

Archivos:

- `lib/features/catalog/search_screen.dart`
- `lib/features/catalog/catalog_controls.dart` (sin cambios; se reutiliza el estado vacío)
- `lib/features/catalog/catalog_query.dart`
- `lib/features/catalog/collection_screen.dart`
- `test/features/catalog/search_screen_test.dart`

Marcadores: ninguno comercial. No se añadieron marcas ni copys de producto.

Preguntas abiertas: la ruta conserva el campo y el retroceso actuales, porque las pruebas y la navegación ya dependen de ese cromo. El historial sigue grabándose solo al enviar la búsqueda.

## Rewards

Qué se construyó: dos pantallas nuevas. El resumen muestra un anillo completo (no un arco de progreso inventado), el saldo de `RewardsReader` y el nivel como marcador. «Cómo ganar puntos» lista Por cada compra, Compartir catálogo en redes y Comprar a mayoreo. «Canjear puntos» lista Descuentos, Envío gratis y Acceso anticipado, con los subtítulos de la guía. «Comparte y gana» abre las tarjetas de bolsos y perfumes. Copiar o compartir solo pone un enlace en el portapapeles si se inyecta una URL; si no, avisa `Enlace pendiente de contrato` y no copia una URL falsa. No se tocó el cálculo, los modelos, la API ni el backend de Rewards.

Archivos:

- `lib/features/rewards/rewards_guide_screen.dart`
- `lib/features/rewards/rewards_share_screen.dart`
- `lib/features/account/account_screen.dart` (fila de navegación)
- `test/features/rewards/rewards_guide_screen_test.dart`

Marcadores: `Pendiente de contrato` en el nivel, en cada forma de ganar, en cada canje y en los puntos por compartir. `Imagen pendiente` en perfumes, porque no hay asset de esa colección. `La guía ilustra puntos y niveles. El saldo mostrado es el contrato en MXN.` Sin saldo: `Monetta Rewards aún no está disponible`.

Preguntas abiertas: el contrato V1 es saldo en centavos MXN, no puntos ni niveles. El referido y los puntos por compartir siguen desactivados. No existe una URL pública de catálogo en la app.

## Menú

Qué se construyó: el cajón de Inicio muestra identidad (o el estado sin nombre), campana de notificaciones, accesos con icono (Bolsas, Carteras, Relojes, Perfumes, Todas las marcas y Categorías), la tarjeta «Comparte el catálogo y gana», WhatsApp del número ya configurado y las redes de `HomeContent`. Se conservan búsqueda, tema, belleza, mayoreo, contacto e historia.

Archivos:

- `lib/features/navigation/monetta_side_menu.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/account/account_screen.dart` (la bandeja de notificaciones queda visible para el menú)
- `test/features/navigation/monetta_side_menu_test.dart`

Marcadores: `Enlace público: pendiente de contrato`. Compartir envía «Únete al mundo de Monetta» sin URL. No se usa la identidad de ejemplo de la guía.

Preguntas abiertas: el enlace público del catálogo no existe. El cajón sigue incluyendo destinos anteriores para no cortar la navegación que ya estaba probada.

## Capturas

Son evidencias de widgets a 390 y 834 px, con fuentes empaquetadas, modo claro y oscuro. No son capturas de una tienda ni de un dispositivo de producción. Personalización y Búsqueda usan el catálogo de demostración. Rewards muestra el saldo de prueba `$184 Monetta` del lector inyectado; ese saldo no es la cifra de la guía.

| Vista | Teléfono claro | Teléfono oscuro | Tablet |
|---|---|---|---|
| Personalización | [390](screenshots/personalization-390-light.png) | [390 oscuro](screenshots/personalization-390-dark.png) | [834](screenshots/personalization-834-light.png) |
| Búsqueda | [390](screenshots/search-390-light.png) | [390 oscuro](screenshots/search-390-dark.png) | [834](screenshots/search-834-light.png) |
| Rewards | [390](screenshots/rewards-390-light.png) | [390 oscuro](screenshots/rewards-390-dark.png) | [834](screenshots/rewards-834-light.png) |
| Compartir catálogo | [390](screenshots/rewards-share-390-light.png) | [390 oscuro](screenshots/rewards-share-390-dark.png) | [834](screenshots/rewards-share-834-light.png) |
| Menú | [390](screenshots/menu-390-light.png) | [390 oscuro](screenshots/menu-390-dark.png) | [834](screenshots/menu-834-light.png) |

## Comparación con main

La corrida completa de `flutter analyze` y `flutter test` en esta rama y en `origin/main` (`c390964`) se anota aquí al terminar. Las pruebas de estas cuatro pantallas, más el cajón de Inicio, pasaron en local. No se regeneraron goldens en este cambio.

`kCheckoutTokenCorrelationAvailable` sigue en `false`. No hay cambios en checkout, pagos, pedidos, modelos/API/backend de Rewards, servicios Shopify ni despliegues.

## Reproducir

```sh
flutter analyze
flutter test
bash bin/check_no_secrets.sh
MONETTA_M4_CAPTURE_DIR=/tmp/monetta-m4-captures flutter test \
  test/features/personalization/personalization_screen_test.dart \
  test/features/catalog/search_screen_test.dart \
  test/features/rewards/rewards_guide_screen_test.dart \
  test/features/navigation/monetta_side_menu_test.dart
```
