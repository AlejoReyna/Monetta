# Auditoría independiente de PR #7

Fecha: 2026-09-07. PR: https://github.com/AlejoReyna/Monetta/pull/7.

**Commit revisado: `5393ff818b50dc114b7b8a2a21a797d6d57ce4ed`**, posterior a `af8be2e`. Recomendación: **pedir cambios antes de aprobar**. Resolver el análisis de Flutter no cierra los defectos funcionales siguientes ni demuestra preparación para producción.

Alcance: revisión de código, diferencias y documentación F01–F30/J01–J11; inspección de CI; suite Flutter local, suite accounts_orders y probes específicos. No se modificó código de producto, no se publicaron comentarios en GitHub y no se realizaron operaciones en Shopify ni pagos reales. Las conclusiones de ejecución local se distinguen de los escenarios derivados del código.

## Hallazgos

### R1 · P1 · Un producto con siete imágenes impide sincronizar el catálogo

Referencias: [queries.dart:27](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/shopify/queries.dart#L27), [catalog_sync.dart:221](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/shopify/catalog_sync.dart#L221). F08/F09 requieren reapertura.

La consulta limita las imágenes a seis. El nuevo control de integridad lanza una excepción cuando `images.pageInfo.hasNextPage` es verdadero, pero nunca descarga las imágenes restantes. Un producto válido con siete imágenes aborta toda la sincronización, preservando un catálogo viejo. El mismo límite estructural existe para más de 50 variantes o 25 colecciones.

**Evidencia:** probe local reproduce `CatalogSyncOutcome.failed` con `CatalogSyncIncompleteException`. El snapshot incluido tiene 145 productos, 11 con más de seis imágenes; esto es evidencia del asset, no un conteo del Shopify actual.

**Corrección y aceptación:** paginar las conexiones que deben ser completas. Si las imágenes son una vista previa deliberadamente limitada, modelarlo explícitamente y no abortar por esa limitación. Probar 7 imágenes, 51 variantes y 26 colecciones, incluyendo una falla en páginas posteriores; nunca publicar variantes truncadas como catálogo completo.

### R2 · P1 · Una respuesta incompleta puede borrar la última caché válida

Referencia: [catalog_sync.dart:177–192](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/shopify/catalog_sync.dart#L177), reemplazo en [catalog_repository.dart:209–220](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/repositories/catalog_repository.dart#L209).

`products: null` se convierte en cero nodos. La ausencia de `pageInfo` se interpreta como fin de paginación. El resultado se considera una sincronización completa válida y `replaceProducts` borra la caché anterior.

**Evidencia:** un transporte falso que devuelve `{"data":{"products":null}}` sin errores GraphQL deja la caché vacía y devuelve `updated`. No se afirma que Shopify haya emitido esa respuesta en vivo: el defecto está en aceptar una estructura incompleta como prueba suficiente para una escritura destructiva.

**Corrección y aceptación:** exigir conexión, colección de nodos/edges y metadatos de paginación válidos antes de reemplazar. Probar conexión nula, ausente, malformada y respuesta vacía válida. Las primeras deben conservar caché y cursor; sólo la última puede vaciar el catálogo.

### R3 · P1 · La migración de tienda acepta cachés antiguas sin procedencia

Referencia: [catalog_repository.dart:271–288](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/repositories/catalog_repository.dart#L271). F10 requiere reapertura.

La incompatibilidad sólo se detecta cuando el cursor o la metadata ya tienen un dominio no nulo. Un cursor de una instalación anterior sin `shopDomain` recibe el dominio nuevo conservando sus fechas. Puede ejecutarse un delta sobre productos de staging y posteriormente etiquetar esa caché como perteneciente a la tienda nueva. Los productos ausentes en el delta no se eliminan.

**Evidencia:** probe con producto previo y cursor reciente sin procedencia; tras sincronizar un delta vacío configurado para `monetta.mx`, el producto previo permanece y el cursor queda marcado `monetta.mx`.

**Corrección y aceptación:** tratar procedencia desconocida como migración que exige un catálogo completo verificado, no como coincidencia. Probar una base anterior real, cambio staging→producción, productos con IDs distintos, wishlist/bolsa y fallo de la primera sincronización. No mostrar ni enviar IDs de staging como productos confirmados de producción.

### R4 · P1 · Un webhook interrumpido puede recibir ACK sin haber aplicado sus efectos

Referencias: [pgWebhookEventsRepository.ts:29–34](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/services/accounts_orders/src/db/pgWebhookEventsRepository.ts#L29), [handlers.ts:81–87](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/services/accounts_orders/src/webhooks/handlers.ts#L81), [server.ts:259–260](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/services/accounts_orders/src/api/server.ts#L259). F12 requiere reapertura.

`tryClaim` devuelve el mismo `false` para un evento completado y para uno en `processing` con menos de cinco minutos. El handler retorna y la ruta responde 200 en ambos casos. Si el proceso original muere después de reclamar el evento y el reintento llega antes de vencer esos cinco minutos, se reconoce como recibido aunque los efectos nunca terminaron. No hay un worker que retome esas filas ni payload persistido suficiente para reproducirlas; esperar cinco minutos no provoca por sí solo su recuperación.

**Evidencia:** recorrido estático del claim SQL, handler, ruta HTTP y migración 010. Las pruebas existentes de excepciones recuperables no equivalen a matar el proceso después del claim.

**Corrección y aceptación:** distinguir `completed` de `busy`, y garantizar recuperación durable antes de reconocer una entrega. Usar reintento HTTP o una cola durable con payload y worker según el diseño elegido. Probar con PostgreSQL: claim, interrupción antes del efecto, reintento inmediato, recuperación y efecto único; además duplicados concurrentes y reintento posterior a completar.

### R5 · P1 · Una finalización tardía de checkout limpia la bolsa de otra cuenta

Referencias: [shopify_checkout_coordinator.dart:99–105](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/app/shopify_checkout_coordinator.dart#L99), [checkout_screen.dart:251–252](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/features/checkout/checkout_screen.dart#L251), [catalog_store.dart:556–566](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/app/catalog_store.dart#L556).

El coordinador conserva el scope del carrito para borrar su sesión, pero el callback sólo recibe IDs de variantes. `clearPurchasedBagLines` opera sobre la cuenta activa al ejecutarse. Si el scope cambia mientras se espera el resultado nativo, el checkout de A puede borrar una variante coincidente de B y dejar intacta la bolsa comprada de A.

**Evidencia:** probe local: agregar variante a A, capturar IDs comprados, cambiar a B, agregar la misma variante y ejecutar el callback tardío. La bolsa de B queda vacía; la de A conserva el artículo. Es una reproducción de la frontera de estado; no se ejecutó este cambio de sesión en un dispositivo durante un pago.

**Corrección y aceptación:** transportar scope, generación y líneas/cantidades del checkout; escribir en el scope capturado y actualizar memoria sólo si sigue vigente. Probar A→B, A→invitado, cancelación, callback repetido y artículos añadidos mientras se espera el resultado. Una compra de A jamás debe modificar la bolsa de B.

### R6 · P2 · “Mis pedidos” queda limitado a 25 sin navegación

Referencias: [customer_orders.dart:72–95](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/customer_auth/customer_orders.dart#L72), [order_history_repository.dart:105–136](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/repositories/order_history_repository.dart#L105).

La nueva fuente primaria consulta `orders(first: 25)` una sola vez, sin `after` ni `pageInfo`. Luego reemplaza todo el historial local. Los pedidos anteriores quedan inaccesibles y pueden desaparecer de la caché aunque Shopify los conserve.

**Evidencia:** inspección del servicio y su único recorrido de refresh. No es una limitación documentada con paginación en la UI.

**Corrección y aceptación:** paginar o implementar carga incremental explícita y persistencia acorde. Probar cliente con 26 y 60 pedidos, identificadores únicos, segunda página fallida y recuperación sin eliminar historial válido.

### R7 · P2 · Un apartado visible en Shopify puede aparecer dos veces

Referencia: [order_history_repository.dart:184–220](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/repositories/order_history_repository.dart#L184).

Se agrega cada pedido de Customer Account API como una fila y después cada apartado del mirror como otra fila `apartado:...`, sin combinar por identidad Shopify. Un apartado que ya es un pedido Shopify aparece duplicado. Además, `shopifyOrderId` recibe `order.number` en la fila CAA: el número comercial del pedido no es su ID Shopify.

**Evidencia:** recorrido estático del ensamblado de filas.

**Corrección y aceptación:** usar GID/ID canónico para combinar fuentes, conservar el número visible por separado y enriquecer una sola fila con los datos del apartado. Fixture con el mismo pedido en ambas fuentes: una fila, identidad correcta y estado actualizado; fixture con pedidos distintos: ambos conservados.

### R8 · P2 · Un catálogo vacío confirmado se repuebla desde el asset al abrir

Referencias: [catalog_repository.dart:89–105](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/data/repositories/catalog_repository.dart#L89), [catalog_store.dart:196](https://github.com/AlejoReyna/Monetta/blob/5393ff818b50dc114b7b8a2a21a797d6d57ce4ed/lib/app/catalog_store.dart#L196).

El seed sólo pregunta si hay productos, sin distinguir una instalación nueva de una sincronización Shopify vacía y válida. Tras despublicar todos los productos y sincronizar, la próxima carga puede mostrar otra vez productos del asset. Una sincronización completa posterior exitosa vuelve a eliminarlos; durante la carga o sin conexión queda un catálogo que la tienda había retirado.

**Evidencia:** probe de full sync vacío seguido del método de seed usado al iniciar. Se verifica la reaparición antes de la siguiente sincronización, no persistencia después de una sincronización completa exitosa.

**Corrección y aceptación:** persistir estado de inicialización/resultado vacío y respetarlo al decidir el fallback. Probar primera instalación offline frente a caché Shopify legítimamente vacía y reinicio offline.

## CI y pruebas ejecutadas

| Verificación | Resultado observado |
|---|---|
| PR HEAD | `5393ff8`, confirmado al terminar las comprobaciones |
| Flutter CI | Falla en análisis: `unawaited_return_in_try_block`, `account_controller.dart:121` y `:125` |
| Suite Flutter local completa | **517 pasan, 2 fallan** |
| accounts_orders local | **86/86 pasan**, incluidos dos tests PostgreSQL en base desechable |
| accounts-orders CI | **84 pasan, 2 omitidos**: `wp01Security.pg.test.ts` se salta si PostgreSQL no responde |
| Probes de esta auditoría | **5/5 reproducen comportamiento defectuoso**; no son pruebas de aceptación de una solución |
| Otros checks remotos | verify, functions-and-web, ios-compile y catalog-monitor-retired verdes; Macroscope omitido |
| Shopify/auth/pagos/dispositivos en vivo | **No ejecutados en esta auditoría** |

[Job Flutter](https://github.com/AlejoReyna/Monetta/actions/runs/34153514736/job/101840470707). [Job accounts-orders](https://github.com/AlejoReyna/Monetta/actions/runs/34153514736/job/101840470840).

Flutter local: 3.44.8. Flutter del job remoto: 3.47.2. Los resultados locales no sustituyen una ejecución completa con la versión de CI; sus dos fallos observados son expectativas concretas de schema y texto.

El `try` de `accessTokenForBackend` devuelve Futures sin esperarlos: el `catch` no captura fallos asíncronos del refresh. Corregir ambos retornos y probar rechazo asíncrono. Ese fallo de análisis también impide ejecutar los pasos posteriores del job, incluyendo tests y build Android.

Los dos tests Flutter fallidos tienen expectativas desactualizadas: `database_test.dart:16` exige schema 5 frente al 6 actual; `product_screen_test.dart:65` exige el texto antiguo de apartado. Actualizarlos conforme al comportamiento aprobado; no revertir la migración o la corrección del texto para satisfacerlos.

El workflow no levanta PostgreSQL y permite que los tests de persistencia desaparezcan del resultado verde. Añadir servicio DB y hacer obligatorio ese grupo en CI; la indisponibilidad debe fallar en ese entorno.

## Qué sí avanzó y qué todavía no está probado

Hay mejoras sustanciales en autorización de administrador, registro de cuentas, selección/persistencia de variantes, aislamiento habitual de bolsa/wishlist, composición de checkout, estados del historial y abandono del origen externo de productos en el runtime de la app. Los tests de seguridad de cuentas pasan también con PostgreSQL local. Estas mejoras no cierran R1–R8.

La validación de extremo a extremo permanece pendiente por implementación y por entorno:

- `integration_test/app_smoke_test.dart` sólo ejecuta `expect(true, isTrue)`; no arranca ni recorre la aplicación.
- `tools/audit/lib/seed.mjs:82–92` declara que los adaptadores remotos no existen; incluso en modo live las entidades quedan `skipped` y `remote_write_attempted: false`. No crea clientes Shopify, usuarios funcionales ni pedidos de prueba.
- `J01-J11_RESULTS.md` reconoce cero journeys aprobados en vivo. No se probaron login alojado, compra de invitado/autenticado, Checkout Kit, matriz de métodos de pago ni restauración operativa.
- Un build iOS correcto demuestra compilación, no cobro, Apple Pay, conciliación ni configuración de producción.

## Condiciones para cerrar la revisión y cambiar a monetta.mx

1. Corregir R1–R8 con regresiones que verifiquen el resultado esperado, además de los tres bloqueos Flutter y la omisión de PostgreSQL en CI. Ejecutar la suite completa y builds aplicables.
2. Implementar fixtures reales en un entorno de desarrollo autorizado: invitado, cliente A, cliente B, cuenta legacy si se mantiene, administrador legítimo y administrador revocado. Registrar IDs reales de fixtures, repetir sin duplicar y limpiar sólo recursos del run.
3. Ejecutar autenticación y aislamiento en dispositivo: alta/login, callback, restauración, expiración, logout, cambio A/B, denegación de usuario normal en APIs admin y revocación del administrador. Validar acceso directo al backend, no sólo botones ocultos.
4. Ejecutar compras en modo prueba de invitado y cliente autenticado; cancelación, rechazo, reintento, cierre de app y retorno de navegador. Comprobar cuenta compradora, variantes, cantidades, importe/moneda, pedido Shopify y estado local. Verificar devoluciones y eventos duplicados/fuera de orden. El apartado continúa siendo operación manual; WhatsApp por sí solo no confirma pago o inventario reservado.
5. Para producción, verificar la identidad canónica de la tienda detrás de `monetta.mx`, publicación del catálogo para el canal autorizado, tokens/scopes oficiales, configuración Storefront/Customer Account/Admin coherente, callbacks y enlaces de retorno, endpoints/webhooks firmados y migraciones. El cambio no consiste sólo en reemplazar un hostname. Probar instalación nueva y actualización de una instalación staging sin reutilizar IDs, carritos ni credenciales de la otra tienda.
6. Registrar operación admin, privacidad/exportación y restauración; completar la matriz de pagos iOS/Android y los requisitos de notificaciones si se habilitan. Mantener el origen externo de extracción de productos desactivado y verificar el retiro operativo documentado.
7. Entregar evidencia por journey: commit/build, entorno, pasos, fixtures, esperado/observado, resultado y evidencia sanitizada. Credenciales o configuración faltantes deben constar como bloqueo, nunca como PASS. El canary o cambio de producción requiere una ejecución posterior expresamente autorizada.

Los probes reproducibles de esta revisión están archivados en `pr7_review_probes.dart.txt`. Son evidencia del defecto: sus aserciones actuales deberán invertirse/adaptarse cuando se conviertan en regresiones de las correcciones.

Para reproducirlos sobre el commit revisado, copiar ese archivo a `test/pr7_audit_probe_test.dart` y ejecutar `flutter test --no-pub test/pr7_audit_probe_test.dart` desde la raíz del repositorio con las dependencias instaladas. Eliminar después esa copia temporal. El import del fixture espera precisamente esa ubicación.
