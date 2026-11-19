# Monetta UI v4.3 · verificación local

Base observada en `fix/web-brands-row`, commit `967aca1`. Se preservó el delta de cabecera, redes, pruebas web, notificaciones, configuración y servicio de cuentas. La revisión usa el maestro v4.3 pp. 93–123 para contratos y aceptación, la guía visual v3.2 para composición y el manifiesto v4.1 para procedencia de activos. Los PDF, el ZIP y las láminas renderizadas están fuera de Git.

## Resultados por recorrido

| Caso | Shopify local | Flutter local | Verificación pendiente |
| --- | --- | --- | --- |
| AT-01 Ofertas | Entrada del menú, comparación válida de una variante disponible, búsqueda en colección paginada, cambio de color en rápida y consulta restaurada al volver de ficha. | Colección fija de variantes disponibles con oferta, búsqueda local y selección por ID. | Confirmar colección `ofertas`, filtros por mercado, vigencia y catálogo completo en staging. |
| AT-02 Agregar | Nueva colección, Para ti, rápida y ficha usan la misma mutación. Fixture de opción obligatoria, doble toque, rechazo de stock y foco al cerrar. | Destacados, rápida y ficha comparten la bolsa editable. Pruebas de pendiente, error y variante. | Confirmar reconciliación de carrito Shopify, concurrencia y continuidad en dispositivos Duo. |
| AT-03 Carrito | Fixture de 2→3→4→2, descuento visible solo cuando llega en la respuesta, error en línea, invitado y cuenta. | Secuencia editable y cierre con Atrás. Los totales y descuentos de la tienda dependen de la reconciliación Shopify. | Reglas de elegibilidad, tarifa invitada, crédito, reidentificación y recotización dentro de checkout. |
| AT-04 Banners | B01–B03 con destinos distintos, B04 editorial con CTA accionable, B08, B28, B31 y B32. | B04 editorial y verificación a 320 puntos con texto ampliado. | Cotejar destinos publicados y lectura visual de los artes a ampliación del sistema en dispositivos físicos. |
| AT-05 Responsive | Inicio, menú, ficha y carrito en 320/390/768/1440 px con movimiento reducido y Escape. | Ficha y lateral a los cuatro anchos, área segura y extensión de texto en B04. | VoiceOver/TalkBack, teclado virtual real, opacidad bajo ajustes del sistema y mediciones de campo p75. |

### Resultado de las pruebas

