# Matriz de pruebas del refactor in situ

El orquestador la sigue y la actualiza; los subagentes no editan este archivo.

**Reglas generales**

- **Evidencia.** Cuenta sólo la salida de un comando que el **auditor** ejecutó en su propia sesión. Un reporte de subagente no es evidencia.
  - **Excepción de G6.** El sandbox no puede compilar Android ni iOS (bitácora de RF-00). La persona ejecuta los comandos de G6 en su terminal y pega la salida. La bitácora lo registra como «ejecutado por la persona», con las líneas finales, y el auditor revisa los cambios que el build deje en el árbol.
- **Gates no ejecutados.** Un gate que no se ejecutó nunca cuenta como aprobado. Si el sandbox o el entorno lo impiden, márcalo «no ejecutado» y detente.
- **Conteo de pruebas.**
  - RF-00 registra el conteo base de cada suite.
  - Después de cada WP, el conteo debe ser igual o mayor.
  - La única excepción es un borrado deliberado de pruebas (por ejemplo, RF-20), registrado en la bitácora con su delta.
- **Pruebas rojas.**
  - Sólo existen dentro del árbol de trabajo de un WP en curso.
  - Nunca se hace commit de una prueba roja ni se usa `skip:`.
  - El WP no se cierra hasta que todas pasan a verde.
- **Goldens.** Se generan en macOS con las fuentes reales cargadas. Un golden cambiado requiere aprobación de la persona, registrada en la bitácora.

## 1. Gates

| Gate | Qué verifica | Comando | Cuándo | Criterio de aprobación |
|---|---|---|---|---|
| G0 | Diff limpio y dentro del alcance | `git status --porcelain` · `git diff --stat` · `git diff --check` | Todo WP | Sólo archivos del alcance; sin espacios ni marcas de conflicto; sin secretos |
| G1 | Formato | `dart format --output=none --set-exit-if-changed lib test integration_test` | WP con Dart | exit 0 |
| G2 | Análisis estático | `flutter analyze --no-pub` | WP con Dart | 0 issues |
| G3 | Pruebas del WP | `flutter test --no-pub <rutas>` o vitest/node de los archivos del WP | Cada iteración | Todas pasan; cada ID asignado aparece en el código (`grep -rn "ID " test services server`) |
| G4 | Suite completa del área | `flutter test --no-pub` · `npm --prefix services/accounts_orders test && … run typecheck && … run build` · `npm run test:api && npm run typecheck:api` | Cierre del WP | 0 fallos; conteo ≥ base |
| G5 | Catálogo y secretos | `dart run bin/verify_catalog_snapshot.dart` · `./bin/check_no_secrets.sh` | Cierre del WP | exit 0 |
| G6 | Compilación nativa | Android: `flutter build apk --no-pub --debug --flavor staging --dart-define-from-file=config/dart_defines.ci.json` · iOS: `flutter build ios --no-pub --simulator --debug --dart-define-from-file=config/dart_defines.ci.json` | WP que toca nativo, `pubspec`, assets o fuentes, plugins o composición de arranque | Ambos compilan |
| G7 | Postgres | `REQUIRE_POSTGRES_TESTS=1 WP01_PG_ADMIN_URL=postgres://postgres:postgres@localhost:5432/postgres npm --prefix services/accounts_orders test` | WP que toca SQL, ledger, webhooks o outbox | 0 fallos y 0 omitidas |
| G8 | Verificación en dispositivo | Checklist DEV-xx (sección 5), en los simuladores de la Mac (D-05) | WP que toca OAuth, checkout, push, almacenamiento seguro o tipografía | La persona confirma; su nota o captura queda en la bitácora |

En cada iteración del subagente bastan G0–G3. Para cerrar el WP se exigen G0–G5, más G6–G8 cuando apliquen.

## 2. Invariantes: pruebas existentes que deben seguir verdes

