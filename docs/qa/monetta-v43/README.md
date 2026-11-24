# Monetta UI v4.3 · verificación local

## Ajustes de cierre y escalabilidad (22 de noviembre de 2026)

Se aplicaron los ajustes de escalabilidad y cierre sobre la copia local de `fix/web-brands-row` sin alterar las referencias históricas de `test/goldens/ui04/`:

- **Escalabilidad >1,000 productos en web:** `templates/collection.ofertas.json` pasó a `48` productos por página, `sections/monetta-collection.liquid` exige al menos `48` en Ofertas y agrega el botón `[data-collection-more]`, `assets/monetta-listing.js` limita la búsqueda local a lotes de `10` páginas (`MAX_PAGES_PER_SCAN = 10`) con respaldo de continuación y backoff ante `HTTP 429`, `sections/monetta-product-rail.liquid` prioriza `nueva-coleccion`/`novedades` y reduce a `40` la paginación cuando no ordena por fecha, y `snippets/monetta-home-feed.liquid` pagina por `40`.
- **Registro Rewards (`G01`/`G17-A`):** se retiró la doble compuerta en `templates/index.json` (`registro` con `enabled: true` y sin `enabled` en `banners`) y se añadió respaldo `routes.account_login_url` en `snippets/monetta-rewards-register.liquid` y `assets/monetta-guia.js`, manteniendo `monetta_rewards_signup` y `monetta_rewards_shipping` en `false` por defecto hasta cerrar `P01` y checkout.
- **Menú web autenticado (`G02`):** `sections/monetta-header.liquid` y `assets/monetta-v43.css` leen metafields reales (`rewards_tier` y `rewards_balance`, mostrando el bloque `Saldo` en dos líneas verde `#3B7030` con contraste AA) sin fabricar niveles ni saldos.
- **Reposición (`G12`):** `ProductScreen` y `QuickView` conectan `showRestockRequestSheet` y `submitRestockViaPushNotifications` únicamente cuando `NotificationScope.maybeOf(context)?.variantRestockAvailable == true` (oculto sin backend por variante).
- **Retiro de «Compartir catálogo»:** se desconectó `PartnerHubScreen` de `HomeScreen` (y de `AccountScreen` / `AboutMonettaScreen`, que ahora enlaza a `WholesaleScreen`), se actualizó el copy de `AboutMonettaScreen` hacia Mayoreo y el tooltip de `PartnerHubScreen`.
- **«6 pagos sin intereses» (`G09`/`G10`) y decisión Invitado/Iniciar sesión (`G39`):** franja condicional ligada exclusivamente a metafield/dato autoritativo por variante (`six_msi_amount` en web y `ProductVariant.sixMsiInstallmentAmount` en Flutter), y modal explícito `_showGuestCheckoutChoiceSheet` (`Iniciar sesión` con Halo C y `Continuar como invitado` sin halo) al entrar a `openCheckout` como invitado con login disponible.

### Verificación de la pasada del 22 de noviembre

- `node design-system/build.mjs --check`, `node tools/style-guideline-theme/port-css.mjs --check` y `git diff --check`: pasaron.
- Arnés web Playwright (`docs/qa/monetta-v43/storefront.mjs`): pasaron AT-01 a AT-05 junto con búsqueda por lotes de 12 páginas y recuperación de `HTTP 429`, compuerta de registro Rewards, metafields de `G02`, franja condicional de 6 pagos sin intereses por variante y `axe-core` con `0` infracciones.
- `@shopify/theme-check-node` sobre `storefront-theme/`: `251` hallazgos heredados, `0` en los archivos modificados.
- `dart format --output=none --set-exit-if-changed` sobre los 10 archivos Dart modificados y `flutter analyze --no-fatal-infos lib test integration_test`: `0` errores, `0` advertencias y `389` observaciones informativas heredadas.
- `flutter test --exclude-tags golden`: `1,826` pruebas aprobadas, `5` omitidas y `0` fallos (los 10 goldens `ui04` permanecen intactos a la espera de aprobación visual humana).

## Correcciones tras la segunda QA del navegador

Se revisaron el informe y las capturas del 20 de noviembre. El borrador `193804599330` recibió nueve archivos actualizados y la descarga de verificación coincidió byte a byte. Theme Check mantuvo 253 hallazgos heredados y el arnés local volvió a pasar AT-01 a AT-05.

