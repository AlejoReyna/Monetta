# Monetta — guía para Claude Code

**Qué es:** app Flutter **sólo para iOS y Android** de la tienda Shopify monetta.mx. Nunca uses Flutter web ni instales Chrome.

**Piezas del repositorio:**
- `services/accounts_orders/`: backend propio (Node + Express + Postgres; staging en Fly.io).
- `api/` y `server/catalog/`: espejo de catálogo en Vercel.
- `web/`: galería de capturas hecha con Vite. No es la app.
- `services/catalog_monitor/` y `dashboard/`: retirados.

**Toolchain fijado:** Flutter 3.44.8 vía fvm (`.fvmrc`), Dart 3.12.2, Node 24 y Postgres 16 en CI. No actualices dependencias salvo que un WP lo pida.

**Documentación:**
- `docs/SYSTEM_IMPLEMENTATION.md`: descripción vigente del sistema.
- `docs/ARCHITECTURE.md` y `README.md`: desactualizados hasta RF-22.

## Programa activo: refactor in situ (no rebuild)

- La persona eligió refactorizar el árbol actual. La reconstrucción aislada (ADR-01 de `docs/PROPUESTA_RECONSTRUCCION_MVVM.md`) está **rechazada**.
- Hallazgos y decisiones de diseño: `docs/REVISION_PROPUESTA_RECONSTRUCCION_MVVM.md` (R01–R20, tabla de ADR, decisiones E1–E12).
- Plan, estado de los WP y decisiones tomadas: `.claude/refactor/PLAN.md`.
- Gates y filas de prueba: `.claude/refactor/MATRIZ_DE_PRUEBAS.md`.
- Encargos a subagentes: `.claude/refactor/PLANTILLA_ENCARGO.md`.
- Registro de auditorías: `.claude/refactor/BITACORA.md`.
- Punto de entrada del bucle: `/refactor [estado | siguiente | RF-XX | auditar]`.
- **Regla de oro:** cada WP deja la suite verde y la app liberable. Se sigue el patrón estrangulador:
  1. crear lo nuevo;
  2. hacer que lo viejo delegue en lo nuevo;
  3. migrar las llamadas;
  4. borrar lo viejo.

## Roles

### Sesión principal: orquestador y auditor principal

Si eres un subagente, salta esta sección: tus reglas están en tu archivo de `.claude/agents/`.

1. **Planea con `PLAN.md`.** No empieces trabajo que dependa de decisiones pendientes o de WPs abiertos. RF-00 es la excepción de preparación: puede verificar el entorno, medir la línea base y recoger el inventario mientras consulta E1, E2, E3 y E5. No adoptes sus recomendaciones por defecto ni lo marques aprobado hasta registrar las decisiones de la persona y cumplir sus entregables. Para los demás WPs, consulta la decisión pendiente antes de empezar el trabajo dependiente.
2. **Delega el código extenso a subagentes Sonnet 5.5.** El modelo ya está fijado en sus archivos; no pases `model` al invocarlos.
   - `flutter-implementer`: Dart/Flutter en `lib/` y sus pruebas.
   - `backend-implementer`: TypeScript en `services/accounts_orders/`, `server/catalog/`, `api/` y `functions/`.
   - `test-engineer`: sólo pruebas (caracterización, contrato, escala de texto, goldens).
   - Delega cuando el cambio de código de producción toque más de un archivo o más de unas 30 líneas, cuando haya que escribir varias pruebas o en barridos mecánicos.
   - Tú mismo puedes hacer los cambios pequeños, el CI, la documentación y la matriz.
3. **Un encargo = un WP**, o una parte declarada de él. El encargo debe ser autocontenido según la plantilla: el subagente no ve esta conversación. Los subagentes corren en segundo plano: espera su notificación y no hagas sondeo.
4. **Trabajo en serie por defecto.** En paralelo sólo cuando se cumplan las tres condiciones:
   - los WP tocan archivos disjuntos;
   - usas `isolation: "worktree"`;
   - la persona autorizó commits.
5. **Independencia entre prueba e implementación.** Si un WP cambia comportamiento:
   1. `test-engineer` escribe primero la prueba, roja (comportamiento objetivo) o de caracterización (comportamiento vigente);
   2. tú compruebas que falla por la razón correcta;
   3. sólo entonces encargas la implementación.
6. **Auditas todo.** El reporte de un subagente no cuenta como evidencia.
   - Ejecuta tú mismo los gates de la matriz.
   - Lee el diff completo.
   - Aplica el checklist de `/refactor`.
   - Clasifica cada hallazgo como Blocker, Alta, Media o Baja.
   - Con un Blocker o una Alta, el WP vuelve al subagente. Máximo 3 iteraciones; después, escala a la persona.
7. **Al cerrar un WP:**
   - actualiza su estado en `PLAN.md`;
   - actualiza sus filas en la matriz;
   - añade una entrada en `BITACORA.md` con cada comando ejecutado y su resultado.
8. **Commits sólo si la persona los pidió en esta sesión.** Usa la rama `refactor/rf-XX-<slug>`. Nunca en `main`. Nunca push.
   - Cuando se versione la preparación de `.claude/`, incluir también `docs/PROPUESTA_RECONSTRUCCION_MVVM.md` y `docs/REVISION_PROPUESTA_RECONSTRUCCION_MVVM.md`: esta guía los referencia.
   - `.claude/settings.local.json` es configuración local y queda excluido del commit.

### Subagentes

Obedecen su encargo y su archivo de agente. No editan `.claude/`, no hacen commit ni push, no despliegan y no invocan a otros agentes.

## Invariantes

Ningún cambio puede romperlos. Si un WP toca alguno, debe probarlo.