| ID | Invariante | Pruebas actuales | WP con riesgo |
|---|---|---|---|
| INV-01 | Compra tardía de la cuenta A con la cuenta B activa; recibo idempotente; rollback ante fallo | `test/app/pr7_checkout_scope_test.dart` | RF-50, RF-51, RF-52 |
| INV-02 | Bolsa y favoritos aislados por cuenta y tienda | `test/app/catalog_store_bag_scope_test.dart` · `test/data/local/stores_test.dart` | RF-30, RF-32, RF-50 |
| INV-03 | Migraciones v1→v7 y v5→v7; reset por tienda | `test/data/local/database_test.dart` · `test/data/local/pr7_migration_test.dart` | RF-60 y cualquier cambio de esquema |
| INV-04 | Sincronización completa o incompleta, paginación anidada, regresiones de PR7 | `test/shopify/catalog_sync_test.dart` · `test/shopify/pr7_catalog_regression_test.dart` · `test/data/repositories/catalog_repository_test.dart` | RF-40, RF-42, RF-50 |
| INV-05 | Autoridad Firestore frente a delta; snapshots válidos, vacíos e inválidos | `test/data/repositories/catalog_write_coordinator_test.dart` · `test/data/repositories/realtime_catalog_repository_test.dart` · `test/app/catalog_store_realtime_test.dart` | RF-42, RF-50 |
| INV-06 | Contratos del carrito, dinero en cadenas, descuentos, política de URL de checkout | `test/data/shopify/cart/cart_contracts_test.dart` · `cart_repository_test.dart` · `storefront_cart_api_test.dart` · `checkout_url_policy_test.dart` · `test/app/cart_controller_test.dart` · `test/app/cart_discount_controller_test.dart` | RF-52, RF-60 |
| INV-07 | Checkout nativo, coordinador e identidad del comprador | `test/platform/shopify_checkout_channel_test.dart` · `test/app/shopify_checkout_coordinator_test.dart` · `test/app/checkout_buyer_identity_test.dart` · `test/app/shopify_cart_composition_test.dart` | RF-30, RF-51, RF-52 |
| INV-08 | Sesión OAuth, refresh y merge local; cuenta propia | `test/data/customer_auth/customer_session_repository_test.dart` · `customer_identity_test.dart` · `customer_orders_test.dart` · `test/data/accounts_orders/system_account_session_repository_test.dart` · `test/app/account_controller_test.dart` | RF-18, RF-32, RF-62 |
| INV-09 | Historial de pedidos | `test/data/repositories/order_history_repository_test.dart` · `test/data/local/order_summary_store_test.dart` | RF-12, RF-61 |
| INV-10 | Atributos de atribución del carrito | `test/shopify/cart_attribution_test.dart` | RF-31, RF-52, RF-67 |
| INV-11 | Configuración de entorno; catálogo externo rechazado | `test/app/runtime_config_test.dart` · `test/shopify/storefront_config_test.dart` | RF-20, RF-30 |
| INV-12 | Pureza y fronteras de la arquitectura | `test/architecture_test.dart` | Todos |
| INV-13 | Notificaciones: controlador, bandeja y pantalla | `test/app/notification_controller_test.dart` · `test/features/notifications/` | RF-14, RF-31, RF-64 |
| INV-14 | Normalización y recomendación | `test/normalize/golden_catalog_test.dart` · `test/reco/scorer_test.dart` | RF-40, RF-50 |
| INV-15 | Backend: seguridad WP01, webhooks, ledger de Rewards, token de cliente | `services/accounts_orders/test/` (los `*.pg.test.ts` corren con G7) | RF-12, RF-13, RF-21, RF-70 |
| INV-16 | Espejo de catálogo: HMAC, payload, reconcile | `server/catalog/*.test.ts` (`npm run test:api`; en CI y en `make test-services` desde RF-10) | RF-23, RF-71 |

## 3. Filas nuevas

**Tipos:**
- **CAR** (caracterización): fija el comportamiento vigente y pasa hoy.
- **OBJ** (objetivo): roja hoy, verde al cerrar el WP.
- **TRQ** (trinquete): falla si aumentan las violaciones conocidas.

**Estado inicial:** todas las filas están `pendiente`.