| Hallazgo | Resultado |
| --- | --- |
| Carrito a 320 px y cabecera a 390 px | Chromium en staging confirmó el acceso completo a «Iniciar sesión» y los controles de cabecera dentro de la pantalla a 320 y 390 px. Las acciones del carrito conservan un área visible independiente del desplazamiento de líneas y sugerencias. |
| Texto de Mayoreo | Staging pasó con texto al 200% a 320, 640 y 1280 px. El riel móvil muestra un paso completo por avance y la cuadrícula se ajusta al ancho disponible. |
| Menú y foco | Staging pasó a 1280 y 1440 px. «Inicio» aparece en el menú, una pulsación de Escape lo cierra y el foco vuelve a «Abrir menú». En una carga nueva, el primer Tab enfocó «Saltar al contenido» y «Agregar» mostró un contorno visible de 3 px. |
| Regreso desde ficha | Con filtros y búsqueda en Ofertas, staging volvió a la misma posición de desplazamiento (176 px antes y después) tras abrir la vista rápida y la ficha. |
| Contacto y cantidad | El encabezado equivalente de B31 contiene «confianza.» una sola vez. Un doble clic rápido en «+» agregó una sola unidad en el carrito de staging. La compra inmediata conserva la línea confirmada para poder retomar el checkout si se vuelve a la tienda. |

