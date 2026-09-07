# Auditoría funcional de Monetta — 7 de septiembre de 2026

**Dictamen: no está lista para abrir compras de producción.** Hay una base funcional considerable, pero la configuración actual no conecta el pago, existen defectos de selección de variantes y de identidad, y la posventa depende de un espejo de pedidos que puede perder eventos. Cambiar solamente el dominio del shop no resuelve esos problemas.

La prioridad es cerrar seguridad, catálogo propio, compra y posventa. La UI visual queda al final. No se propone continuar extracción de catálogos de terceros ni sustituirla por otro scraper.

## 1. Alcance y calidad de la evidencia

- Repositorio auditado: `/Users/alexis/develop/monetta-app`.
- Base: commit `32f846df654705f938c397574081e22da04a8bb6`, rama `codex/storefront-polish-catalog-reliability`, **incluyendo los cambios locales presentes**. Había 32 archivos rastreados modificados y archivos nuevos, entre ellos `dashboard/`. Una copia del último commit no reproduce todo este estado.
- Revisión de composición Flutter, pantallas, persistencia, Shopify Storefront/Customer Accounts, checkout nativo, administración, backend de cuentas/pedidos, webhooks, notificaciones, configuración y CI.
- Se ejecutaron pruebas existentes y seis sondas locales de defectos. Se consultaron endpoints públicos de descubrimiento de ambas tiendas y documentación oficial de Shopify.
- **No se realizó una compra, login interactivo, devolución, publicación, despliegue ni cambio de configuración de Shopify.** No se verificaron paneles privados, base de datos desplegada, credenciales reales de producción, entregabilidad de push ni dispositivos físicos.
- No se hizo una sesión manual completa en simulador. Las afirmaciones sobre comportamiento de pantallas provienen de su código y pruebas, no de una grabación de uso real.
- La configuración gitignored describe una compilación hecha con ese archivo, **no demuestra qué configuración tiene un binario ya instalado o desplegado**.
- No se modificó código funcional ni el trabajo existente. Los entregables de esta auditoría están en `docs/`.

Clasificación: **reproducido** = sonda local ejecutada; **confirmado en código/configuración** = recorrido de implementación verificable; **pendiente operativo** = necesita tienda, infraestructura o dispositivo real. P0 bloquea exposición; P1 bloquea el flujo correspondiente; P2 limita operación; P3 mejora posterior.

## 2. Qué producto existe realmente en este repositorio

| Superficie | Qué es | Consecuencia |
|---|---|---|
| `lib/`, `ios/`, `android/` | Aplicación Flutter con flujos comerciales | Es donde están catálogo, cuenta, bolsa y checkout |
| `web/` | Visor Vite de capturas de la app | No es una tienda web transaccional: no permite comprar, iniciar sesión ni administrar |
| `vercel.json` raíz | Publica `web/dist` y funciones de catálogo | Un deploy web exitoso aquí no publica los flujos Flutter |
| `dashboard/` | Dashboard React para el monitor de catálogo externo | No es un panel general de Monetta/Shopify; pierde su función principal con la decisión de retirar ese monitor |
| `services/accounts_orders/` | Backend de cuentas heredadas, pedidos, administración y notificaciones | Su uso es distinto de un servidor que extrae productos de terceros |
| `services/catalog_monitor/` | Extracción, selección y suministro de catálogo externo | Retirar del camino del producto y de la planificación |
| `server/catalog/`, `api/`, `functions/` | Dos implementaciones de espejo Shopify → Firestore | Son otro camino de catálogo; no hacen falta como autoridad de compra si la app usa Storefront directamente |

**Si el objetivo incluye una tienda navegable en navegador, falta ese entregable en este repositorio.** Esta auditoría no certifica el tema Shopify desplegado en monetta.mx ni otros repositorios. El dominio real es la fuente comercial deseada, no evidencia de que `web/` ya sea esa tienda.

## 3. Estado efectivo de la configuración local

Lectura de [config/dart_defines.staging.json](/Users/alexis/develop/monetta-app/config/dart_defines.staging.json), sin divulgar credenciales:

| Ajuste | Observado | Efecto al compilar con este archivo |
|---|---|---|
| APP_ENV | staging | El guard exige Firestore |
| SHOPIFY_STORE_DOMAIN | monetta-staging.myshopify.com | Customer Accounts apunta a staging |
| SHOPIFY_STOREFRONT_ACCESS_TOKEN | Vacío | No se construye transporte Storefront ni la composición real de carrito/checkout |
| CUSTOMER_ACCOUNT_SHOP_ID | 90228850722 | OAuth de staging; client ID presente, validez no probada |
| FIRESTORE_CATALOG_ENABLED | true | Catálogo servido desde proyecto Firebase staging |
| ACCOUNTS_ORDERS_BASE_URL | Vacío | No se refresca historial remoto |
| ADMIN_API_BASE_URL / OWNER_ADMIN_EMAILS | No presentes | Panel real sin configurar; acceso normal no habilitado |
| ENABLE_EXTERNAL_CATALOG | true | Contradice la nueva decisión: carga el catálogo externo |
| EXTERNAL_CATALOG_BASE_URL | https://catalog.monetta.mx | Dependencia externa aún activa |
| NOTIFICATIONS_ENABLED | No presente | Valor por defecto false; push no habilitado |

`main.dart` sólo crea `ShopifyCartComposition.production` si `StorefrontConfig.isUsable` es verdadero. El catálogo visible, por sí solo, no prueba que esos productos puedan comprarse.