| ID | Tipo | Qué demuestra | WP | Evidencia de origen |
|---|---|---|---|---|
| CHAR-01 | OBJ | La ficha abierta, cuando su producto sale del catálogo, muestra «Este artículo ya no está disponible» sin excepción | RF-11 | `product_screen.dart:165` (R09) |
| CHAR-02 | OBJ | Notificación de un producto fuera de caché: con conexión, se resuelve en remoto y abre la ficha; sin conexión, muestra «no se pudo comprobar» con reintento; `external:*` muestra «enlace no disponible» | RF-31 | `main.dart:776-813` |
| CHAR-03 | CAR | DB v7 con la tienda `monetta.mx`, reabierta con la misma configuración: sin pérdida. Con un dominio distinto: reset completo (regla vigente) | RF-16 | `catalog_repository.dart:283-311` (R10) |
| CHAR-04 | CAR | Fusión invitado→cuenta: la cantidad del invitado sobrescribe la de la cuenta; sin tope | RF-16; cambia en RF-50 según E4 | `bag_store.dart:119-141` (R16) |
| CHAR-05 | CAR | El contador de la bolsa suma líneas que la lista oculta (producto o variante ausente) | RF-16; cambia según E4 | `catalog_store.dart:151-167` |
| CHAR-06 | CAR | Catálogo vacío: el full sync de Storefront lo aplica; el snapshot vacío de Firestore se ignora | RF-16; cambia según E10 | `catalog_repository.dart:203-228` · `realtime_catalog_repository.dart:105` |
| CHAR-07 | CAR | En el filtro de colección pasan los productos sin `collectionHandles` | RF-16; decisión en RF-40 | `collection_screen.dart:218-221` |
| CHAR-08 | OBJ | El arranque con un cliente de notificaciones que nunca responde pinta el inicio igual; las notificaciones se inicializan después | RF-14 | `main.dart:772` · `notification_controller.dart:96` (R13) |
| CHAR-09 | OBJ | Una notificación tocada en arranque en frío abre su destino una vez que el Navigator existe | RF-14, RF-31 | `notification_controller.dart:101-106` |
| CHAR-10 | OBJ | Mientras `restore()` no termina, pedir el permiso del sistema espera el estado guardado: con el permiso ya concedido no vuelve a pedirlo ni pisa las preferencias | RF-14 | `home_screen.dart:115-123` · `notification_controller.dart:158-170` |
| CHAR-11 | CAR | El catálogo completo (navegador abierto desde la UI) muestra los productos de la tienda con tarjetas «$N MXN», sin descuento, sin precio tachado y sin «NUEVO» (D-10), y su filtro de categoría deja sólo esa categoría | RF-20 | `catalog_browse_screen.dart` · `product_tile.dart:238` · `theme.dart` `formatCatalogMoney` |
| CHAR-12 | CAR | Búsqueda vigente sobre el catálogo incluido: normalización, términos de facetas y consulta vacía sin resultados | RF-40 | `catalog_query.dart:17-60` |
| CHAR-13 | CAR | Filtro y orden vigentes del navegador del catálogo | RF-40 | `catalog_browse_screen.dart:1153-1193` |
| CHAR-14 | CAR | Upsert vigente de los destacados en la caché, antes de pasarlo por el coordinador | RF-42 | `catalog_store.dart:326-333` (R08) |
| CONTRACT-01 | OBJ | ID de pedido de Rewards: el mismo fixture en el cliente y el servidor; el cliente envía un segmento válido y el servidor acepta GID o numérico | RF-12 | `rewards_api.dart:78-80` · `rewards/routes.ts:69` (R12) |
| CONTRACT-02 | OBJ | Rewards apagado: el servidor responde JSON (`feature_disabled`); la ruta desconocida da `not_found` con `requestId`; el cliente muestra «no disponible» y nunca «revisa tu conexión» | RF-13 | `server.ts:538-543,777-787` (R11) |
| CONTRACT-03 | OBJ | Los parsers de Rewards rechazan fechas inválidas, IDs ausentes y cantidades ausentes con un error de contrato tipado | RF-15 | `rewards_models.dart:47-162` (R15) |
| CONTRACT-04 | OBJ | Los atributos del carrito por escenario de origen siguen la decisión E8 | RF-67 | `cart_attribution.dart:46` (R03) |
| CONTRACT-05 | OBJ | Cada cliente HTTP propio agota su tiempo máximo y lo traduce a un error tipado | RF-14 | 7 clientes sin timeout (R13) |
| CONTRACT-06 | OBJ | Admin sin catálogo externo: `GET/PUT /admin/external-policy/:id` dan el 404 JSON `not_found` con `requestId`; `POST /admin/sync` con `external-status` da 422 `INVALID_SYNC_CHANNEL`; el control-plane no trae `sources` ni `health.sources`; `/admin/me` no trae `manageExternalSources`; `CATALOG_MONITOR_*` ya no se lee | RF-21 | `admin/routes.ts:270,502-544,787,888` · `config.ts:99-108` |
| ARCH-01 | TRQ | Ningún archivo de `lib/features/` importa `main.dart` | RF-30 | 15 archivos hoy (R18) |
| ARCH-02 | TRQ | `lib/features/` no importa implementaciones de `lib/data/`, salvo la lista explícita de helpers puros | RF-33 | 21 archivos hoy (H03) |
| ARCH-03 | OBJ | Ningún archivo de `lib/` ni `test/` referencia el catálogo externo, salvo el guard de `RuntimeConfig` | RF-20 | R02 |
| ARCH-04 | TRQ | `lib/app/composition/` es el único lugar que construye implementaciones concretas de `data/` | RF-30, RF-33 | R18 |
| ARCH-05 | TRQ | Sólo el repositorio del catálogo y el coordinador escriben en la caché: ninguna llamada nueva a `cache.upsertProducts` fuera de ellos | RF-42 | `catalog_store.dart:328` (R08) |
| UI-01 | OBJ | Cada helper de tipografía y los temas claro y oscuro resuelven a una familia empaquetada (Inter o Playfair Display), con el peso por defecto del helper declarado; los archivos existen y `MonettaApp` registra su licencia OFL | RF-17 | `boutique_tokens.dart:53-175` · `theme.dart:269-362` |
| UI-02 | OBJ | La raíz aplica la política E-T1 por tamaño (D-12): ningún texto pasa de 1.5×, el de 20 px o más no pasa de 1.2× y el menor no pasa de 24 px; la escala es monótona y a 1.0 no cambia | RF-17 | `main.dart:908` (sin tope) |
| UI-03 | OBJ | Sin overflow a escala 1.0, 1.3 y 1.5, con la política E-T1 (D-12) y las fuentes reales cargadas, en inicio, colección, búsqueda, ficha, bolsa, checkout, cuenta y pedidos (teléfono de 375×812 y de 440×956) | RF-17 | R13/RF-17 |
| UI-04 | OBJ | Goldens de referencia a escala 1.0 con las fuentes nuevas, aprobados por la persona | RF-17 | — |
| DEV-01 | Manual | iOS: login con Shopify, checkout sheet, push en frío y en caliente, cierre de sesión | RF-14, RF-31, RF-51, RF-52, RF-62 | — |
| DEV-02 | Manual | Android: lo mismo que DEV-01 | Igual que DEV-01 | — |
| DEV-03 | Manual | Tipografía: capturas en iPhone pequeño, iPhone Pro Max y un Android, con texto predeterminado, grande y máximo; comparadas con las de referencia del paso 0 de RF-17 | RF-17 | — |

