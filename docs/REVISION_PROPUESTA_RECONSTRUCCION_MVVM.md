# Revisión de la propuesta de reconstrucción MVVM de Monetta

**Fecha:** 6 de octubre de 2026, America/Monterrey.
**Documento revisado:** `docs/PROPUESTA_RECONSTRUCCION_MVVM.md` (sin versionar).
**Referencia examinada:** HEAD `48a6786` más el árbol de trabajo (cambios sin commit de Rewards en `services/accounts_orders`).
**Naturaleza:** revisión independiente. No se implementaron cambios, no se desplegó nada y no se modificaron datos ni infraestructura.

## Método y límites

- Se leyó el código citado por la propuesta y el que lo rodea. Cada hallazgo indica `archivo:línea` del snapshot.
- Las versiones y restricciones de paquetes se consultaron en la API de pub.dev el 2026-10-06. Toolchain local: Flutter 3.44.8 (fvm) con Dart 3.12.2, verificado con `dart --version`.
- Guía oficial: tabla de `docs.flutter.dev/app-architecture/recommendations`, consultada el mismo día.
- **No se ejecutó la suite de Flutter.** El sandbox de la revisión no permite escribir en la caché del SDK y `flutter` no arranca.
- **La suite de `accounts_orders` corrió en parte:** 53 pruebas aprobadas, 58 fallidas por `listen EPERM` y 9 de Postgres omitidas. El EPERM viene de que el sandbox prohíbe abrir puertos locales; no es un fallo del producto.
- No se consultó el estado del CI en GitHub. **Esta revisión no afirma que ninguna suite esté verde.**
- Etiquetas:
  - **[Hecho]**: verificado en código, configuración o metadatos.
  - **[Inferencia]**: deducción razonada, sin ejecución.
  - **[Decisión]**: corresponde a la persona propietaria.

## A) Veredicto

**Requiere rediseño del plan de ejecución. El diagnóstico y la arquitectura destino son aceptables con cambios.**

Lo que se sostiene:

- El diagnóstico H01–H15 casi completo. H10 necesita otra evidencia (ver B3).
- La separación entre bolsa local y carrito confirmado.
- La tabla de estados de §7.3.
- Las reglas de dependencia de §3.2.
- El rechazo a `BaseRepository`, singletons y bus de eventos.
- La norma de no declarar verificado lo que se omitió.

Lo que no resiste el contraste con el repositorio:

1. **Reconstruir en un checkout aislado (ADR-01).** Sólo cambian la presentación y la composición. Hacerlo en paralelo obliga a portar 124 archivos de prueba antes de poder mostrar equivalencia, y compite con un lanzamiento que, según los propios documentos del repo, aún no ocurre (R01).
2. **Riverpod y go_router como base (ADR-02/03).** Ambos ya están declarados y resueltos, pero no se usan en ningún archivo. La app no tiene enlaces externos. La guía oficial que cita la propuesta recomienda `provider` para la inyección de dependencias y deja `ChangeNotifier` como opción válida (R04–R06).
3. **El alcance mezcla la app con backend, espejo de catálogo, galería y dashboard.** Cada uno tiene su propio ciclo y su propio riesgo (R07, R19).
4. **La matriz funcional omite flujos con efecto comercial:**
   - atribución de carrito, que hoy siempre envía `_rec_source=direct`;
   - apartado por WhatsApp con código `MN-XXXX`;
   - recordatorio local de carrito;
   - telemetría;
   - reseñas de Loox;
   - historial de búsqueda (R03).

Ruta recomendada: refactor in situ por estrangulamiento, con un tag de baseline como referencia ejecutable.

1. Corregir los defectos de contrato de B2, que no tienen por qué esperar a ninguna reconstrucción.
2. Rehacer la composición y la navegación.
3. Hacer un piloto vertical antes de extender el patrón al resto de la app.

## B) Hallazgos priorizados

Formato del encabezado: ID · sección o ADR · gravedad.

- **Alta:** pérdida de datos, crash, dinero incorrecto o una decisión central que deja de sostenerse.
- **Media:** defecto funcional o costo significativo.
- **Baja:** limpieza o precisión.

### B1. Estrategia y alcance

#### R01 · ADR-01, §11 · Alta — La reconstrucción aislada cuesta más de lo que aporta

**Qué se conserva y qué se reescribe**

- [Hecho] La propuesta reutiliza reglas, pruebas, contratos, recursos y adaptadores (§1). Se conservan `data/`, `domain/`, `reco/`, `normalize/`, `platform/` y los puentes nativos de checkout (`ios/Runner/ShopifyCheckoutBridge.swift` y `android/.../ShopifyCheckoutBridge.kt`).
- [Hecho] Lo que se reescribiría es `lib/app/`, `lib/features/` y `main.dart`: 34 028 de las 48 337 líneas no generadas de `lib/`.

**Pruebas acopladas al código actual**

- [Hecho] Hay 124 archivos de prueba, con unas 688 declaraciones `test`/`testWidgets`.
- [Hecho] 22 de esos archivos importan `main.dart`, 26 usan `CatalogStore` y 24 montan scopes. En un checkout nuevo ninguno compila hasta portarlo.

**Estado del producto**

- [Hecho] `docs/SYSTEM_IMPLEMENTATION.md` §9 deja como «pendiente de aceptación externa»:
  - el login de extremo a extremo;
  - el checkout real desde la app;
  - las notificaciones push en producción;
  - `accounts_orders` en el entorno final.
- [Hecho] `docs/AUDITORIA_FLUJOS_2026-09-07.md` §8 marca «Login/pago/fulfillment reales, native release actual, backup/restore — No ejecutados».
- [Hecho] Otras señales:
  - `pubspec.yaml` está en `0.1.0+1` y no hay tags;
  - `fly.toml` despliega `monetta-accounts-staging`;
  - el ejemplo de configuración de producción conserva el marcador `REPLACE_PRODUCTION_BACKEND_HOST`.
- [Inferencia] Todavía no hay base instalada en producción. Por eso la compatibilidad de actualización es barata hoy, y el costo dominante del plan es retrasar el lanzamiento o mantener dos apps a la vez.

**Escenario de fallo:** mientras se reconstruye, se corrige un defecto en el árbol vigente, como el WIP actual de Rewards. La app nueva no hereda esa corrección, y la equivalencia se mide contra una referencia que se movió.

**Alternativa:** refactor in situ.

- `git tag baseline/48a6786` da la «referencia reproducible» que busca ADR-01 sin una segunda app.
- Cada PR deja la suite verde y la app liberable.
- Las pruebas de PR7 siguen corriendo sin portarlas.