La API Storefront de staging devolvió México como mercado y el inglés como único idioma publicado. Para que el checkout muestre español se debe publicar ese idioma y habilitarlo para México en Shopify, además de verificar las traducciones de entrega y checkout. [Idioma del checkout](https://help.shopify.com/en/manual/checkout-settings/checkout-language) · [Idiomas de Markets](https://help.shopify.com/en/manual/markets/getting-started/localization)

La aceptación con datos reales aún requiere un producto con opciones en Para ti, dos variantes elegibles y una no elegible con la regla de Mayoreo, y una cuenta de cliente de prueba autorizada. La prueba local sí cubre la selección de variantes y el escenario de ajuste de cantidades con descuento simulado.

## Verificación en staging con catálogo real

Se duplicó el tema activo `193754824738` para montar la revisión en el borrador `193804599330`. La copia conserva `config/settings_data.json` y las rutas de cuenta del entorno. Shopify confirmó la carga y el navegador confirmó el ID del tema servido. [Abrir el preview del borrador](https://monetta-staging.myshopify.com/?preview_theme_id=193804599330)

| Recorrido | Evidencia de Shopify |
| --- | --- |
| Ofertas | `/collections/ofertas` devolvió 404. El menú del borrador abre `/collections/all?view=ofertas`, que encontró 39 productos con una variante disponible en oferta durante la prueba. Se abrió la rápida y luego la ficha con el mismo ID de variante. Atrás conservó la consulta. Se corrigió el título «Ofertas», pasó el arnés local y Shopify devolvió el archivo corregido al descargarlo del borrador. El navegador recibió 429 en la comprobación final. |
| Colecciones | Una búsqueda en Catálogo devolvió 67 coincidencias del catálogo real. Categorías y Todas las marcas abrieron con su contenido. |
| Agregar y ajustar | Nueva colección, Para ti y Vista rápida confirmaron una unidad en el lateral del borrador. Una prueba independiente del mismo tema confirmó el alta desde ficha, el recorrido de cantidades 2→3→4→2 y el cierre con el carrito vacío. |
| Compra inmediata | La prueba local pasó con y sin selector. En la segunda QA del navegador pasó con variante única y conservó la línea previa. El caso con opciones quedó pendiente de un producto adecuado en Para ti. |
| Entrega invitada | El botón del lateral abrió Shopify Checkout con HTTP 200. Para el carrito de dos piezas, Shopify Ajax devolvió Estándar a $0 MXN y Expreso a $195 MXN para los CP 64000 y 66200. Son tarifas observadas en staging para esa compra. |
| Mayoreo y Contacto | El CTA B04 abrió la vista de respaldo de Mayoreo y mostró los tres pasos. La vista de respaldo de Contacto mostró B31 y el enlace a WhatsApp. Las páginas con los handles directos `contacto` y `mayoreo` devolvieron 404. |
| Regresión de tema | Shopify confirmó la carga final sin incidencias y la descarga de verificación devolvió las plantillas y la configuración esperadas. Theme Check comparó el tema activo descargado con el borrador preparado y mantuvo 253 hallazgos heredados, con cero nuevos. La prueba web local volvió a pasar AT-01 a AT-05. |

El carrito de prueba devolvió descuento cero para las cantidades observadas. La validación de la elegibilidad de mayoreo requiere las variantes que cubra la regla comercial. Shopify CLI tenía acceso a temas y carecía de autenticación de una app para leer descuentos por Admin API. Queda por comprobar la recotización con una cuenta identificada y las capacidades de Rewards, seis pagos y reposición. Las pruebas se detuvieron antes de registrar un pedido o cobro.

## Dictamen y plan de cierre del 20 de noviembre de 2026

**La entrega estaba implementada parcialmente.** La revisión partió de `fix/web-brands-row`, commit `22f31da`, y de los archivos funcionales v4.3 que ya estaban en la copia de trabajo. Se cotejaron las 52 fichas del maestro UI v4.3 (pp. 93–110), los casos AT-01 a AT-05 (p. 122), las dependencias (p. 123) y las láminas móvil y escritorio de la guía v3.2 (pp. 2–25), con la precedencia de la p. 3 del maestro. El atlas y la guía muestran datos de ejemplo.

| Paso | Brecha observada | Implementación y criterio de cierre |
| --- | --- | --- |
| 1. Consolidar el tema entregado | El commit referenciaba seis archivos de tema presentes solo en la copia de trabajo. | Incluir en el conjunto de cambios CSS v4.3, recomendaciones, acción de agregar, registro, precio por variante y plantilla de Marcas. Validar las referencias y ejecutar Theme Check contra la línea de base. |
| 2. Cerrar búsqueda y Ofertas (G05, G05-A, G05-B) | El catálogo web carecía de búsqueda dentro de cada colección. Una faceta podía devolver un artículo por una variante y mostrar el descuento de otra. Si faltaba la colección, desaparecía el destino del menú. | Buscar dentro del alcance filtrado, incluso en páginas posteriores. Exigir variante disponible, comparación válida y coincidencia con facetas y rango de precio. Usar primero la colección configurada y, si falta, la vista `/collections/all?view=ofertas`. Probar página posterior, filtros, orden, ficha y retorno a la consulta. |
| 3. Corregir compra inmediata (G01-B, G10, G14) | Una respuesta de alta 200 sin HTML de carrito permitía ir al pago pese a fallar la lectura. Para ti con opciones abría la ficha web y en Flutter terminaba en la bolsa. | Compartir alta y comprobación del carrito web. Si Shopify aceptó el alta y la lectura falla, repetir solo la lectura desde la misma acción. En Para ti abrir el selector web o exigir una elección explícita en Flutter. Flutter usa el checkout de la bolsa desde Para ti y la ficha. Cubrir stock rechazado, cancelación, doble toque y conservación de las líneas anteriores. |
| 4. Alinear lateral y menú (G02, G14, G14-C) | En web el lateral mostraba texto de tarifa bajo Total y el avión era oscuro. Flutter colocaba Continuar antes de las recomendaciones. El menú web enseñaba un saldo vacío y un separador de nivel. | Aplicar el orden del maestro (pp. 32–35), el avión dorado de Rewards condicionado a la configuración de la tienda y datos de miembro disponibles. Verificar que Ofertas sea accionable con teclado y que el menú devuelva el foco a su disparador. |
| 5. Validar y aceptar | La aceptación comercial exige pruebas en Shopify. La verificación del 20 de noviembre encontró la pantalla de contraseña en Inicio, Categorías, Contacto y Mayoreo del preview. Ofertas devolvió 429. | Ejecutar los cinco recorridos en local. Con acceso a staging, confirmar tema servido, colección y facetas, identidad al pagar, tarifa y descuentos. Cerrar las dependencias comerciales y comprobar iOS, Android y Duo en dispositivos. |

La vista alternativa de Ofertas se construye con los precios y el inventario del catálogo público del mercado actual. La consulta de solo lectura a la API Storefront de staging devolvió HTTP 200. El canal de la app no expuso la colección `ofertas` y devolvió al menos una variante con descuento y stock en la muestra de 30 productos de hasta 8 variantes cada uno. El canal y el tema web requieren su propia comprobación. La selección se apoya en [`variant.matched` de Shopify](https://shopify.dev/docs/api/liquid/objects/variant#variant-matched), y la recuperación del carrito vuelve a leer las secciones de [Ajax Cart API](https://shopify.dev/docs/api/ajax/reference/cart#bundled-section-rendering).

## Resultados por recorrido

| Caso | Shopify local | Flutter local | Verificación pendiente |
| --- | --- | --- | --- |
| AT-01 Ofertas | Entrada del menú con vista de respaldo, comparación de variante que cruza facetas y precio, segunda página, cambio de color y consulta restaurada en el retorno. | Colección fija de variantes disponibles con oferta, búsqueda local y selección por ID. | Confirmar colección `ofertas` o vista de respaldo, filtros por mercado y vigencia en staging. |
| AT-02 Agregar | Nueva colección, Para ti, rápida y ficha usan la misma mutación. Opción obligatoria, doble toque, rechazo de stock, recuperación de 200/503 sin repetir alta y foco al cerrar. | Destacados, rápida y ficha comparten la bolsa editable. Comprar ahora continúa al flujo protegido de pago. Pruebas de pendiente, error y variante. | Confirmar reconciliación de carrito Shopify, concurrencia y continuidad en dispositivos Duo. |
| AT-03 Carrito | Fixture de 2→3→4→2 con dos variantes elegibles y una línea no elegible, descuento de la respuesta, error en línea, invitado y cuenta. | Secuencia editable, recomendaciones antes de Continuar al pago y cierre con Atrás. Importes de la tienda a cargo de Shopify. | Reglas de elegibilidad, tarifa invitada, crédito, reidentificación y recotización dentro de checkout. |
| AT-04 Banners | B01–B03 con destinos distintos, B04 editorial con CTA accionable, B08, B28, B31 y B32. En ancho estrecho con texto al 200%, el CTA pasa debajo del arte para conservar el lettering completo. | B04 editorial y verificación a 320 puntos con texto ampliado. | Cotejar destinos publicados y lectura visual de los artes a ampliación del sistema en dispositivos físicos. |
| AT-05 Responsive | Inicio, menú, ficha y carrito a 320/390/768/1440 px con movimiento reducido. Escape y foco de retorno del menú. Texto del menú ampliado al 200%. | Ficha y lateral a los cuatro anchos, área segura y extensión de texto en B04. | VoiceOver/TalkBack, teclado virtual real, opacidad bajo ajustes del sistema y mediciones de campo p75. |

### Resultado de las pruebas del 20 de noviembre

- Playwright en Chromium con Node 24.22.3 pasó AT-01 a AT-05 con Liquid y respuestas sintéticas. Axe reportó cero infracciones en las cuatro vistas verificadas a 390 px. La búsqueda de colección encontró una coincidencia en la segunda página, recuperó un HTTP 503 con la consulta intacta y conservó el término al cambiar el orden. Los controles de Ofertas en menú se probaron al doble de su tamaño de texto, con retorno de foco a 320, 390, 768 y 1440 px. La validación con lector de pantalla y zoom nativo queda pendiente.
- Flutter 3.44.8, suite completa. 1,821 aprobadas, 5 omitidas y 10 fallos de referencia de UI-04. Los diez renders de Inicio, Colección, Ficha, Bolsa y Cuenta son idénticos byte a byte a los generados en `22f31da` con el mismo SDK. Las referencias quedan como evidencia histórica. El análisis de `lib test integration_test` reportó 389 observaciones informativas y cero errores o advertencias.
- Theme Check con Node 24.22.3. 251 hallazgos en la base y 251 en la revisión, con cero nuevos. Pasaron los generadores de diseño, el formato de Dart modificado y `git diff --check`.
- Android compiló e instaló el APK `stagingDebug` de prueba. La ejecución de arranque en el emulador quedó incompleta. La interfaz del sistema dejó de responder durante el intento automatizado y el APK se quedó en la pantalla de arranque al abrirlo manualmente. El test usa ahora la navegación vigente de Inicio, Categorías y el banner al catálogo, y pasó análisis estático.
- La revisión inicial se detuvo en la pantalla de contraseña y el 429. La sección de staging al principio recoge las verificaciones realizadas después de obtener acceso.

### Reproducir

La prueba web carga las secciones Liquid, las hojas de estilo, los assets y los JS del tema real. El servidor solo escucha en loopback y reemplaza las respuestas de Shopify por fixtures sintéticos. LiquidJS aproxima el contexto de Shopify y las rutas de cuenta/checkout, filtros y descuentos reales requieren otro entorno. Las capturas y los informes se guardan fuera del repositorio.

```sh
npm install --prefix /tmp/monetta-v43-qa liquidjs playwright axe-core @shopify/theme-check-node
/tmp/monetta-v43-qa/node_modules/.bin/playwright install chromium
MONETTA_QA_DEPS=/tmp/monetta-v43-qa node docs/qa/monetta-v43/storefront.mjs
MONETTA_1TO1_CAPTURE_DIR=/tmp/monetta-v43-qa/app flutter test test/features/monetta_v43_acceptance_test.dart test/features/home/home_followup_presentation_test.dart
node design-system/build.mjs --check
node tools/style-guideline-theme/port-css.mjs --check
git diff --check
```

La evidencia de esta revisión quedó en `/tmp/monetta-v43-review/web` y `/tmp/monetta-v43-review/app`. Los comandos anteriores guardan una reproducción nueva en `/tmp/monetta-v43-qa`. Las referencias históricas de [Inicio web](../../audits/2026-11-11-v41/evidence/viewport-home-390-1x.png) e [Inicio Flutter](../../client-guide-m3/screenshots/home-followup-390-light.png) permiten comparar los rieles y B04. Los fixtures no usan identidades ni pagos reales.

## Matriz de 52 fichas

**QA** indica un recorrido ejercitado con fixtures locales. **Código** indica revisión de la entrada y de su dependencia. **Condicionado** identifica una capacidad editorial, del dispositivo o de una integración que requiere verificación aparte.

| Ficha | Shopify | Flutter | Fuente y evidencia | Pendiente |
| --- | --- | --- | --- | --- |
| G01 Inicio | `index.json`, `monetta-guia-home` | `HomeScreen` | Manifiesto y catálogo, QA AT-04/05 | Orden efectivo de las secciones y configuración de Rewards |
| G01-A Nueva colección | `monetta-home-feature` | `HomeNewCollectionSection` | Catálogo Shopify, QA AT-02 | Fecha de alta aprobada, colección editorial y límite de 40 en staging |
| G01-B Lo más buscado y Para ti | `monetta-product-rail`, `monetta-home-feed` | `HomeMostWantedSection`, `HomeForYouSection` | Colección editorial o historial local, QA AT-02 | Colección de Lo más buscado, historias y control de rotación |
| G02 Menú | `monetta-header` | `MonettaSideMenu` | Rutas, cuenta y catálogo, QA AT-01/05 | Redes y saldo web |
| G03 Categorías | `monetta-guia-categories` | `CategoriesScreen`, `CategoryTree` | Manifiesto y facetas, revisión de código | Ratificar todos los destinos y subniveles web |
| G04 Todas las marcas | `list-collections.marcas.json` | `BrandsScreen` | Logos y proveedores, QA AT-04 | Confirmar el alternate view y la lista configurada en staging |
| G05 Colección y catálogo | `monetta-collection` | `CollectionScreen` | Shopify y caché, QA de banner y búsqueda local paginada con reintento | Datos y facetas del catálogo de staging |
| G05-A Colección de marca | `monetta-collection`, `monetta-guia-url` | `BrandScreen` | Vendor/faceta, manifiesto y búsqueda local, QA B28 | Colecciones, logos y facetas por entorno |
| G05-B Ofertas | `monetta-collection`, `monetta-listing.js` | `CollectionScreen(offersCollection: true)` | Variante, precio, comparación, facetas, paginación y stock, QA AT-01 | Colección o vista de respaldo en staging y vigencia comercial |
| G06 Búsqueda global | `monetta-search`, predictive search | `SearchScreen` | Shopify y caché, código y pruebas existentes | Journey de staging y relevancia real |
| G07 Filtros | `monetta-listing-layout` | `CatalogControls`, `CollectionScreen` | Shopify Search & Discovery y facetas, código | Facetas habilitadas y conteos en staging |
| G07-A Nuevos, ofertas, disponibles | Filtros nativos y vista Ofertas | `matchingCatalogVariants` | Variante Shopify, QA AT-01 | Campo de alta y filtro de vigencia web |
| G08 Ordenar | `monetta-listing.js` | `CatalogOrder` | Shopify y precio de variante, código | Orden completo con catálogo de staging |
| G09 Vista rápida | `monetta-quick-view` | `showProductQuickView` | Variante y stock, QA AT-01/02 | Galería ampliada y pagos si llega proveedor |
| G10 Producto | `monetta-product` | `ProductScreen` | Variante, galería, políticas y checkout reconciliado, QA AT-02/05 | Capacidad de seis pagos y fecha comercial |
| G10-A Detalle y recomendación | `monetta-product-recommendations`, `monetta-product-discovery` | `product_recommendations` | Shopify y vistos locales, código | Contenido y recomendaciones reales de staging |
| G10-B Agregar fijo | `monetta-product.js` | `ProductScreen`, `PurchaseDockButton` | Una acción con la misma variante, QA AT-02/05 | Dispositivo con teclado y pose Duo |
| G11 Zoom | `monetta-product.js` | `product_zoom.dart` | Foto de variante, código y pruebas de ficha | Galería por variante con álbum del proveedor |
| G12 Reposición | Control condicionado | `RestockPushAdapter` | Disponibilidad exacta y consentimiento, revisión de código | Contrato por variante, envío y autorización iOS/Android |
| G13 Mayoreo | `page.guia-mayoreo` | `WholesaleScreen` | B32 y pasos, QA AT-04 | Grupos, apartados y descuento real |
| G14 Carrito lateral | `monetta-cart-sheet` | `showBagDrawer`, `BagScreen` | Carrito Shopify y almacén, QA AT-02/03 | Concurrencia real y sesión reconocida |
| G14-A Cantidades y recuperación | `monetta-cart.js` | `BagScreen`, `CartController` | Respuesta Shopify, QA AT-03 | Carrera de stock en staging |
| G14-B Mayoreo | Asignaciones Shopify del fixture | `ShopifyCartSummary` | Descuentos reales de backend cuando existen, QA AT-03 web | Elegibilidad, aro y aviso de cruce |
| G14-C Total y crédito | Resumen del lateral | `ShopifyCartSummary` | Total Shopify y orden del lateral, QA AT-03 | Aviso Rewards en app cuando exista capacidad comercial y crédito compatible |
| G15 Checkout y pago | Shopify Checkout | `CheckoutFlowScreen`, coordinador Shopify | Estado confirmado del proveedor, código | Resultado desconocido, rechazo y liquidación de prueba autorizada |
| G15-A Dirección y método | Checkout hospedado | Flujo local y checkout hospedado | Shopify Checkout, código | Tarifa y métodos de staging |
| G16 Confirmación | Shopify Checkout / cuenta | Confirmación y pedido asociado | Shopify Orders y verificación, código | Pedido de prueba autorizado |
| G17 Acceso y registro | Rutas hospedadas Shopify | `AccountScope`, invitación | Sesión Customer Accounts, código | Modalidad y retorno autorizado |
| G17-A Correo y recuperación | `monetta-rewards-register`, cuenta hospedada | `HomeAccountInvitation` | Shopify y proveedor de cuenta, código | Probar login hint y cancelación real |
| G18 Mi cuenta | Customer Accounts y menú | `AccountScreen` | Identidad de cuenta, código | Orden y capacidades web hospedadas |
| G19 Rewards | `page.guia-rewards` / cuenta | `RewardsScreen` | Servicio privado de Rewards, condicionado | Contrato web, nivel y condiciones |
| G20 Beneficios de nivel | Capacidad condicionada | Campos si el servicio los entrega | Servicio Rewards, revisión de contrato | PRO/VIP/ÉLITE, bonos y progreso |
| G21 Saldo y movimientos | Capacidad condicionada | Pantalla Rewards / movimientos | `accounts_orders`, código | Lectura autenticada equivalente en web |
| G22 Mis pedidos | Cuenta Shopify | `OrdersScreen` | Shopify y `accounts_orders`, código | Identidad y cuenta de staging con estados variados |
| G23 Detalle de pedido | Cuenta Shopify | Detalle y seguimiento de pedido | Eventos de envío autorizados, código | Pedidos parciales y estados reales |
| G24 Favoritos | `monetta-merchandising.js` | `FavoritesScreen` | Almacenamiento local y catálogo, código | Sincronización de variantes y 60 únicos en datos reales |
| G25 Notificaciones | Capacidad condicionada | `NotificationsScreen`, `NotificationScope` | Firebase y servicio privado, código | Entrega iOS y destinos retirados |
| G26 Perfil | Cuenta Shopify | Perfil de cuenta | Customer Accounts, código | Escrituras disponibles por modalidad de cuenta |
| G27 Direcciones | Cuenta Shopify | Flujo de direcciones | Customer Accounts/Shopify, código | Alta, edición y aislamiento con sesión real |
| G28 Métodos de pago | Checkout hospedado | Capacidad condicionada | Proveedor de Shopify, código | Capacidad de métodos guardados |
| G29 Preferencias | Sin pantalla equivalente del tema | `PreferencesScreen` | Preferencias y controles del sistema, código | Patrón de preferencias web de la cuenta |
| G30 Ayuda y políticas | Footer y páginas Shopify | Ayuda y políticas | Fuentes de políticas, código | Contenido autorizado de producción |
| G30-A FAQ y lectura | Páginas de ayuda y acordeones de ficha | `HelpScreen` | Contenido autorizado, código | Validar corpus y destinos Canonical |
| G31 Capas y retorno | `monetta-core.js`, diálogos nativos | Drawer, rápida y Duo | Foco, Escape y Atrás, QA AT-02/05 | Lector de pantalla y gestos de plataforma |
| G32 Acceso fallido/cancelado | Cuenta hospedada | Controlador de cuenta e invitación | Proveedor de sesión, código | Cancelación, valores y retorno real |
| G33 Contenido no disponible | Plantilla 404 y estados de listado | Recuperación de colección y ficha | API y caché, código | Enlace retirado de staging |
| G34 Permiso de avisos | Capacidad de plataforma | Prompt de notificaciones | Permiso iOS/Android, código | VoiceOver/TalkBack y permiso denegado en físico |
| G35 Opciones y agregado | `monetta-feature-add`, `monetta-cart.js` | `ProductQuickAddButton` | Variante exacta, QA AT-02 | Stock en carrera y actualización en Duo |
| G37 Búsqueda y filtros, estados | Listado y búsqueda predictiva | `SearchScreen`, `CollectionScreen` | Shopify y caché, QA AT-01 más código | Red lenta y reintento sobre datos de staging |
| G38 Ayuda y destinos | Resolver, pie y contacto | Ayuda, Contacto y enlaces | Rutas configuradas, código | Políticas, redes y grupos vigentes |
| G39 Compra invitada y envío | Carrito y checkout hospedado | Carrito y `CheckoutFlowScreen` | Fixture de acceso y continuidad, QA AT-03 | Tarifas, recotización y cuenta reconocida |
| G40 Contacto | `page.guia-contacto` | `ContactScreen` | B31, WhatsApp y enlaces configurables, QA AT-04 | Ratificar grupos, redes y destino publicado |

## Dependencias para cerrar la aceptación

| Responsable | Insumo | Criterio de desbloqueo |
| --- | --- | --- |
| Alexis | Preview autorizado de Shopify, configuración de cuenta y catálogo | URL y rol del tema verificables, páginas y Ofertas accesibles, facetas activadas, flujo invitado y cuenta con retorno |
| Alexis | Proveedor de seis pagos y tarifa invitada | Importe por variante y método confirmado por el proveedor. Nueva tarifa y total al cambiar identidad/dirección en checkout |
| Alexis | Elegibilidad de mayoreo y crédito | Respuesta oficial que identifique líneas elegibles, umbral, asignaciones y crédito aplicable. Fixture de 2→3→4→2 con línea no elegible |
| Miguel y Julissa | Condiciones Rewards, bono, cashback, alta comercial | Reglas publicables y campos autoritativos. Activar registro y aviso de envío en el tema después de validar checkout |
| Miguel y Julissa | Apartado, comunidad, redes | Copy aprobado y URL por entorno. El contacto por WhatsApp queda disponible para consulta |
| Operación de avisos | Reposición por variante y consentimiento | Registrar solicitud con variante exacta, deduplicar, comprobar transición de stock y entrega autorizada en ambos sistemas |
| QA de dispositivos | Autorización de staging y equipos físicos | VoiceOver/TalkBack, teclado, áreas seguras, retorno y Duo. Medir LCP 2.5 s, INP 200 ms y CLS 0.1 en p75 con datos de campo |

Se usaron Theme Check, recorridos locales y consultas HTTP de solo lectura a staging. Los cambios de esta revisión están en la copia local.