## 4. Asignación de filas por WP

| WP | Filas nuevas | Invariantes que debe mantener verdes | Gates extra |
|---|---|---|---|
| RF-00 | Conteos base de todas las suites | Todos | G6, G7 de base |
| RF-10 | — | INV-16 | — |
| RF-11 | CHAR-01 | INV-12 | — |
| RF-12 | CONTRACT-01 | INV-09, INV-15 | G7 |
| RF-13 | CONTRACT-02 | INV-15 | G7 |
| RF-14 | CHAR-08, CHAR-09, CHAR-10, CONTRACT-05 | INV-13, INV-08 | G6, G8 (DEV-01, DEV-02) |
| RF-15 | CONTRACT-03 | — | — |
| RF-16 | CHAR-03 a CHAR-07 | INV-02, INV-03, INV-04, INV-05 | — |
| RF-17 | UI-01 a UI-04 | INV-12 | G6, G8 (DEV-03) |
| RF-18 | — (pruebas nuevas del servicio y de la fila con prefijo INV-08 o INV-06) | INV-08, INV-06 | G6, porque cambia la composición de Customer Account en `main.dart` |
| RF-19 | — | INV-07 | G6 (iOS y Android, ejecutado por la persona) |
| RF-24 | CHAR-03, casos 7 y 8 en su versión objetivo (D-08); los demás casos de CHAR-03 sin cambios | INV-04, INV-05 | — |
| RF-20 | ARCH-03, CHAR-11 | INV-11, INV-14 (se retira `mixed_feed_test`) | G6 |
| RF-21 | CONTRACT-06 y ampliación de ARCH-03 (fuentes externas del admin de la app) | INV-15, INV-11 | G7 |
| RF-22 | — | Todos | G6 |
| RF-23 | — | INV-16 | — |
| RF-30 | ARCH-01, ARCH-04 | INV-02, INV-07, INV-11, INV-13 | G6 |
| RF-31 | CHAR-02, CHAR-09 | INV-10, INV-13 | G8 (DEV-01, DEV-02) |
| RF-32 | — | INV-02, INV-08 | — |
| RF-33 | ARCH-02, ARCH-04 | INV-12 | — |
| RF-40 a RF-43 | CHAR-12 y CHAR-13 (RF-40), CHAR-14 y ARCH-05 (RF-42); CHAR-07 cambia sólo según D-13 | INV-04, INV-05, INV-12, INV-14 | G6 en RF-41 |
| RF-50 a RF-52 | Según E4 y E10 | INV-01, INV-02, INV-05, INV-06, INV-07 | G6, G8 (DEV-01, DEV-02) |
| RF-60 | Fixtures de dinero (R14) | INV-03, INV-06 | G6 |