**Prueba que resuelve la duda:** en el piloto (fase 4 de D2), contar las pruebas adaptadas frente a las reescritas y los PR que tuvieron que tocar dos árboles. Con el refactor in situ, el segundo número es 0 por construcción.

#### R02 · §2.1, §6.2 · Alta — El código retirado sigue en tres unidades de compilación y en la ruta viva

**Dónde sigue el código retirado**

- [Hecho] En `lib/` quedan unas 1 767 líneas del catálogo externo o de su modelo mixto:
  - `data/external_catalog/`
  - `app/external_catalog_controller.dart`
  - `app/mixed_feed.dart`
  - `features/home/external_catalog_section.dart`
  - `features/product/external_product_screen.dart`
  - `reco/external_facets.dart`
  - `domain/catalog_item.dart` (con fuentes `coachUs`… y `commissionRate`)
  - `catalog_item_mapper.dart`
- [Hecho] En `test/` hay unas 1 704 líneas más del mismo código.
- [Hecho] `services/catalog_monitor` y `dashboard` suman unas 20 800 líneas de TS/TSX.

**La ruta viva todavía pasa por ese modelo**

- [Hecho] `home_screen.dart:268` y `collection_screen.dart:261` llaman a `fullDeduplicatedCatalog(monettaItems: store.catalogItems, externalItems: const [])`.
- [Hecho] `catalog_browse_screen.dart` importa `external_product_screen.dart`.
- [Hecho] El backend sigue cableando el monitor. `services/accounts_orders/src/api/server.ts:831-841` crea un `HttpExternalCatalogAdminClient` si existe `catalogMonitorBaseUrl`, y `admin/routes.ts:270,506,888` expone las fuentes y el job `external-status`.

**Costo:** cada capa nueva tendría que decidir qué hacer con `CatalogItem`. Además, parte de la evidencia de H10 (E17) apunta a ese modelo y no al `Product` vigente.

**Alternativa:** antes del refactor, un PR que elimine código —no infraestructura— y deje un tag forense.

- `home` y `collection` pasan a trabajar sobre `Product`.
- Se retira `externalCatalogClient` del admin.
- El retiro de servidores sigue siendo un proyecto aparte, como ya dice la propuesta.

**Prueba:** `grep -ri external lib test` sólo encuentra el guard de `RuntimeConfig`, y la suite sigue verde.

#### R03 · §9 · Alta — La matriz de equivalencia omite flujos con efecto comercial