[config/README.md](/Users/alexis/develop/monetta-app/config/README.md) documenta que Firestore staging refleja catálogo de la tienda real. Por tanto, **poner un token de la tienda staging sobre ese catálogo no es una reparación válida**: los IDs de variantes deben pertenecer al mismo shop que el carrito. No consulté el contenido actual de Firestore; la intención de mezcla está documentada y debe verificarse/eliminarse.

El archivo real de producción no estaba presente en el inventario; el ejemplo contiene placeholders y [shopify/shopify.app.production.toml](/Users/alexis/develop/monetta-app/shopify/shopify.app.production.toml) también. El ejemplo omite la allowlist de acceso administrativo y la configuración completa de notificaciones/telemetría.

## 4. Qué puede hacer un usuario y dónde termina cada flujo

| Flujo | Implementación actual | Límite / falta |
|---|---|---|
| Abrir sin cuenta | Catálogo cacheado, snapshot inicial, onboarding | Puede mostrar catálogo antiguo; estado remoto no equivale a compra disponible |
| Explorar | Home, categorías, colecciones, marcas, filtros | Parte de navegación y taxonomía es local; no todo se administra desde Shopify |
| Buscar | Búsqueda sobre datos cargados y normalizados | Queries de predictive search existen pero no están conectadas; depende de frescura/completitud local |
| Recomendaciones | Motor local por interacciones/preferencias | No sincroniza perfil entre dispositivos; datos externos todavía participan si el flag está activo |
| Ver producto | Imágenes, descripción, precio, variantes, disponibilidad | Selección de variante no llega a la bolsa; ver F04 |
| Guardar favoritos | Persistencia SQLite | No hay sincronización de cuenta entre dispositivos; aislamiento entre cuentas incorrecto |
| Agregar a bolsa | Persistencia y cambio/eliminación de cantidades | Una línea por producto; no puede mantener dos variantes distintas del mismo producto |
| Ver bolsa Shopify | Reconciliación, descuentos y costo remoto cuando existe configuración | En staging actual no existe esa composición; también falta resolver intención local obsoleta |
| Capturar entrega | Formulario local de contacto y dirección, revisión | La integración real sólo transmite correo/teléfono/país; dirección vuelve a requerirse en Shopify |
| Pagar | Cart API → checkoutUrl → Checkout Kit nativo | Desconectado con configuración actual; no se probó orden completa |
| Comprar con sesión | Existe OAuth Shopify | Carrito se prepara como invitado; no lleva token del comprador |
| Cancelar checkout | Conserva bolsa | Correcto en código/pruebas; falta dispositivo real |
| Completar checkout | Callback nativo borra sesión de carrito y bolsa | No refresca historial ni muestra detalle/estado de pedido propio; fallback navegador no confirma finalización |
| Iniciar sesión | Login alojado Shopify, PKCE, refresh en almacenamiento seguro | No probado en ambas plataformas con producción; fallback de identidad y logout incompletos |
| Mis pedidos | Consulta autenticada al backend, caché local | En staging no tiene backend; pantalla sólo presenta fecha, total y origen; errores parecen lista vacía |
| Perfil / direcciones | Muestra nombre/correo | No hay edición de perfil, CRUD de direcciones ni dirección predeterminada |
| Seguimiento / devolución | No hay flujo completo | Sin detalle de líneas, tracking, devoluciones, cancelación o factura en app |
| Apartar / asesoría | Abre WhatsApp con mensaje y atribución | No reserva inventario, no crea automáticamente pedido ni confirma anticipo |
| Vende con Monetta | Abre y comparte enlaces de catálogos; cotiza vía WhatsApp | No hay aprobación de revendedor, precios privados, compra mayorista ni ledger de comisiones |
| Notificaciones | Consentimientos, intereses, alertas y cliente push implementados | Desactivadas en config auditada; dependen de Firebase, App Check, API y worker |
| Cerrar sesión | Elimina sesión local | No termina sesión alojada Shopify; separación de datos local incompleta |

No hay evidencia de un registro privado de revendedores: los enlaces de mayoreo en contenido editorial son accesibles desde el flujo público. Si sus precios deben ser exclusivos, eso es un requisito funcional por definir y aplicar, no un ajuste visual.

## 5. Hallazgos priorizados, reproducción y aceptación

### F01 — P0: elevación a owner por correo no verificado — REPRODUCIDO

[services/accounts_orders/src/api/server.ts:337](/Users/alexis/develop/monetta-app/services/accounts_orders/src/api/server.ts:337) permite registro con email no verificado. `src/admin/authorizer.ts` concede bootstrap de owner si el email de una cuenta Monetta coincide con `OWNER_ADMIN_EMAILS`, sin comprobar `emailVerified`.

Sonda local: cuenta con `emailVerified=false` y correo sintético allowlisted obtuvo `role=owner`. Depende de que la allowlist y el endpoint estén habilitados; no demuestra una explotación en producción ni afecta automáticamente a todo login Shopify.

**Corregir:** provisionar principales administrativos explícitos por identidad autenticada; quitar bootstrap por email autodeclarado. Revisar principales previamente creados, conservar propietarios válidos mediante migración explícita.

**Aceptación:** registro de un correo allowlisted no obtiene capacidades; usuario normal recibe 403; owner provisionado funciona; principal desactivado no revive.

### F02 — P0: registro con deviceId conocido reemplaza credenciales — REPRODUCIDO

`src/db/pgAppAccountsRepository.ts:40` busca cuenta por sesión/deviceId y, si existe, actualiza email y password_hash. `/accounts/register` no requiere la credencial anterior. Un deviceId es identificador, no prueba de posesión.