- Playwright completó AT-01 a AT-05 en el tema local. Axe reportó cero infracciones en Inicio, Ofertas, ficha y carrito lateral a 390 px con esos fixtures. La revisión con lector de pantalla y zoom nativo sigue pendiente.
- Flutter 3.44.8 completó 22 pruebas en el recorrido v4.3 y en las comprobaciones de activos y banners. Incluyen una recomendación agregada dentro del lateral, selector de variante, Atrás y cuatro anchos con área segura. Las fotos de producto de estos widgets usan el estado de respaldo del fixture.
- La ejecución completa de Flutter sobre el estado intermedio registró 1,779 pruebas aprobadas, 5 omitidas y 44 fallos. Los recorridos dirigidos posteriores comprobaron las correcciones de expectativas de v4.1 y de la espera al abrir la rápida. Los diez UI-04 fallaron también en la copia base con Flutter 3.44.8. Las referencias aprobadas se preservaron.
- El análisis final con Flutter 3.44.8 reportó 390 observaciones informativas, sin errores ni warnings. Theme Check con Node 24 registró 251 hallazgos tanto en HEAD como en el tema editado, sin hallazgos nuevos. Pasaron la paridad de generadores, la sintaxis JS y `git diff --check`.
- El endpoint de staging respondió con redirección a `/password`. Falta un preview autorizado del tema modificado para los scripts históricos de journeys. El fixture usa las interfaces Ajax y de acceso hospedado documentadas por Shopify. [Ajax Cart API](https://shopify.dev/docs/api/ajax/reference/cart), [Retorno de cuentas](https://shopify.dev/docs/storefronts/themes/sign-in).

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

Las PNG web están en `/tmp/monetta-v43-qa/captures` y las PNG Flutter en `/tmp/monetta-v43-qa/app`. Las referencias históricas de [Inicio web](../../audits/2026-11-11-v41/evidence/viewport-home-390-1x.png) e [Inicio Flutter](../../client-guide-m3/screenshots/home-followup-390-light.png) permiten comparar los rieles y B04. Los fixtures no usan identidades ni pagos reales.

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
| G05 Colección y catálogo | `monetta-collection` | `CollectionScreen` | Shopify y caché, QA de banner | Búsqueda local general web y filtros del catálogo de staging |
| G05-A Colección de marca | `monetta-collection`, `monetta-guia-url` | `BrandScreen` | Vendor/faceta y manifest, QA B28 | Colecciones, logos y facetas por entorno |
| G05-B Ofertas | `monetta-collection`, `monetta-listing.js` | `CollectionScreen(offersCollection: true)` | Variante, precio, comparación y stock, QA AT-01 | Colección publicada y vigencia comercial |
| G06 Búsqueda global | `monetta-search`, predictive search | `SearchScreen` | Shopify y caché, código y pruebas existentes | Journey de staging y relevancia real |
| G07 Filtros | `monetta-listing-layout` | `CatalogControls`, `CollectionScreen` | Shopify Search & Discovery y facetas, código | Facetas habilitadas y conteos en staging |
| G07-A Nuevos, ofertas, disponibles | Filtros nativos y vista Ofertas | `matchingCatalogVariants` | Variante Shopify, QA AT-01 | Campo de alta y filtro de vigencia web |
| G08 Ordenar | `monetta-listing.js` | `CatalogOrder` | Shopify y precio de variante, código | Orden completo con catálogo de staging |
| G09 Vista rápida | `monetta-quick-view` | `showProductQuickView` | Variante y stock, QA AT-01/02 | Galería ampliada y pagos si llega proveedor |
| G10 Producto | `monetta-product` | `ProductScreen` | Variante, galería y políticas, QA AT-02/05 | Capacidad de seis pagos y fecha comercial |
| G10-A Detalle y recomendación | `monetta-product-recommendations`, `monetta-product-discovery` | `product_recommendations` | Shopify y vistos locales, código | Contenido y recomendaciones reales de staging |
| G10-B Agregar fijo | `monetta-product.js` | `ProductScreen`, `PurchaseDockButton` | Una acción con la misma variante, QA AT-02/05 | Dispositivo con teclado y pose Duo |
| G11 Zoom | `monetta-product.js` | `product_zoom.dart` | Foto de variante, código y pruebas de ficha | Galería por variante con álbum del proveedor |
| G12 Reposición | Control condicionado | `RestockPushAdapter` | Disponibilidad exacta y consentimiento, revisión de código | Contrato por variante, envío y autorización iOS/Android |
| G13 Mayoreo | `page.guia-mayoreo` | `WholesaleScreen` | B32 y pasos, QA AT-04 | Grupos, apartados y descuento real |
| G14 Carrito lateral | `monetta-cart-sheet` | `showBagDrawer`, `BagScreen` | Carrito Shopify y almacén, QA AT-02/03 | Concurrencia real y sesión reconocida |
| G14-A Cantidades y recuperación | `monetta-cart.js` | `BagScreen`, `CartController` | Respuesta Shopify, QA AT-03 | Carrera de stock en staging |
| G14-B Mayoreo | Asignaciones Shopify del fixture | `ShopifyCartSummary` | Descuentos reales de backend cuando existen, QA AT-03 web | Elegibilidad, aro y aviso de cruce |
| G14-C Total y crédito | Resumen del lateral | `ShopifyCartSummary` | Total Shopify, QA AT-03 | Crédito compatible y orden del resumen en checkout |
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
| Alexis | Preview autorizado de Shopify, configuración de cuenta y catálogo | URL y rol del tema verificables, páginas y colección `ofertas` accesibles, facetas activadas, flujo invitado y cuenta con retorno |
| Alexis | Proveedor de seis pagos y tarifa invitada | Importe por variante y método confirmado por el proveedor. Nueva tarifa y total al cambiar identidad/dirección en checkout |
| Alexis | Elegibilidad de mayoreo y crédito | Respuesta oficial que identifique líneas elegibles, umbral, asignaciones y crédito aplicable. Fixture de 2→3→4→2 con línea no elegible |
| Miguel y Julissa | Condiciones Rewards, bono, cashback, alta comercial | Reglas publicables y campos autoritativos. Activar registro y aviso de envío en el tema después de validar checkout |
| Miguel y Julissa | Apartado, comunidad, redes | Copy aprobado y URL por entorno. El contacto por WhatsApp queda disponible para consulta |
| Operación de avisos | Reposición por variante y consentimiento | Registrar solicitud con variante exacta, deduplicar, comprobar transición de stock y entrega autorizada en ambos sistemas |
| QA de dispositivos | Autorización de staging y equipos físicos | VoiceOver/TalkBack, teclado, áreas seguras, retorno y Duo. Medir LCP 2.5 s, INP 200 ms y CLS 0.1 en p75 con datos de campo |

No había un preview autorizado y actualizado escuchando en el puerto de QA. `theme dev` escribe un tema remoto, de modo que se usaron Theme Check y la prueba local del repositorio. Publicar, registrar clientes reales, enviar notificaciones o realizar pagos requiere autorización aparte.