- [Hecho] La propuesta no menciona estos flujos vigentes:
  - Atribución de carrito (`data/shopify/cart_attribution.dart`). El propio código la describe como «evidence base for the revenue-share arrangement».
  - Apartado por WhatsApp con código `MN-XXXX` (`ApartadoRequest`; procedimiento en `docs/audits/2026-09-07/APARTADO_AND_RESELLER_SOP.md`).
  - Pedidos de apartado en el historial (`OrderSummaries.source = whatsappApartado`).
  - Recordatorio local de carrito (`flutter_local_notifications`, `LocalCartReminderConfig`).
  - Telemetría y Crashlytics (`ProductTelemetry`).
  - Experiencias de clientes con Loox.
  - Historial de búsqueda persistente.
  - Destacados del inicio («Today's Picks»).
- [Hecho] `_rec_source` siempre vale `direct`. `CartAttribution.recoSource` tiene ese valor por defecto (`cart_attribution.dart:46`), la única construcción está en `main.dart:635-639` y ningún código llama a `copyWith(recoSource: …)`. `_campaign` nunca se envía.

**Escenario de fallo:** la reconstrucción «conserva» la atribución copiando el comportamiento actual y reproduce un dato que no distingue push, búsqueda ni recomendación. O el resolver de navegación nuevo pierde el origen, y nadie lo nota porque ninguna prueba lo cubre.

**Alternativa:**

- Añadir estas filas a §9 como P0, cada una con su evidencia.
- Decidir (E8) si `_rec_source` es un requisito contractual. Si lo es, el origen tiene que viajar con cada línea de bolsa, que hoy no tiene columna para guardarlo.

**Prueba:** un test de contrato sobre `cartCreate` que verifique los atributos enviados en cada escenario de origen.

#### R04 · ADR-02, ADR-03, ADR-13, H15 · Media — Dependencias declaradas sin uso fijan la toolchain de codegen

**Paquetes declarados que nadie importa**

- [Hecho] `pubspec.yaml` declara:
  - en dependencias: `flutter_riverpod` (lock 3.1.0), `riverpod_annotation` 4.0.0, `go_router` (lock 14.8.1), `freezed_annotation` y `json_annotation`;
  - en dependencias de desarrollo: `riverpod_generator` 4.0.0+1, `riverpod_lint` 3.1.0, `custom_lint` 0.8.1, `freezed` 3.2.3 y `json_serializable` 6.11.2.
- [Hecho] **No hay ni un import de ellos en `lib/` ni en `test/`**, y `analysis_options.yaml` no activa plugins.
- [Hecho] `main.dart:245` lo dice explícitamente: «Deliberately plain Flutter rather than Riverpod for now».
- [Hecho] `docs/ARCHITECTURE.md:29,33,97,295` describe controladores Riverpod y entidades freezed que no existen.

**Cómo bloquean la actualización de `drift_dev`** (datos de pub.dev)

- [Hecho] `custom_lint` 0.8.1 —su última versión, de septiembre de 2025— exige `analyzer ^8.0.0`.
- [Hecho] `freezed` 3.2.3 y `json_serializable` 6.11.2 exigen `analyzer <9`.
- [Hecho] `drift_dev` 2.33 o superior exige `analyzer ≥10`, y 2.34 o superior exige `analyzer ^13`.
- Resultado: los paquetes sin uso fijan `analyzer` en 8.4.0. Con eso, `drift_dev` —el único generador que la app sí usa— no puede pasar de 2.33.

**Compatibilidad declarada con Dart 3.12.2 / Flutter 3.44.8** (pub.dev)

| Paquete | Versión | Restricción declarada | ¿Compatible? |
|---|---|---|---|
| `flutter_riverpod` | 3.4.3 | sdk ^3.12.0 | Sí |
| `riverpod_generator` | 4.0.9 | sdk ^3.12.0; analyzer ≥13 <15 | Sí, pero no convive con `freezed` 3.x ni con `custom_lint` 0.8.1 |
| `riverpod_lint` | 3.1.8 | sdk ^3.12.0; analyzer ^13; usa `analysis_server_plugin`, no `custom_lint` | Sí |
| `riverpod_lint` | 3.1.9 | sdk ≥3.13.0-0 | **No** |
| `freezed` | 4.0.2 | sdk ≥3.13.0 | **No** |
| `go_router` | 18.0.2 | sdk ^3.12.0; flutter ≥3.44.0 | Sí; el lock está cuatro versiones mayores atrás |
| `provider` | 6.1.5+1 | sdk ≥2.12 <4; no depende de analyzer | Sí |

**Consecuencia:** la alternativa de ADR-13, «Riverpod generator y Freezed», no se puede instalar junta con este toolchain en sus versiones actuales. La resolución final debe confirmarse con `flutter pub get` en 3.44.8, que esta revisión no pudo ejecutar.

**Alternativa:** decidir dentro del piloto si se adopta cada paquete o se retira. Por defecto, retirar los que no se usan y corregir `ARCHITECTURE.md` y `README.md`.

**Prueba:** después de retirarlos,

1. `flutter pub get` resuelve sin conflictos;
2. `dart run build_runner build` produce un `database.g.dart` idéntico;
3. `flutter pub outdated` muestra que `drift_dev` ya se puede actualizar.

#### R05 · ADR-02 · Media — Usar Riverpod como ViewModel equivale a reescribir la presentación

**Punto de partida**

- [Hecho] El estado vigente vive en 12 subclases de `ChangeNotifier` dentro de `lib/app/` (11 vigentes y una retirada). Entre ellas: `CatalogStore`, `AccountController`, `CartController`, `NotificationController` y `AdminController`. Se exponen a la UI con `InheritedNotifier`.
- [Hecho] En Riverpod 3.1.0, `ChangeNotifierProvider` vive en `package:flutter_riverpod/legacy.dart`; lo verifiqué en el pub-cache.
- [Hecho] Riverpod 3.1.0 reintenta por defecto los providers que fallan: hasta 10 veces, con espera exponencial de 200 ms a 6.4 s (`ProviderContainer.defaultRetry`). Esos reintentos se suman a los del transporte.

**Lo que dice la guía oficial**

- [Hecho] MVVM: *Strongly recommend*.
- [Hecho] `ChangeNotifier` y `Listenable`: *Conditional* («ultimately the decision comes down to personal preference»).
- [Hecho] Commands: *Recommend*.
- [Hecho] Inyección de dependencias: *Strongly recommend*, con la nota «We recommend you use the provider package».
- [Hecho] Capa de dominio: *Conditional* («in most apps they add unnecessary overhead»).

**Costo:** el propio ADR descarta la API legacy. Entonces adoptar Riverpod obliga a:

- convertir cada controlador en un `Notifier`;
- convertir cada consumidor en un `ConsumerWidget`;
- adaptar cada una de las 24 pruebas que montan scopes.

Eso es reescribir toda la presentación, no sólo cambiar la técnica de inyección.

**Alternativa:**

- ViewModels con `ChangeNotifier`, estado inmutable y `Command`, que es el patrón del caso de estudio oficial.
- Inyección de dependencias con `provider` 6.1.5+1, que se corresponde casi uno a uno con los scopes actuales (`StoreScope.of` pasa a ser `context.watch` o `context.select`).
- Reconsiderar Riverpod sólo si el piloto registra alguno de estos problemas:
  - ciclos de vida por parámetro (family o autoDispose) que no se resuelvan con dependencias por ruta;
  - bugs causados por dispose olvidados.

**Prueba:** el piloto de catálogo y ficha, con esos criterios escritos antes de empezar.

#### R06 · ADR-03, §7.2 · Media — Sin enlaces externos, el contrato público de URLs es prematuro

**Entradas externas reales**

- [Hecho] `ios/Runner/Runner.entitlements` sólo declara `aps-environment`; no hay associated domains.
- [Hecho] `AndroidManifest.xml` no tiene intent-filters `VIEW` para http/https.
- [Hecho] El único esquema registrado es el callback de OAuth `shop.<id>.oauth` (`build.gradle.kts:51-62` y `CFBundleURLSchemes` en `Info.plist`).
- Por lo tanto, lo único que entra desde fuera son los payloads de notificación (`NotificationRouteData{type, productKey, handle}`) y los resultados de OAuth y checkout.

**Cómo navega la app hoy**

- [Hecho] La navegación ya pasa por 15 helpers `open*` (`openProduct`, `openCollection`, `openBag`, `openAccount`, `openOrders`, `openOrderDetail`, `openSearch`, …).
- [Hecho] En 25 archivos hay 17 construcciones de `MaterialPageRoute` o `PageRouteBuilder` y 59 llamadas push/pop.

**Sobre go_router**

- [Hecho] La guía oficial lo recomienda (*Recommend*). La objeción no es a la librería, sino al momento y al contrato público de URLs.

**Costo:** definir `/productos/:handle` o `/pedidos/:orderId` como contrato público cuando nadie lo consume. Si después llegan universal links con otro diseño, habrá que mantener alias.

**Alternativa:**

- Ahora: un resolver tipado (`sealed class AppDestination`) que usen tanto las notificaciones como los helpers, con pantallas de «destino no disponible» y «artículo ya no disponible».
- Más adelante, si se adopta go_router: usar 18.x, que es compatible, y no 14.8.1. Hacerlo cuando los enlaces externos sean un requisito (E6).

**Prueba:** tests del resolver con:

- producto en caché;
- producto fuera de caché, con y sin conexión;
- `external:*`;
- tipo desconocido;
- JSON malformado;
- `productKey` que no es `String`. Hoy `notification_models.dart:104` hace `as String?` y lanzaría `TypeError`.

#### R07 · ADR-10, ADR-11, §10.3 · Media — Backend y espejo quedan fuera del alcance; el CI prueba el target histórico

- [Hecho] `docs/REALTIME_CATALOG_SETUP.md:3-5` dice: «Historical Firebase Functions plan. Staging currently uses the synchronous Vercel implementation in `api/`».
- [Hecho] H07 se queda corto. Las diferencias reales entre targets son:

| | Functions | Vercel |
|---|---|---|
| Credencial Admin | token estático | client credentials, con caché del token de 24 h |
| Timeout | 4 s | 2.75 s, dentro del presupuesto de 5 s de Shopify |
| Imágenes | 6 | 20 |

- [Hecho] `quality.yml:101-129` ejecuta las pruebas de `functions/`, pero para Vercel sólo `typecheck:api`. `npm run test:api` —el vitest de `server/catalog`, que cubre HMAC, payload, reconcile y firebaseAdmin— no corre ni en CI ni en `make test-services` (`Makefile:30-35`).
- [Hecho] El backend ya es hexagonal en parte (`engagement/{api,application,domain,infrastructure}`). La concentración está en `admin/routes.ts` (1 935 líneas) y `api/server.ts` (952).

**Alternativa:**

- No crear un paquete compartido.
- Añadir `test:api` al CI de inmediato.
- Retirar `functions/` del árbol y del CI en cuanto se confirme que ninguna suscripción de Shopify ni ningún despliegue lo usan.
- Tratar el refactor del backend como un proyecto propio. Para esta reconstrucción, la app sólo necesita cambios aditivos de contrato: 404 en JSON, capacidades e ID de pedido (R11, R12).

**Prueba:** listar `webhookSubscriptions` en la Admin API y ejecutar `firebase functions:list` sobre el proyecto.

#### R08 · ADR-06 · Media — Los dos modos de autoridad tienen contratos de datos distintos

**Completitud de los datos**

- [Hecho] Storefront pide `images(first: 6)`, `variants(first: 50)` y `collections(first: 25)`, con `pageInfo` y continuación anidada (`queries.dart:27-47`, `catalog_sync.dart:235-274`).
- [Hecho] El espejo de Vercel pide `images(first: 20)`, `collections(first: 10)` y `variants(first: 20)` sin `pageInfo` (`server/catalog/shopifyAdmin.ts:18-32`). Si hay más, trunca en silencio.

**Precios**

- [Hecho] `server/catalog/catalog.ts:22`, idéntico en ambos targets: `price: finiteMoney(variant.price) ?? 0`. Un precio inválido o ausente se publica como 0, y además se convierte a float.

**Catálogo vacío**

- [Hecho] Las políticas son opuestas:
  - El full sync de Storefront aplica un vacío «legítimo» de forma atómica (`catalog_repository.dart:203-228`).
  - El snapshot vacío de Firestore se ignora (`realtime_catalog_repository.dart:60-66,105`).

**Un segundo escritor**

- [Hecho] `CatalogStore.upsertShopifyProducts` (`catalog_store.dart:329-336`) escribe en la caché sin pasar por `CatalogWriteCoordinator`. Lo llama `FeaturedCatalogController` después de leer de Storefront.

**Modo usado por entorno**

- [Hecho] El ejemplo de configuración de producción usa `FIRESTORE_CATALOG_ENABLED=false`. El espejo documentado es de staging.

**Escenario de fallo:** en modo espejo, un producto con 21 variantes pierde la vigesimoprimera. Si esa variante está en la bolsa, la lista la oculta (`catalog_store.dart:151-161`), pero el contador la sigue sumando (`163-164`).

**Alternativa:**

- El producto v1 usa sólo `storefrontDirect`, que ya es el modo del ejemplo de producción.
- El espejo se congela como experimental y queda fuera del refactor.
- Si se decide conservarlo, necesita: `pageInfo` anidado, rechazo de precios inválidos, una sola política de catálogo vacío y que el upsert de destacados pase por el coordinador.

**Prueba:** pasar el mismo fixture (25 variantes, 12 colecciones, precio `"abc"`) por ambos mappers y comparar el resultado.

### B2. Defectos e invariantes vigentes que la propuesta no registra

Ninguno de estos puntos necesita la reconstrucción: todos se corrigen in situ. Conviene hacerlo antes de cualquier refactor, porque definen el comportamiento que se quiere conservar.

#### R09 · §7.3 · Alta — La ficha falla si su producto desaparece

- [Hecho] `product_screen.dart:165` hace `store.products.firstWhere((p) => p.id == widget.productId)` sin `orElse`.
- [Hecho] La ficha depende de `StoreScope`, así que se reconstruye en cada `notifyListeners`.
- [Hecho] Hay dos caminos que reemplazan el catálogo completo: el full sync, que lo hace de forma atómica (`catalog_repository.dart:227`), y cada snapshot de Firestore (`catalog_store.dart:372`).

**Escenario de fallo:** la persona propietaria despublica una pieza mientras alguien tiene su ficha abierta. `build` lanza `StateError: No element` y en release se ve una pantalla gris. Ninguna prueba cubre este caso.

- [Hecho] Defecto relacionado en `main.dart:788-812`: si una notificación apunta a un producto que no está en caché, la app vuelve al inicio en silencio, sin intentar resolverlo en remoto.

**Alternativa:**

- En la ficha: un estado «Este artículo ya no está disponible».
- En el resolver de notificaciones: buscar el producto en remoto cuando no está en caché.

**Prueba:** un widget test que abre la ficha, emite un catálogo sin ese producto y espera el estado de ausencia sin excepciones.

#### R10 · §12 · Alta — Un cambio en el dominio de la tienda borra todos los datos de la persona usuaria

- [Hecho] `catalog_repository.dart:283-311` compara el `shopDomain` configurado con el que quedó guardado. Si no coinciden, `resetShopState` (`catalog_cache_store.dart:100-128`) borra:
  - catálogo y colecciones;
  - cursores de sincronización;
  - bolsa y favoritos;
  - eventos de recomendación;
  - sesiones, pedidos y cuentas.
- [Hecho] `pr7_migration_test.dart:110-111` exige ese vaciado.
- [Hecho] El dominio sale de `StorefrontConfig.shopDomain.trim()`, sin normalizar mayúsculas (`main.dart:497-499`).
- [Hecho] Hoy conviven dos formas del dominio: staging usa `monetta.mx` y el espejo usa `fakcei-n9.myshopify.com`.

**Escenario de fallo:** la composición nueva normaliza el dominio de otra forma, por ejemplo a `*.myshopify.com`. La primera apertura después de actualizar borra todo y cierra la sesión.

**Alternativa:** tratar el `ShopScope` como invariante de compatibilidad, con normalización explícita, alias conocidos y una prueba que lo proteja.

**Prueba:** un fixture de DB v7 con `monetta.mx` que abre la composición nueva sin perder datos.

#### R11 · ADR-12, WIP · Alta para el WIP — Con Rewards apagado, la app pide revisar la conexión

**El WIP no enciende Rewards en staging**

- [Hecho] El WIP cambia el valor por defecto a `rewardsEnabled: false` (`rewardsConfig.ts:29`).
- [Hecho] Para compensar, añade `REWARDS_ENABLED = "true"` al final de `fly.toml`, pero después de `[[http_service.checks]]` (`fly.toml:60-69`). En TOML, una clave pertenece a la última tabla declarada, así que queda dentro de `http_service.checks[0]` y no en `[env]`. Confirmarlo con `fly config show` o `fly config validate`.

**Qué ve la persona usuaria cuando Rewards está apagado**

1. Sin Rewards, las rutas no se montan (`server.ts:538-543,886`).
2. Express no tiene un catch-all en JSON (`server.ts:777-787`), así que responde un 404 en HTML.
3. `RewardsApi._throwFor` ignora el status y convierte ese 404 en `internal_error` (`rewards_api.dart:35-45`).
4. La UI muestra «No pudimos consultar tu saldo — Revisa tu conexión e inténtalo de nuevo» (`rewards_section.dart:455-500`).

**Escenario de fallo:** se despliega el WIP. Rewards queda apagado en staging, al revés de lo que dice el comentario, y cada sesión ve un error de conexión que no existe.

**Alternativa:**

- En `fly.toml`: mover la clave a `[env]`.
- En el servidor: un 404 en JSON (`{error:"not_found", requestId}`) y una capacidad explícita (`program.enabled=false`).
- En el cliente: mapear el 404 o `feature_disabled` al estado «no disponible».

**Prueba:**

- Una prueba de `accounts_orders` sin la variable debe recibir una respuesta en JSON.
- Un widget test que reciba esa respuesta debe mostrar el estado «no disponible».

#### R12 · ADR-04 · Media — El contrato del ID de pedido está roto entre la app y Rewards

- [Hecho] La app canonicaliza `shopifyOrderId` a `gid://shopify/Order/<n>` (`order_history_repository.dart:200-221`).
- [Hecho] `rewards_api.dart:78-80` interpola ese valor sin codificar en `/customers/me/orders/$id/rewards`.
- [Hecho] El backend define la ruta `orders/:id/rewards` (`rewards/routes.ts:69`) y guarda el ID numérico (`webhookBridge.ts:61`). Su propio test usa `/orders/8001/rewards`.

**Efecto:**

1. El GID contiene `/`, así que la URL no coincide con la ruta.
2. Express responde un 404 en HTML.
3. `_safeLoad` se traga el error (`rewards_section.dart:800-809`).
4. El estado de Rewards por pedido nunca se muestra.

Aunque se codificara la URL, el GID tampoco coincidiría con el ID numérico guardado.

**Alternativa:** fijar un solo formato de ID de pedido en el contrato —recomiendo el GID, normalizado en el servidor— y construir las URLs con `Uri(pathSegments: …)`.

**Prueba:** un test de contrato que use el mismo fixture en el cliente y en el servidor.

#### R13 · ADR-12, ADR-09 · Alta — El arranque espera llamadas de red opcionales que no tienen timeout

- [Hecho] `main.dart:772` hace `await _notifications!.restore()` antes de montar el Navigator.
- [Hecho] Ese `restore()` espera `fetchConfig()` (`notification_controller.dart:96`). Si ya hay credencial, también espera el registro y la sincronización.
- [Hecho] Todas esas llamadas pasan por `NotificationApiClient._send`, que no tiene `.timeout` (`notification_api_client.dart:191-196`).
- [Hecho] No es un caso aislado. Siete clientes HTTP carecen de timeout:
  - notificaciones;
  - notificaciones de admin;
  - admin;
  - historial de pedidos;
  - cuenta propia;
  - Rewards;
  - Loox.

  Sólo los clientes de Storefront y Customer Account lo tienen.

**Escenario de fallo** (en builds con notificaciones configuradas): con una red móvil inestable, o con el backend de notificaciones aceptando la conexión sin responder, la app se queda en blanco hasta que vence el timeout del sistema operativo. La propuesta pide lo contrario: que una caída de notificaciones no bloquee el catálogo.

**Alternativa:**

- Sacar `restore()` del camino crítico del arranque.
- Crear un transporte común con timeout; ese es el núcleo de ADR-09.

**Prueba:** levantar `MonettaApp` con un cliente fake que nunca responde y comprobar que el inicio se pinta igual.

#### R14 · ADR-05, H10 · Media — En dinero, el riesgo real es el `double` de `Product` y de la caché

**Dónde hay `double`**

- [Hecho] `Product` y `ProductVariant` usan `double price` (`domain/product.dart:67-112`).
- [Hecho] `CachedVariants.price` y `OrderSummaries.totalAmount` son columnas `REAL` (`tables.dart:53-54,238`).
- [Hecho] `bagSubtotal` es `double` (`catalog_store.dart:166-167`).
- [Hecho] El espejo envía floats y usa `?? 0` (R08).

**Lo que ya está bien**

- [Hecho] `CartMoney` guarda las cadenas decimales de Shopify (`domain/cart.dart:1-12`).
- [Hecho] Rewards usa centavos enteros.

**Costo de migrar:** [Inferencia] las columnas `REAL` pertenecen a cachés reconstruibles. Pasarlas a centavos con un esquema v8 es de bajo riesgo: basta con reconvertir o con vaciar y volver a sincronizar, sin la ceremonia de §12.

**Alternativa:**

- `Money(minorUnits, currency)` para precios de catálogo y estimados de bolsa.
- Los totales confirmados siguen siendo los que devuelve Shopify.
- Un solo formateador de dinero. Hoy `theme.dart` importa `Money` desde `catalog_item.dart`, el modelo retirado.

**Prueba:** fixtures `"1299.00"`, `"0.10"`, `"999999.99"`, `compareAt` nulo y precio ausente. El precio ausente debe rechazarse; nunca convertirse en 0.

#### R15 · H11 · Media — Los parsers de Rewards tienen más fallas de las descritas

- [Hecho] Cuatro fechas usan `DateTime.tryParse(...) ?? DateTime.now()`: `asOf`, `nextExpiry.at`, `createdAt` y `expiresAt` (`rewards_models.dart:47,49,105,139`).
- [Hecho] `quoteId: '${json['quoteId']}'` produce la cadena `"null"` cuando el campo falta (`:131`). `orderShopifyId` tiene el mismo problema (`:162`).
- [Hecho] Las cantidades ausentes se convierten en 0.

**Escenario de fallo:**

- Un `asOf` inválido hace pasar por fresco un saldo viejo.
- Un quote sin ID manda `"null"` al canje. El servidor lo rechazaría, pero la UI no sabría explicar por qué.

**Alternativa:** DTO estrictos que fallen con un error de contrato. El `idempotencyKey` del canje ya está bien resuelto.

**Prueba:** tests de parseo con campos ausentes o inválidos que esperen una excepción tipada.

#### R16 · ADR-07 · Baja-media — La regla vigente de fusión invitado→cuenta es «sobrescribir»

- [Hecho] `bag_store.dart:119-141` usa `insertOnConflictUpdate` sobre la clave primaria `(variantId, accountId)` (`tables.dart:142-150`). En la práctica, la cantidad del invitado reemplaza la de la cuenta.
- [Hecho] La lectura de filas ocurre fuera de la transacción (`:120-122`).
- [Hecho] La fusión no aplica el tope de 10 que sí aplica `updateBagQuantity` (`catalog_store.dart:541`).
- ADR-07 propone sumar. Eso cambia el comportamiento, así que es una decisión de producto (E4).
- [Hecho] Además, el contador de la bolsa suma líneas que la lista oculta (ver R08).

**Prueba:** una cuenta con V×2 y un invitado con V×1 deben dar el resultado que se decida en E4, respetando el tope.

#### R17 · §3.4, H01 · Baja — La tabla de separación de `CatalogStore` necesita precisión

- [Hecho] Parte de lo que la tabla asigna a `CatalogStore` ya vive fuera:
  - El carrito Shopify y su reconciliación: `data/shopify/cart/cart_repository.dart`, `app/cart_controller.dart` y `app/shopify_checkout_coordinator.dart`.
  - La sesión: `CustomerSessionRepository`, `SystemAccountSessionRepository` y `AccountController`.
- [Hecho] Y hay responsabilidades que la tabla no menciona:
  - `CatalogStore` cierra la DB compartida (`catalog_store.dart:733-737`), aunque la crea `main.dart` y la usan otros stores.
  - Su guard contra hidratación tardía (`catalog_store.dart:262`) tiene que repetirse en cada repositorio con alcance.
  - El cambio de cuenta lo orquesta hoy un callback en `main.dart:697-703`, que actualiza el alcance del catálogo, el historial de búsqueda y la invalidación del checkout.

**Alternativa:**

- Un `ShopperScope` (tienda + cuenta) que consuman todos los repositorios con alcance.
- Un caso de uso `ChangeAccountScope`.
- Que la composición sea la dueña del cierre de la DB.

#### R18 · §6.2, H03 · Media — Los scopes dependen de la posición en el árbol, y la UI usa filas de Drift

- [Hecho] Seis scopes sólo existen bajo `home:` (`main.dart:890-924`): Editorial, HomeContent, FeaturedCatalog, Admin, AdminNotification y Onboarding.
- [Hecho] Las rutas empujadas no los ven. Por eso `HomeScreen` (1 478 líneas) los lee y pasa los controladores por constructor.
- [Hecho] Quince archivos de `features/` importan `main.dart`.
- [Hecho] `features/orders/*` y `account_screen.dart` usan directamente la fila generada por Drift (`database.dart show OrderSummary`).

**Alternativa:**

- Un contenedor de dependencias montado sobre el Navigator.
- Modelos de dominio propios para los pedidos.
- Pruebas de arquitectura que exijan ambas cosas.

#### R19 · §7.5 · Baja — Priorizar la 404 por superficie

- [Hecho] El `vercel.json` raíz reescribe a `/` todo lo que no es `/api` (`vercel.json:15`).
- [Hecho] Ese mismo archivo despliega el webhook y el cron del espejo de staging (`VERCEL_CATALOG_WEBHOOK_SETUP.md:95-99`). Cambiar los rewrites de la galería toca también el proyecto del webhook.
- [Hecho] `dashboard/vercel.json:5` también reescribe todo, y el dashboard está retirado.

**Prioridades:**

- P1: el 404 en JSON de `accounts_orders`. Es barato y además resuelve R11.
- P2: la galería, probando también que `/api` siga respondiendo bien.
- Nada en el dashboard: se despublica junto con el retiro.

#### R20 · ADR-14 · Baja — El ranking se recalcula en `build`

- [Hecho] `HomeScreen.build` llama a `store.feed()` (`home_screen.dart:316`).
- [Hecho] Cada `record()` notifica a todo el árbol (`catalog_store.dart:438-452,619-629`), incluido el inicio que queda debajo de la ruta activa.

Con unos 140–270 productos el costo es bajo, pero conviene medirlo antes de que el catálogo crezca.

### B3. Verificación de H01–H15

| ID | Resultado | Nota |
|---|---|---|
| H01 | Confirmado, con precisiones | Ver R17 |
| H02 | Confirmado | Además, `_ErrorScreen` muestra `${snapshot.error}` crudo (`main.dart:866-868`) |
| H03 | Confirmado | 15 archivos importan `main.dart` y 21 importan `data/`. Algunos imports de `data/` son legítimos porque traen helpers puros (`media_url`, `normalize/facets`) |
| H04 | Confirmado y ampliado | Regla oculta: un producto sin `collectionHandles` pasa el filtro de cualquier colección (`collection_screen.dart:218-221`). Los productos del asset nunca tienen esos handles |
| H05 | Confirmado y ampliado | No tiene timeout, y el widget lee la configuración del entorno directamente (`rewards_section.dart:113,188`) |
| H06 | Confirmado | Cuatro archivos idénticos |
| H07 | Confirmado, pero subestimado | También difieren el token (estático frente a client credentials) y el timeout (4 s frente a 2.75 s); ver R07 |
| H08 | Confirmado | Unas 70 líneas idénticas (`customer_identity.dart:138`, `customer_orders.dart:187`) |
| H09 | Confirmado | Los dos widgets son idénticos |
| H10 | Confirmado; la evidencia debe corregirse | E17 apunta a `CatalogItem`, el modelo mixto retirado. El riesgo vigente es el `double` de `Product` (R14) |
| H11 | Confirmado y ampliado | Ver R15 |
| H12 | Confirmado | Además, `dashboard/vercel.json` reescribe todas las rutas |
| H13 | Confirmado | Ver R09 y R06 |
| H14 | Confirmado, con una excepción | El upsert de destacados no pasa por el coordinador (R08) |
| H15 | Confirmado y ampliado | `make schema` (`Makefile:21-22`) llama a `scripts/fetch_schema.sh`, que no existe, y `make gen` menciona ferry, freezed y riverpod |

## C) ADR: conservar, modificar o rechazar

| ADR | Veredicto | Cambio | Base |
|---|---|---|---|
| 01 Reconstrucción aislada | **Rechazar** (adoptar su alternativa) | Refactor in situ por estrangulamiento, con tag de baseline como referencia y sin segunda app | R01 |
| 02 Riverpod | **Modificar** | `ChangeNotifier` + `Command` + `provider` 6.1.5+1. Riverpod sólo si se cumplen los criterios del piloto. Retirar las dependencias sin uso | R04, R05 |
| 03 go_router | **Modificar** (posponer) | Ahora: resolver tipado `AppDestination` y pantallas de ausencia. go_router 18.x cuando haya enlaces externos. Sin contrato público de URLs | R06, R09 |
| 04 DTO / dominio | **Conservar**, con límites | DTO estrictos sólo para los contratos JSON propios. Los mappers de Storefront se mantienen. IDs tipados para pedidos (GID, legacy y número visible). La UI deja de usar filas de Drift | R12, R15, R18 |
| 05 Dinero exacto | **Conservar**, con la evidencia corregida | `Money` en unidades menores para catálogo, caché y bolsa. `CartMoney` intacto. Migración simple de las cachés. Quitar el `?? 0` del espejo | R14 |
| 06 Autoridad configurable | **Modificar** | Un solo modo de producto (`storefrontDirect`). Espejo experimental, fuera del alcance. Una sola política para el catálogo vacío. Upsert a través del coordinador | R08 |
| 07 Persistencia y operaciones optimistas | **Conservar** | Documentar los invariantes vigentes: fusión que sobrescribe, reset por tienda, guard contra respuestas tardías. Cambiarlos sólo por la decisión E4 | R10, R16 |
| 08 Identidades | **Conservar** | Añadir la decisión E5 sobre la cuenta propia | E5 |
| 09 Transporte y errores | **Conservar y adelantar** | Primero, timeouts y transporte común: hoy 7 clientes HTTP no tienen timeout. Una sola convención: excepciones tipadas en los límites, que es el estilo vigente, sin un `Result` paralelo | R13 |
| 10 Núcleo común del espejo | **Rechazar** | Sin paquete compartido. Retirar Functions cuando se confirme que no se usa. `test:api` en CI de inmediato | R07 |
| 11 Backend modular | **Modificar** (sacar del alcance) | Proyecto propio. La app sólo necesita cambios aditivos de contrato | R07, R11, R12 |
| 12 Configuración y capacidades | **Conservar y priorizar** | Notificaciones fuera del arranque. Capacidad de Rewards explícita. Ninguna excepción cruda en pantalla | R11, R13 |
| 13 Codegen selectivo | **Conservar**, con restricción | Sólo `drift_dev`. Freezed 4 exige Dart ≥3.13. `riverpod_generator` 4.0.9 no convive con freezed 3.x ni con `custom_lint` 0.8.1 | R04 |
| 14 Calidad y rendimiento | **Conservar** | Medir `feed()` dentro de `build` y la notificación global por cada evento | R20 |

## D) Arquitectura y fases corregidas

### D1. Arquitectura

Se mantiene el destino de §3, con estos ajustes:

1. **Sin una carpeta `infrastructure/` aparte.** Los SDK y los canales nativos son *services* de `data/`, como en la guía oficial. `lib/platform/` (dos archivos) puede quedarse donde está.
2. **Interfaces sólo donde haya dos o más implementaciones o haga falta un fake.** Hoy eso aplica a:
   - la fuente de catálogo;
   - el lanzador de checkout;
   - el gateway de notificaciones;
   - las fuentes remotas de sesión y de pedidos.
3. **Casos de uso sólo para cuatro operaciones:**
   - `CompleteCheckout`: compra → bolsa → invalidación → pedidos.
   - `ChangeAccountScope`: login, logout, cambio de cuenta y fusión del invitado.
   - `ResetShop`: el reset por tienda de R10.
   - `RedeemRewards`: quote → canje → código → liberación, cuando se active el canje.

   Todo lo demás va directo del ViewModel al repositorio.
4. **Value Objects sólo donde dan una garantía real:** `Money`, `ShopperScope`, `OrderId` (GID, legacy y número visible) y los GID de producto y variante. No hace falta envolver cada `String`.

```text
lib/
  main.dart                      # sólo bootstrap()
  app/
    bootstrap.dart               # configuración → capacidades → composición → runApp
    composition/                 # AppDependencies: construcción, alcance y cierre (DB, clientes HTTP)
    destinations/                # AppDestination, resolver de notificaciones, 404 / no disponible
    config/                      # RuntimeConfig, StorefrontConfig… (ya existen; se agrupan)
  domain/                        # entidades, VOs e interfaces justificadas
  data/
    services/                    # Storefront, Customer Account, accounts_orders, FCM, canal de checkout
    repositories/                # catálogo, bolsa, favoritos, interacciones, sesión, pedidos, Rewards
    local/  normalize/           # misma forma que hoy
  reco/                          # puro, sin cambios
  features/<feature>/            # <feature>_screen.dart + <feature>_view_model.dart (ChangeNotifier + Command)
```

### D2. Fases

Todas las fases son in situ. Cada PR deja la suite verde y la app liberable.

| Fase | Prioridad | Trabajo | Criterio de salida |
|---|---|---|---|
| 0 | P0 | • Crear el tag `baseline/48a6786`.<br>• Corregir y cerrar el WIP de Rewards (R11).<br>• Ejecutar y registrar todas las suites: Flutter, `accounts_orders` con `REQUIRE_POSTGRES_TESTS=1`, `test:api` y `functions`.<br>• Inventariar despliegues vivos, configuración real de producción y cuentas propias reales.<br>• Tomar las decisiones E1–E3. | Documento de baseline con el resultado de cada suite y las decisiones por escrito. |
| 1 | P0 | • Correcciones de contrato: R09, R11, R12, R13 y R15.<br>• Añadir `test:api` al CI.<br>• Hacer las extracciones D02 y D03 de la propuesta.<br>• Tests de caracterización: R10 (DB v7), R16, catálogo vacío, regla de colección (H04) y notificación fuera de caché. | Sólo cambian los comportamientos listados, y las pruebas nuevas pasan. |
| 2 | P0 | • Eliminar el código retirado (R02).<br>• Retirar las dependencias sin uso (R04).<br>• Corregir `README` y `ARCHITECTURE`. | `pub get` reproducible en 3.44.8, `database.g.dart` idéntico y documentación fiel al código. |
| — | — | **Punto de lanzamiento posible** (E1). | Criterios de lanzamiento de la auditoría. |
| 3 | P0 | • Composición montada sobre el Navigator (R18).<br>• `AppDestination` con pantallas de ausencia (R06, R09).<br>• `ShopperScope`.<br>• Pruebas de arquitectura nuevas en modo trinquete: el número de violaciones sólo puede bajar. | Ningún archivo de `features/` importa `main.dart`, y las 24 pruebas con scopes quedan adaptadas mediante un helper. |
| 4 | P0 | Piloto vertical de catálogo, colección, búsqueda y ficha:<br>• funciones puras de consulta que no dependan de `CatalogStore` (H04);<br>• ViewModels;<br>• upsert a través del coordinador (R08). | Criterios de R05 evaluados, reconstrucciones medidas y pruebas adaptadas en vez de reescritas. |
| 5 | P0 | • Separar `CatalogStore` en bolsa, favoritos, interacciones y recomendaciones, detrás de una fachada temporal.<br>• `CompleteCheckout`.<br>• Mover el cierre de la DB a la composición.<br>• ViewModel del checkout (hoy 1 955 líneas). | Las pruebas de PR7 conservan su intención y el checkout se verifica en dispositivo. |
| 6 | P1 | • Cuenta y pedidos, Rewards, notificaciones, admin, onboarding, editorial y las funciones que decida E9.<br>• `Money` con esquema v8 (R14). | Matriz §9 completa, con una columna de verificación. |
| 7 | P1 (pista aparte) | Backend:<br>• 404 en JSON y capacidades, si no se hicieron en la fase 1;<br>• dividir `admin/routes.ts`;<br>• decidir el espejo (E3);<br>• retirar Functions. | Los contratos que usa la app siguen intactos. |
| 8 | P2 | • 404 de la galería, cuidando el `vercel.json` compartido.<br>• Retiro operativo del monitor y del dashboard, con autorización. | Proyecto aparte. |

La fase 8 de la propuesta (ensayo de actualización) se convierte en un control continuo:

1. Hacer ahora un `drift_dev schema dump` de v7.
2. Hacer un dump por cada versión futura.
3. Probar la migración desde cada versión publicada.

Las versiones v1–v6 sólo importan si existen instalaciones reales (E1).

## E) Decisiones de producto pendientes

1. **Secuencia.** ¿Lanzar con la arquitectura actual tras las fases 1–2 y refactorizar sobre el producto ya vivo? Recomendación: sí.
2. **Código retirado.** ¿Autorizar el PR que elimina del árbol el código del catálogo externo (app, pruebas y admin del backend), dejando un tag forense? Es independiente del retiro de infraestructura. Recomendación: sí.
3. **Autoridad del catálogo en producción.** ¿Sólo `storefrontDirect`? ¿Hay una necesidad operativa medida que justifique el espejo, como la latencia de los webhooks frente al delta al abrir la app?
4. **Fusión invitado→cuenta.**
   - ¿Preservar «sobrescribir», que es lo vigente, o pasar a «sumar con tope de 10»?
   - ¿El contador de la bolsa debe contar líneas ocultas, o la bolsa debe mostrar «artículo ya no disponible»?
5. **Cuenta propia Monetta.**
   - ¿Se mantiene, se congela sin registro (`LEGACY_ACCOUNT_REGISTRATION_ENABLED=false`) o se migra? Primero falta inventariar las cuentas reales.
   - Si el registro sigue abierto, verificar que exista la eliminación de cuenta desde la app, que App Store exige. No la encontré en `lib/`.
6. **Enlaces externos.** ¿Hay universal links o App Links en el roadmap? La respuesta define si hoy conviene adoptar go_router y un contrato de URLs.
7. **Rewards en el lanzamiento.** Si sale apagado, ¿se oculta la sección o se muestra «próximamente»? En ningún caso debe verse un error.
8. **Atribución.** ¿El acuerdo de revenue share requiere `_rec_source` y `_campaign`? Hoy se envía siempre `direct`.
9. **Funciones de nicho.** ¿Cuáles entran en v1? Partner hub, mayoreo, creador de catálogo, contacto, experiencias de clientes y panel de la persona propietaria.
10. **Catálogo vacío.** ¿Una sola política para ambos modos? Recomendación: no aplicar un full sync vacío sin una segunda confirmación, y mostrar «catálogo no disponible».
11. **Dominio canónico de la tienda.** ¿`monetta.mx` o `*.myshopify.com`, y con qué normalización? (Ver R10.)
12. **Galería web.** ¿Es pública o privada? Si es pública, ¿conviene separarla del proyecto que aloja el webhook de staging?

## F) Checklist mínimo para iniciar la implementación

**Baseline**

- [ ] Tag de baseline creado.
- [ ] WIP de Rewards integrado o separado, con `fly.toml` corregido.
- [ ] Resultado registrado de cada suite: `flutter analyze`, `flutter test`, `accounts_orders` con Postgres, `npm run test:api` y `functions`.
- [ ] El CI ejecuta `npm run test:api`.

**Decisiones y dependencias**

- [ ] Decisiones E1, E2, E3 y E5 tomadas por escrito.
- [ ] Dependencias sin uso retiradas o justificadas, y `flutter pub get` reproducible en 3.44.8.

**Pruebas**

- [ ] Prueba de compatibilidad de datos: DB v7, claves de almacenamiento seguro y dominio de tienda, sin pérdida (R10).
- [ ] Tests de caracterización para las reglas que hoy nadie cubre:
  - producto que desaparece con la ficha abierta;
  - fusión invitado→cuenta;
  - contador de bolsa frente a líneas visibles;
  - catálogo vacío;
  - filtro de colección;
  - notificación fuera de caché;
  - Rewards apagado.
- [ ] Pruebas de arquitectura nuevas en modo trinquete:
  - ningún archivo de `features/` importa `main.dart`;
  - ningún archivo de `features/` importa implementaciones de `data/`, salvo una lista explícita de excepciones.

**Contratos y matriz**

- [ ] Matriz §9 con las filas de R03 y una columna de estado: «existe código», «tiene test automático» o «verificado en dispositivo».
- [ ] Contratos definidos para el ID de pedido, el 404 en JSON y las capacidades.

## Anexo. Respuestas a §15.1

| # | Pregunta | Respuesta |
|---|---|---|
| 1 | ¿Reconstrucción aislada o refactor incremental? | Refactor incremental in situ (R01). |
| 2 | ¿Riverpod o ChangeNotifier con inyección de dependencias? | `ChangeNotifier` + `Command` + `provider`. Riverpod sólo si el piloto cumple los criterios de R05. |
| 3 | ¿Separar `data/` e `infrastructure/`? | No. Los SDK y los canales nativos son services de `data/` (D1). |
| 4 | ¿Los repositorios tienen la responsabilidad y el alcance correctos? | Sí, siempre que compartan un `ShopperScope`, repitan el guard contra respuestas tardías y haya una sola caché por dominio (R17, R08). |
| 5 | ¿Qué operaciones necesitan casos de uso? | Sólo las cuatro de D1. El resto va directo del ViewModel al repositorio. |
| 6 | ¿Qué autoridad de catálogo por entorno y cómo probar el fallback? | `storefrontDirect` para el producto, el espejo como experimental y una sola política de catálogo vacío (R08, E3). |
| 7 | ¿Qué interfaces, DTO y Value Objects aportan garantías reales? | `Money`, `ShopperScope`, `OrderId` y los DTO de los contratos propios. No hacen falta DTO extra para Storefront (D1, R12). |
| 8 | ¿Qué duplicación extraer? | D02 y D03, ya. D01 se resuelve retirando Functions. Storefront y Admin son contratos distintos y no deben unificarse (R07). |
| 9 | ¿La 404 queda bien definida en cada superficie? | App: resolver y estados de ausencia (R06, R09). API: 404 en JSON (R11). Galería: P2, cuidando el `vercel.json` compartido. Dashboard: nada (R19). |
| 10 | ¿Qué falta para garantizar equivalencia, migración y recuperación? | Confirmar el estado de lanzamiento y si hay instalaciones reales; los despliegues vivos; la configuración de producción; las cuentas propias reales, y ejecutar las suites. Todo eso es la fase 0. |