1. **Tienda.**
   - Si el `shopDomain` configurado difiere del persistido, `CatalogRepository` borra catálogo, bolsa, favoritos, sesiones y cuentas (`catalog_repository.dart:283-311`, `catalog_cache_store.dart:100-128`).
   - No cambies cómo se deriva o se normaliza el dominio sin un RF aprobado y la prueba CHAR-03.
2. **Base local.**
   - Archivo `monetta.sqlite` en el directorio de soporte de la app; `schemaVersion` 7.
   - Un cambio de esquema sólo entra con versión nueva, migración probada y dump de esquema.
   - Nunca edites un paso de migración existente.
3. **Credenciales.**
   - Los tokens van sólo en `flutter_secure_storage`; nunca en SQLite, logs ni analytics.
   - No renombres sus claves.
4. **Bolsa.**
   - Clave `(variantId, accountId)`; el invitado usa `''`.
   - La variante es exacta: nunca se sustituye.
   - Aplicar una compra es idempotente: `BagStore.applyPurchase` usa `checkout_receipts` dentro de una transacción.
5. **Autoridad del catálogo.**
   - Las escrituras a la caché pasan por `CatalogWriteCoordinator`. Hay una excepción conocida (R08); no añadas otras.
   - Una sincronización incompleta nunca reemplaza la caché.
6. **Dinero.**
   - Los importes del carrito Shopify viajan como cadenas decimales (`CartMoney`).
   - Ningún total comercial se calcula con `double`.
   - Los importes de Rewards los decide el servidor.
7. **Identidad.** Los GID de Shopify son la identidad canónica en la app. El número visible de un pedido no es su identidad.
8. **Checkout.**
   - La UI depende de `CheckoutLauncher`, nunca del SDK de Checkout Kit.
   - La URL de checkout no se registra ni se persiste.
9. **Cambio de cuenta.**
   - Login, logout o cambio de cuenta invalidan el checkout precargado y reasignan el alcance de bolsa, favoritos e historial de búsqueda (hoy en `main.dart:697-703`).
   - Un resultado tardío de la cuenta A nunca se aplica a la cuenta B.
10. **Catálogo externo retirado.**
    - `ENABLE_EXTERNAL_CATALOG` sigue rechazado.
    - Ninguna llamada a hosts retirados.
11. **Atribución.** Todo carrito lleva `_channel`, `_platform`, `_device_id`, `_app_version` y `_rec_source`. Es un requisito comercial.
12. **Admin.** La autoridad la tiene el servidor. La lista de correos del cliente sólo sirve a la UX.
13. **Pureza.** `lib/reco`, `lib/data/normalize`, `lib/data/shopify` y `lib/domain` no importan Flutter (lo verifica `test/architecture_test.dart`).
14. **Fuera de límites.** Prohibido:
    - desplegar (fly, vercel, firebase);
    - migrar bases remotas;
    - tocar secretos o archivos `.env` reales;
    - modificar `.claude/settings*.json`.

## Comandos

| Gate | Comando |
|---|---|
| Dependencias | `flutter pub get --offline` |
| Formato | `dart format --output=none --set-exit-if-changed lib test integration_test` |
| Análisis | `flutter analyze --no-pub` |
| Pruebas de la app | `flutter test --no-pub` (o rutas concretas) |
| Catálogo | `dart run bin/verify_catalog_snapshot.dart` |
| Secretos | `./bin/check_no_secrets.sh` |
| Backend | `npm --prefix services/accounts_orders test`, `… run typecheck`, `… run build` |
| Backend con Postgres | `REQUIRE_POSTGRES_TESTS=1 WP01_PG_ADMIN_URL=postgres://postgres:postgres@localhost:5432/postgres npm --prefix services/accounts_orders test` |
| Espejo de catálogo | `npm run test:api`, `npm run typecheck:api` |
| Compilación Android | `flutter build apk --no-pub --debug --flavor staging --dart-define-from-file=config/dart_defines.ci.json` |

## Entorno

**Sandbox.** Con el sandbox de Bash activo:
- `flutter` necesita escribir en `~/fvm/versions/3.44.8/bin/cache` y en `~/.pub-cache`;
- las pruebas del backend necesitan abrir puertos locales;
- Dart no tiene red: el proxy rompe el TLS con `pub.dev` y `storage.googleapis.com` («Handshake error in client»). Resuelve con `flutter pub get --offline` y pasa `--no-pub` a `flutter analyze`, `test` y `build`. Sin `--no-pub`, el `pub get` implícito se queda colgado en «Resolving dependencies...» (RF-00).

La persona autorizó preparar `.claude/settings.local.json` con esas rutas, `~/.dartServer`, `~/.dart-tool` y `sandbox.network.allowLocalBinding = true`. RF-00 debe comprobar que Claude carga la configuración y que los gates pueden ejecutarse; la existencia del JSON no demuestra que las pruebas hayan pasado. Este permiso local no modifica el sandbox de otras aplicaciones. Si la configuración del proyecto no tiene efecto, registrar la causa antes de plantear el fallback en `~/.claude/settings.json`.

Si un gate falla por el sandbox, **no es un resultado de prueba**:
1. márcalo «no ejecutado»;
2. cita el error exacto;
3. pide a la persona que lo habilite.

Nunca declares aprobado un gate que no ejecutaste.

**Dispositivo.** La verificación en dispositivo (OAuth, checkout, push, tipografía) la hace la persona. Tú preparas el checklist DEV-xx y registras su respuesta.

## Estilo

- Comentarios y nombres en inglés, como el código vecino. Textos de UI en español. Documentos del refactor en español.
- `analysis_options.yaml` es estricto: nada de `// ignore`, nada de `skip:` en pruebas y no se debilitan pruebas existentes.
- Conserva las firmas públicas salvo que el WP diga otra cosa.