Las filas de las fases 6 a 8 se añaden al planear cada WP, antes de empezarlo.

## 5. Checklists de dispositivo

**Simuladores (D-05).** No hay dispositivos físicos; G8 se ejecuta en la Mac:
- **iOS:** iOS Simulator 27.0. El simulador sólo ejecuta builds de debug.
- **Android:** emulador `Medium_Phone_API_37.0`, con Google Play, que recibe FCM.
- **Push en iOS:** `xcrun simctl push` simula un push local. El payload lleva `gcm.message_id`, para que Firebase Messaging lo trate como mensaje FCM.
- **Push en Android:** necesita un FCM real; por ejemplo, la prueba de campaña del admin dirigida al dispositivo.
- **Configuración:** `config/dart_defines.staging.json` con `NOTIFICATIONS_ENABLED` y `FIREBASE_APP_CHECK_DEBUG` en `true`. El token de depuración de App Check de cada simulador se registra en Firebase.
- **Riesgo residual:** APNs de producción y dispositivos físicos quedan sin verificar; se repasan antes de publicar (E1).

**DEV-01 iOS y DEV-02 Android** (build de staging):

1. Abrir la app sin red: el inicio pinta desde la caché.
2. Iniciar sesión con Shopify (OAuth); cerrar sesión; volver a entrar.
3. Agregar a la bolsa → checkout sheet → cancelar. La bolsa se conserva.
4. Completar una compra de prueba en staging, si está autorizado. La bolsa resta sólo lo comprado.
5. Push tocado con la app cerrada y con la app abierta, a un producto y a una colección.
6. Cambiar de cuenta. Ni la bolsa ni los pedidos de la cuenta anterior aparecen.

**DEV-03 Tipografía:**

1. Tres dispositivos: iPhone pequeño, iPhone Pro Max y un Android.
2. Tres ajustes de texto del sistema: predeterminado, grande y máximo.
3. Pantallas: inicio, colección, ficha, bolsa y cuenta.
4. Comparar con las capturas de referencia del paso 0 de RF-17.

La persona aprueba o lista lo que sigue viéndose grande.

## 6. Estado de las filas

El orquestador actualiza esta sección al cerrar cada WP.