Sonda con repositorio en memoria reprodujo el reemplazo y se inspeccionó el mismo patrón SQL. El supuesto de explotación es conocer un deviceId existente; no se probó contra usuarios reales.

**Corregir:** registro nunca debe modificar otra cuenta por deviceId; separar creación, login y cambio de credenciales autenticado. No borrar usuarios heredados.

**Aceptación:** repetir registro con el deviceId de A no cambia email, password, vínculo Shopify, roles ni sesiones de A. Cambios de identidad requieren sesión y prueba adecuada.

### F03 — P0 de lanzamiento: catálogo externo todavía activo — CONFIRMADO

Flag local true, `main.dart`, `mixed_feed.dart`, catálogo, recomendaciones, detalle externo, administración, notificaciones y dashboard conservan el camino externo. El validador de producción lo prohíbe, pero `ExternalCatalogConfig` y el guard de runtime no aplican por sí mismos esa restricción a todo build.

**Corregir:** retirar la dependencia del producto completo, configuración y CI/deploy del monitor. Desacoplar AdminScreen del ExternalCatalogController y `syncAll` de `external-status` antes de eliminar piezas. No basta esconder la sección de home. Inventariar y retirar jobs/servicios desplegados con evidencia del entorno; no asumir que desactivar el cliente detiene el servidor.

**Aceptación:** inicio, búsqueda, home, admin y notificaciones no solicitan `catalog.monetta.mx`, ni incluyen productos externos; pruebas y build funcionan sin `catalog_monitor`/dashboard. Conservar respaldo histórico antes de eliminar infraestructura/datos.

### F04 — P1: la variante seleccionada no se compra — CONFIRMADO

[lib/features/product/product_screen.dart:56](/Users/alexis/develop/monetta-app/lib/features/product/product_screen.dart:56) elige variante para mostrar precio/stock, pero el botón en línea 412 llama `store.addToBag(product)` sin variante. [lib/app/catalog_store.dart:446](/Users/alexis/develop/monetta-app/lib/app/catalog_store.dart:446) selecciona una variante disponible por su cuenta. `bagLines` vuelve a resolverla; la hidratación descarta el variantId persistido. `BagLines` usa productId como única clave.

**Impacto:** seleccionar color/tamaño B puede agregar A. Si A se agota, la bolsa puede sustituirla por otra variante sin consentimiento. También puede ocultar líneas agotadas manteniendo el contador.

**Corregir:** llevar variantId exacto desde detalle, minicart y persistencia hasta Cart API; clave de línea por variante y scope; no sustituir mercancía automáticamente.

**Aceptación:** A y B del mismo producto se agregan como dos líneas; sobreviven reinicio; B mantiene su precio; stock agotado o eliminación produce aviso explícito y no sustitución.

### F05 — P1: pago desactivado en staging actual — CONFIRMADO

Token Storefront vacío → no hay transporte, carrito ni launcher de producción ([lib/main.dart:644](/Users/alexis/develop/monetta-app/lib/main.dart:644)). Se permite avanzar por captura/revisión y el botón final informa que checkout no está disponible (`checkout_screen.dart:461`).

**Corregir:** configuración completa y coherente del mismo shop; bloquear el inicio del flujo si no puede terminar. No mezclar productos reales cacheados con un carrito staging.

**Aceptación:** build de pruebas con productos del mismo shop crea carrito real y abre checkout; build incompleto explica indisponibilidad antes de pedir dirección.

### F06 — P1: sesión de app no se transfiere al checkout — CONFIRMADO

`checkout_screen.dart:240` siempre construye `GuestCartBuyerIdentity`. El scope local autenticado sólo separa el almacenamiento; no autentica al comprador en Shopify. La capa API sí soporta una identidad con token, pero la pantalla no la utiliza.

