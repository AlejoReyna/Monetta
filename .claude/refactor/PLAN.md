# Plan del refactor in situ

**Origen:** `docs/REVISION_PROPUESTA_RECONSTRUCCION_MVVM.md`. Los IDs R01–R20 y E1–E12 se refieren a ese documento.

**Mantenimiento:** el orquestador actualiza las columnas «Estado» y la tabla de decisiones. Los subagentes no editan este archivo.

**Estados de un WP:**
- `pendiente`
- `en curso`
- `bloqueado: <motivo>`
- `aprobado`: auditado, con todos los gates cumplidos
- `cerrado`: aprobado y con commit, si se autorizó

## Decisiones

Ningún WP que dependa de una decisión `pendiente` puede empezar.

**Excepción de preparación:** RF-00 recoge E1, E2, E3 y E5; no las exige como requisito para verificar el entorno y ejecutar la línea base. Las recomendaciones no cuentan como decisiones de la persona. RF-00 sigue pendiente de aprobación hasta registrar esas decisiones y completar sus entregables.

| ID | Decisión | Recomendación | Estado | Bloquea |
|---|---|---|---|---|
| D-01 | Refactor in situ, no rebuild | — | **tomada, 2026-10-06** | — |
| D-02 | Sacar de RF-00 lo que depende de dispositivos o de la persona | Mover DEV-03 al paso 0 de RF-17; webhooks a RF-23, instalaciones a RF-60 y cuentas propias a RF-62 | **tomada, 2026-10-06:** como se recomienda | RF-00 |
| D-03 | Mínimo de iOS: Xcode 27.0 sólo compila para iOS 15.0–27 | Subir a iOS 15.0 en RF-19 | **tomada, 2026-10-06:** subir a 15.0; ningún modelo de iPhone ni de iPad queda fuera | RF-19 |
| D-04 | Aprobar RF-00 con G6 iOS en rojo como parte de la base | Sí; RF-19 bloquea a los WPs que exigen G6 | **tomada, 2026-10-06:** sí | RF-14, RF-17, RF-20 y sus dependientes |
| D-05 | G8 sin dispositivos físicos | Simuladores de la Mac: iOS Simulator 27.0 (iPhone 17, 17e y 18 Pro Max) y el emulador Android `Medium_Phone_API_37.0` con Google Play | **tomada, 2026-10-06:** simuladores. Riesgo residual: APNs de producción, builds de release en iOS y dispositivos físicos quedan sin verificar; repetir DEV-01 y DEV-02 en un dispositivo o en prueba interna antes de publicar (E1) | G8 de RF-14, RF-17, RF-31, RF-50–52 y RF-62 |
| D-06 | La cadena del refactor salió de `main` en `48a6786`, y el diseño siguió en `main` con PRs (#8, #9 y #10) | Integrar `main` antes de RF-16 y después de cada PR de diseño | **tomada, 2026-10-07:** integrar ahora. `cbeb237` trae `main` (`7e304b1`) y el PR #10 (`b66e5c4`) | RF-16, RF-17 |
| D-07 | Orden de la fase 1 después de RF-15 | RF-16 y RF-18 primero; RF-17 después, porque necesita a la persona (capturas DEV-03 y fuentes) | **tomada, 2026-10-07:** como se recomienda; la persona respondió «sí, continúa pero en loop» | RF-17 |
| E1 | ¿Lanzar tras las fases 1–2 y refactorizar sobre el producto vivo? | Sí | **tomada, 2026-10-06:** sí; las fases 3+ se hacen con la app publicada | Orden de las fases 3+ |
| E2 | Eliminar del árbol el código del catálogo externo, con tag forense | Sí | **tomada, 2026-10-06:** sí, con tag forense (`baseline/48a6786` sirve de referencia) | RF-20, RF-21 |
| E3 | Autoridad del catálogo en producción | Sólo `storefrontDirect`; el espejo queda experimental | **tomada, 2026-10-06:** sólo `storefrontDirect`; el espejo queda experimental | RF-42, RF-71 |
| E4 | Fusión invitado→cuenta y contador de la bolsa | Sumar con tope de 10; el contador cuenta sólo líneas visibles; aviso para artículos no disponibles | **tomada, 2026-10-07:** como se recomienda | RF-50 |
| E5 | Cuenta propia Monetta | Congelar el registro; inventariar cuentas reales; evaluar la migración | **tomada, 2026-10-06:** congelar el registro, inventariar las cuentas reales (existen; cifra pendiente) y evaluar su migración | RF-62 |
| E6 | ¿Universal links o App Links en la v1? | No: sin go_router por ahora | **tomada, 2026-10-07:** no en la v1; sin go_router por ahora | Alcance de RF-31 |
| E7 | Qué ve la persona si Rewards está apagado | Ocultar la sección o «próximamente», nunca un error | **tomada, 2026-10-06:** mantener el estado vigente «Monetta Rewards aún no está disponible» (`rewards_section.dart:442`, `rewards_balance_card.dart:195`); nunca un error ni «revisa tu conexión» | Textos de RF-13 |
| E8 | ¿El acuerdo comercial exige `_rec_source` y `_campaign`? | Confirmarlo con el contrato | pendiente: la persona aún no lo sabe (consultado 2026-10-07) | RF-67 |
| E9 | Funciones de nicho en la v1 (partner, mayoreo, creador de catálogo, contacto, experiencias, admin) | Inventario con la persona | pendiente | RF-66 |
| E10 | Política ante un catálogo vacío | No aplicar un vacío sin una segunda confirmación | **tomada, 2026-10-07:** un vacío sólo se aplica cuando una segunda sincronización lo confirma; mientras, se muestra el último catálogo bueno | RF-42, RF-50 |
| E11 | Dominio canónico de la tienda | `monetta.mx`, como hoy, sin normalizarlo de otra forma | **tomada, 2026-10-07:** `monetta.mx`, derivado y normalizado como hoy | RF-30, RF-32 |
| E12 | ¿Galería web pública o privada? | — | pendiente | RF-80 |
| E-T1 | Tope de escala de texto | Global 1.5 y titulares 1.2 | **tomada, 2026-10-07:** global 1.5 y titulares 1.2 | RF-17 |
| E-T2 | ¿Empaquetar Playfair Display e Inter (licencia OFL 1.1)? | Sí | **tomada, 2026-10-07:** sí, empaquetarlas con su licencia. **2026-10-08:** las descarga el orquestador con curl desde los repositorios oficiales, con su `OFL.txt`; TTF estáticos de los pesos usados, en `assets/fonts/` sin declararse en `pubspec.yaml` hasta el paso 3 | RF-17 |
| D-08 | Defectos latentes del reset por tienda que confirmó CHAR-03 (casos 7 y 8): la semilla del asset y cada snapshot de Firestore guardan la metadata sin `shopDomain`, y el siguiente arranque o sync con `monetta.mx` lo toma por otra tienda | WP nuevo RF-24 en la fase 1, antes del lanzamiento (E1): conservar la procedencia de tienda en la semilla y en Firestore, cambiando CHAR-03 de forma explícita | **tomada, 2026-10-07:** como se recomienda; RF-24 va después de RF-18. El orquestador lo pone antes que RF-17, porque no necesita a la persona (D-07). La persona no sabe si `FIRESTORE_CATALOG_ENABLED` está en `true` en sus archivos reales; se trata como latente | RF-24; lanzamiento (E1) |
| D-09 | Diseño de RF-24: qué tienda registra la metadata del catálogo incluido y la de Firestore | Procedencia explícita: la semilla registra la tienda de su `_source` (monetta.mx), Firestore la configurada y una instalación nueva guarda su tienda en el cursor desde el primer arranque; la comparación exacta no cambia | **tomada, 2026-10-07:** como se recomienda. La persona confirmó que todo es del catálogo de monetta.mx; el catálogo externo de EE. UU. no participa | RF-24 |
| D-10 | Aspecto de las tarjetas del catálogo completo cuando el navegador pase de `CatalogItem` a `Product` (RF-20) | Conservar el aspecto actual («$1,749 MXN», sin etiquetas): RF-20 es limpieza sin cambios visuales, y la alineación con las demás rejillas puede ir en RF-17 o en un PR de diseño | **tomada, 2026-10-08:** conservar el aspecto actual en RF-20 | RF-20 |
| D-12 | Cómo se aplica «titulares 1.2» de E-T1: un `TextScaler` sólo recibe el tamaño, y un rol no se distingue por tamaño (`boutiqueTitle` va de 15 a 24 px; `boutiqueText`, de 9 a 20) | Por tamaño, en la raíz: un solo `TextScaler` en `MaterialApp.builder`, sin tocar llamadas. El texto de 20 px o más crece como máximo 1.2×, y el menor hasta 1.5× sin pasar de 24 px, para que ningún texto pequeño supere a un titular. La alternativa por rol exigía un barrido de unas 106 llamadas y, a escala máxima, dejaba un título de 15 px (18 px) por debajo del cuerpo de 14 px (21 px) | **tomada, 2026-10-08:** por tamaño, en la raíz | RF-17 (UI-02, UI-03) |
| D-13 | Regla de colección de CHAR-07: ¿un producto sin `collectionHandles` debe seguir apareciendo en cualquier colección? Hoy sí (`collection_screen.dart:218-219`), y los productos del catálogo incluido nunca traen esos handles | Conservar la regla mientras el catálogo incluido no traiga la pertenencia a colecciones. Una regla estricta exige primero que el script de refresco la incluya | **tomada, 2026-10-09:** conservar la regla actual; RF-40 sólo la mueve a una función pura (CHAR-07 no cambia) | RF-40 |
| D-14 | ¿Empezar la fase 3 antes del lanzamiento (E1)? | Sí, en ramas aparte que salen de `38d97cb` (código de las fases 1–2 aprobado, G6 pendiente), sin tocar la línea que se lanza. Los arreglos que pidan G6 o DEV-03 se integran hacia delante | **tomada, 2026-10-09:** sí, en ramas aparte. La persona eligió ramas, lo que autoriza los commits en `refactor/rf-3X-*` (nunca push). El checkout principal sigue en la línea de lanzamiento. **Ampliada el 2026-10-09 a la fase 4**, con el borrador del plan: ramas `refactor/rf-4X-*` sobre la fase 3. RF-43 vuelve a la persona como decisión | RF-30–RF-33, RF-40–RF-43 |
| D-15 | Estrategia de los goldens de UI-04, que usan fuentes reales y no coinciden entre macOS y el CI de Ubuntu (la regla prohíbe `skip:`) | Goldens con la etiqueta `golden`: el job de Ubuntu los excluye y corren en macOS (en local y en el job de macOS del CI), con una tolerancia de píxeles pequeña. La persona aprueba las imágenes | **tomada, 2026-10-09:** como se recomienda | RF-17 (paso 4) |
| D-11 | Orden del paso 1 de RF-17 frente a las capturas DEV-03 | Adelantar UI-01 a UI-03 (rojas, sin commit) mientras la persona corre G6 y las capturas: no tocan `lib/`, así que las capturas siguen siendo el «antes». UI-03 se escribe con las fuentes reales cargadas | **tomada, 2026-10-08:** adelantar | RF-17 |

**Opciones de E-T1:**
- **(a) Tope global de 1.3.** Prioriza el diseño y es el cambio más simple.
- **(b) Recomendada.** Tope global de 1.5 y tope de 1.2 para titulares. El cuerpo puede crecer para quien lo necesita sin que los titulares desborden.
- **(c) Sin tope global; titulares a 1.2.** Prioriza la accesibilidad.

## Resumen de WPs

| WP | Título | Fase | Agentes | Depende de | Decisiones | Estado |
|---|---|---|---|---|---|---|
| RF-00 | Baseline y entorno | 0 | orquestador | — | E1, E2, E3, E5 (recoger; no bloquean la medición inicial) | cerrado |
| RF-10 | CI: pruebas del espejo y Makefile | 1 | orquestador | RF-00 | — | cerrado |
| RF-19 | Mínimo iOS 15.0 para Xcode 27 | 1 | orquestador (configuración nativa, menos de 30 líneas) | RF-00 | D-03 | cerrado |
| RF-11 | Ficha: producto que desaparece | 1 | test-engineer → flutter-implementer | RF-00 | — | cerrado |
| RF-12 | Contrato del ID de pedido en Rewards | 1 | test-engineer → backend + flutter | RF-00 | — | cerrado |
| RF-13 | Rewards apagado: JSON 404 y estado «no disponible» | 1 | test-engineer → backend + flutter | RF-00 | E7 | cerrado |
| RF-14 | Timeouts y notificaciones fuera del arranque | 1 | test-engineer → flutter-implementer | RF-00, RF-19 | D-05 (G8) | bloqueado: G6 y G8 de la persona |
| RF-15 | Parsers estrictos de Rewards | 1 | test-engineer → flutter-implementer | RF-00 | — | cerrado |
| RF-16 | Caracterización de reglas vigentes | 1 | test-engineer | RF-00 | — | cerrado |
| RF-18 | Extracciones D02 y D03 | 1 | flutter-implementer | RF-00 | — | bloqueado: G6 de la persona (código aprobado y con commit) |
| RF-24 | Procedencia de tienda en la semilla y en Firestore | 1 | test-engineer → flutter-implementer | RF-16; empieza cuando el código de RF-18 esté aprobado (D-08) | D-08, D-09 | cerrado |
| RF-17 | Tipografía consistente y escala de texto acotada | 1 | test-engineer → flutter-implementer | RF-00, RF-19, RF-18, RF-24 (orden de D-07 y D-08) | E-T1, E-T2, D-11, D-12 | bloqueado: lo pendiente es de la persona. El código del paso 3 está aprobado y con commit; faltan G6 y G8 con DEV-03 (el «antes» se captura en `.claude/worktrees/rf-17-antes`). Los goldens del paso 4 (UI-04, `test/goldens/ui04/`) ya están hechos y con commit, y los aprueba la persona |
| RF-20 | Eliminar el catálogo externo de la app | 2 | test-engineer → flutter-implementer | RF-16, RF-19 | E2, D-10 | bloqueado: G6 de la persona (código aprobado y con commit) |
| RF-21 | Eliminar el catálogo externo del admin (backend y app) | 2 | test-engineer → flutter-implementer → backend-implementer | RF-00 | E2 | cerrado |
| RF-22 | Dependencias sin uso, Makefile y docs | 2 | flutter-implementer | RF-20 (código aprobado; G6 pendiente: la persona decidió seguir, 2026-10-08) | — | bloqueado: G6 de la persona (código aprobado y con commit) |
| RF-23 | Retirar `functions/` | 2 | backend-implementer | RF-10 | Inventario de webhooks de ambas tiendas (D-02). El repo, verificado el 2026-10-08, no apunta a Functions; faltan las suscripciones vivas, creadas por API | bloqueado: verificación en las tiendas |
| RF-30 | Composición fuera de `main.dart` y sobre el Navigator | 3 | test-engineer → flutter-implementer | RF-22 (código aprobado; G6 pendiente, D-14) | E1, E11, D-14 | bloqueado: G6 de la persona. El código está aprobado y con commit (`80753e3` en `refactor/rf-30-composicion`, worktree `.claude/worktrees/rf-30`) |
| RF-31 | `AppDestination` y resolver de notificaciones | 3 | test-engineer → flutter-implementer | RF-30, RF-14 (los dos con el código aprobado y G6 pendiente; D-14) | E6, D-14 | bloqueado: G6 y G8 (los pasos de push de DEV-01 y DEV-02) de la persona. El código está aprobado y con commit (`1b44983` en `refactor/rf-31-destinos`) |
| RF-32 | `ShopperScope` y `ChangeAccountScope` | 3 | test-engineer → flutter-implementer | RF-30 (código aprobado; G6 pendiente, D-14) | E11, D-14 | cerrado (`732f9e8` en `refactor/rf-32-shopper-scope`). No requiere G6; se apoya en el código de RF-30 y RF-31, cuyo G6 sigue pendiente, igual que RF-24 sobre RF-18 |
| RF-33 | Pruebas de arquitectura en trinquete | 3 | test-engineer | RF-30 (código aprobado; G6 pendiente, D-14) | D-14 | cerrado (`e719391` en `refactor/rf-33-arquitectura`). Sólo pruebas; no requiere G6 |
| RF-40 | Consultas puras del catálogo | 4 | test-engineer → flutter-implementer | RF-33 | D-13, D-14 | cerrado (`4c4a063` en `refactor/rf-40-consultas`). No requiere G6 |
| RF-41 | ViewModels del piloto | 4 | test-engineer → flutter-implementer | RF-40 | D-14 | cerrado (G6 verde el 2026-10-09: Android e iOS compilan sobre `da31075`, ejecutado por la persona). Código en `refactor/rf-41-viewmodels`: PERF-01 (`ba3faa4`), A `SearchScreen` + `Command` (`1b4fa1c`), B `CollectionScreen` (`1a7710c`), C `CatalogBrowseScreen` con CHAR-17 (`c7542fb`), D `ProductScreen` (`653f4b3`, integrada en `9fa75f6`), techos PERF-01 (`1580c62`) y cierre de fachadas (`da31075`). PERF-01 final: 411/0, 435/0, 3/0 y 99/0. Evidencia para RF-43 registrada; RF-43 puede apoyarse en este código como RF-32 en el de RF-30/31 |
| RF-42 | Upsert de destacados vía coordinador | 4 | flutter-implementer | RF-40 | E3, E10 | cerrado (`b2f3816` en `refactor/rf-42-destacados`, rebasado sobre `da31075`; pruebas en `31e4bb8`). Hecho por GPT Sol 6.1 y auditado por el orquestador con contraste en worktree temporal. El invariante 5 queda sin excepciones; no requiere G6 |
| RF-43 | Gate de decisión de DI | 4 | orquestador | RF-41 | — | pendiente |
| RF-50 | Separar `CatalogStore` tras una fachada | 5 | test-engineer → flutter-implementer | RF-43 | E4, E10 | pendiente |
| RF-51 | `CompleteCheckout` y cierre de la DB | 5 | flutter-implementer | RF-50 | — | pendiente |
| RF-52 | ViewModel del checkout | 5 | flutter-implementer | RF-51 | — | pendiente |
| RF-60 | `Money` y esquema v8 | 6 | test-engineer → flutter + backend | RF-50 | Inventario de instalaciones reales y su versión (D-02) | pendiente |
| RF-61 | Modelo de dominio de pedidos y `OrderId` | 6 | flutter-implementer | RF-12 | — | pendiente |
| RF-62 a RF-67 | Cuenta y pedidos, Rewards, notificaciones, admin, funciones de nicho, atribución | 6 | según el WP | RF-52 | E5, E8, E9; inventario de cuentas propias para RF-62 (D-02) | pendiente |
| RF-70 a RF-72 | Backend: dividir `admin/routes.ts`, decisión del espejo, capacidades | 7 | backend-implementer | RF-13 | E3 | pendiente |
| RF-80 a RF-81 | 404 de la galería; retiro operativo autorizado | 8 | según el WP | — | E12 | pendiente |

**Punto de lanzamiento posible:** al cerrar las fases 1 y 2, según E1.

## Detalle de los WPs de las fases 0–3

Los WPs de las fases 4 a 8 se detallan con este mismo formato antes de empezarlos.

### RF-00 · Baseline y entorno

**Objetivo:** una referencia ejecutable con resultados registrados y un entorno donde los gates se pueden ejecutar.

**Pasos:**
1. **WIP de Rewards** (rama `monetta/rewards-default-off`). `REWARDS_ENABLED = "true"` quedó después de `[[http_service.checks]]` en `services/accounts_orders/fly.toml:60-69`, y por las reglas de TOML no cae en `[env]`.
   - Proponer a la persona moverlo a `[env]`.
   - La persona decide si hace commit o merge.
2. **Comprobar el sandbox** para `flutter`, `pub` y los puertos locales. La persona ya autorizó y se preparó `.claude/settings.local.json` con las cuatro rutas de caché y `allowLocalBinding: true`. Verificar su carga efectiva y registrar cualquier bloqueo. Si el proyecto no aplica estos ajustes, identificar la causa antes de plantear la configuración de usuario; no ampliar permisos por rutina.
3. **Ejecutar y registrar en la bitácora** el conteo de cada suite:
   - `flutter analyze` y `flutter test`;
   - `accounts_orders` sin Postgres y con Postgres (G7);
   - `npm run test:api` y `functions`;
   - G5 y G6.
4. **Dump de esquema:** `dart run drift_dev schema dump lib/data/local/database.dart drift_schemas/`, para la versión 7.
5. **Tag de baseline** `baseline/48a6786`, si la persona lo autoriza.
6. **Inventario con la persona:**
   - despliegues vivos (Firebase Functions, proyectos de Vercel, suscripciones de webhooks);
   - configuración real de producción;
   - si existen instalaciones reales y en qué versión;
   - cuentas propias reales.

   Por D-02, RF-00 sólo registra los despliegues vivos y la configuración. Las suscripciones de webhooks pasan a requisito de RF-23, las instalaciones reales a RF-60 y las cuentas propias a RF-62.
7. **Registrar las decisiones E1, E2, E3 y E5.**
8. **Capturas de referencia para DEV-03.** Por D-02 se movieron al paso 0 de RF-17.

**Salida:** entrada RF-00 en la bitácora con los resultados y conteos base de cada suite, inventario, decisiones E1/E2/E3/E5 de la persona y estado de los demás entregables. Los gates no ejecutados se registran como tales y no permiten declarar el WP aprobado.

**Cierre (2026-10-06):** por D-04, RF-00 se aprobó con G6 iOS en rojo como parte de la base. RF-19 lo corrige y bloquea a los WPs que exigen G6.

### RF-10 · CI: pruebas del espejo y Makefile

Origen: R07, H15.

**Cambios:**
- Añadir `npm run test:api` al job `functions-and-web` de `.github/workflows/quality.yml` y a `make test-services`.
- Arreglar el target `make schema`: hoy llama a un script inexistente, `scripts/fetch_schema.sh`.
- Actualizar la descripción de `make gen` (menciona ferry, freezed y riverpod, que no se usan).

**Aceptación:** `npm run test:api` pasa localmente y el workflow lo ejecuta.

### RF-11 · Ficha: producto que desaparece

Origen: R09.

**Orden de trabajo:**
1. `test-engineer` escribe CHAR-01, roja: emite un catálogo sin el producto con la ficha abierta.
2. `flutter-implementer` hace la corrección.

**Alcance:**
- `lib/features/product/product_screen.dart`;
- un widget de «artículo no disponible», con las acciones «Explorar catálogo» y «Volver», en `lib/features/product/`;
- sus pruebas.

**Aceptación:**
- CHAR-01 en verde;
- no queda ningún `firstWhere` sin `orElse` sobre `store.products` en `lib/features/`.

### RF-12 · Contrato del ID de pedido en Rewards

Origen: R12.

**Orden de trabajo:**
1. `test-engineer` escribe CONTRACT-01 con un fixture compartido, en una ruta que fije el encargo.
2. `backend-implementer`: la ruta `orders/:id/rewards` acepta `gid://shopify/Order/<n>` codificado o `<n>`, y lo normaliza al numérico guardado.
3. `flutter-implementer`: el cliente envía el numérico como segmento, con `Uri(pathSegments: …)`.

**Alcance:**
- `services/accounts_orders/src/rewards/routes.ts` y sus pruebas;
- `lib/features/rewards/rewards_api.dart` y sus pruebas.

**Aceptación:** CONTRACT-01 en verde en ambos lados, más G7.

### RF-13 · Rewards apagado

Origen: R11; textos según E7.

**Servidor (`backend-implementer`):**
- Con Rewards apagado, las rutas `/customers/me/rewards*` responden 404 con `{error: "feature_disabled"}`.
- Catch-all JSON al final de `createApp`: `{error: "not_found", requestId}`.

**Cliente (`flutter-implementer`):**
- `RewardsApi` deja de ignorar el status y clasifica los errores en `feature_disabled`, `not_found`, sesión, red y servidor.
- `feature_disabled` muestra el estado que defina E7.

**Aceptación:** CONTRACT-02 en verde, más G7.

### RF-14 · Timeouts y notificaciones fuera del arranque

Origen: R13.

**Orden de trabajo:**
1. `test-engineer` escribe primero CHAR-08 y CHAR-09.
2. `flutter-implementer` aplica los cambios.

**Cambios:**
- Un transporte común con timeout configurable, que por defecto sea el mismo que ya usa Customer Account, para los 7 clientes HTTP sin límite. Customer Account usa dos valores: 15 s para la identidad y 20 s para los pedidos. El valor por defecto es 20 s, el mismo de los pedidos y del transporte de Storefront (`customer_orders.dart:60`, `http_storefront_transport.dart:23`). Los 7 clientes son:
  - notificaciones;
  - notificaciones de admin;
  - admin;
  - historial de pedidos;
  - cuenta propia;
  - Rewards;
  - Loox.
- `NotificationController.restore()` deja de bloquear `_load()` (`main.dart:772`).
- El destino de una notificación en arranque en frío se conserva hasta que existe el Navigator.

**Aceptación:**
- CHAR-08, CHAR-09 y CONTRACT-05 en verde;
- G6;
- DEV-01 y DEV-02, sólo los pasos de push.

### RF-15 · Parsers estrictos de Rewards

Origen: R15.

**Cambios:**
- CONTRACT-03 primero.
- Los DTO de `rewards_models.dart` fallan con un error de contrato tipado en lugar de sustituir con `DateTime.now()`, `0` o `"null"`.
- La UI muestra un error recuperable.

**Aceptación:** CONTRACT-03 en verde; las pruebas existentes de Rewards siguen verdes.

### RF-16 · Caracterización de reglas vigentes

**Agente:** sólo `test-engineer`.

**Pruebas:** CHAR-03 a CHAR-07, en verde hoy, fijando el comportamiento vigente.

**Por qué:** estas reglas sólo existen en el código. Cualquier cambio posterior a ellas (por E4 o E10) cambia la prueba de forma explícita y queda en la bitácora.

### RF-17 · Tipografía consistente y escala de texto acotada

Lo pidió la persona.

**Evidencia (hechos):**
- **Sin tope de escala.**
  - Ningún `textScaler` ni `MediaQuery.withClampedTextScaling` en `MaterialApp`, cuyo `builder` está en `main.dart:857`.
  - Todo el texto crece con el ajuste del sistema: iOS Dynamic Type llega a unas 3 veces con los tamaños de accesibilidad; Android, a 2 veces.
  - Algunos contenedores ya escalan su altura: `product_tile.dart:602`, `catalog_controls.dart:136`, `home_boutique_sections.dart:257` y `:325`, `search_screen.dart:731`, `brand_screen.dart:386`.
- **Fuentes del diseño sin empaquetar.**
  - `boutique_tokens.dart:47-64` declara `Playfair Display` e `Inter` «when registered».
  - `pubspec.yaml` no tiene sección `fonts:` y no existe `assets/fonts/`.
  - Cada plataforma usa un respaldo distinto.
- **Cuatro familias para la misma pieza visual.**
  - En `theme.dart:279-372`: `display` y `wordmark` usan Helvetica Neue; `editorial` usa New York y sus respaldos; `sans` y `eyebrow` no fijan familia, así que usan la fuente por defecto de Material (SF en iOS, Roboto en Android).
  - En `boutique_tokens.dart`: Playfair e Inter, con sus respaldos.
  - Un mismo tamaño nominal se ve distinto según la familia.
- **Uso:**
  - `boutiqueText` 172, `sans` 131, `eyebrow` 64, `boutiqueEyebrow` 40, `display` 26, `boutiqueDisplay` 26, `boutiqueTitle` 25, `editorial` 23.
  - Pesos usados: w300 (además del valor por defecto de `display`), w400, w500, w600, w700 y w800.

**Diagnóstico de la persona (2026-10-08):** lo ve en **iPhone con el tamaño de texto predeterminado**. El problema no es la escala de texto, sino la familia tipográfica, el tamaño nominal o ambos. Hay que confirmarlo con las capturas DEV-03.

**Inferencias a confirmar en el paso 0:**
- En iOS, «New York» y «SF Pro Text» no se resuelven por nombre de familia.
- En Android, el texto cae a Noto Serif y Roboto, que se ven más grandes.

**Pasos:**
0. **Diagnóstico con la persona.**
   - Preguntar en qué dispositivo, pantalla y ajuste de texto lo ve.
   - Si la persona usa el zoom de pantalla de iOS o el tamaño de visualización de Android, todo se ve más grande, y eso no es un defecto de la app.
   - **Capturas de referencia DEV-03** (movidas desde RF-00 por D-02), antes de cualquier cambio de tipografía:
     - `test-engineer` escribe un `integration_test` que recorre inicio, colección, ficha, bolsa y cuenta, y captura cada pantalla con texto predeterminado, grande y máximo;
     - la persona lo corre en un iPhone pequeño, un iPhone Pro Max y un Android, en simulador o dispositivo, porque el sandbox no puede operar simuladores.
1. **`test-engineer` escribe las pruebas objetivo** UI-01, UI-02 y UI-03, a 1.0, 1.3 y la escala máxima de E-T1, en teléfonos de 375×812 y 440×956. Registra cuáles fallan hoy.
2. **La persona decide E-T1 y E-T2.**
   - Las fuentes se obtienen de su fuente oficial (Google Fonts o el repositorio del autor), con su `OFL.txt`.
   - Las descarga la persona, o el orquestador con su aprobación. Los subagentes no descargan nada.
3. **`flutter-implementer`:**
   - `assets/fonts/` con los TTF de los pesos realmente usados, y la sección `fonts:` en `pubspec.yaml` (permitido en este WP).
   - Licencias registradas en `LicenseRegistry`.
   - Roles de tipografía unificados en `boutique_tokens.dart`. Los helpers antiguos de `theme.dart` delegan en ellos, sin tocar sus más de 400 llamadas.
   - La política de E-T1 en `MaterialApp.builder` con `MediaQuery.withClampedTextScaling`, y el tope de titulares con `TextScaler.clamp`.
   - Corrección de los contenedores que desborden.
   - Las fuentes variables sólo se aceptan con `FontVariation` y verificadas en dispositivo; si no, TTF estáticos.
4. **Gates:** G6; G8 con DEV-03, comparado contra las capturas del paso 0; UI-04, con los goldens nuevos aprobados por la persona.

**Aceptación:**
- UI-01 a UI-04 en verde;
- DEV-03 aprobado;
- el aumento de tamaño del bundle documentado en la bitácora.

**Detalle del paso 1 (2026-10-08, D-11 y D-12):**
- **UI-01** (`test/app/bundled_fonts_test.dart`):
  - el `FontManifest.json` declara `Inter` y `Playfair Display` con archivos que existen;
  - los 13 helpers y los temas claro y oscuro resuelven a una de las dos familias, y el peso por defecto de cada helper está declarado;
  - `MonettaApp` registra al montarse la licencia OFL de cada familia.
- **UI-02** (`test/app/text_scale_policy_test.dart`): con `MonettaApp` montada, la escala bajo `HomeScreen` es `min(k·s, s ≥ 20 ? 1.2·s : min(1.5·s, 24))` para k en {0.85, 1.0, 1.3, 2.0, 3.1}, también después de un cambio en caliente.
- **UI-03** (`test/features/text_scale/`): ninguna excepción de overflow en inicio, colección, búsqueda, ficha, bolsa, checkout, cuenta y pedidos, a 375×812 y 440×956.
  - Inter y Playfair se registran con `FontLoader`.
  - Un oráculo aplica esa misma escala para k en {1.0, 1.3, 1.5}.
- Las tres compilan hoy, sin API nueva, y quedan sin commit hasta el paso 3.

**Requisitos que el paso 1 dejó para el paso 3 (2026-10-08):**
- Declarar los `OFL.txt` como assets, o llevar su texto en código, porque hoy `rootBundle` no los encuentra. `MonettaApp` registra la licencia al montarse.
- Corregir las alturas reservadas con `textScaler.scale(<alto en px>)`:
  - `product_tile.dart:126` y `:748`;
  - `search_screen.dart:731`;
  - `catalog_controls.dart:137`;
  - `brand_screen.dart:386`;
  - `home_boutique_sections.dart:257` y `:325`;
  - `product_screen.dart:1180`.

  Con D-12 una altura grande cuenta como titular y queda topada en 1.2×, mientras el texto que contiene crece hasta 1.5×. Ésa es la causa de los 4 overflows de UI-03 en `product_tile.dart:316`. La altura debe salir del tamaño escalado de cada texto, como ya hace la variante de borde a borde (`product_tile.dart:128-134`).
- `sans()` y `eyebrow()` deben fijar familia. Los 2 overflows de Inicio a 1.3 están en texto que hoy se dibuja con la fuente de pruebas (`customer_experiences_section.dart:704` y `home_account_invitation.dart:146`); si siguen al pasar a Inter, se corrige el contenedor.

### RF-18 · Extracciones D02 y D03

**Cambios:**
- `CustomerApiDiscoveryService` compartido. El código duplicado está en `customer_identity.dart:138` y `customer_orders.dart:187`. Debe tener una sola caché y controlar las peticiones concurrentes.
- Un componente común de fila de resumen, que reemplace a `shopify_cart_summary.dart:269` y `checkout_screen.dart:1264`.

**Aceptación:** INV-08 e INV-06 verdes; las pruebas de discovery existentes cubren el servicio compartido.

### RF-24 · Procedencia de tienda en la semilla y en Firestore

Origen: D-08; casos 7 y 8 de CHAR-03 (RF-16).

**Hechos (los confirmó CHAR-03):**
- La semilla del asset (`catalog_repository.dart:101-109`) y cada snapshot de Firestore (`realtime_catalog_repository.dart:121-129`) guardan la metadata sin `shopDomain`. `_writeMetadata` (`catalog_cache_store.dart:224-237`) escribe ese `null`.
- `_cursorForConfiguredShop` (`catalog_repository.dart:283-311`) compara el dominio configurado con el del cursor y con el de la metadata. Una metadata sin tienda cuenta como otra tienda y dispara `resetShopState`.
- Efectos:
  - con Firestore activo y dominio configurado, cada arranque posterior a un snapshot borra cuenta, sesión, bolsa, favoritos y pedidos (caso 7);
  - en una instalación nueva, el primer sync borra la semilla antes de intentar la red. Si falla, el segundo arranque sin red queda sin catálogo (caso 8).
- El asset declara su origen: `"_source": "https://monetta.mx/products.json?"` en `assets/catalog/catalog.json`.

**Orden de trabajo:**
1. `test-engineer` escribe la versión objetivo (roja) de los casos 7 y 8:
   - tras un snapshot de Firestore, arrancar con la misma tienda no hace reset ni pierde filas;
   - en una instalación nueva, un primer sync fallido conserva la semilla, y el segundo arranque sin red muestra ese catálogo.
2. `flutter-implementer` hace la corrección.

**Decisión de diseño:** qué tienda registra la metadata de la semilla (la del `_source` del asset o la configurada) y la de Firestore (la del cursor, la configurada o la de la metadata anterior). El orquestador la recomienda al empezar el WP y se la muestra a la persona.

**Restricciones:**
- Invariante 1: no cambia cómo se deriva ni cómo se normaliza el dominio configurado (E11).
- Los demás casos de CHAR-03 siguen verdes sin cambios: reset ante otra tienda (también si sólo cambian las mayúsculas), ningún reset con dominio `null` y borrado del estado sin procedencia (regla de PR7).
- Los casos 7 y 8 cambian de nombre y de aserciones de forma explícita, con la delta en la bitácora.
- Firestore sigue experimental (E3): la corrección no lo activa.

**Alcance:**
- `lib/data/repositories/catalog_repository.dart` y `lib/data/repositories/realtime_catalog_repository.dart`;
- `lib/app/catalog_store.dart`, sólo si hace falta pasarle la tienda;
- sus pruebas, incluidos los casos 7 y 8 de `test/data/local/shop_scope_characterization_test.dart`.

**Aceptación:** los casos 7 y 8 en su versión objetivo, en verde; el resto de CHAR-03 sin cambios; INV-04 e INV-05 verdes; G4.

### RF-19 · Mínimo iOS 15.0 para Xcode 27

Origen: G6 iOS de RF-00; decisión D-03.

**Hecho:** Xcode 27.0 trata como error cualquier mínimo de iOS por debajo de 15.0. El proyecto declara 13.0, y sus pods, de 9.0 a 13.0 (`build/g6_ios.log` de RF-00).

**Cambios:**
- `ios/Podfile:2`: `platform :ios, '15.0'`.
- En el `post_install` de `ios/Podfile`, subir a 15.0 cada pod con un mínimo menor, sin bajar los que ya piden más.
- `ios/Runner.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 15.0` en las 6 configuraciones (líneas 505, 687, 738, 846, 894 y 945).
- `ios/Podfile.lock`: lo regenera `pod install`, que corre la persona porque el sandbox no tiene red.

**Aceptación:**
- G6 iOS y Android en verde, ejecutados por la persona, sin ningún `error:` de deployment target en el log;
- G0, G1, G2, G4 y G5.

**Impacto:** quien siga en iOS 13 o 14 ya no podrá instalar la app. No queda fuera ningún modelo de iPhone ni de iPad, porque iOS 15 corre en los mismos equipos que iOS 13.

### RF-20 · Eliminar el catálogo externo de la app

Origen: R02; requiere E2.

**Cambios:**
- Borrar del árbol:
  - `lib/data/external_catalog/`;
  - `app/external_catalog_controller.dart`;
  - `app/mixed_feed.dart`;
  - `features/home/external_catalog_section.dart`;
  - `features/product/external_product_screen.dart`;
  - `reco/external_facets.dart`;
  - sus pruebas.
- Reemplazar `fullDeduplicatedCatalog` y `catalogItems` por `Product` en el inicio y en la colección.
- Reducir `domain/catalog_item.dart` a lo que siga en uso.
- Mover `Money` y su formateo a un módulo propio, como antesala de RF-60.

**Aceptación:** ARCH-03, con la delta del conteo de pruebas registrada.

**Detalle (2026-10-08, al empezar el WP):**
- **Hechos:**
  - El catálogo externo ya está desconectado en ejecución: `ExternalCatalogConfig.fromEnvironment()` devuelve `disabled`, el inicio pasa `externalItems: const []` y `main.dart:831` ignora las rutas `external:*`. Es código muerto: unas 1 670 líneas en sus módulos.
  - `CatalogItem` sigue vivo en el navegador del catálogo completo (`catalog_browse_screen.dart`), en `ProductTileData.fromCatalogItem` y en `CatalogStore.catalogItems`.
  - Las tarjetas del navegador usan `formatCatalogMoney` («$1,749 MXN»), sin etiqueta de descuento, sin precio tachado y sin «NUEVO». Las demás rejillas usan `fromProduct` («$ 1,749.00», con descuento, «NUEVO» y color en el nombre).
- **Partes, en serie, en el mismo árbol** (ARCH-03 queda en rojo hasta la última):
  - **A · `test-engineer`:** ARCH-03 (OBJ) y una caracterización del navegador alcanzado desde la UI.
  - **B · `flutter-implementer`:** borra los módulos externos y sus pruebas, y quita las ramas externas del navegador, de la tarjeta y del store.
  - **C · `flutter-implementer`:** pasa el navegador, el inicio y la colección a `Product`; retira `CatalogItem` y su mapper; mueve `Money` y su formateo a un módulo propio.
- **Contrato con el backend:** `showExternalPicks` (ajustes del inicio en el admin) y `AdminChannel.externalCatalog` (auditoría `external_source`) se quedan hasta RF-21. Quitarlos antes no sería aditivo. ARCH-03 los admite explícitamente hasta entonces, junto con la guarda de `RuntimeConfig` y de `dart_defines_validation`.
- **Pendiente con la persona:** el aspecto de las tarjetas del catálogo completo (D-10).
- **Gates:** G6, que ejecuta la persona.

### RF-21 · Eliminar el catálogo externo del admin backend

Origen: R02; requiere E2.

**Cambios:** retirar `externalCatalogClient.ts`, sus rutas (`admin/routes.ts:270,506,888`), la configuración `catalogMonitor*` y sus pruebas.

**Aceptación:** G4 del backend y G7.

**Detalle (2026-10-08, al empezar el WP):**
- **Hallazgo:** el admin de la app conserva la gestión de fuentes externas. Son `AdminSourcePolicy`, `ExternalSourceAdminClient` (`updateSourceCanonical` → `PUT /admin/external-policy/:id`), `AdminController.sources`/`saveSource`, `AdminControlSnapshot.sources`/`sourcesHealthStatus` y la capacidad `manageExternalSources`. RF-20 no la cubrió porque la lista de ARCH-03 no tenía esos nombres. No tiene interfaz: la capacidad siempre es `false`.
- **Hechos del backend:**
  - El control-plane devuelve `sources` y `health.sources`; la app los lee con valores por defecto.
  - `GET/PUT /admin/external-policy/:id` responden con errores propios (`EXTERNAL_SOURCE_NOT_FOUND`, `EXTERNAL_CATALOG_NOT_CONFIGURED`).
  - `POST /admin/sync` acepta `external-status` («para reintentos de clientes viejos»).
  - `loadConfig` rechaza un `CATALOG_MONITOR_BASE_URL` inválido.
  - La migración `009` permite `external-status` en un CHECK.
- **Partes, en serie, en la misma rama:**
  - **A · `test-engineer`:**
    - amplía ARCH-03 con los nombres de fuentes externas del admin de la app;
    - escribe CONTRACT-06 (OBJ) en el backend.
  - **B · `flutter-implementer`:** retira de la app la gestión de fuentes externas. Va primero porque es aditivo: el backend todavía las sirve.
  - **C · `backend-implementer`:**
    - retira el cliente, las rutas, el canal `external-status`, la auditoría `external_source` que emitían esas rutas, la configuración `CATALOG_MONITOR_*`, `manageExternalSources` y sus pruebas;
    - los trabajos de sync ya guardados con `external-status` deben seguir leyéndose.
- **Se queda:**
  - `showExternalPicks`: el backend lo exige en el PUT de ajustes del inicio. Quitarlo exige primero un backend que lo acepte opcional, desplegado antes que la app;
  - `AdminChannel.externalCatalog`, que etiqueta la auditoría histórica `external_source`;
  - la migración `009`, que no se edita (invariante 2).
- **Gates:**
  - App: G0–G5.
  - Backend: G4 (`test`, `typecheck`, `build`) y G7, ejecutados por el orquestador si hay Postgres local.

### RF-22 · Dependencias sin uso, Makefile y docs

Origen: R04, H15.

**Cambios:**
- Retirar `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `riverpod_lint`, `custom_lint`, `go_router`, `freezed`, `freezed_annotation`, `json_serializable` y `json_annotation`. Antes, confirmar con `grep` que siguen sin uso.
- Corregir `README.md` y `docs/ARCHITECTURE.md`.

**Aceptación:**
- `flutter pub get` sin conflictos;
- `dart run build_runner build --delete-conflicting-outputs` produce un `database.g.dart` idéntico;
- G6.

### RF-23 · Retirar `functions/`

Origen: R07.

**Requisito previo (D-02):** la persona confirma que ninguna suscripción de webhook ni ningún despliegue usa Functions. Para eso revisa Monetta Staging, Monetta real y sus apps instaladas, y registra topic, URL de destino y app responsable. RF-00 sólo registró que no hay Functions vivas conocidas y que ningún `shopify/*.toml` apunta a ellas.

**Cambios:** retirar el directorio, `firebase.json` en lo que toque a Functions, el job del CI y `make test-services`.

### RF-30 · Composición fuera de `main.dart` y sobre el Navigator

Origen: R18.

**Cambios:**
- Crear `lib/app/composition/` (construcción, alcance y cierre de las dependencias).
- Mover los scopes ahí, con los mismos nombres y la misma API, reexportados para no romper las pruebas que los montan: eran 24 en la revisión y son 39 archivos el 2026-10-09.
- Montar todas las dependencias de la app por encima del Navigator.
- `main.dart` queda sólo con `bootstrap()`.
- Sin dependencias nuevas.

**Aceptación:** ARCH-01 y ARCH-04 en verde; INV-02, INV-07, INV-11 e INV-13 verdes; G6.

### RF-31 · `AppDestination` y resolver de notificaciones

Origen: R06; alcance según E6.

**Cambios:**
- `sealed class AppDestination`.
- Un resolver que use tanto las notificaciones como los helpers `open*`.
- Las pantallas «destino no disponible» y «artículo ya no disponible», reutilizando la de RF-11.
- El origen de la navegación (push, búsqueda, colección…) llega disponible para RF-67.

**Aceptación:** CHAR-02 y CHAR-09 en verde; DEV-01 y DEV-02, sólo los pasos de push.

**Detalle (2026-10-09, al empezar el WP):**
- **Hoy:** una notificación de un producto que no está en caché, o de un `external:*`, vuelve al inicio en silencio (`lib/app/monetta_app.dart:93-128`).
- **Mecanismo de resolución:** `CatalogStore.syncWithShopify()`, que ya pasa por el coordinador. No hay consulta nueva ni escritor nuevo (invariante 5).
  - Si después de sincronizar el producto aparece, se abre la ficha.
  - Si el resultado es `updated` o `upToDate` y no aparece, se muestra «Este artículo ya no está disponible» (RF-11).
  - Si es `failed`, `skippedNotConfigured`, `skippedRealtimeAuthoritative` o una excepción, se muestra «No se pudo comprobar este artículo» con «Reintentar».
  - Un `external:*` muestra «Enlace no disponible».
- **API:** `AppDestination` (sellada, con `NavigationOrigin` para RF-67) y `DestinationNavigator.open`, en `lib/app/destinations/`. Los helpers `openProduct` y `openCollection` delegan en ella y conservan `monettaFadeRoute` y el envoltorio de `StoreScope`.
- **Pruebas:** CHAR-02 se escribe contra la API nueva y no compila hasta la implementación (precedente de RF-15). El orquestador verifica con stubs temporales que falla por comportamiento.

### RF-32 · `ShopperScope` y `ChangeAccountScope`

Origen: R17.

**Cambios:**
- Un Value Object que una la tienda y la cuenta.
- El caso de uso `ChangeAccountScope` reemplaza el callback de `main.dart:697-703`.
- Mantener el guard contra respuestas tardías.

**Aceptación:** INV-02 e INV-08 verdes, más una prueba nueva de cambio A→B con hidratación lenta.

### RF-33 · Pruebas de arquitectura en trinquete

**Cambios:** ARCH-02 y ARCH-04, con su lista de excepciones explícita, y ampliar INV-12 a los directorios nuevos.

## Detalle de los WPs de la fase 4 (aprobado por la persona el 2026-10-09)

Borrador del orquestador del 2026-10-09, escrito sobre el código de `471167a`.
- La persona lo revisa antes de empezar la fase, que espera el lanzamiento (E1).
- Las líneas citadas se vuelven a verificar al encargar cada WP.

### RF-40 · Consultas puras del catálogo

Origen: H04 y R05 (el piloto).

**Hechos:**
- `lib/features/catalog/catalog_query.dart:17-60` ya concentra el emparejador de búsqueda: `productSearchTerms`, `searchProducts` y `productMatchesAnyTerm`. Pero recibe `CatalogStore` e importa `app/`.
- El filtro de colección vive dentro de la pantalla (`collection_screen.dart:205-224`). Combina tres cosas: la categoría por facetas, la regla de `collectionHandles` (CHAR-07) y los términos.
- El navegador del catálogo filtra y ordena en `catalog_browse_screen.dart:1153-1193`.
- Las facetas son `CanonicalFacets` (`lib/data/normalize/facets.dart:70`) y viven en `CatalogStore.facetsById` (`catalog_store.dart:130`).

**Cambios:**
- Un módulo de consultas puras: búsqueda, filtro de colección, y filtro y orden del navegador.
  - Recibe productos y facetas (`Iterable<Product>` y `Map<String, CanonicalFacets>`), sin `CatalogStore` ni Flutter.
  - Su ubicación (`lib/domain/` o junto a `lib/data/normalize/`) depende de los tipos que use. Entra en la prueba de pureza (INV-12).
- `catalog_query.dart` y las tres pantallas delegan en él (patrón estrangulador). Las firmas públicas se conservan hasta RF-41.

**Pruebas primero:**
- CHAR-12 (CAR): la búsqueda vigente sobre el catálogo del asset. Cubre la normalización, los términos de facetas y que una consulta vacía no devuelve nada.
- CHAR-13 (CAR): el filtro y el orden vigentes del navegador.
- CHAR-07 ya fija la regla de colección. Cambia sólo si D-13 lo decide.

**Aceptación:**
- CHAR-07, CHAR-12 y CHAR-13 en verde sobre el módulo puro;
- INV-04, INV-05, INV-12 e INV-14 verdes.

**Diseño al empezar (2026-10-09):**
- El módulo puro va en `lib/features/catalog/query/`:
  - no importa Flutter, `CatalogStore` ni `composition/`; lo vigila una regla nueva de INV-12;
  - recibe `Iterable<Product>` y `Map<String, CanonicalFacets>` (o una función de búsqueda de facetas);
  - usa las etiquetas de `app/shopper_copy.dart` y `reco/explainer.dart`, que no importan Flutter.
- `normalizeSearchText` y `CollectionFilter` se mudan ahí. `search_history.dart` y `collection_screen.dart` los reexportan, así que su API pública no cambia.
- `_filterCatalog` del navegador y sus tipos privados (`_CatalogFilters` y `_CatalogSort`) pasan a ser públicos en el módulo.
- Patrón estrangulador: las funciones de `catalog_query.dart` que reciben `CatalogStore` quedan como envoltorios que delegan en las puras, hasta RF-41.

### RF-41 · ViewModels del piloto

Origen: R05 (ADR-02 modificado).

**Hechos:**
- El estado vive en 11 `ChangeNotifier` de `lib/app/`, expuestos con scopes `InheritedNotifier`:
  - `CatalogStore`, `AccountController`, `CartController` y `FeaturedCatalogController`;
  - `NotificationController` y `AdminNotificationController`;
  - `OnboardingController`, `EditorialContentController` y `HomeContentController`;
  - `AdminController` y `ThemeController`.
- Las pantallas del piloto llevan la lógica dentro: `catalog_browse_screen.dart` (1 260 líneas), `collection_screen.dart` (1 123), `search_screen.dart` (1 019) y `product_screen.dart` (1 207).

**Cambios:**
- Un ViewModel por pantalla del piloto, en `<feature>_view_model.dart`: `ChangeNotifier`, estado inmutable y `Command` para las acciones, con las consultas de RF-40.
- La inyección sigue con los scopes actuales: no hay dependencias nuevas durante el piloto.
- Se miden las reconstrucciones de las cuatro pantallas antes y después.
- Para RF-43 se registran dos cosas:
  - los ciclos de vida por parámetro que no se resuelvan con dependencias por ruta;
  - los errores por un `dispose` olvidado.

**Aceptación:**
- Las pruebas existentes de las cuatro pantallas pasan adaptadas, no reescritas. Se cuentan unas y otras.
- INV-02, INV-04 e INV-14 verdes.
- G6.

### RF-42 · Upsert de destacados a través del coordinador

Origen: R08 (ADR-06 modificado). Decisiones E3 y E10.

**Hechos:**
- `CatalogStore.upsertShopifyProducts` (`catalog_store.dart:326-333`) escribe en la caché con `cache.upsertProducts` sin pasar por `CatalogWriteCoordinator` (`lib/data/repositories/catalog_write_coordinator.dart:13`). Es la excepción conocida del invariante 5.
- La cablea `main.dart:515` como `cacheProducts` de `FeaturedCatalogController` (`featured_catalog_controller.dart:16-22`).
- Las demás escrituras pasan por el repositorio (`catalog_repository.dart:171` y `:251`).

**Cambios:**
- El upsert de destacados pasa por el coordinador, con la autoridad de E3 (sólo `storefrontDirect`) y la política de vacío de E10.
- Una prueba de fuente (ARCH-05, TRQ) impide escrituras directas nuevas a la caché fuera del repositorio.

**Aceptación:**
- en verde, la caracterización previa del upsert (CHAR-14) y su versión a través del coordinador;
- ARCH-05;
- INV-04 e INV-05 verdes;
- el invariante 5 de `CLAUDE.md` queda sin excepción.

### RF-43 · Gate de decisión de inyección de dependencias

Origen: R05.

**Trabajo del orquestador:**
- Evaluar los criterios de R05 con la evidencia de RF-41: los ciclos de vida por parámetro (family o autoDispose) y los errores por un `dispose` olvidado.
- Presentar las opciones a la persona, con el costo de cada una medido sobre las 24 pruebas que montan scopes:
  - conservar los scopes actuales;
  - `provider` 6.1.5+1;
  - Riverpod.

**Salida:** la decisión, registrada en la tabla. Si la inyección cambia, se crea un WP nuevo antes de la fase 5.