| ID | Estado | WP | Entrada de bitácora |
|---|---|---|---|
| CHAR-01 | verde | RF-11 | 2026-10-06 · RF-11 · iteración 1 |
| CONTRACT-01 | verde | RF-12 | 2026-10-06 · RF-12 · iteración 1 |
| CONTRACT-02 | verde | RF-13 | 2026-10-06 · RF-13 · iteración 1 |
| CONTRACT-03 | verde | RF-15 | 2026-10-07 · RF-15 · iteración 1 |
| CHAR-03 | verde (CAR). Los casos 7 y 8, antes defectos latentes, pasaron a objetivo y quedaron verdes en RF-24 (D-08, D-09) | RF-16, RF-24 | 2026-10-07 · RF-16 · iteración 1 · 2026-10-08 · RF-24 · iteración 1 |
| CHAR-04 | verde (CAR; cambia en RF-50 según E4) | RF-16 | 2026-10-07 · RF-16 · iteración 1 |
| CHAR-05 | verde (CAR; cambia según E4) | RF-16 | 2026-10-07 · RF-16 · iteración 1 |
| CHAR-06 | verde (CAR; cambia según E10) | RF-16 | 2026-10-07 · RF-16 · iteración 1 |
| CHAR-07 | verde (CAR; decisión en RF-40) | RF-16 | 2026-10-07 · RF-16 · iteración 1 |
| ARCH-03 | verde (OBJ). Ampliada en RF-21 con la gestión de fuentes externas del admin. Excepciones vivas: la guarda de `ENABLE_EXTERNAL_CATALOG` y `AdminChannel.externalCatalog`, que etiqueta la auditoría histórica `external_source` | RF-20, RF-21 | 2026-10-08 · RF-20 · iteración 1 · 2026-10-08 · RF-21 · iteración 1 |
| CONTRACT-06 | verde | RF-21 | 2026-10-08 · RF-21 · iteración 1 |
| CHAR-11 | verde (CAR, D-10) | RF-20 | 2026-10-08 · RF-20 · iteración 1 |
| UI-01 | verde (OBJ). Las 13 funciones de estilo y los temas, en Android e iOS, usan Inter o Playfair Display, que están empaquetadas; `MonettaApp` registra su OFL | RF-17 | 2026-10-08 · RF-17 · paso 1 · 2026-10-09 · RF-17 · paso 3 |
| UI-02 | verde (OBJ, D-12). `BoundedTextScaler` en la raíz | RF-17 | 2026-10-08 · RF-17 · paso 1 · 2026-10-09 · RF-17 · paso 3 |
| UI-03 | verde (OBJ). 60 casos: 10 pantallas, 2 teléfonos y 3 escalas | RF-17 | 2026-10-08 · RF-17 · paso 1 · 2026-10-09 · RF-17 · paso 3 |
| Las demás | pendiente | — | — |

## 7. Conteos base (RF-00)

Los midió el auditor el 2026-10-06. Las suites de backend se midieron con el WIP de Rewards (`07846f6`), que añade 2 pruebas; el código Flutter es el de `48a6786`. Después de cada WP, cada suite debe tener un conteo igual o mayor.

| Suite | Comando | Base |
|---|---|---|
| Flutter | `flutter test --no-pub` | 705 aprobadas y 5 omitidas (`skip: true` en pruebas de capturas); 123 archivos `*_test.dart` |
| Análisis | `flutter analyze --no-pub` | 0 issues |
| Formato | `dart format --output=none --set-exit-if-changed lib test integration_test` | 300 archivos, 0 cambios |
| Backend sin Postgres | `npm --prefix services/accounts_orders test` | 111 aprobadas y 9 omitidas (los 3 `*.pg.test.ts`); 22 archivos |
| Backend con Postgres (G7) | `REQUIRE_POSTGRES_TESTS=1 … test` | 120 aprobadas, 0 omitidas |
| Herramienta de auditoría | `node --test tools/audit/test/shopifyAdapter.test.mjs` | 8 aprobadas |
| Espejo | `npm run test:api` | 19 aprobadas; 5 archivos |
| Functions | `npm --prefix functions test` | 13 aprobadas; 3 archivos |
| G5 catálogo | `dart run bin/verify_catalog_snapshot.dart` | exit 0 con el snapshot del 2026-10-06 (`b749abb`), que tiene 103 productos. El del 2026-09-15 fallaba por antigüedad |
| G5 secretos | `./bin/check_no_secrets.sh` | exit 0 |
| G6 (ejecutado por la persona) | Android e iOS | Android compila. En la base, iOS **fallaba** con Xcode 27.0 porque el mínimo declarado era iOS 13.0 (D-03, D-04); compila desde RF-19 |