**Corregir:** obtener token vigente de Customer Account y pasarlo a buyerIdentity para cuentas Shopify; distinguir cuentas Monetta heredadas sin vínculo autenticado. Shopify documenta este flujo en [Authenticate checkouts](https://shopify.dev/docs/storefronts/mobile/checkout-kit/authenticate-checkouts).

**Aceptación:** invitado compra sin login; cliente autenticado llega reconocido al checkout; token expirado se renueva; logout/cambio de cuenta invalida el checkout precargado del anterior.

### F07 — P1: dirección capturada no se transmite; estimaciones locales — CONFIRMADO

El draft incluye nombre, calle, colonia, CP, ciudad y estado; el launcher usa sólo email, phone y MX. La revisión calcula desde la bolsa local y [lib/app/motion.dart:18](/Users/alexis/develop/monetta-app/lib/app/motion.dart:18) fija envío gratis desde $1,499 y tarifa $149, además de texto de 3–5 días. Existen etiquetas de estimado y resumen remoto en bolsa; eso no convierte el formulario/revisión en cotización real.

**Corregir:** preferir capturar entrega/envío directamente en Shopify, o implementar la integración oficial de dirección y costos sin duplicar captura. Es cambio de flujo, no rediseño. Evitar promesas basadas en constantes cuando las reglas reales difieran.

**Aceptación:** no se pide dos veces la misma dirección; precio, descuento, moneda, envío e impuestos finales corresponden al checkout. Probar CP sin cobertura, cargo adicional y descuento que modifica umbral de envío.

### F08 — P1: full sync no elimina productos retirados — REPRODUCIDO

[lib/data/repositories/catalog_repository.dart:185](/Users/alexis/develop/monetta-app/lib/data/repositories/catalog_repository.dart:185) sólo hace upserts aunque `wasFullSync=true`. Una respuesta completa vacía no vacía el catálogo; conserva rows y puede etiquetarlas saludables.

Sonda: cargar producto 1 y luego hacer full sync vacío deja producto 1.

**Corregir:** reemplazo completo atómico después de validar todas las páginas; migrar referencias y reportar líneas no comprables. Eliminar un producto o despublicarlo debe reflejarse en app.

**Aceptación:** full sync A+B seguido por B deja sólo B; full válido vacío deja vacío; error/timeout parcial conserva último catálogo válido. Cursor, productos y metadata se confirman coherentemente.

### F09 — P1: paginación incompleta se declara exitosa — REPRODUCIDO

[lib/data/shopify/catalog_sync.dart:144](/Users/alexis/develop/monetta-app/lib/data/shopify/catalog_sync.dart:144) termina por `maxPages` (20) o falta de cursor y aun devuelve full sync con timestamp avanzado. La sonda con una página y `hasNextPage=true` reprodujo éxito falso. Además el fragmento limita imágenes a 6, variantes a 20 y membresías a 10 sin completar conexiones.

**Corregir:** abortar sin avanzar cursor cuando falta completitud; detectar cursor repetido/ausente; paginar o declarar límites explícitos en conexiones internas.

**Aceptación:** 250/251 productos, overflow, cursor repetido, 21 variantes y producto con más de 10 colecciones tienen resultados completos o error seguro. Esta corrección debe anteceder al reemplazo destructivo de F08.

### F10 — P1: caché y cursor no identifican el shop — CONFIRMADO

`SyncCursorStore` usa singleton id=0; SQLite se abre como `monetta.sqlite`; catálogo/cuentas carecen de namespace de tienda. CartSessionScope sí incluye dominio. Flavors distintos reducen mezcla en instalaciones separadas, pero no resuelven cambios de fuente dentro de un mismo app id ni un futuro cambio de shop.

**Corregir:** registrar identidad de tienda/fuente y rechazar reutilización de cursor/catalogación incompatible. Forzar full sync al cambiar shop. No remapear variantes entre tiendas por semejanza de nombre.

**Aceptación:** pasar tienda A → B no conserva productos, cursores, tokens ni carritos de A; favoritos/bolsa tienen migración explícita o aviso de incompatibilidad; nada se compra usando IDs de otro shop.

### F11 — P1: favoritos y bolsa no están aislados por cuenta — REPRODUCIDO

`BagStore.all()` y `WishlistStore.allProductIds()` leen todas las filas, sin filtro de accountId; sus claves tampoco incluyen cuenta. CatalogStore no se rehidrata por usuario. Los comentarios de merge afirman separación que las lecturas no implementan.

**Corregir:** elegir y aplicar una política explícita: datos personales por cuenta más invitado separado, con merge al login. Hoy la presencia de accountId promete una semántica que no se cumple.

**Aceptación:** A agrega favoritos/bolsa, sale, entra B: B no ve ni modifica A; invitado nuevo no hereda A; volver a A restaura sus datos. Dos variantes/cuentas no colisionan. Sincronización entre dispositivos es otro trabajo, no queda resuelta por SQLite.

### F12 — P1: webhook fallido queda consumido y el retry se descarta — REPRODUCIDO

`src/webhooks/handlers.ts:74` inserta delivery antes de ejecutar efectos; `pgWebhookEventsRepository.ts` devuelve false ante cualquier conflicto, sin revisar processed_at. Si falla el upsert de pedido, el siguiente delivery con mismo ID no intenta recuperarlo.

Sonda: primer upsert falla; segundo delivery termina ignorado, con una sola llamada al upsert.

**Corregir:** transacción/inbox durable con estados y reintentos, sin doble procesamiento concurrente. La confirmación del evento debe corresponder a efectos durables.

**Aceptación:** fallo después de claim, fallo después de cliente, fallo después de pedido y reinicio se recuperan; duplicado completo no repite efectos; evento concurrente no se pierde.

### F13 — P1: historial parcial, errores silenciosos y sin recuperación histórica — CONFIRMADO

La app lee `/customers/me/orders`, no Customer Account API para pedidos. El backend sólo conoce los eventos recibidos; no hay backfill operativo y `shopify-orders` responde `SYNC_CHANNEL_NOT_CONFIGURED`. El cliente absorbe fallos y AccountScreen termina diciendo «Aún no tienes pedidos» incluso sin servicio disponible.

La autorización del endpoint está bien encaminada: resuelve cliente desde bearer, no desde un ID de usuario arbitrario.

**Corregir:** preferir Customer Account API como fuente del historial del comprador y dejar backend para enriquecimiento; alternativamente implementar backfill/reconciliación robusta del espejo con permisos necesarios. Diferenciar vacío, no configurado, error y caché vieja.

**Aceptación:** cliente existente ve pedidos anteriores a instalar la app; pedido nuevo aparece; caída del servicio no finge vacío. Paginación y actualización de estados verificadas.

### F14 — P1: respuesta tardía puede reponer pedidos tras logout — CONFIRMADO EN CÓDIGO

`AccountController.loadOrders()` captura cuenta y realiza awaits, pero no comprueba que siga siendo la actual antes de asignar `orders`. Logout pone la lista vacía, pero un refresh anterior puede volver a llenarla; cambiar de A a B puede mostrar temporalmente resultados de A.

**Corregir:** generación/cancelación de carga y guard por identidad después de cada await; `try/finally` para ordersLoading. Invalidar estados privados al cambiar sesión.

**Aceptación:** respuesta diferida de A que llega después de entrar B se descarta; logout durante refresh nunca repuebla lista. No se afirma reproducción dinámica todavía.

### F15 — P1: espejo acepta actualizaciones de pedidos fuera de orden — CONFIRMADO

`pgOrdersRepository.ts:59` sobrescribe estado financiero/fulfillment y usa now() sin comparar updated_at de Shopify. Un evento antiguo puede reemplazar uno reciente. Shopify [no garantiza orden y recomienda reconciliación](https://shopify.dev/docs/apps/build/webhooks).

**Corregir:** control de versión temporal/lectura canónica, backfill, métricas de retraso y replay de eventos fallidos. Verificar el shop esperado en ingreso: hoy el wrapper sólo comprueba HMAC e ID de delivery; shop/redact elimina todo el espejo single-tenant.

**Aceptación:** paid → refunded → delivery antiguo paid conserva refunded. Un webhook válido de otra tienda no altera el entorno. Bases y secretos de staging/producción separados.

### F16 — P1 operativo: métodos de pago, salida a proveedores y regreso sin verificar

Hay Checkout Kit fijado y bridges nativos; no hay formulario de tarjetas propio. Los callbacks externos `checkoutDidClickLink` / `onCheckoutLinkClicked` no hacen nada y no existe la fase de regreso de enlaces externos. Esto requiere pruebas por proveedor; **no significa que todo pago externo falle automáticamente**, pues depende de su ruta SDK/WebView.

**Corregir/verificar:** métodos realmente habilitados en Shopify, redirects bancarios/3DS, wallets, rechazo, cancelación, timeout, app en background y regreso desde navegador. Aplicar el soporte oficial del SDK según comportamiento real, sin abrir enlaces arbitrarios.

**Aceptación:** evidencia iOS/Android por cada método ofrecido. Checkout completado, orden creada y pago confirmado/pending son estados distintos; no marcar transferencia o pago diferido como cobrado por cerrar exitosamente la hoja.

### F17 — P2: terminación de compra no cierra la posventa — CONFIRMADO

Completion borra bolsa y vuelve a raíz; no entrega número/detalle de pedido propio ni fuerza loadOrders. Abrir fallback navegador nunca confirma completion ni recupera por sí mismo una compra terminada fuera de la app. El draft de checkout además usa localIntent capturado al salir de la bolsa, aunque al pagar lea un draft nuevo.

**Corregir:** estado de resultado con recuperación canónica, refresco de historial y asociación segura. Reconstruir intención desde variantes actuales al presentar, sin borrar compras nuevas agregadas en paralelo.

**Aceptación:** cancelar/fallar conserva bolsa; completar vacía sólo lo comprado; pedido aparece sin volver a iniciar sesión; retorno de navegador no duplica compra ni finge éxito.

### F18 — P2: cuenta incompleta y logout sólo local — CONFIRMADO

No hay edición de perfil/direcciones ni flujo de eliminar cuenta. `CustomerSessionRepository.logout` elimina token local, pero no usa end_session_endpoint. `_resolveIdentity` puede derivar identidad de claims de idToken decodificados cuando falla consulta de identidad, excepto token rechazado.

**Corregir:** logout alojado soportado por Shopify y lifecycle coherente; resolver identidad autorizada antes de fijar vínculo de cuenta. Agregar gestión de perfil/direcciones o enlace autenticado al portal, y proceso real de baja.

**Aceptación:** A cierra sesión y B puede iniciar la suya; no reaparece A por cookie sin aclaración; credencial revocada vuelve a invitado; caída de identidad no crea vínculos inconsistentes.

### F19 — P1 antes de exponer backend: cuentas heredadas sin transición segura

Backend y repositorios conservan registro/password; la UI normal sólo abre Shopify. Documentación histórica dice que hay cuentas reales: se debe validar inventario y migrar, no borrar tablas. No se encontraron flujos completos de recuperación de contraseña/verificación de email ni rate limiting en login/registro (sí hay para mutaciones admin).

**Corregir:** endurecer endpoints heredados, cerrar registros nuevos si ya no forman parte del producto, y definir vínculo probado a Customer Account sin confiar sólo en email. Plan de recuperación/migración con rollback y respaldo.

**Aceptación:** usuario heredado conserva acceso legítimo e historial; un email autodeclarado no enlaza pedidos ajenos; intentos automatizados están limitados; migración es reversible.

### F20 — P1 para operación admin: permisos del servidor y entrada de UI difieren

Servidor expone `/admin/me` con capacidades; Flutter decide mostrar acceso con allowlist de email/preview y no consume esa respuesta. El ejemplo de producción ni configura OWNER_ADMIN_EMAILS. Un owner por principal/Customer ID puede quedar oculto en app.

**Corregir:** usar capacidades de `/admin/me` para navegación y acciones; mantener autorización server-side. Separar owner real de preview. Retirar obligatoriedad de ExternalCatalogController.

**Aceptación:** owner autorizado por servidor ve y usa panel; usuario normal no; revocar rol cierra acciones; configuración incompleta no simula panel operativo.

### F21 — P2: admin sólo carga primera página y no controla toda la operación

`HttpAdminClient.fetchSnapshot` hace una sola lectura sin cursor. Backend usa 50 por defecto, máximo 100. No hay loadMore de productos, aunque sí existe para auditoría.

**Corregir:** paginar búsqueda/listado de productos y presentar límites reales. La edición actual cubre título, precio de variante y publicación; no es gestión completa de stock por ubicación, medios, altas/bajas, clientes o fulfillment.

**Aceptación:** producto 51/101 se encuentra y edita; no confundir cantidad cargada con total del shop. Operaciones no disponibles se realizan en Shopify Admin.

### F22 — P1 al retirar externo: «sincronizar todo» requiere monitor

`HttpAdminClient.syncAll():387` ejecuta `external-status` obligatoriamente. Backend sin monitor responde error; al fallar, se omite refreshAfter en AdminController. Además `shopify-products` sólo lee primera página de 100 y marca completed: no es reconciliación integral. Jobs se lanzan en memoria tras responder 202.

**Corregir:** eliminar canal externo; definir con precisión qué sincroniza cada job; progreso durable y recuperación tras reinicio; actualización de catálogo completo independiente de fallos ajenos.

**Aceptación:** sync sin monitor termina correctamente y refleja producto creado/editado/retirado; job interrumpido se recupera; no reportar complete sólo por aceptar 202 o leer primera página.

### F23 — P2: guardar portada no refresca la fuente que lee el comprador

`AdminController.saveStorefront` actualiza estado admin pero no activa refreshAfter. Home normalmente consume HomeContentController. Se escribe/lee `$app:storefront_config` desde credenciales de apps distintas, cuya definición/acceso público deben validarse en producción.

**Corregir:** refrescar HomeContent tras guardar; verificar definición, namespace efectivo, permisos Storefront y publicación del metaobject. No asumir que existe sólo porque una query/mutación está escrita.

**Aceptación:** cambiar anuncio/visibilidad desde admin se refleja en otro cliente sin reinstalar. Manejar errores de permisos, versión y ausencia del objeto de forma visible.

### F24 — P1 de migración: TOML de producción y permisos incompletos

`shopify.app.production.toml` tiene client_id y host placeholder. Declara read_orders/read_customers/read_products, aunque el panel implementa escrituras de productos, publicación y contenido. No existe handler/subscripción app/uninstalled allí.

**Corregir:** enlazar app real, scopes mínimos verificados para cada operación, publicación Headless, metaobjects, endpoints reales y protegido customer data. Confirmar método de emisión de Admin token compatible con la app/distribución; no copiar credenciales de staging.

**Aceptación:** valida config; lecturas y cada escritura autorizada pasan en staging; producción queda preparada y revisable, sin desplegarla automáticamente durante la reparación nocturna.

### F25 — P2: fuente Firestore y Storefront no tienen igual semántica

Firestore ignora snapshot vacío y rechaza uno entero si contiene un documento inválido. El mapper de servidor considera publicado `ACTIVE && publishedAt != null`, no comprueba publicación Headless específica. Por ello «visible en espejo» y «comprable por este storefront» pueden diferir. Hay implementaciones duplicadas en Vercel y Functions.

**Corregir:** para la nueva arquitectura, Storefront directo debe definir catálogo comprable. Si se conserva alguna caché propia, no puede ampliar visibilidad del canal; distinguir vacío válido de fallo y tener una sola autoridad/escritor por entorno.

**Aceptación:** retirar publicación Headless elimina producto de la experiencia comprable; ausencia/fallo de espejo no conecta otra tienda. No volver a introducir un servidor extractor como solución.

### F26 — P2: navegación y contexto comercial parcialmente estáticos

Menu, predictive search y recomendaciones Shopify tienen documentos GraphQL sin consumidores encontrados. Home sólo lee 50 colecciones. Runtime usa reglas de normalización del asset. `StorefrontConfig.country/language` existen, pero las queries de catálogo no aplican `@inContext`; datos de producto asumen MXN.

**Corregir:** conectar navegación gestionable si es requisito; paginar colecciones; aplicar mercado/idioma de manera efectiva. Separar búsqueda/recomendación local intencional de la promesa de usar Shopify. Al volver a foreground se refrescan destacados, no el catálogo general.

**Aceptación:** cambio de colección/menú se refleja sin release según contrato; precio/currency coincide con mercado MX del checkout; reabrir app refresca catálogo con control de concurrencia y sin depender de Home destacado.

### F27 — P2: apartados, mayoreo y soporte son procesos manuales

Producto abre WhatsApp; los pedidos de apartado aparecen sólo si se registran y vinculan en Shopify con tags adecuados. No existe reserva automática, anticipo, vencimiento ni conciliación de saldo. Partner abre Canva/Drive/WhatsApp y permite compartir links, no pedidos mayoristas transaccionales.

**Acción:** documentar dueño y pasos operativos: respuesta, disponibilidad, reserva, cobro, registro y entrega. Confirmar vigencia/permisos de catálogos, grupos y teléfono. No prometer «apartado confirmado» por abrir WhatsApp.

**Aceptación:** mensaje llega con variante/cantidad correctas; operador crea y vincula pedido al cliente adecuado; stock y estado posterior quedan verificables. Acceso privado a mayoreo sólo si negocio lo requiere.

### F28 — P2: push implementado pero no operativo en config actual

Existen instalación con App Check, preferencias, perfil, alertas, campañas, reglas y worker. Falta habilitación/configuración en build auditado; necesita APNs/FCM, identidad Firebase por app id, secretos backend y proceso worker separado. UI admin ofrece borrador, preview, prueba y envío; no cubre toda la gestión de reportes/cancelación que tiene API.

El deep link a collection en main.dart transforma handle a filtro de categoría, no a colección Shopify; puede abrir un resultado distinto. Hay eventos de telemetría de checkout definidos sin wiring completo de finalización.

**Aceptación:** opt-in/out efectivo; sin consentimiento no llega campaña; alerta abre producto correcto; colección abre su handle; cold start y foreground funcionan; campañas sobreviven reinicio; compra deja de recibir recordatorios incompatibles. Retirar triggers/productos externos.

### F29 — P1 operativo: privacidad y mantenimiento sin cierre durable

data_request sólo registra warning y marca evento procesado; no hay export/cola con responsable y cierre. Redact limpia partes del espejo/engagement, pero no ofrece proceso integral para cuentas heredadas, cache local y datos restantes. healthz/livez no comprueban PostgreSQL; no hay readyz en este servicio.

**Corregir:** proceso de solicitud/baja con inventario, seguimiento y evidencia; validar políticas aplicables con responsable del negocio. Agregar readiness, alertas, backups y prueba de restauración. No se afirma un incumplimiento legal concreto a partir del código.

**Aceptación:** una solicitud de prueba se exporta/cierra; borrado cubre datos identificados y reintentos; caída DB pone readiness no listo; restauración ensayada. No usar un log como prueba de cumplimiento.

### F30 — P1 de release: gates de calidad no están verdes

482 tests Flutter pasan, pero analyze reportó 20 infos y formato detectó dos archivos. CI referencia carpeta inexistente integration_test. check_no_secrets rechaza el fixture público [config/dart_defines.ci.json](/Users/alexis/develop/monetta-app/config/dart_defines.ci.json); no encontró en esa ejecución patrones de secreto privado. Son fallas del gate, no prueba de fuga de secretos.

**Corregir:** formato/lints, regla del fixture con excepción específica y validación de contenido, integración real y CI actualizado sin monitor externo. No deshabilitar todo el escáner para pasar.

**Aceptación:** formato, analyze, suites, escáner, build y pruebas de integración pasan sobre el commit final. Mantener versiones reproducibles; el workflow usa Flutter stable sin pin aunque existe `.fvmrc`.

## 6. Qué puede administrar hoy la persona propietaria

| Operación | Panel de app | Dependencias / límite |
|---|---|---|
| Consultar productos/estado | Sí, primera página | Backend, identidad owner y credencial Admin; listado incompleto |
| Editar título/precio de variante | Implementado | Flags de escritura, scopes y control de versión; comprobar errores de cambios parciales |
| Publicar/despublicar | Implementado para publicación configurada | No equivale a ocultar en todos los canales de Shopify |
| Stock por ubicación | No hay editor completo | Shopify Admin |
| Crear/eliminar producto, fotos | No hay flujo completo | Shopify Admin |
| Elegir productos de «Hoy» | Implementado | Colección manual `monetta-todays-picks`, publicación, permisos; shopper muestra hasta 12 |
| Ordenar destacados | API y controlador | Trabajo asíncrono puede devolver jobId; controlador no completa polling del reordenamiento como sí hace sync |
| Cambiar anuncio/secciones | Implementado | Metaobject público y refresco de home pendientes de validación |
| Cambiar historia/catálogos de revendedores | Lectura desde Shopify | Edición mediante Shopify Metaobjects; no editor completo en panel |
| Sincronizar | Acción existente | Dependencia externa y éxito parcial descritos en F22 |
| Auditoría | Lectura paginada | Vista recorta eventos; no sustituye auditoría durable del servidor |
| Campañas push | Borrador, audiencia, prueba, enviar, reglas | API + worker + Firebase; no configurados en build auditado |
| Pedidos, envíos, cancelaciones y reembolsos | Sin flujo administrativo propio | Operar en Shopify Admin |
| Usuarios, roles y permisos | Sin gestor completo | Provisionamiento server-side; hoy requiere intervención técnica |
| Pagos, impuestos, tarifas y políticas | Fuera de la app | Configuración de Shopify Admin; verificar con propietario |

No hace falta construir un segundo Shopify Admin para lanzar. El criterio debe ser que cada tarea tenga un lugar real donde hacerse, que la app no prometa capacidad inexistente y que su lectura se actualice correctamente.

## 7. Plan de cambio a monetta.mx

### Arquitectura objetivo

App → **Storefront API oficial de Monetta** para catálogo comprable, carrito y checkout; app → **Customer Account API** para login y datos del cliente; **Shopify Checkout** procesa pago/envío/impuestos. SQLite conserva caché e intención local validada. Backend propio sólo para capacidades necesarias de administración, notificaciones y enriquecimiento/operación de pedidos; sin extracción de productos de terceros.

Headless permite gestionar credenciales y publicar productos al canal; no basta cambiar un hostname. Referencia: [Bring your own headless stack](https://shopify.dev/docs/storefronts/headless/bring-your-own-stack).

### Identidad verificada públicamente

El 7 de septiembre respondieron correctamente los documentos públicos:

- monetta.mx → issuer `https://shopify.com/authentication/72391655575`, auth/token/logout en `clientes.monetta.mx`, GraphQL Customer Account `https://clientes.monetta.mx/customer/api/2026-07/graphql`.
- monetta-staging.myshopify.com → issuer de shop `90228850722`, endpoints en shopify.com para ese shop.

Esto confirma dos tiendas/identidades diferentes. No valida un client ID, sus scopes ni login completo. `fakcei-n9`/`monetta-2` figuran como alias históricos en docs: reconfirmar hostname canónico `.myshopify.com` en Admin, no elegir por semejanza.

### Inventario que se debe preparar

| Capa | Valores / recursos a cambiar o verificar |
|---|---|
| Storefront móvil | dominio real, token **público** del canal real, versión API, mercado MX y ES |
| Catálogo | publicación de productos/colecciones al canal Headless, variantes e inventario real, imágenes, metafields y metaobjects accesibles |
| Customer Account | shop ID 72391655575, client ID Mobile real, callback exacto, scopes/protected data aprobados |
| Android | flavor production ya existe con callback real; firma release debe verificarse |
| iOS | build settings ya contienen callbacks reales/staging; verificar scheme y configuración seleccionados por el comando de release, bundle ID/profiles |
| Caché | identidad del shop; migración segura sin reusar cursor, tokens y variantes staging |
| Backend | host HTTPS real, DB separada, shop canónico, app client ID/secret, publicación Headless, colección destacada, principales admin y flags |
| Shopify app TOML | enlace real, host, scopes, webhooks y lifecycle correctos |
| Contenido | `monetta-todays-picks`, storefront_config, contenido editorial, home, Loox, links de soporte/revendedores |
| Firebase opcional | app IDs/bundle IDs, proyecto production, App Check/APNs/FCM; no usar Firebase staging en release |
| Checkout | host real de checkoutUrl permitido explícitamente; no relajar a comodines si difiere del host Storefront |
| Comercio | métodos activos, modo test vs real, MXN/Markets, cobertura, tarifas, impuestos, inventario, notificaciones transaccionales y políticas |
| Operación | monitor de webhooks, backups/restauración, incidentes, rollback, stock y devolución de canary |

**Ya hay avances que no deben rehacerse:** flavors Android con callback real/staging; callback variable en iOS; cliente Storefront/Cart API y puentes Checkout Kit; PKCE/refresh seguro; bearer en consulta de pedidos; idempotency/conflictos/auditoría de mutaciones admin. Documentos viejos describen varios de estos como ausentes: el código actual tiene prioridad.

### Secuencia de corte

1. Corregir P0 y catálogo/variantes en entorno aislado. Retirar monitor de flujos y dependencias.
2. Habilitar staging comercial coherente: **catálogo, cuenta y carrito del mismo shop**. Permitir staging Storefront sin obligación artificial de Firestore.
3. Completar compra invitado/autenticado, cancelación, errores y posventa con pagos de prueba.
4. Preparar configuración production sin secretos en Git y validar todos los recursos de la tabla.
5. Reconciliar catálogo publicado completo y comparar IDs/precios/inventario; no tomar 139 del snapshot como conteo esperado de producción.
6. Ejecutar canary privada iOS/Android y una orden real de bajo importe sólo con autorización operativa; revisar pago, impuestos, envío, stock, correo, historial y webhook. Reembolsar según procedimiento aprobado.
7. Liberar gradualmente con rollback probado. Mantener builds, app config y DB de staging separadas de producción.

## 8. Verificaciones ejecutadas

| Verificación | Resultado del 7 de septiembre |
|---|---|
| flutter test | **482 pasan** |
| accounts_orders tests | **68 pasan**, 15 archivos |
| test:api | **19 pasan**, 5 archivos |
| functions tests | **13 pasan**, 3 archivos |
| dashboard tests | **28 pasan**, 6 archivos; warnings React Router |
| Total pruebas existentes ejecutadas | **610 pasan**; no significa E2E de comercio |
| Typecheck accounts_orders / API / functions / dashboard | Pasan |
| Build web / dashboard | Pasan; son visor y dashboard, no tienda web |
| flutter analyze | **20 infos**, no estado limpio; revisar gate fatal-info |
| dart format --output=none … | **Falla**: main.dart y onboarding_controller.dart; integration_test no existe |
| validate_dart_defines staging | Pasa aun con checkout sin configurar; sólo valida el contrato actual de catálogo |
| verify_catalog_snapshot | Pasa: **139 productos / 386 imágenes** del snapshot, sin revisión remota de imágenes |
| check_no_secrets.sh | **Falla** por archivo CI público no exceptuado; no evidencia aquí de credencial privada filtrada |
| Sondas nuevas | **6 defectos reproducidos**: owner no verificado, registro por deviceId, retry perdido, catálogo no elimina, paginación falsa, lectura sin scope |
| Discovery público real/staging | HTTP/JSON correctos; identidades diferentes |
| Login/pago/fulfillment reales, native release actual, backup/restore | **No ejecutados** |

No se ejecutó crawler ni suite completa del monitor externo porque se retira del objetivo. No se verificó el historial de Git en busca de secretos; el escáner sólo revisa archivos candidatos actuales.

Las sondas usan datos sintéticos y repositorios en memoria; son evidencia del comportamiento defectuoso, **no pruebas que deban mantenerse verdes legitimando ese comportamiento**. Copias en `docs/audits/2026-09-07/`; instrucciones en su README. Las pruebas de regresión definitivas deben exigir el comportamiento corregido.

## 9. Criterio de listo para lanzamiento

- Ningún P0 abierto, ninguna dependencia de extracción externa en runtime.
- Catálogo, sesión, variantes y checkout del mismo shop; publicación e inventario verificados.
- Invitado y cliente autenticado compran en ambos sistemas; cancelar/rechazar no pierde bolsa ni crea falsa confirmación.
- Usuario recibe confirmación coherente y puede consultar pedido/estado; pedidos anteriores no desaparecen por falta de backfill.
- Owner legítimo opera; usuario normal y email no verificado no obtienen privilegios.
- Retiro de producto, cambios de precio y stock se reflejan; ninguna sync parcial se declara completa.
- Separación de cuentas, logout, expiración, consentimiento y procesos de datos verificados.
- CI verde, credenciales/entornos separados, observabilidad y recuperación verificadas.
- Pagos/operación de producción tienen evidencia real y aprobación de la persona propietaria.

El trabajo de una noche debe producir correcciones demostrables y una lista corta de verificaciones operativas pendientes; no una declaración de «todo listo» basada en compilar.
