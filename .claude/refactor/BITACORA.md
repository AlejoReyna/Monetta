# Bitácora de auditoría del refactor

Registro de solo anexado: no se borra ni se reescribe ninguna entrada. Cada iteración de auditoría añade una entrada nueva y la más reciente va al final.

## Formato de cada entrada

```markdown
### AAAA-MM-DD · RF-XX · iteración N · VEREDICTO
- **Agente(s):** flutter-implementer | backend-implementer | test-engineer | orquestador
- **Base:** `git rev-parse --short HEAD` → …
- **Archivos del diff:** …
- **Gates (ejecutados por el auditor):**
  - G0 … → resultado
  - G1 … → resultado
  - G2 …
  - G3 …
  - G4 … → N pruebas aprobadas, M fallidas (base: …)
  - G5 …
  - G6/G7/G8: aplica o no aplica, con resultado
- **Filas de la matriz:** ID → estado (rojo, verde o no aplica), con la evidencia
- **Hallazgos:**
  - [Blocker | Alta | Media | Baja] `archivo:línea` — descripción — corrección
- **Decisiones de la persona en esta iteración:** …
- **Commit:** no autorizado | `<hash>` en `refactor/rf-XX-…`
- **Siguiente paso:** …
```

Los veredictos posibles son APROBADO, RECHAZADO, BLOQUEADO y NO EJECUTADO.

Un gate que no corrió se escribe así: `G4 → NO EJECUTADO (sandbox: <error literal>)`. Nunca se omite.

## Entradas

### 2026-10-06 · Preparación del programa · orquestador

Se crearon `.claude/CLAUDE.md`, `.claude/agents/`, `.claude/skills/refactor/` y `.claude/refactor/`, a partir de `docs/REVISION_PROPUESTA_RECONSTRUCCION_MVVM.md`.

Ningún gate se ejecutó. En la sesión de revisión, el sandbox impidió correr `flutter`, porque no puede escribir en la caché del SDK. En el backend, 58 pruebas fallaron por `listen EPERM` (bloqueo de puertos locales del sandbox) y 53 pasaron; las 9 de Postgres se omitieron.

**Siguiente paso:** RF-00.

### 2026-10-06 · Preparación del sandbox para Claude · NO EJECUTADO

- **Autorización:** la persona confirmó refactor in situ y pidió preparar los permisos locales de caché Flutter/Dart y apertura de puertos del backend.
- **Configuración:** se creó `.claude/settings.local.json` con las cuatro rutas solicitadas y `sandbox.network.allowLocalBinding = true`; quedó excluido de Git.
- **Flujo:** se aclaró que RF-00 puede preparar entorno y medir la línea base antes de recoger E1, E2, E3 y E5. Esas decisiones siguen pendientes y no se adoptaron sus recomendaciones.
- **Versionado futuro:** la guía exige incluir los documentos de propuesta y revisión cuando se haga un commit autorizado de `.claude/`; el archivo local de settings queda fuera.
- **Validación de preparación:** un script Python comprobó que el JSON coincide con los permisos solicitados y que existen los dos documentos referenciados; `git check-ignore -v .claude/settings.local.json` confirmó su exclusión y `git diff --check` no reportó errores. La carga efectiva y la ejecución de las suites en el sandbox de Claude quedan para RF-00.
- **Gates:** no se ejecutaron suites ni se inició RF-00 en esta preparación.
- **Commit:** no realizado.
- **Siguiente paso:** invocar `/refactor` en Claude Code para empezar RF-00.

### 2026-10-06 · RF-00 · iteración 1 · BLOQUEADO

- **Agente(s):** orquestador.
- **Base:** `git rev-parse --short HEAD` → `48a6786` al empezar (igual que `main` y `origin/main`). `git status --porcelain` → WIP de Rewards (6 archivos de `services/accounts_orders/` más `.gitignore`), y `.claude/` y los dos docs sin versionar. El WIP quedó en `07846f6` (`monetta/rewards-default-off`); RF-00 sigue en `refactor/rf-00-baseline`, creada desde `07846f6`.
- **Archivos del diff:**
  - Commit del WIP (`07846f6`): `services/accounts_orders/{.env.example, fly.toml, src/config.ts, src/rewards/rewardsConfig.ts, test/rewardsApi.test.ts, test/rewardsService.test.ts}`.
  - Commit de RF-00: `.claude/` (sin `settings.local.json`, que ignora `.gitignore`), los dos docs de la propuesta y la revisión, `.gitignore`, `drift_schemas/drift_schema_v7.json`, y `README.md` y `services/accounts_orders/README.md`. Los README los editó la persona (Postgres 16 local para G7 y Postgres en producción) y pidió incluirlos.
  - En `.claude/`, esta iteración añade `--no-pub` a los comandos `flutter` de `CLAUDE.md`, de `flutter-implementer.md`, de `test-engineer.md` y de los gates G2, G3, G4 y G6 de la matriz; agrega la fila «Dependencias» (`flutter pub get --offline`) y la nota del sandbox; registra E1, E2, E3 y E5 en `PLAN.md`, y crea la sección 7 de la matriz con los conteos base.
  - En `docs/PROPUESTA_RECONSTRUCCION_MVVM.md:3-5`, los saltos de línea duros (dos espacios finales) se cambiaron por `\` para que `git diff --check` pase. Se ven igual.
- **Entorno y sandbox:**
  - `flutter --version` → Flutter 3.44.8 y Dart 3.12.2.
  - `node --version` → v26.10.0, con npm 11.19.1. CI usa Node 24, y `npm ci` avisa `EBADENGINE`: la raíz pide `24.x` y `functions/` pide `22`.
  - Postgres 16.15 (Homebrew), levantado por la persona y comprobado con `select version()` vía `pg`.
  - `.claude/settings.local.json` sí se carga:
    - las cuatro rutas de caché aparecen en la lista de escritura del sandbox;
    - `allowLocalBinding` funciona: el backend pasa sin `listen EPERM`, cuando en la revisión fallaban 58 pruebas por eso.
  - `flutter doctor -v`:
    - `Unable to locate Android SDK`;
    - Xcode 27.0 pide `sudo xcodebuild -runFirstLaunch`;
    - `Handshake error in client` con `pub.dev` y `storage.googleapis.com`, aunque estaban permitidos;
    - `Proxy failed to establish tunnel (403 Forbidden)` con `maven.google.com`, `cocoapods.org` y `github.com`.
  - Dart no tiene red en el sandbox:
    - `flutter pub get` quedó 16 min en «Resolving dependencies...» y se detuvo;
    - `flutter analyze` repitió el bloqueo con su `pub get` implícito y también se detuvo;
    - `ps` y `pgrep` no están permitidos, así que no se pudo confirmar que esos procesos terminaran.
  - Solución de trabajo:
    - los 201 paquetes del `pubspec.lock` están en `~/.pub-cache`;
    - `flutter pub get --offline` → exit 0;
    - todos los comandos `flutter` llevan `--no-pub`.
  - Node sí descarga de `registry.npmjs.org`, con la caché npm en el scratchpad.
- **Gates (ejecutados por el auditor):**
  - G0 `git status --porcelain` · `git diff --cached --stat` · `git diff --cached --check`:
    - sólo los archivos listados arriba;
    - `--check` reportó espacio final en `docs/PROPUESTA_RECONSTRUCCION_MVVM.md:3-5`; tras la corrección, limpio;
    - `settings.local.json` no está en el índice.
  - G1 `dart format --output=none --set-exit-if-changed lib test integration_test` → exit 0; 300 archivos, 0 cambiados.
  - G2 `flutter analyze --no-pub` → «No issues found!».
  - G3 → no aplica: RF-00 no tiene filas propias.
  - G4 Flutter `flutter test --no-pub --reporter expanded` → exit 0:
    - **705 aprobadas, 5 omitidas, 0 fallidas**;
    - 123 archivos `*_test.dart`.
  - G4 backend:
    - `npm --prefix services/accounts_orders test` → **111 aprobadas, 9 omitidas** (los 3 `*.pg.test.ts`) en 22 archivos. Incluye las 2 pruebas que añade el WIP.
    - `… run typecheck` → exit 0; `… run build` → exit 0.
    - `node --test tools/audit/test/shopifyAdapter.test.mjs` (paso del job de CI) → 8 aprobadas.
  - G4 espejo: `npm ci` → exit 0; `npm run test:api` → **19 aprobadas** (5 archivos); `npm run typecheck:api` → exit 0.
  - `functions/`: `npm ci` → exit 0; `npm --prefix functions test` → **13 aprobadas** (3 archivos); `… run typecheck` → exit 0; `… run build` → exit 0.
  - G5:
    - `dart run bin/verify_catalog_snapshot.dart` → **exit 2**: «El snapshot excede 14 días de antigüedad» (`_snapshot` = `2026-09-15`, 21 días);
    - `./bin/check_no_secrets.sh` → exit 0 (antes de cada commit).
  - G6 Android `flutter build apk --no-pub --debug --flavor staging --dart-define-from-file=config/dart_defines.ci.json` → **NO EJECUTADO**:
    - sandbox: `Failed to download https://storage.googleapis.com/flutter_infra_release/flutter/0cd610717bde95fd88343c64f81c11ba4e5c0010/android-arm-profile/darwin-x64.zip` · `HttpException: Proxy failed to establish tunnel (403 Forbidden)`;
    - entorno: sin Android SDK.
  - G6 iOS `flutter build ios --no-pub --simulator --debug --dart-define-from-file=config/dart_defines.ci.json` → **NO EJECUTADO**:
    - sandbox: `xcodebuild: error: Could not resolve package dependencies: You don’t have permission to save the file “ManifestLoading” in the folder “manifests”`;
    - entorno: Xcode pide `xcodebuild -runFirstLaunch`.
  - G7 `REQUIRE_POSTGRES_TESTS=1 WP01_PG_ADMIN_URL=postgres://postgres:postgres@localhost:5432/postgres npm --prefix services/accounts_orders test` → exit 0; **120 aprobadas, 0 omitidas**, 22 archivos.
  - G8 → DEV-03 (capturas de referencia) pendiente de la persona.
  - Dump de esquema `dart run drift_dev schema dump lib/data/local/database.dart drift_schemas/` → `drift_schemas/drift_schema_v7.json`: 14 entidades, sin marcas de tiempo.
- **WIP de Rewards:**
  - `REWARDS_ENABLED = "true"` estaba en `fly.toml:67-69`, después de `[[http_service.checks]]`, y pertenecía a esa tabla.
  - Con autorización de la persona, se movió a `[env]`. Como Python 3.9 no trae `tomllib`, se comprobó con la última cabecera de tabla antes de la clave: `[env]`. En `HEAD`, la clave no existía.
  - Antes del commit: `git diff --check` limpio y `./bin/check_no_secrets.sh` con exit 0.
  - Riesgo vigente: cualquier entorno sin `REWARDS_ENABLED` arranca con Rewards apagado y cae en R11 hasta RF-13. Hoy sólo existe staging, que lo enciende.
- **Tag:** `baseline/48a6786`, anotado y local, sin push.
- **Inventario (respuestas de la persona y evidencia del repo):**
  - **Despliegues vivos:** Fly `monetta-accounts-staging` y Vercel (espejo `/api` y galería).
    - No hay backend de producción: `shopify/shopify.app.production.toml` sólo tiene `REPLACE_PRODUCTION_BACKEND_HOST`.
    - No hay confirmación de Firebase Functions vivas.
  - **Webhooks:** pendiente. La persona revisará en Monetta Staging, en Monetta real y en sus apps instaladas el topic, la URL de destino y la app responsable.
    - En el repo, `shopify.app.staging.toml` suscribe 7 topics a Fly.
    - `shopify.app.catalog-mirror.toml` apunta a `https://monetta-catalog-staging.vercel.app/api`, que la persona verificó el 27 de agosto.
    - Ningún TOML apunta a Firebase Functions. RF-23 sigue bloqueado hasta confirmarlo.
  - **Instalaciones reales:** pendiente; sólo hay evidencia documentada de desarrollo. Se conservan las migraciones existentes.
  - **Cuentas propias reales:** existen; la cifra está pendiente. También falta saber en qué base viven, porque el único backend vivo es staging.
- **Filas de la matriz:** RF-00 no tiene filas propias; sus conteos base quedan en la sección 7 de la matriz.
- **Hallazgos:**
  - [Alta] `assets/catalog/catalog.json` (`_snapshot` = `2026-09-15`):
    - G5 falla por antigüedad, así que ningún WP puede cerrarse y el job `flutter` del CI falla en cada PR;
    - corrección: la persona ejecuta `make refresh-catalog` fuera del sandbox (Dart no sale por el proxy) y se versiona en un commit aparte.
  - [Media] `services/accounts_orders/src/api/server.ts:389,411,443`:
    - `orders/cancelled`, `refunds/create` y `fulfillment_events/create` alimentan el ledger de Rewards, pero ningún `shopify/shopify.app*.toml` los suscribe; sin esas suscripciones, los créditos no se liberan ni se revierten;
    - corrección: confirmarlo en el inventario de webhooks y corregirlo en la pista de Rewards.
  - [Media] `services/accounts_orders/src/rewards/worker.ts:24-44`:
    - el advisory lock de sesión se toma y se libera con `pool.query`, que puede usar conexiones distintas (lo documenta el README de la persona);
    - corrección: un mismo cliente de `pool.connect()` para el lock, el mantenimiento y la liberación, antes de desplegar el worker; hoy no corre, porque `fly.toml` sólo declara el proceso `app`.
  - [Baja] `test/features/product/product_package_c_captures_test.dart:86,106,126,167` y `test/features/account/package_e_captures_test.dart:337`:
    - 5 pruebas con `skip: true`, contra la regla de estilo;
    - corrección: decidir en un WP si se borran o se sacan de `flutter test`. Mientras tanto, la base cuenta 5 omitidas.
  - [Baja] Node local v26.10.0 frente a Node 24 del CI. Todas las suites pasan; conviene usar Node 24 para tener paridad.
  - [Baja] `npm ci` en la raíz informa 6 vulnerabilidades (1 moderada, 3 altas y 2 críticas) en el árbol completo. El gate `npm audit --omit=dev --audit-level=moderate` del CI no se ejecutó aquí: no está en la lista de RF-00.
- **Decisiones de la persona en esta iteración:**
  - E1: sí, lanzar tras las fases 1–2.
  - E2: sí, con tag forense.
  - E3: sólo `storefrontDirect`.
  - E5: congelar el registro, inventariar y evaluar la migración.
  - Operación:
    - mover `REWARDS_ENABLED` a `[env]`;
    - commit del WIP en su rama y de RF-00 en `refactor/rf-00-baseline`, sin push;
    - crear el tag;
    - Postgres levantado por la persona para G7;
    - incluir sus cambios en los README.
- **Commit:** `07846f6` (WIP de Rewards en `monetta/rewards-default-off`). La preparación y RF-00 van en `refactor/rf-00-baseline`, en el commit que contiene esta entrada.
- **Pendiente para aprobar RF-00:**
  1. G5 de catálogo en verde, con el snapshot refrescado.
  2. G6: la persona decide cómo se ejecuta (entorno local habilitado, ejecución suya o evidencia de CI).
  3. DEV-03: capturas de referencia.
  4. Inventario de webhooks, instalaciones reales y ubicación de las cuentas propias.
- **Siguiente paso:** resolver los pendientes y cerrar RF-00 en la iteración 2. RF-10 a RF-18 esperan a que RF-00 esté aprobado.

### 2026-10-06 · RF-00 · iteración 2 · BLOQUEADO

- **Agente(s):** orquestador. La persona ejecutó en su terminal el refresco del catálogo y G6.
- **Base:** `a05639b`; el catálogo quedó en `b749abb` (`refactor/rf-00-baseline`).
- **Archivos del diff:**
  - `assets/catalog/catalog.json`, en el commit `b749abb`.
  - En este commit: `android/.gitignore` (añade `.kotlin/`), `.claude/refactor/PLAN.md` (D-02, requisitos movidos y estado de RF-00), `.claude/refactor/MATRIZ_DE_PRUEBAS.md` (excepción de G6; DEV-03 apunta al paso 0 de RF-17) y esta entrada.
- **Entorno:**
  - La persona instaló cmdline-tools 23.0, la plataforma `android-36` y el NDK `28.2.13676358`.
  - `flutter doctor -v` en el sandbox: detecta el SDK y Java (JBR 25 de Android Studio), pero dice «Android license status unknown», que no se puede verificar desde aquí. El proyecto usa Gradle 9.1.0 y AGP 9.0.1, compatibles con Java 25.
  - La persona ejecutó `sudo xcodebuild -runFirstLaunch` antes de G6. Sólo hay un Xcode instalado, el 27.0.
  - `xcrun simctl list runtimes` no conecta con CoreSimulatorService dentro del sandbox. `emulator -list-avds` → `Medium_Phone_API_37.0`.
- **Gates:**
  - **G5 catálogo** `dart run bin/verify_catalog_snapshot.dart` → exit 0: «Catálogo válido: 103 productos, 340 imágenes». La persona refrescó el snapshot (2026-10-06) con `make refresh-catalog`.
    - Revisión: salieron 33 productos y no entró ninguno. De esos 33, 31 tienen vendor «Monetta» (26 como «Monetta» y 5 como «Monetta », con espacio final), 1 Guess y 1 Steve Madden. Siguen las mismas 21 colecciones.
    - La descarga está completa: el script exige HTTP 200 y para en la primera página con menos de 250 productos, y aquí hubo una sola.
    - `git diff --check` limpio; `./bin/check_no_secrets.sh` → exit 0.
  - **G4 Flutter** con el catálogo nuevo, `flutter test --no-pub --reporter expanded` → exit 0; 705 aprobadas y 5 omitidas, igual que la base.
  - **G6 Android** (ejecutado por la persona): `flutter build apk --debug --flavor staging --dart-define-from-file=config/dart_defines.ci.json` → «✓ Built build/app/outputs/flutter-apk/app-staging-debug.apk» en 588.2 s. Gradle instaló por su cuenta Android SDK Platform 34 y 35 y CMake 3.22.1.
  - **G6 iOS** (ejecutado por la persona): `flutter build ios --simulator --debug --dart-define-from-file=config/dart_defines.ci.json` → **falla** con «Failed to build iOS app» y «Encountered error while building for simulator».
    - `pod install` tardó 801.4 s y Xcode, 15.5 s.
    - Los únicos problemas listados son de «Target Integrity (Xcode)»: «The iOS Simulator deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to 13.0 […] but the range of supported deployment target versions is 15.0 to 27.0.x», en `ios/Runner.xcodeproj`, y en `ios/Pods/Pods.xcodeproj` con valores de 9.0 a 13.0.
    - El proyecto declara 13.0 en `ios/Podfile:2` y en las 6 configuraciones de `ios/Runner.xcodeproj/project.pbxproj`. El `post_install` sólo llama a `flutter_additional_ios_build_settings`.
    - Causa probable, por confirmar con la salida detallada (`-v`): Xcode 27.0 no acepta mínimos de iOS por debajo de 15.0.
  - **Efectos de los builds en el árbol:** sólo `android/.kotlin/`, el marcador de sesión del daemon de Kotlin, que ninguna regla ignoraba; se añadió `.kotlin/` a `android/.gitignore`. `pod install` no cambió `ios/Podfile.lock`.
- **Hallazgos:**
  - [Alta] G6 iOS no compila con Xcode 27.0, el único instalado. Bloquea la aprobación de RF-00 y el cierre de cualquier WP con G6. Vías posibles, a decidir por la persona:
    - un WP que suba el mínimo a iOS 15.0;
    - instalar la versión de Xcode del CI;
    - usar el job `ios-compile` del CI como evidencia.
  - [Baja] Avisos del build de Android:
    - `firebase_analytics`, `firebase_remote_config`, `package_info_plus` y `share_plus` aplican el Kotlin Gradle Plugin («Future versions of Flutter will fail to build»);
    - `flutter_secure_storage` no soporta Swift Package Manager.

    No afectan a Flutter 3.44.8, pero importarán al actualizar la toolchain.
  - **Resuelto:** el hallazgo Alta de la iteración 1 sobre G5 de catálogo, con `b749abb`.
- **Decisiones de la persona en esta iteración:**
  - D-02: DEV-03 pasa al paso 0 de RF-17; los webhooks, a RF-23; las instalaciones reales, a RF-60, y las cuentas propias, a RF-62.
  - Commit del catálogo refrescado.
  - G6 se ejecuta en su terminal.
- **Commit:** `b749abb` (catálogo) y el commit que contiene esta entrada. Sin push.
- **Pendiente para aprobar RF-00:** G6 iOS.
- **Siguiente paso:** confirmar la causa con la salida detallada del build de iOS; después, la persona elige la vía.

### 2026-10-06 · RF-00 · iteración 3 · APROBADO

- **Agente(s):** orquestador. La persona ejecutó en su terminal el build detallado de iOS.
- **Base:** `5118da2` (`refactor/rf-00-baseline`).
- **Archivos del diff:**
  - `.claude/refactor/PLAN.md`: D-03, D-04, el WP nuevo RF-19, RF-19 como dependencia de RF-14, RF-17 y RF-20, y RF-00 cerrado.
  - `.claude/refactor/MATRIZ_DE_PRUEBAS.md`: fila de RF-19 y conteos base finales de G5 y G6.
  - Esta entrada.
- **Gates:**
  - **G6 iOS** (ejecutado por la persona): `flutter build ios --simulator --debug --dart-define-from-file=config/dart_defines.ci.json -v > build/g6_ios.log 2>&1` → exit 1. El log confirma la causa (`build/g6_ios.log:55330-55375`):
    - todos los errores son `error: The iOS Simulator deployment target 'IPHONEOS_DEPLOYMENT_TARGET' is set to <9.0–13.0>, but the range of supported deployment target versions is 15.0 to 27.0.x`, en el target `Runner` y en los pods;
    - el build termina en `** BUILD FAILED **` («Building workspace Runner with scheme Runner and configuration Debug», 1 failure);
    - no hay errores de otro tipo.
  - Tras el build, `git status --porcelain` sale vacío.
  - No hubo cambios de código desde la iteración 2, así que G1, G2, G4, G5 y G7 conservan sus resultados.
  - **G0 de este commit:** `git diff --check` limpio; `./bin/check_no_secrets.sh` → exit 0.
- **Base final de RF-00:** la sección 7 de la matriz. G5 de catálogo en verde; G6 Android en verde y G6 iOS en rojo (Xcode 27.0 con mínimo de iOS 13.0).
- **Hallazgos:**
  - [Alta] G6 iOS: lo corrige RF-19 (D-03).
  - Siguen abiertos, fuera del alcance de RF-00:
    - [Media] webhooks de Rewards sin suscripción declarada (`server.ts:389,411,443`);
    - [Media] advisory lock del worker de Rewards (`worker.ts:24-44`);
    - [Baja] 5 pruebas con `skip: true`;
    - [Baja] Node 26 en local frente a Node 24 en CI;
    - [Baja] las vulnerabilidades que reporta `npm ci`, sin auditar;
    - [Baja] plugins que aplican KGP y `flutter_secure_storage` sin Swift Package Manager.
- **Decisiones de la persona en esta iteración:**
  - D-03: subir el mínimo a iOS 15.0 en el WP nuevo RF-19. Antes de decidir, la persona preguntó en qué iOS vamos: es iOS 27, e iOS 15 corre en los mismos equipos que iOS 13.
  - D-04: aprobar RF-00 con G6 iOS en rojo como parte de la base. RF-19 bloquea a RF-14, RF-17 y RF-20 y, por transitividad, a sus dependientes.
- **Commit:** el que contiene esta entrada, en `refactor/rf-00-baseline`. RF-00 queda `cerrado`. Sin push.
- **Siguiente paso:** RF-10, el primer WP pendiente con dependencias y decisiones listas; RF-19 va justo después.

### 2026-10-06 · RF-10 · iteración 1 · APROBADO

- **Agente(s):** orquestador (CI y Makefile).
- **Base:** `833cf8f`. Rama `refactor/rf-10-ci-espejo`, creada desde `refactor/rf-00-baseline`.
- **Archivos del diff:**
  - `.github/workflows/quality.yml`: paso `npm run test:api` en el job `functions-and-web`, antes de `typecheck:api`.
  - `Makefile`:
    - `npm run test:api` en `test-services`;
    - se quita el target `schema`, también de `.PHONY`;
    - la descripción de `gen` pasa a «Run code generation (drift)».
  - `.claude/refactor/PLAN.md`, `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y esta entrada.
- **Por qué se quitó `schema` en vez de arreglarlo:** llamaba a `scripts/fetch_schema.sh`, que no existe. El proyecto no genera código de GraphQL a propósito (`lib/data/shopify/README.md:102`, `docs/ARCHITECTURE.md:299`, `pubspec.yaml:24`). No hay directorio `scripts/` ni archivos `.graphql`, y nada usa un esquema descargado.
- **Gates (ejecutados por el auditor):**
  - G0 `git status --porcelain` · `git diff --stat` · `git diff --check` → sólo `quality.yml`, `Makefile` y los archivos de `.claude/refactor/`; `--check` limpio.
  - G1 y G2 → no aplican: no hay cambios de Dart.
  - G3 `npm run test:api` → 19 aprobadas en 5 archivos, igual que la base.
  - Workflow: `YAML.safe_load` de Ruby sobre `quality.yml` parsea sin errores.
    - En `functions-and-web`, `npm run test:api` es el paso 9 de 13, después del `npm ci` de la raíz (paso 3).
    - Disparadores: `pull_request`, `push` y `workflow_dispatch`.
  - Makefile:
    - `make help` muestra `gen  Run code generation (drift)` y ya no lista `schema`;
    - `make -n schema` → «No rule to make target `schema'»;
    - `make -n test-services` incluye `npm run test:api`.
  - G4: `npm ci` en `web/` → 14 paquetes añadidos; `make test-services` → exit 0 en 11 s.
    - backend: 111 aprobadas y 9 omitidas; functions: 13; espejo: 19;
    - typecheck de backend, functions y espejo en verde, y `build:web` compila;
    - conteos iguales a la base.
  - G5 `dart run bin/verify_catalog_snapshot.dart` → «Catálogo válido: 103 productos, 340 imágenes»; `./bin/check_no_secrets.sh` → exit 0.
  - G6, G7 y G8 → no aplican.
- **Filas de la matriz:** INV-16 en verde (19 de 19); ahora corre en CI y en `make test-services`.
- **Aceptación:**
  - `npm run test:api` pasa en local.
  - Que el workflow lo ejecuta está verificado en su definición. La primera ejecución real en CI llegará con el próximo push de la persona.
- **Hallazgos:** ninguno.
- **Docs:** ningún documento vigente describe el CI ni los targets de `make`. Los que mencionan `test:api` son históricos (2026-09-07) y no se tocan.
- **Decisiones de la persona en esta iteración:** ninguna.
- **Commit:** el que contiene esta entrada, en `refactor/rf-10-ci-espejo`. Sin push.
- **Siguiente paso:** RF-19 (mínimo iOS 15.0).

### 2026-10-06 · RF-19 · iteración 1 · APROBADO

- **Agente(s):** orquestador (configuración nativa). La persona ejecutó G6 en su terminal.
- **Base:** `f7e7157`. Rama `refactor/rf-19-ios-15`, creada desde `refactor/rf-10-ci-espejo`.
- **Archivos del diff:**
  - `ios/Podfile`: `platform :ios, '15.0'`, y un `post_install` que sube a 15.0 cada pod con un mínimo menor, sin bajar ninguno.
  - `ios/Runner.xcodeproj/project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET = 15.0` en las 6 configuraciones.
  - `ios/Podfile.lock`: sólo cambia `PODFILE CHECKSUM`; ninguna versión de pod.
  - `.claude/refactor/PLAN.md`, `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y esta entrada.
- **Gates:**
  - G0 `git status --porcelain` · `git diff --check` → sólo esos archivos; `--check` limpio.
  - Validaciones de configuración:
    - `ruby -c ios/Podfile` → «Syntax OK»;
    - `plutil -lint ios/Runner.xcodeproj/project.pbxproj` → OK;
    - las 6 configuraciones quedan en 15.0 y ninguna por debajo.
  - G1, G2 y G4 → no aplican: no hay cambios de Dart ni de TypeScript, y el gate de esta área es G6.
  - INV-07 `flutter test --no-pub test/platform/shopify_checkout_channel_test.dart test/app/shopify_checkout_coordinator_test.dart test/app/checkout_buyer_identity_test.dart test/app/shopify_cart_composition_test.dart` → 23 aprobadas.
  - G5 → catálogo válido (103 productos, 340 imágenes); `./bin/check_no_secrets.sh` → exit 0.
  - G6 iOS (ejecutado por la persona): `flutter build ios --simulator --debug --dart-define-from-file=config/dart_defines.ci.json -v > build/rf19_ios.log 2>&1` → exit 0.
    - `pod install` corrió solo (22.6 s) y reescribió el checksum de `Podfile.lock`.
    - `** BUILD SUCCEEDED **` (`build/rf19_ios.log:145502`) y `✓ Built build/ios/iphonesimulator/Runner.app`.
    - 0 errores de deployment target. La única línea con `error:` (`:144800`) viene del script de Flutter que hace `plutil -extract NSBonjourServices` sobre una clave que no existe; no es un error del build.
  - G6 Android (ejecutado por la persona): `flutter build apk --debug --flavor staging --dart-define-from-file=config/dart_defines.ci.json > build/rf19_apk.log 2>&1` → exit 0; `✓ Built build/app/outputs/flutter-apk/app-staging-debug.apk` en 24.5 s.
  - G7 y G8 → no aplican.
- **Filas de la matriz:** INV-07 en verde. En la sección 7, iOS ya compila desde este WP.
- **Hallazgos:** ninguno nuevo. Siguen los Baja de RF-00: plugins que aplican KGP y `flutter_secure_storage` sin Swift Package Manager.
- **Impacto de producto (D-03):** quien siga en iOS 13 o 14 ya no puede instalar la app. No queda fuera ningún modelo de iPhone ni de iPad.
- **Decisiones de la persona en esta iteración:** ninguna nueva.
- **Commit:** el que contiene esta entrada, en `refactor/rf-19-ios-15`. Sin push.
- **Siguiente paso:** RF-11 (ficha: producto que desaparece).

### 2026-10-06 · RF-11 · iteración 1 · APROBADO

- **Agente(s):** `test-engineer` escribió la prueba roja CHAR-01 y `flutter-implementer` hizo la corrección. El orquestador redactó los encargos y auditó.
- **Base:** `b5f46aa`. Rama `refactor/rf-11-ficha-no-disponible`, creada desde `refactor/rf-19-ios-15`.
- **Archivos del diff:**
  - `test/features/product/product_unavailable_test.dart` (nuevo, de `test-engineer`): 5 pruebas `CHAR-01`.
  - `lib/features/product/product_screen.dart`: busca el producto sin lanzar y, si no lo encuentra, devuelve `ProductUnavailable`.
  - `lib/features/product/product_unavailable.dart` (nuevo): el estado «Este artículo ya no está disponible».
    - «Explorar el catálogo» vuelve a la primera ruta y «Volver» cierra la ficha.
    - El atrás no registra `productView`.
  - `.claude/agents/test-engineer.md` y `.claude/agents/flutter-implementer.md`: el párrafo del sandbox que se añadió en RF-00 partía la lista numerada; ahora va después de ella.
  - `.claude/refactor/PLAN.md`, `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y esta entrada.
- **Fase roja (verificada por el auditor):**
  - `flutter test --no-pub test/features/product/product_unavailable_test.dart --reporter expanded` → exit 1; las 5 pruebas fallan con `Actual: StateError:<Bad state: No element>`.
  - **Origen:** una sonda temporal sin `takeException` (`test/zz_rf11_origin_probe_test.dart`, borrada al terminar) mostró `#1 _ProductScreenState.build (product_screen.dart:165:36)`.
  - **Producción intacta en esa fase:** `git diff --quiet -- lib`.
  - **La prueba roja no cambió después:** su última modificación (17:47:43) es anterior a la corrección (17:52:04) y conserva sus 310 líneas.
- **Gates (ejecutados por el auditor):**
  - G0 → sólo los archivos listados; `git diff --check` limpio.
  - G1 `dart format --output=none --set-exit-if-changed lib test integration_test` → 302 archivos, 0 cambiados.
  - G2 `flutter analyze --no-pub` → «No issues found!».
  - G3 `flutter test --no-pub test/features/product/` → `+26 ~4: All tests passed!`.
  - G4 `flutter test --no-pub` → `+710 ~5: All tests passed!`. Son las 705 de la base más las 5 CHAR-01, con las mismas omitidas.
  - G5 → catálogo válido (103 productos); `./bin/check_no_secrets.sh` → exit 0.
  - G6, G7 y G8 → no aplican: el cambio es sólo de presentación en Dart.
  - `grep -rn "firstWhere" lib/features/` → sólo `admin_screen.dart:1098`, que es sobre variantes. Ninguno sobre `store.products`.
  - `grep -rn "CHAR-01" test` → 6 coincidencias: los 5 nombres de prueba y el comentario del archivo.
- **Filas de la matriz:** CHAR-01 → verde. INV-12 → verde, dentro de G4.
- **Checklist:**
  - el alcance es el del encargo;
  - textos de UI en español y comentarios en inglés;
  - las pruebas nuevas no usan `skip:`, `// ignore`, red ni reloj real;
  - no hay secretos;
  - no cambia ningún contrato ni la arquitectura, así que no hay docs que actualizar (`lib/features/product/` no tiene README).
- **Hallazgos:**
  - [Baja] `product_screen.dart:166-172` busca el producto con un bucle. El código vecino usa `where(...).firstOrNull` (`catalog_creator_document.dart:58`).
  - [Baja] `product_unavailable.dart:50-89` repite el diseño de `EEmptyState` (`account_boutique.dart:348`), que sólo admite una acción. Si `EEmptyState` aceptara una acción secundaria opcional, se podría reutilizar.
  - [Baja] Ninguna prueba demuestra que salir del estado de ausencia no registra `productView`. Se cumple por construcción: el widget no llama a `store.record`.
  - [Baja] En `product_unavailable_test.dart:74-94`, `emit` espera hasta 1 s con un sondeo de tiempo real dentro de `runAsync`. Con el equipo cargado, la prueba podría volverse frágil.
- **Decisiones de la persona en esta iteración:** ninguna. Los textos del estado y el comportamiento de las acciones los fijó el orquestador en el encargo, siguiendo el plan y el texto que ya usa favoritos.
- **Commit:** el que contiene esta entrada, en `refactor/rf-11-ficha-no-disponible`. Sin push.
- **Siguiente paso:** RF-12 (contrato del ID de pedido en Rewards).

### 2026-10-06 · RF-12 · iteración 1 · APROBADO

- **Agente(s):** `test-engineer` escribió CONTRACT-01, roja en los dos lados. Después, `backend-implementer` corrigió el servidor y `flutter-implementer` el cliente, en serie. El orquestador redactó los encargos, actualizó el documento del contrato y auditó.
- **Base:** `e53af69`. Rama `refactor/rf-12-rewards-order-id`, creada desde `refactor/rf-11-ficha-no-disponible`.
- **Archivos del diff:**
  - `test/fixtures/contracts/rewards_order_id.json` (nuevo): el fixture único.
  - `test/features/rewards/rewards_order_id_contract_test.dart` y `services/accounts_orders/test/rewardsOrderIdContract.test.ts` (nuevos): leen ese mismo fixture.
  - `services/accounts_orders/src/rewards/routes.ts`: `canonicalShopifyOrderId` acepta el numérico o `gid://shopify/Order/<n>`; cualquier otro formato da 400 `{error:'invalid_request'}`. La validación de vacío y de más de 64 caracteres se conserva.
  - `lib/features/rewards/rewards_api.dart`: `orderRewards` valida y normaliza al numérico, y construye la ruta con `pathSegments`. Ante formatos inválidos lanza `ArgumentError` antes de cualquier petición.
  - `docs/redesign/REWARDS_CONTRACT_V1.md:79`: documenta el contrato del `:id`.
  - `.claude/refactor/PLAN.md`, `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y esta entrada.
- **Fase roja (verificada por el auditor):**
  - Producción intacta: `git diff --quiet -- lib services/accounts_orders/src`.
  - **Dart:** 1 caso aprobado y 4 fallidos.
    - GID: `Expected: '/customers/me/orders/8001/rewards'`, `Actual: '/customers/me/orders/gid://shopify/Order/8001/rewards'`.
    - Rechazados: `Expected: throws <Instance of 'ArgumentError'>`; la petición se hizo.
  - **TypeScript:** 1 caso aprobado y 4 fallidos.
    - GID: `expected 404 to be 200`.
    - Rechazados: `expected 404 to be 400`.
  - `flutter-implementer` no ejecutó la roja antes de editar (paso 4 de su archivo). El rojo ya lo había verificado el auditor.
- **Gates (ejecutados por el auditor):**
  - G0 → sólo los archivos listados; `git diff --check` limpio.
  - G1 → 303 archivos, 0 cambiados.
  - G2 → «No issues found!».
  - G3 → CONTRACT-01 en Dart `+5: All tests passed!`; en TypeScript `Tests 5 passed (5)`.
  - G4 Flutter `flutter test --no-pub` → `+715 ~5: All tests passed!`, es decir, 710 más 5.
  - G4 backend `npm --prefix services/accounts_orders test` → 116 aprobadas y 9 omitidas, es decir, 111 más 5. `run typecheck` y `run build` → exit 0.
  - G5 → catálogo válido; `./bin/check_no_secrets.sh` → exit 0.
  - G7 `REQUIRE_POSTGRES_TESTS=1 … test` → 23 archivos, 125 de 125, 0 omitidas.
  - G6 y G8 → no aplican.
- **Filas de la matriz:** CONTRACT-01 → verde. INV-09 e INV-15 → verdes, dentro de G4 y G7.
- **Checklist:**
  - el alcance es el de los tres encargos más el documento;
  - identidad: la app conserva el GID como identidad canónica y sólo el borde HTTP de Rewards convierte al numérico;
  - autorización: otra cuenta sigue recibiendo 404 (`rewardsApi.test.ts`);
  - el contrato es aditivo para el numérico. Los formatos mal formados pasan de 404 a 400; está documentado y ningún cliente legítimo los envía;
  - un `ArgumentError` lo atrapa `_safeLoad` (`rewards_section.dart:801-810`), así que no hay excepción cruda en la UI;
  - `RewardsAccountService.forOrder` no tiene llamadores.
- **Hallazgos:**
  - [Baja] Proceso: `flutter-implementer` no confirmó la prueba roja antes de editar, como pide su archivo de agente.
- **Decisiones de la persona en esta iteración:** ninguna. El formato del cable y el rechazo los fijó el orquestador siguiendo R12 y el plan.
- **Commit:** el que contiene esta entrada, en `refactor/rf-12-rewards-order-id`. Sin push.
- **Siguiente paso:** RF-13 necesita la decisión E7. Si sigue pendiente, el siguiente WP sin bloqueos es RF-14.

### 2026-10-06 · RF-13 · iteración 1 · APROBADO

- **Agente(s):** `test-engineer` escribió CONTRACT-02, roja en los dos lados. Después, en serie, `backend-implementer` hizo el servidor y `flutter-implementer` el cliente. El orquestador redactó los encargos, actualizó el documento del contrato y auditó.
- **Base:** `bc677a7`, el commit que registra E7. Rama `refactor/rf-13-rewards-apagado`.
- **Decisión aplicada (E7):** con Rewards apagado se mantiene el estado vigente, «Monetta Rewards aún no está disponible».
- **Archivos del diff:**
  - `test/fixtures/contracts/rewards_disabled.json` (nuevo): el fixture único.
  - Pruebas nuevas que leen ese fixture:
    - `services/accounts_orders/test/rewardsDisabledContract.test.ts`, 3 casos;
    - `test/features/rewards/rewards_disabled_contract_test.dart`, 14 casos.
  - `services/accounts_orders/src/rewards/routes.ts`: `registerRewardsDisabledRoutes`. Para cualquier método y sin autenticar responde 404 `{error:'feature_disabled', requestId}` en `/customers/me/rewards`, `/customers/me/rewards/*` y `/customers/me/orders/:id/rewards`.
  - `services/accounts_orders/src/api/server.ts`:
    - monta esas rutas cuando no hay `deps.rewards`;
    - añade un 404 en JSON `{error:'not_found', requestId}` justo antes del manejador de errores.
  - `lib/features/rewards/rewards_api.dart`:
    - `_send` convierte los fallos de transporte (`ClientException`, `IOException`, `TimeoutException`) en `RewardsApiError('network')`;
    - `_throwFor` conserva el `error` del JSON. Si no lo hay, deriva el código del status: 401/403 → `unauthorized`, 404 → `not_found`, `>=500` → `service_unavailable`, cualquier otro → `internal_error`.
  - `lib/features/rewards/rewards_error_kind.dart` (nuevo): un solo clasificador (`unavailable`, `session`, `network`, `serviceDown`) para la sección y la tarjeta.
  - `lib/features/rewards/rewards_section.dart` y `lib/features/rewards/rewards_balance_card.dart`: cuatro estados distintos.
    - «Servicio caído» lleva el texto nuevo «Monetta Rewards no responde en este momento…».
    - En la tarjeta, la sesión vencida muestra «Tu sesión terminó…», sin reintento.
  - `docs/redesign/REWARDS_CONTRACT_V1.md`:
    - §2: programa apagado, ruta desconocida y `requestId`;
    - §4: códigos nuevos y cómo los clasifica el cliente;
    - se corrigió además la referencia rota a «§6», que debía apuntar a §4.
  - `.claude/refactor/PLAN.md`, `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y esta entrada.
- **Fase roja (verificada por el auditor):**
  - Producción intacta: `git diff --quiet -- lib services/accounts_orders/src`.
  - TypeScript: 3 de 3 rojos con `expected 'text/html; charset=utf-8' to contain 'application/json'`.
  - Dart: 11 rojos y 3 verdes (los casos 1, 8 y 12).
    - Clasificación: `internal_error` donde se esperaba `not_found`, `service_unavailable` o `unauthorized`, y un `ClientException` crudo donde se esperaba `network`.
    - Sección y tarjeta: «Revisa tu conexión» visible, o «Tu sesión terminó» ausente.
- **Gates (ejecutados por el auditor):**
  - G0 → sólo los archivos listados; `git diff --check` limpio.
  - G1 → 305 archivos, 0 cambiados.
  - G2 → «No issues found!».
  - G3 → `flutter test --no-pub test/features/rewards/` da `+34: All tests passed!`; `rewardsDisabledContract.test.ts` da 3 de 3.
  - G4 Flutter → `+729 ~5: All tests passed!`, es decir, 715 más 14.
  - G4 backend → 119 aprobadas y 9 omitidas, es decir, 116 más 3. Typecheck y build → exit 0.
  - G5 → catálogo válido; `./bin/check_no_secrets.sh` → exit 0.
  - G7 → 24 archivos, 128 de 128, 0 omitidas.
  - G6 y G8 → no aplican.
  - `grep` de `ClientException`/`SocketException` en `lib/`: ningún consumidor de `RewardsApi` los atrapaba. Las coincidencias son del admin y de Loox, ajenas a Rewards.
- **Filas de la matriz:** CONTRACT-02 → verde. INV-15 → verde, dentro de G7.
- **Checklist:**
  - el contrato es aditivo: sólo cambian respuestas que antes eran HTML;
  - con Rewards encendido, sus rutas no cambian;
  - se mantienen la autorización en el servidor y los cuerpos de los errores existentes;
  - la UI distingue ausencia, sin conexión, servicio caído y sesión vencida, y no muestra excepciones crudas;
  - textos en español; sin secretos;
  - la doc del contrato está actualizada.
- **Hallazgos:**
  - [Baja] `rewards_section.dart` (`_RewardsError`) y `rewards_balance_card.dart` (`_CardError`) agrupan el caso `unavailable`, hoy inalcanzable, con el texto de conexión para que el `switch` sea exhaustivo. Si un llamador futuro les pasara ese error directamente, volvería el defecto R11.
  - [Baja] Faltan pruebas de 403, de otros 5xx, de la red en métodos distintos de `summary` y del estado de sesión en la tarjeta sin reintento.
  - [Baja] Una respuesta 200 con JSON inválido sigue saliendo como `FormatException`, que la UI clasifica como «sin conexión». Corresponde a RF-15 (CONTRACT-03).
- **Decisiones de la persona en esta iteración:** E7, registrada en `bc677a7`.
- **Commit:** el que contiene esta entrada, en `refactor/rf-13-rewards-apagado`. Sin push.
- **Siguiente paso:** RF-14 (timeouts y notificaciones fuera del arranque).

### 2026-10-06 · RF-14 · iteración 1 · PENDIENTE DE G6 Y G8

- **Agente(s):** `test-engineer` escribió las pruebas rojas en dos rondas; `flutter-implementer` implementó. El orquestador redactó los encargos, verificó el rojo y auditó.
- **Base:** `1bf3c64`. Rama `refactor/rf-14-timeouts-notificaciones`.
- **Decisiones aplicadas:**
  - D-05, tomada en esta sesión: G8 en los simuladores de la Mac.
  - Timeout por defecto de 20 s, anotado en `PLAN.md`.
- **Fila nueva:** CHAR-10, porque al quitar la espera de `restore()`, el primer frame del inicio pedía el permiso antes de cargar el estado guardado (`home_screen.dart:115-123`) y volvía a encender los anuncios.
- **Fase roja (verificada por el auditor):**
  - `lib/` intacto.
  - 15 rojas, cada una por su razón:
    - CHAR-08: `HomeScreen` no aparece.
    - CHAR-09: `CollectionScreen` no aparece.
    - CHAR-09 sin red: `takeInitialMessageCalls` 0, se esperaba 1.
    - CHAR-10: `requestPermission` 1, se esperaba 0.
    - CONTRACT-05, las 11: `Actual: <null>` a los 21 s.
  - Una caracterización (CHAR-09 vigente) en verde.
- **Archivos del diff:**
  - `lib/data/http/timeout_http_client.dart` (nuevo): transporte con un plazo para cabeceras y cuerpo, con `Timer`.
  - Los 7 clientes: parámetro `timeout` y traducción a su error tipado. Los mensajes de notificaciones están en español.
  - `lib/app/notification_controller.dart`:
    - `restore()` lee el mensaje inicial aunque falle la red;
    - las acciones esperan a un `restore()` en curso;
    - guardas tras `dispose()`.
  - `lib/main.dart`:
    - `restore()` sin `await`;
    - la ruta que llega antes del Navigator se conserva y se abre una vez.
  - Pruebas nuevas: `test/app/startup_notifications_test.dart`, `test/app/notification_restore_race_test.dart` y `test/data/http/http_timeout_contract_test.dart`.
  - `.claude/refactor/PLAN.md`, `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y esta entrada.
  - Fuera del WP: `.claude/skills/refactor/SKILL.md` (la persona quitó `disable-model-invocation`). Queda fuera del commit de RF-14.
- **Gates (ejecutados por el auditor):**
  - G0 → sólo los archivos listados; `git diff --check` limpio, con los archivos nuevos incluidos.
  - G1 → 309 archivos, 0 cambiados.
  - G2 → «No issues found!».
  - G3 → `+16: All tests passed!`.
  - G4 → `+745 ~5: All tests passed!`, es decir, 729 más 16.
  - G5 → catálogo válido (103 productos, 340 imágenes); `./bin/check_no_secrets.sh` → OK.
  - G6 → **no ejecutado**: el WP toca la composición de arranque y le toca a la persona.
  - G8 (DEV-01 y DEV-02, pasos de push, en simuladores) → **no ejecutado**: le toca a la persona.
- **Checklist:**
  - alcance correcto;
  - INV-13 e INV-08 verdes en G4;
  - el transporte no registra URLs, cabeceras ni tokens;
  - firmas públicas conservadas, sólo con el parámetro opcional añadido;
  - sin `skip` ni `// ignore`.
- **Hallazgos:**
  - [Baja] Un timeout antes de las cabeceras no aborta la petición subyacente; sólo se descarta su respuesta. En Loox, el `http.get` por defecto sigue en segundo plano.
  - [Baja] Las guardas de `dispose()` en `NotificationController` no tienen prueba propia.
  - [Baja] Abrir la ruta pendiente depende de que el post-frame que sigue a `_loading` monte el Navigator. CHAR-09 lo cubre, y RF-31 lo reemplaza con `AppDestination`.
  - [Baja] Si `_local.initialize` falla, se pierde `localInitial` y no se escuchan los mensajes abiertos en esa sesión. Es comportamiento previo.
- **Veredicto:** código aprobado. El WP queda en espera de G6 y G8; sin commit hasta cerrarlo.

### 2026-10-07 · RF-14 · commit con G6 y G8 pendientes

- **Motivo:** la persona pidió dejar el bucle `/refactor` corriendo solo. Para eso el árbol debe quedar limpio, así que autorizó hacer el commit del código aprobado antes de cerrar el WP.
- **Estado:** RF-14 sigue `bloqueado: G6 y G8 de la persona` en `PLAN.md`. Cuando la persona ejecute G6 y G8, se registran aquí y el WP pasa a `cerrado`. Si algo falla, la corrección va en un commit nuevo sobre la misma rama.
- **Rama:** `refactor/rf-14-timeouts-notificaciones`. Los WPs siguientes parten de esta rama.
- **Fuera del commit:** `.claude/skills/refactor/SKILL.md` (cambio de la persona) y `.claude/settings.local.json`.

### 2026-10-07 · RF-15 · iteración 1 · CERRADO

- **Agentes:** `test-engineer` (CONTRACT-03) → `flutter-implementer`. Base `1072f10`, rama `refactor/rf-15-parsers-rewards`. Lanzado por el bucle `/loop /refactor siguiente`.
- **Campos obligatorios:** se fijaron con el contrato (`REWARDS_CONTRACT_V1.md` §3) y el servidor (`service.ts:44-70`, `pgRewardsRepository.ts:94-103`). `balance.nextExpiry` puede ser `null`, y `orderShopifyId` y `reason` de un movimiento también.
- **Fase roja (verificada por el auditor):**
  - El archivo nuevo sólo no compilaba por la falta de `RewardsContractError`: 14 issues de analyze, todos derivados de esa clase.
  - Con un stub temporal de la clase (revertido con `git checkout`), las pruebas fallaron por comportamiento:
    - los DTO devolvían valores rellenados con `now`, `0` o `"null"` (40 casos);
    - lanzaban `TypeError` o `FormatException` sin envolver;
    - `activity` descartaba en silencio el movimiento inválido;
    - la UI mostraba «Revisa tu conexión».
- **Diff:**
  - `rewards_models.dart`:
    - `RewardsContractError extends RewardsApiError` (`invalid_response`, `field`, sin valores del cuerpo);
    - lectores estrictos;
    - texto amigable.
  - `rewards_api.dart`:
    - `_decodeObject`;
    - `activity` valida cada movimiento (`movements[i].campo`) y `nextCursor`.
  - `REWARDS_CONTRACT_V1.md` §4 documenta `invalid_response`.
  - Pruebas: nuevo `rewards_strict_parsing_contract_test.dart`, con 86 pruebas. En `rewards_components_test.dart`, el cuerpo parcial se completó según el contrato y la aserción quedó igual.
- **Gates (ejecutados por el auditor):**
  - G0 → sólo los archivos listados; `git diff --check` limpio.
  - G1 → 310 archivos, 0 cambiados.
  - G2 → «No issues found!».
  - G3 → `test/features/rewards` `+120: All tests passed!`.
  - G4 → `+835 ~5: All tests passed!` (la base era 745).
  - G5 → catálogo válido (103 productos, 340 imágenes); secretos OK.
  - G6–G8 → no aplican.
- **Checklist:**
  - el alcance es el del encargo;
  - el contrato HTTP no cambia: sólo se endurece la lectura en el cliente;
  - el error no lleva valores del cuerpo;
  - estado recuperable distinto de «sin conexión»;
  - sin `skip` ni `// ignore`.
- **Hallazgos:**
  - [Baja] `redeem` y `releaseRedemption` siguen haciendo `jsonDecode(...) as Map` sin envolver, así que un 200 inválido se mostraría como `network`. Hoy el canje está apagado (`409 redemption_disabled`). Conviene cubrirlo cuando se active el canje.
  - [Baja] `program` e `incentives` conservan el cast antiguo: un tipo incorrecto lanzaría `TypeError` y se mostraría como `network`. Es comportamiento vigente y queda fuera de R15.
- **Veredicto:** aprobado y cerrado. Commit en `refactor/rf-15-parsers-rewards`.

### 2026-10-07 · Sincronización con main · APROBADO

- **Motivo:**
  - La cadena del refactor salió de `main` en `48a6786`.
  - Desde entonces `main` recibió dos PRs: el catálogo de borde a borde (#8) y la barra inferior plana (#9).
  - El PR #10, todavía abierto, trae el fondo blanco, el total de piezas sólo para dueños y las categorías en el panel de filtros.
  - Sin sincronizar, RF-16 habría fijado el catálogo viejo y RF-17 habría reescrito los mismos archivos de tema.
  - La persona autorizó la sincronización y pidió seguir en bucle (D-06 y D-07).
- **Rama:** `refactor/rf-16-caracterizacion`, desde `438e9b7`.
  - El merge `cbeb237` trae `feat/fondo-blanco-main` (`b66e5c4`), que es `main` en `7e304b1` más el PR #10.
  - Se hizo sin red, porque esa rama local es la cabeza del PR. Cuando el PR se fusione en GitHub, traer `main` sólo añadirá el commit de merge.
- **Conflictos:**
  - Sólo `assets/catalog/catalog.json`, dos refrescos de la misma tienda. Se queda el de `main`, del 2026-10-07.
  - El cambio de iOS de RF-19 es idéntico en las dos ramas.
- **Gates (ejecutados por el orquestador):**
  - G0 → árbol limpio después del commit.
  - G1 → 317 archivos, 0 cambiados.
  - G2 → «No issues found!».
  - G4 → `+960 ~5: All tests passed!`. Las bases eran 835 en el refactor y 834 en `main` con el PR #10.
  - G5 → catálogo válido (103 productos, 340 imágenes); secretos OK.
  - G6 a G8 → no aplican a la sincronización.
- **Dispositivo:** la persona compiló e instaló en su iPhone 16e un build de release de staging de la rama del PR #10, con las variables de CI. Es el primer build de release en un dispositivo físico, aunque no cubre DEV-01 ni DEV-02.
- **Fuera de la matriz:** las pruebas de los PRs #8 a #10 no tienen filas, porque son trabajo fuera del plan.
- **Veredicto:** sincronización aprobada. RF-16 sigue en esta misma rama.

### 2026-10-07 · RF-16 · iteración 1 · APROBADO

- **Agente(s):** `test-engineer` escribió las pruebas. El orquestador redactó el encargo, auditó y corrigió dos comentarios. Lanzado por el bucle `/loop /refactor siguiente`.
- **Base:** `d97b2d5`, rama `refactor/rf-16-caracterizacion`.
- **Verificación previa:** antes del encargo, el orquestador releyó las líneas que citan CHAR-03 a CHAR-07 y siguen siendo correctas después del merge con `main`.
- **Archivos del diff:**
  - Nuevos:
    - `test/fixtures/db/monetta_v7_monetta_mx.sql`: esquema v7 exacto, `user_version 7` y datos ficticios de `monetta.mx` en las 14 tablas;
    - `test/data/local/shop_scope_characterization_test.dart` (CHAR-03, 8 pruebas);
    - `test/data/local/bag_merge_characterization_test.dart` (CHAR-04, 4);
    - `test/app/bag_counter_characterization_test.dart` (CHAR-05, 3);
    - `test/app/empty_catalog_characterization_test.dart` (CHAR-06, 2);
    - `test/features/catalog/collection_handle_characterization_test.dart` (CHAR-07, 2).
  - `.claude/refactor/PLAN.md`, `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y esta entrada.
  - `lib/` intacto.
- **Gates (ejecutados por el auditor sobre el árbol final, después de corregir los comentarios):**
  - G0 → sólo archivos del alcance. `git diff --check` limpio, y `git diff --no-index --check` también sobre cada archivo nuevo.
  - G1 → `Formatted 322 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → las 5 rutas nuevas: `+19: All tests passed!`.
  - G4 → `+979 ~5: All tests passed!` (base 960, más 19).
  - G5 → `Catálogo válido: 103 productos, 340 imágenes.`; `./bin/check_no_secrets.sh` → OK. El sandbox imprime un aviso de `python3` (`couldn't create cache file … Operation not permitted`), con exit 0.
  - G6 a G8 → no aplican: el WP sólo añade pruebas.
- **Filas de la matriz:** CHAR-03 a CHAR-07 → verde (CAR). Lo que fija cada una:
  - **CHAR-03:**
    - el fixture es v7 (esquema idéntico al del código y `user_version` 7);
    - con el mismo dominio no se pierde ninguna fila, tampoco al reabrir;
    - con otro dominio, o con uno que sólo difiere en mayúsculas, se hace el reset exacto de `resetShopState`. Se conservan `app_preferences`, `checkout_receipts` y el device (con `account_id` null). El asset no se siembra;
    - con dominio `null` o vacío, no hay reset;
    - una bolsa sin procedencia se borra al arrancar con dominio: es la regla de PR7 (R3, `catalog_repository.dart:298-299`), no un defecto;
    - casos 7 y 8: defectos latentes (ver abajo).
  - **CHAR-04:** la fila del invitado reemplaza la de la cuenta (cantidad y `productId`), sin tope (V×15). Se conservan las variantes que sólo tenía la cuenta y la cuenta B no cambia.
  - **CHAR-05:** `bagQuantity` es 11 mientras `bagLines` tiene 1 línea y `bagSubtotal` sólo cuenta la visible. El tooltip de `BagAction` dice «Mi bolsa, 11 artículos».
  - **CHAR-06:**
    - Storefront: un full sync de 0 productos vacía el catálogo de inmediato, y el asset no vuelve al reabrir.
    - Firestore: un snapshot vacío conserva el catálogo y la caché, y marca la metadata `invalid`/`Vacío`.
  - **CHAR-07:** con `collectionHandle`, el producto sin handles pasa y el de otra colección no.
- **Defectos de producción confirmados por las pruebas** (fuera del diff, sin corregir):
  - [Alta, latente] **Firestore.** `realtime_catalog_repository.dart:121-129` escribe la metadata sin `shopDomain`. Con `FIRESTORE_CATALOG_ENABLED=true` y un dominio configurado, cada arranque posterior a un snapshot hace el reset completo: borra cuentas, sesiones, bolsa, favoritos y pedidos (CHAR-03, caso 7). Hoy Firestore está apagado en los ejemplos de staging y producción, y E3 lo deja experimental.
  - [Media] **Primer arranque sin red.** La semilla del asset (`catalog_repository.dart:101-109`) tampoco guarda `shopDomain`. El primer `sync()` la toma por otra tienda (`:292`, `:300-307`) y la borra antes de fallar. La sesión sigue mostrando el asset en memoria, pero el segundo arranque sin red queda sin catálogo hasta un full sync correcto (CHAR-03, caso 8). Afecta la ruta de producción (`storefrontDirect`).
  - Se registran como decisión D-08 en `PLAN.md`.
- **Hallazgos del diff:**
  - [Baja, corregido por el orquestador] `shop_scope_characterization_test.dart:1` citaba «INV-01», que en la matriz es otra invariante. Ahora cita «R10, decision E11».
  - [Baja, corregido por el orquestador] El comentario del caso 8 atribuía al segundo `syncWithShopify()` lo que hizo el primero, que ya había esperado `_start`. Las aserciones no cambian.
  - [Baja] CHAR-05 crea el store sin `shopDomain`, porque con dominio la bolsa sin procedencia se borraría (regla de PR7). La regla del contador no depende del dominio.
  - [Baja] `CatalogRepository.sync()` usa `DateTime.now()` sin inyección (`catalog_repository.dart:215`). CHAR-06 fuerza el full sync con un cursor sin fechas. Queda como candidato para RF-40.
- **Checklist:**
  - el alcance es el del encargo;
  - sin `skip`, sin `// ignore`, sin red y sin reloj real;
  - cada prueba lleva su ID;
  - el conteo es mayor que la base;
  - el fixture no contiene secretos (`ana@example.com`, sin tokens);
  - no hay cambios de contrato ni de arquitectura, así que no hay documentos que actualizar.
- **Decisiones de la persona en esta iteración:** ninguna todavía. Quedan consultados el commit y D-08.
- **Commit:** no autorizado en esta sesión.
- **Siguiente paso:** con el árbol limpio, RF-18.

### 2026-10-07 · RF-16 · decisiones y commit · CERRADO

- **Decisiones de la persona** (respuestas a las preguntas del orquestador):
  - **Commits:** autorizados en esta sesión. Cada WP aprobado va a su rama `refactor/rf-XX-…`, nunca a `main`, y no se hace push.
  - **D-08:** se crea RF-24 en la fase 1, después de RF-18. El orquestador lo ordena antes que RF-17, porque RF-17 necesita a la persona (D-07). El detalle está en `PLAN.md`.
  - **Firestore:** la persona no sabe si `FIRESTORE_CATALOG_ENABLED` está en `true` en sus archivos reales de dart-defines. El defecto del caso 7 se trata como latente; RF-24 lo corrige de todos modos.
- **Matriz:** fila de asignación nueva para RF-24.
- **Commit:** en `refactor/rf-16-caracterizacion`, con las pruebas, el fixture y los documentos del refactor. `.claude/settings.local.json` queda fuera.
- **Siguiente paso:** RF-18, en una rama nueva que sale de esta.

### 2026-10-07 · RF-18 · iteración 1 · PENDIENTE DE G6

- **Agente(s):** `flutter-implementer`. El orquestador redactó el encargo, auditó, pasó a inglés los prefijos de las pruebas nuevas y actualizó la documentación.
- **Base:** `f0a3115`, rama `refactor/rf-18-extracciones`.
- **Archivos del diff:**
  - Nuevos:
    - `lib/data/customer_auth/customer_api_discovery.dart`: `CustomerApiDiscoveryService` con caché, una sola petición en vuelo y fallos sin cachear; el código se movió tal cual, con los mismos `debugDetail`;
    - `lib/features/checkout/checkout_summary_row.dart` (`CheckoutSummaryRow`);
    - `test/data/customer_auth/customer_api_discovery_test.dart` (16 pruebas);
    - `test/features/checkout/checkout_summary_row_test.dart` (2).
  - `customer_identity.dart` y `customer_orders.dart`:
    - parámetro opcional `discovery`; sin él, cada servicio crea el suyo con su cliente y su timeout, sin cederle el cliente;
    - se borraron las dos copias del discovery.
  - `kMaxCustomerApiResponseBytes` se movió al archivo del discovery, para evitar una importación circular, y `customer_identity.dart` lo reexporta. La ruta pública no cambia.
  - `main.dart`: una sola instancia, inyectada en identidad y en pedidos, y cerrada en `dispose()` (7 líneas).
  - `checkout_screen.dart` y `shopify_cart_summary.dart`: usan `CheckoutSummaryRow`; se borraron `_SummaryRow` y `_SummaryTextRow`.
  - `docs/SYSTEM_IMPLEMENTATION.md` §4.3: referencias nuevas y la nota sobre el discovery compartido.
  - `.claude/refactor/PLAN.md`, `.claude/refactor/MATRIZ_DE_PRUEBAS.md` y esta entrada.
- **Gates (ejecutados por el auditor sobre el árbol final):**
  - G0 → sólo archivos del alcance. `git diff --check` limpio, y `git diff --no-index --check` también sobre cada archivo nuevo.
  - G1 → `Formatted 326 files (0 changed)`. El renombrado de los prefijos exigió volver a formatear un archivo de prueba; después se repitieron todos los gates.
  - G2 → «No issues found!».
  - G3 → las dos pruebas nuevas: `+18: All tests passed!`.
  - G4 → `+997 ~5: All tests passed!` (base 979, más 18).
  - G5 → `Catálogo válido: 103 productos, 340 imágenes.`; secretos OK.
  - G6 → **no ejecutado.** El WP cambia la composición de Customer Account en `main.dart`; le toca a la persona.
  - G7 y G8 → no aplican.
- **Invariantes:** INV-08 e INV-06 verdes en G4. El discovery no recibe tokens (invariante 3). Las firmas públicas no cambian; sólo se añade el parámetro opcional.
- **Checklist:**
  - alcance correcto, con la desviación declarada de la constante;
  - sin `skip` ni `// ignore`;
  - timeouts probados con `tester.pump`, sin reloj real;
  - sin cambios de contrato HTTP;
  - documentación actualizada.
- **Hallazgos:**
  - [Baja, corregido por el orquestador] Los prefijos `discovery compartido:` y `fila de resumen:` mezclaban español con descripciones en inglés. Ahora son `INV-08 shared discovery:` e `INV-06 summary row:`, como las pruebas vecinas.
  - [Baja] **Comportamiento en producción.** El discovery compartido usa 15 s, el timeout de identidad. Para los pedidos baja de 20 s a 15 s, sólo en el discovery. Sin inyección, pedidos conserva sus 20 s (probado).
  - [Baja] El cableado de `main.dart` no tiene prueba directa. Lo cubren el análisis y G6, y RF-30 moverá la composición.
  - [Baja, de RF-16] Por indicación del encargo, las descripciones de CHAR-03 a CHAR-07 quedaron en español, a diferencia de la convención del repositorio («nombres en inglés, como el código vecino»). Quedan así. Los encargos siguientes piden descripciones en inglés después del ID.
- **Veredicto:** código aprobado. RF-18 queda en espera de G6.

### 2026-10-07 · RF-18 · commit con G6 pendiente

- **Decisión de la persona:** commit ahora y G6 después, como en RF-14.
- **Estado:** RF-18 queda `bloqueado: G6 de la persona` en `PLAN.md`. Cuando la persona compile Android e iOS sobre esta rama, se registra aquí y RF-18 pasa a `cerrado`. Esa misma compilación cubre el G6 de RF-14, porque esta rama contiene su código. A RF-14 le sigue faltando G8 (DEV-01 y DEV-02, pasos de push).
- **Rama:** `refactor/rf-18-extracciones`. RF-24 sale de esta rama: D-08 sólo exige que el código de RF-18 esté aprobado.

### 2026-10-08 · RF-24 · iteración 1 · CERRADO

- **Agente(s):**
  - `test-engineer` escribió la fase roja. La primera sesión se cortó por el límite de uso de la API sin dejar cambios y se retomó con el mismo encargo.
  - `flutter-implementer` hizo la corrección.
  - El orquestador redactó los encargos, verificó el rojo, auditó y actualizó la documentación.
- **Base:** `b86e08d`, rama `refactor/rf-24-procedencia-tienda`.
- **Decisiones:**
  - D-08: crear RF-24 antes del lanzamiento.
  - D-09: procedencia explícita. La persona preguntó si se trataba del catálogo de EE. UU.; se le aclaró que todo es el catálogo de monetta.mx.
- **Fase roja (verificada por el auditor):**
  - `lib/` intacto (0 líneas de diff).
  - En `shop_scope_characterization_test.dart`: `+8 -3`. Las tres rojas fallaron por la razón esperada:
    - R1 (antes caso 7): `Expected: 'monetta.mx' Actual: <null>` en la metadata de Firestore;
    - R2 (antes caso 8): `cached_products` vacía tras el sync fallido;
    - R3: `sync_cursors` sin fila en una instalación nueva.
  - Las guardas G1 (otra tienda configurada) y G2 (asset sin `_source`) y los seis casos anteriores pasaban.
  - Formato y análisis limpios.
- **Archivos del diff:**
  - `catalog_repository.dart`:
    - `_assetShopDomain` toma el host de `_source` para la metadata de la semilla;
    - la rama de instalación nueva guarda `SyncCursor(shopDomain: configured)`.
  - `realtime_catalog_repository.dart`: parámetro opcional `shopDomain`, que se escribe en la metadata de cada snapshot.
  - `catalog_store.dart`: `_startRealtimeCatalog` pasa `_shopDomain` (1 línea).
  - Pruebas:
    - `shop_scope_characterization_test.dart`: casos 7 y 8 → R1 y R2; nuevas R3, G1 y G2;
    - una prueba nueva en `catalog_repository_test.dart` y otra en `realtime_catalog_repository_test.dart` (`CHAR-03 (RF-24) …`).
  - `docs/SYSTEM_IMPLEMENTATION.md`: §3.11 y §3.12 explican la procedencia de tienda; se refrescaron las referencias de línea de esos bloques.
  - `.claude/refactor/` (plan, matriz y esta entrada).
- **Gates (ejecutados por el auditor):**
  - G0 → sólo archivos del alcance; `git diff --check` limpio.
  - G1 → `Formatted 326 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → CHAR-03 y `test/data/repositories`: `+37: All tests passed!`.
  - G4 → `+1002 ~5: All tests passed!` (base 997; +3 en CHAR-03, +2 unitarias).
  - G5 → `Catálogo válido: 103 productos, 340 imágenes.`; secretos OK.
  - G6 a G8 → no aplican: no toca nativo, `pubspec`, assets, plugins ni la composición de arranque.
- **Filas:** CHAR-03 → verde, con los casos 7 y 8 en su versión objetivo.
- **Invariantes:**
  - Invariante 1: la comparación exacta y la derivación del dominio configurado no cambian; el reset ante otra tienda sigue (G1 y caso de mayúsculas).
  - Invariante 5: Firestore sigue escribiendo a través de `CatalogWriteCoordinator`.
  - INV-04 e INV-05 verdes en G4.
- **Checklist:**
  - alcance correcto;
  - firmas públicas conservadas, sólo con el parámetro opcional;
  - sin `skip` ni `// ignore`;
  - sin red ni reloj real;
  - documentación actualizada.
- **Hallazgos:**
  - [Baja] Las instalaciones que ya tengan metadata de Firestore sin tienda (sólo si Firestore estuvo activo) sufren un último reset en el primer arranque con este cambio. Después quedan consistentes. No hay migración, porque Firestore está apagado en los ejemplos y E3 lo deja experimental.
  - [Baja] Si el host de `_source` del asset dejara de coincidir con el dominio configurado (por ejemplo `www.monetta.mx`), volvería el reset en el primer sync. `bin/refresh_catalog_snapshot.dart` genera hoy `https://monetta.mx/products.json?`.
- **Commit:** en `refactor/rf-24-procedencia-tienda` (autorizado en esta sesión).
- **Siguiente paso:** RF-17 está bloqueado por RF-18 (G6) y necesita a la persona. El siguiente elegible es RF-20.

### 2026-10-08 · Sincronización con main (PR #10 y PR #11) · APROBADO

- **Motivo:**
  - La persona indicó que el trabajo de diseño ya estaba en `main`: PR #10 (`5430240`) y PR #11 (`6b91639`, que incluye `925f433`, con la barra compacta, la cabecera con nombre, el dock de compra y el agregado rápido).
  - Pidió aplicar D-06 con `git merge origin/main`.
  - Antes había simulado el merge con `git merge-tree`: un solo conflicto trivial en los imports de `product_screen.dart`.
- **Procedimiento:**
  - El trabajo en curso de RF-20 (parte A, el plan y la matriz) se apartó con `git stash --include-untracked`.
  - Merge `64bbdb5` sobre `e5cbbd1`, en la rama `refactor/rf-20-catalogo-externo-app`.
  - Conflicto único: los imports de `lib/features/product/product_screen.dart`. Se conservan `product_unavailable.dart` (RF-11) y `purchase_dock.dart` (PR #11). `catalog_store.dart` y `checkout_screen.dart` se fusionaron solos.
  - Después se restauró el stash.
- **Gates (ejecutados por el orquestador, sobre el árbol fusionado y antes del commit):**
  - G1 → `Formatted 347 files (0 changed)`.
  - G2 → «No issues found!».
  - G4 → `+1245 ~5: All tests passed!`: 1002 de la línea del refactor más 243 de PR #11.
  - G5 → catálogo válido (103 productos, 340 imágenes); secretos OK.
  - G6 a G8 → no aplican a la sincronización. Las compilaciones pendientes (RF-14 y RF-18) cubrirán también este código.
- **Efecto en RF-20:**
  - CHAR-11 sigue verde sobre el código fusionado: el aspecto que fija D-10 no cambió con PR #11.
  - ARCH-03 sigue roja, ahora con 781 violaciones en 56 archivos (antes 714 en 47). Las nuevas vienen de las pruebas y los harnesses de PR #11, que construyen el navegador con `CatalogItem`.
- **Veredicto:** sincronización aprobada. RF-20 continúa en esta rama.

### 2026-10-08 · RF-20 · iteración 1 · PENDIENTE DE G6

- **Agentes:**
  - `test-engineer` hizo la parte A.
  - `flutter-implementer` hizo las partes B y C en un solo encargo. Lo cortó el límite semanal de la API y se retomó con su contexto.
  - El orquestador redactó los encargos, verificó el rojo, integró `main` a mitad del WP (ver la entrada de sincronización), auditó y borró un archivo huérfano.
- **Base:** `e5cbbd1`, después `72471f3` tras el merge; rama `refactor/rf-20-catalogo-externo-app`.
- **Decisiones:**
  - D-10 (persona): conservar el aspecto de las tarjetas del catálogo completo.
  - El contrato del admin (`showExternalPicks`, `AdminChannel.externalCatalog`, `external_source`) se queda hasta RF-21, para que los cambios sigan siendo aditivos.
- **Parte A (verificada por el auditor):**
  - `lib/` intacto.
  - ARCH-03 roja por violaciones reales: 714 en 47 archivos antes del merge y 781 en 56 después.
  - CHAR-11 verde antes y después del merge, sin nombrar nada prohibido.
  - La lista de excepciones de ARCH-03 es viva y tiene autoprueba del escáner.
- **Diff (partes B y C):**
  - **Borrados de `lib/`:**
    - `data/external_catalog/` (5 archivos);
    - `app/external_catalog_controller.dart` y `app/mixed_feed.dart`;
    - `features/home/external_catalog_section.dart` y `features/product/external_product_screen.dart`;
    - `reco/external_facets.dart`;
    - `domain/catalog_item.dart` y `data/shopify/catalog_item_mapper.dart`;
    - `features/catalog/extracted_badge.dart` (orquestador: quedó huérfano y sólo marcaba artículos externos).
  - **Navegador:** `CatalogBrowseScreen` y `openCatalogBrowse` reciben `List<Product>` más `Map<String, CanonicalFacets>` y se pueden montar sin `StoreScope`. `ProductTileData.forCatalogBrowse` sustituye a `fromCatalogItem` con la misma salida. El inicio y la colección pasan `store.products` y `store.facetsById`.
  - **Dinero:** `lib/domain/money.dart` (`Money` y `Currency`) y `lib/app/money_format.dart` (`kMoney`, `kUnknownPriceLabel`, `formatCatalogMoney`), movidos sin cambios; `theme.dart` los reexporta.
  - **Guarda:** `ExternalCatalogConfig` queda reducido a `flagRequestedInEnvironment`.
  - **Comentarios:** reescritos sin referencias a módulos borrados, también en `lib/data/local/README.md` (orquestador).
- **Equivalencia (revisada por el auditor campo por campo para productos de monetta.mx):**
  - búsqueda, orden por novedad (`updatedAt` = el antiguo `lastObservedAt`), precio, marca (con respaldo `'Monetta'`), tipo de bolsa, colores, rangos MXN y disponibilidad;
  - el toque abre `ProductScreen`; el agregado rápido y las claves `monetta:<id>` no cambian;
  - el respaldo por `vertical` de `_categoryFor` era inalcanzable para un `Product`: la vertical salía de la misma categoría, y sin categoría daba `otros`, que es lo que devuelve ahora.
- **Pruebas:**
  - **Borradas:** 10 archivos dedicados (90 declaraciones; unas 100 en ejecución por las pruebas parametrizadas) y casos cuyo objeto era externo. Esos casos son:
    - la configuración retirada (3);
    - `externalProductName` (1);
    - tres casos del navegador con artículos externos;
    - USD y precio nulo (1);
    - el agregado rápido externo (1);
    - la ficha externa en `product_header` (13), `product_typography` (3), `product_layout_responsive` (8) y `purchase_dock` (3).
  - **Nuevas:**
    - `ProductTileData the catalog browser keeps the plain MXN price, with no discount`;
    - `the flag is not requested in the test environment` (guarda, INV-11).
  - **Adaptadas** sin perder aserciones: sólo cambió cómo se construyen los datos, con `Product` y facetas a través de `test/support/catalog_browse_fixtures.dart`.
    - El auditor revisó las aserciones borradas archivo por archivo: todas tenían por objeto un artículo externo.
    - En `catalog_browse_screen_test.dart` cambian algunos literales porque las piezas externas se sustituyen por bolsos de monetta.mx (`shopperProductName` en lugar de `externalProductName`); los predicados son los mismos.
    - En `home_external_spacing_test.dart` se retira la aserción sobre un tipo que ya no existe; ARCH-03 garantiza su ausencia.
  - **Delta medida:** 1251 pruebas (1245 tras el merge más las 6 de la parte A) → 1117. Neto −134: 136 borradas y 2 nuevas. La tabla del agente sumaba 34 casos sueltos en vez de 36; prevalece la medición del auditor.
- **Gates (ejecutados por el auditor sobre el árbol final):**
  - G0 → `lib/` y `test/` (más el README de `lib/data/local`); `git diff --check` limpio. El stash está vacío tras el incidente del agente, que hizo un `git stash` por error y lo deshizo; el contenido se verificó íntegro.
  - G1 → `Formatted 329 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → ARCH-03, CHAR-11, INV-11, INV-12, INV-14 y la guarda: `+44: All tests passed!`.
  - G4 → `+1117 ~5: All tests passed!`.
  - G5 → catálogo válido (103 productos, 340 imágenes); secretos OK.
  - G6 → **no ejecutado**: le toca a la persona.
  - G7 y G8 → no aplican.
- **Invariantes:**
  - 10: `ENABLE_EXTERNAL_CATALOG` sigue rechazado (`runtime_config_test`, `dart_defines_validation_test` y `external_catalog_config_test`).
  - 13: `lib/domain/money.dart` sin Flutter (`architecture_test`).
- **Hallazgos:**
  - [Baja] `formatCatalogMoney(null)`, `kUnknownPriceLabel` y `Currency.usd` quedaron sin uso alcanzable. Se movieron sin cambios; RF-60 rediseña `Money`.
  - [Baja] `MonettaProductTile.imageOverlay` quedó sin llamadores. Es un parámetro genérico y se conserva.
  - [Baja] `docs/ARCHITECTURE.md` y `docs/US_SOURCING_DURABILITY.md` aún describen el catálogo externo. Pasan a RF-22, que corrige la documentación.
  - [Baja] El helper `externalApp` de `product_screen_harness.dart` y el nombre del archivo `home_external_spacing_test.dart` conservan «external»; ninguno se refiere ya al catálogo externo.
  - [Baja] RF-21 debe retirar del backend `external_source` y `showExternalPicks`, y después de la app `AdminChannel.externalCatalog` y `showExternalPicks`, con sus excepciones en ARCH-03.
- **Commit:** autorizado en esta sesión, con G6 pendiente, como RF-18.
- **Siguiente paso:** RF-17 sigue esperando el G6 de RF-18 y a la persona. El siguiente elegible es RF-21 (backend).

### 2026-10-08 · RF-21 · iteración 1 · CERRADO

- **Agentes:**
  - `test-engineer` hizo la parte A: ARCH-03 ampliada y CONTRACT-06.
  - `flutter-implementer` hizo la parte B (app).
  - `backend-implementer` hizo la parte C (backend).
  - El orquestador replanteó el WP, verificó el rojo, auditó, quitó un campo obsoleto y actualizó la documentación.
- **Base:** `2cc1ed6`, rama `refactor/rf-21-catalogo-externo-admin`.
- **Replanteamiento:**
  - Al empezar se vio que el admin de la app conservaba la gestión de fuentes externas: `AdminSourcePolicy`, `ExternalSourceAdminClient`, `saveSource`, `sources`/`sourcesHealthStatus` y `manageExternalSources`.
  - RF-20 no la cubrió porque la lista de ARCH-03 no tenía esos nombres.
  - RF-21 pasó a abarcar backend y app. La app fue primero: el cambio es aditivo, porque el backend todavía servía esos datos.
- **Fase roja (verificada por el auditor):**
  - `lib/` y `services/accounts_orders/src/` intactos (0 líneas).
  - ARCH-03 roja con 50 violaciones en los 4 archivos del admin; su autoprueba y su lista viva, verdes.
  - Los 6 casos de CONTRACT-06, rojos cada uno por su razón:
    - `external-policy` respondía con el error propio del admin (404 `EXTERNAL_SOURCE_NOT_FOUND` y 503);
    - el sync aceptaba `external-status` (202);
    - el control-plane traía `sources`;
    - `/admin/me` traía `manageExternalSources`;
    - `loadConfig` lanzaba con `CATALOG_MONITOR_BASE_URL='ftp://x'`.
- **Diff:**
  - **App (parte B):** sólo borrados (174 líneas) en `admin_control.dart`, `admin_client.dart` y `admin_controller.dart`. En `admin_controller_test.dart` se quitaron `sources:`, el fake de `updateSource` y la aserción sobre `controller.sources`, cuyo objeto se borró.
  - **Backend (parte C):**
    - borrados `externalCatalogClient.ts`, el cableado en `server.ts`, las rutas `GET/PUT /admin/external-policy/:id` y sus helpers (con la auditoría `external_source`), `sources` y `health.sources` del control-plane, el canal `external-status` aceptado, `manageExternalSources`, `catalogMonitor*` y `adminExternalWritesEnabled` en `config.ts` y `.env.example`;
    - `StoredAdminSyncChannel` separa el canal aceptado del almacenado: los trabajos guardados con `external-status` siguen legibles, y uno pendiente termina `failed` con `SYNC_CHANNEL_RETIRED`, con prueba nueva;
    - el orquestador quitó del todo `ServerDeps.externalWritesEnabled`, que el agente había dejado `@deprecated` sin efecto, junto con su línea en el fixture de CONTRACT-06. No cambia ninguna aserción.
  - **Pruebas del backend:**
    - borradas: `adminExternalCatalog.test.ts` (2) y `externalCatalogAdminClient.test.ts` (1);
    - adaptadas: la prueba de idempotencia del sync pasa de `external-status` a `shopify-products` con las mismas aserciones, y se quitan `manageExternalSources` y `sources` de dos `toMatchObject`;
    - nueva: trabajos guardados con el canal retirado.
  - **Documentación:** `docs/ADMIN_CONTROL_PANEL.md` (diagrama, autoridades, rutas, banderas y orden de activación) con una nota del retiro. `docs/ADMIN_CONTROL_PLANE_IMPLEMENTATION_PLAN.md` queda como plan histórico.
  - **No se tocaron:** la migración `009`, `fly.toml`, los `.env` reales y `showExternalPicks`.
- **Contrato:**
  - Sólo se retiran rutas y campos que la app ya no usa.
  - `showExternalPicks` sigue exigido por el backend y lo envía la app.
  - Los eventos de auditoría guardados con `external_source` siguen siendo legibles. `AdminChannel.externalCatalog` los etiqueta y conserva su excepción en ARCH-03.
- **Gates (ejecutados por el auditor sobre el árbol final):**
  - G0 → sólo `lib/`, `test/`, `services/accounts_orders/`, `docs/ADMIN_CONTROL_PANEL.md` y `.claude/refactor/`; `git diff --check` limpio.
  - G1 → `Formatted 329 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → `test/architecture` 4/4; CONTRACT-06 6/6.
  - G4 app → `+1118 ~5: All tests passed!` (base 1117, más la autoprueba nueva de ARCH-03).
  - G4 backend → `Tests 123 passed | 9 skipped (132)` (antes del WP pasaban 119); `typecheck` y `build` limpios.
  - G5 → catálogo válido; secretos OK.
  - G6 → no aplica: no toca nativo, `pubspec` ni la composición.
  - G7 → `REQUIRE_POSTGRES_TESTS=1 …` → `Tests 132 passed (132)`, 0 omitidas.
  - G8 → no aplica.
- **Invariantes:**
  - 12 (admin): la autoridad sigue en el servidor; retirar una capacidad no amplía permisos.
  - 2: no se editó ninguna migración.
  - INV-15 verde con G7.
- **Hallazgos:**
  - [Baja] `showExternalPicks` sigue vivo en ambos lados, aunque ya no gobierna ninguna sección. Retirarlo exige desplegar primero un backend que lo acepte opcional y después la app. Queda para un WP posterior.
  - [Baja] Quedan menciones históricas de `catalog_monitor` en comentarios del backend (`Dockerfile`, `logger.ts`, `README.md:214`, migraciones `001` y `009`) y en `docs/SYSTEM_IMPLEMENTATION.md` §741 y §839. Corresponden a RF-81 y RF-22.
- **Commit:** en `refactor/rf-21-catalogo-externo-admin`, autorizado en esta sesión.
- **Siguiente paso:** RF-22 (dependencias sin uso, Makefile y docs) depende de RF-20, que está bloqueado por G6. RF-23 necesita el inventario de webhooks de la persona. Las demás fases dependen de RF-22. Si la persona no ejecuta G6 ni entrega el inventario, el bucle se detiene aquí.

### 2026-10-08 · RF-23 · verificación previa (D-02) · BLOQUEADO

- **Pedido de la persona:** que el orquestador verifique si alguna suscripción de webhook o app instalada apunta a Firebase Functions.
- **Lo verificado en el repositorio:**
  - **TOMLs de apps de Shopify:** ninguno declara una suscripción hacia Functions.
    - `shopify.app.catalog-mirror.toml` apunta a `https://monetta-catalog-staging.vercel.app/api`.
    - `shopify.app.staging.toml`, a `monetta-accounts-staging.fly.dev/webhooks/*`.
    - `shopify.app.production.toml` y `shopify.app.toml` tienen marcadores `REPLACE_*`.
  - **URLs:** no hay ninguna de `cloudfunctions.net`, `run.app`, `firebaseapp.com` ni `web.app` en el repositorio (`.ts`, `.dart`, `.toml`, `.json`, `.yaml` y `.md`).
  - **`functions/`:** expone `shopifyCatalogWebhook` (HTTPS), `processShopifyCatalogWebhook` (Firestore) y `reconcileShopifyCatalog` (programada). `firebase.json` declara el codebase `catalog-webhooks`.
  - **Lo que deja la duda:** `docs/REALTIME_CATALOG_SETUP.md:135-172` describe cómo crear **por Admin API** (`webhookSubscriptionCreate`) cuatro suscripciones hacia el URL desplegado de `shopifyCatalogWebhook`. Esas suscripciones no quedan en el repositorio.
- **Lo que no se puede verificar desde aquí:** las suscripciones vivas y el despliegue de Functions. Hacen falta credenciales de admin de Shopify y de Firebase, que el orquestador no tiene ni debe usar.
- **Pasos para la persona:**
  1. En cada tienda (Monetta Staging y Monetta real), consultar `webhookSubscriptions` con la app que las creó: GraphiQL de Admin API o `shopify app` sobre el TOML del espejo. Buscar `uri` con `cloudfunctions.net` o `run.app`.
  2. Revisar también Configuración → Notificaciones → Webhooks de la tienda.
  3. En la consola de Firebase, mirar en Functions si `shopifyCatalogWebhook` está desplegada y si tiene invocaciones recientes.
- **Estado:** RF-23 bloqueado hasta esa verificación.

### 2026-10-08 · RF-22 · inicio

- **Decisión de la persona:** seguir con RF-22 tomando como base el código aprobado de RF-20, cuyo G6 sigue pendiente, como se hizo con RF-24 sobre RF-18. Una sola compilación al final cubrirá RF-14, RF-18, RF-20 y RF-22.
- **Rama:** `refactor/rf-22-dependencias-docs`, desde `88b1989`.
- **Verificación previa (orquestador):** las 10 dependencias (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`, `riverpod_lint`, `custom_lint`, `go_router`, `freezed`, `freezed_annotation`, `json_serializable` y `json_annotation`) no tienen ningún import en `lib/`, `test/`, `integration_test/`, `bin/` ni `tool/`, ni anotaciones `@riverpod`, `@freezed` o `@JsonSerializable`. `analysis_options.yaml` no carga `custom_lint`.

### 2026-10-08 · RF-22 · iteración 1 · PENDIENTE DE G6

- **Agentes:** `flutter-implementer` se encargó de las dependencias. El orquestador reescribió la documentación y auditó.
- **Base:** `88b1989`, rama `refactor/rf-22-dependencias-docs`. Sale del código aprobado de RF-20, por decisión de la persona.
- **Diff:**
  - **`pubspec.yaml`:** se quitan `flutter_riverpod`, `riverpod_annotation`, `go_router`, `freezed_annotation`, `json_annotation`, `freezed`, `json_serializable`, `riverpod_generator`, `custom_lint` y `riverpod_lint`, con dos comentarios de sección que quedaron vacíos.
  - **`pubspec.lock`:** regenerado con `flutter pub get --offline`.
  - **`analysis_options.yaml`:** sin la exclusión `**/*.freezed.dart` ni `invalid_annotation_target: ignore`; sigue en 0 issues.
  - **`README.md`:** estado real del producto, toolchain fijado, piezas del repositorio (incluidas las retiradas), comandos de `make` sin conteos viejos y lista de documentación (`US_SOURCING_DURABILITY.md` marcado como histórico).
  - **`docs/ARCHITECTURE.md`:** reescrito con hechos verificados en el código.
    - Capas y composición en `main.dart`, con los scopes `InheritedNotifier`.
    - Estado con `ChangeNotifier`, sin Riverpod; navegación con el Navigator, sin router (E6).
    - Mapa de módulos actualizado: sin `core/` ni `data/external_catalog/`.
    - Reglas: pureza (aplicada por prueba), ARCH-03 y la dirección de dependencias como meta de RF-30 y RF-33.
    - Flujos de arranque (con la procedencia de tienda) y de checkout, con `_app_version` y `_campaign`.
    - Codegen: sólo Drift. Registro de decisiones al día.
    - Se retira la sección del catálogo externo.
- **Verificación del auditor:**
  - Las 10 dependencias no tenían imports ni anotaciones (antes del encargo).
  - Comparación independiente de locks: 209 → 178 entradas; 31 quitadas; 0 añadidas; **0 cambios de versión**; `json_annotation` pasa de `direct main` a `transitive` (lo trae Drift).
  - Nadie importa `package:test`, `test_core` ni `mockito`, y ni el CI ni el `Makefile` corren `dart test`.
  - `build_runner`: el agente regeneró 639 salidas y `git diff --exit-code lib/data/local/database.g.dart` salió con 0. El auditor lo repitió sin cambios.
- **Gates (ejecutados por el auditor):**
  - G0 → `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `README.md`, `docs/ARCHITECTURE.md` y `.claude/refactor/`; `git diff --check` limpio.
  - G1 → `Formatted 329 files (0 changed)`.
  - G2 → «No issues found!».
  - G4 → `+1118 ~5: All tests passed!`.
  - G5 → catálogo válido; secretos OK.
  - G6 → **no ejecutado**: cambia `pubspec`; le toca a la persona.
- **Hallazgos:** [Baja] el aviso de `build_runner` («SDK language version 3.12.0 is newer than `analyzer` language version 3.11.0») viene del toolchain fijado y no afecta al resultado.
- **Commit:** con G6 pendiente, como RF-18 y RF-20.
- **Siguiente paso:** las fases 1 y 2 ya sólo dependen de la persona:
  - G6 sobre esta rama (cubre RF-14, RF-18, RF-20 y RF-22);
  - G8 de RF-14;
  - la verificación de RF-23;
  - RF-17 (capturas DEV-03 y fuentes).

  Las fases 3 y siguientes esperan el lanzamiento (E1).

### 2026-10-08 · RF-17 · paso 0 (diagnóstico y capturas DEV-03) · EN CURSO

- **Diagnóstico de la persona:** lo ve en **iPhone con el texto predeterminado**. El problema apunta a la familia tipográfica, al tamaño nominal o a ambos, no a la escala de texto. Se registró en `PLAN.md`.
- **Autorización:** la persona pidió preparar ya el test de capturas, para correrlo junto con el G6.
- **Agente:** `test-engineer`. El orquestador auditó.
- **Base:** `322a803`, rama `refactor/rf-17-tipografia`.
- **Archivos nuevos:**
  - `integration_test/dev03_typography_captures_test.dart` recorre inicio, una colección del inicio (`home-collection-card-*`), la ficha de la primera pieza con stock (`quick-add-*` → `product-card-*`, esperando `purchase-dock-primary`), la bolsa con una pieza agregada desde el dock y la cuenta.
    - Captura cada pantalla a escala 1.0, 1.3 y la máxima (iOS 3.1, Android 2.0): 15 PNG por dispositivo.
    - Esperas acotadas, sin `pumpAndSettle`. Cada pasada vuelve a la raíz. La escala se restaura en un `finally`.
  - `test_driver/integration_test.dart`: `integrationDriver` guarda cada PNG en `build/dev03_captures/` (ignorado por git).
- **Gates (ejecutados por el auditor):**
  - G1 → `Formatted 331 files (0 changed)`, `test_driver/` incluido.
  - G2 → «No issues found!».
  - La suite de `flutter test` no cambia (el agente informó `+1118 ~5`; el test nuevo no corre ahí).
  - `flutter drive` en simuladores → **no ejecutado**: lo corre la persona.
    - El agente intentó correr el test en el host con `flutter test` y el sandbox lo bloqueó al descargar el framework de escritorio (`storage.googleapis.com` 403). En cualquier caso no aplica: las fuentes del host no son las del sistema.
- **Riesgos de fragilidad** (el test nunca se ejecutó en vivo):
  - Depende de que el inicio tenga una tarjeta de colección y de que esa colección tenga una pieza con stock y la variante 0 disponible.
  - La bolsa persiste en el dispositivo: hay que desinstalar la app antes de cada corrida.
  - Si un paso falla, el mensaje nombra el paso.
- **Comandos para la persona:** están en la cabecera del test. Son `flutter devices` y luego `flutter drive --no-pub --driver=test_driver/integration_test.dart --target=integration_test/dev03_typography_captures_test.dart -d "<id>" --dart-define-from-file=config/dart_defines.ci.json --dart-define=DEV03_DEVICE=<iphone17e|iphone18promax|pixel_api37>`.
- **Commit:** sólo el test y su driver, con `lib/` intacto. RF-17 sigue en curso.
- **Siguiente paso:** cuando la persona entregue las capturas, `test-engineer` escribe UI-01 a UI-03 (paso 1) y se obtienen las fuentes (E-T2).

### 2026-10-08 · RF-17 · re-auditoría del paso 0 y decisiones · APROBADO CON CORRECCIÓN

- **Agente:** orquestador.
- **Base:** `1fa60d8`, rama `refactor/rf-17-tipografia`. `origin/main` sigue en `6b91639` (`git ls-remote`), ya integrado, y no hay PRs nuevos.
- **Selección (`/refactor siguiente`):** ningún WP `pendiente` cumple.
  - Las fases 1 y 2 esperan a la persona: G6 de RF-14, RF-18, RF-20 y RF-22; G8 de RF-14; la verificación de RF-23; las capturas de RF-17.
  - Las fases 3 y siguientes esperan el lanzamiento (E1), y RF-30 depende además de RF-22. RF-80 y RF-81 esperan E12.
- **Hallazgo:** [Alta] `integration_test/dev03_typography_captures_test.dart:22-28` — el comando Android no pasaba `--flavor`.
  - `android/app/build.gradle.kts` define los sabores `staging` y `production`, y `pubspec.yaml` no tiene `default-flavor`.
  - Sin `--flavor`, Flutter 3.44.8 busca `app-debug.apk` (`_apkFilesFor`, `flutter_tools/lib/src/android/gradle.dart:140`) y termina con «Gradle build failed to produce an .apk file» (`:1246`).
  - La auditoría del paso 0 no lo detectó.
  - Corrección del orquestador: `--flavor staging`, como G6 y `make run`, con la nota de que la app se instala como Monetta Staging. iOS sigue sin sabor, igual que G6 iOS (esquema `Runner`, configuración `Debug`).
- **Re-verificación del test:**
  - Las claves y los tipos que usa existen en `lib/`: `home-collection-card-`, `quick-add-`, `product-card-`, `purchase-dock-primary`, `bottom-nav-{home,bag,account}` (por interpolación), `bag-heading-row`, `welcome-start-button`, `onboarding-skip`, `BagScreen` y `MiniCartSheet`.
  - `integration_test` está en `dev_dependencies` y en `ios/Podfile.lock`.
- **Gates (ejecutados por el auditor):**
  - G0 → sólo `integration_test/dev03_typography_captures_test.dart`, con 5 inserciones y 2 borrados, todo comentario; `git diff --check` limpio.
  - G1 → `Formatted 331 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → no aplica: el cambio es un comentario, y el test sólo corre en simuladores (lo corre la persona).
- **Decisiones de la persona en esta iteración:**
  - Commit autorizado para RF-17 en esta sesión.
  - Fuentes (E-T2): las descarga el orquestador con curl desde los repositorios oficiales, con su `OFL.txt`. Se usan TTF estáticos de los pesos usados, que quedan en `assets/fonts/` sin declararse en `pubspec.yaml` hasta el paso 3.
  - D-11: el paso 1 se adelanta. UI-01 a UI-03 se escriben ya, rojas y sin commit, mientras la persona corre G6 y las capturas. Como no tocan `lib/`, las capturas siguen siendo el «antes».
- **Commit:** autorizado. La corrección y este registro van juntos en `refactor/rf-17-tipografia`, sin push.
- **Siguiente paso:** descargar las fuentes (paso 2) y encargar UI-01 a UI-03 a `test-engineer` (paso 1).

### 2026-10-08 · RF-17 · paso 2 (fuentes) · APROBADO

- **Agente:** orquestador, con la autorización de la persona (E-T2).
- **Base:** `e466f11`, rama `refactor/rf-17-tipografia`.
- **Procedencia:**
  - **Inter 4.001**, release v4.1 de `rsms/inter` (repositorio del autor). El zip pesa 33 707 794 B, igual que el tamaño que da la API de GitHub; sha256 `9883fdd4…6b11e`. Se toman los TTF estáticos de `extras/ttf/` y `LICENSE.txt`, que es la OFL 1.1 sin nombre reservado.
  - **Playfair Display 1.203**, descarga oficial de Google Fonts (v40). Los TTF estáticos de `static/` vienen de `fonts.gstatic.com` y `OFL.txt` del manifiesto de descarga, con CRLF pasado a LF y sin los espacios finales de una línea, que `git diff --check` rechaza; el texto no cambia. Su licencia reserva el nombre «Playfair Display»: se usan los archivos sin modificar, porque generar instancias propias sería una versión modificada.
- **Verificación propia** de las tablas `name` y `OS/2` de cada TTF: familias `Inter` y `Playfair Display`; pesos 300, 400, 500, 600 y 700, y 400 y 700; ninguno tiene `fvar` (son estáticos) ni es itálico.
- **Pesos elegidos** (conteo en `lib/`):
  - Inter: w300 (`display` por defecto, 23 llamadas, y una explícita), w400, w500, w600 y w700 (`bold` incluido).
  - Playfair Display: sólo se pide a 400 (`boutiqueDisplay`, 12 llamadas; `editorial`, 22, cuando pase a la serif). Se añade el Bold porque `Text` pide w700 cuando el sistema activa el texto en negrita (`MediaQuery.boldTextOf`).
  - Queda fuera w800: sólo lo usan dos marcas de pago itálicas (`_PayPalMark` y `_VisaMark`, en `home_account_invitation.dart`). El paso 3 decide si añade Inter ExtraBold Italic (428 KB) o acepta el peso más cercano.
- **Archivos nuevos** en `assets/fonts/`, sin declarar en `pubspec.yaml` (que sólo empaqueta `assets/rules/`, `assets/images/`, `assets/images/brands/` y `assets/catalog/`): la app no cambia.
  - `inter/`: `Inter-Light.ttf`, `Inter-Regular.ttf`, `Inter-Medium.ttf`, `Inter-SemiBold.ttf`, `Inter-Bold.ttf` y `OFL.txt`.
  - `playfair_display/`: `PlayfairDisplay-Regular.ttf`, `PlayfairDisplay-Bold.ttf` y `OFL.txt`.
  - Total: 2 469 056 B sin comprimir (2 081 956 B de Inter y 387 100 B de Playfair). El aumento real del bundle se mide en el paso 3.
- **Resto de la descarga oficial:** en `scratch/fonts-official/` (ignorado por git), con `SOURCES.md` y el sha256 de cada archivo. Sirve si el paso 3 necesita otro peso, porque los subagentes no descargan.
- **Gates (ejecutados por el auditor):**
  - G0 → sólo `assets/fonts/` (9 archivos) y `.claude/refactor/BITACORA.md`.
  - G5 secretos → «OK: no private secret patterns found in tracked or commit-candidate files».
  - G1, G2 y G3 → no aplican: no hay Dart.
  - G6 → no aplica todavía: nada se empaqueta hasta que el paso 3 declare las fuentes.
- **Commit:** autorizado, en `refactor/rf-17-tipografia`, sin push.
- **Siguiente paso:** encargar UI-01 a UI-03 a `test-engineer` (paso 1, D-11).

### 2026-10-08 · RF-17 · paso 1 (UI-01 a UI-03), iteraciones 1 y 2 · APROBADO

- **Agente:** `test-engineer`. El orquestador auditó.
- **Base:** `ffb2914`, rama `refactor/rf-17-tipografia`.
- **Archivos nuevos (sin commit, porque son pruebas rojas):**
  - `test/app/bundled_fonts_test.dart` (UI-01, 20 pruebas) y `test/app/text_scale_policy_test.dart` (UI-02, 6).
  - `test/features/text_scale/` (UI-03, 60): `text_scale_catalog_screens_test.dart`, `text_scale_purchase_screens_test.dart` y `text_scale_account_screens_test.dart`.
  - Soportes en `test/support/`: `bundled_fonts.dart` (registra los TTF de `assets/fonts/`), `monetta_app_harness.dart` (monta `MonettaApp` con sus bordes de plataforma falsos), `e_t1_text_scaler.dart` (el oráculo `expected(s, k)`) y `text_scale_matrix.dart` (2 teléfonos × 3 escalas, recorrido acotado y registro de cada `FlutterError`).
  - `lib/` no cambia.
- **Iteración 2:** hallazgos Media corregidos en las anclas de UI-03.
  - Ficha: el ancla era `find.byType(ProductScreen)`, que siempre se cumple. Ahora es «Agregar al carrito» bajo `purchase-dock-primary`, porque esa clave también existe en la rama sin stock.
  - Colección y Búsqueda: exigen al menos una tarjeta `product-card-*`.
- **Gates (ejecutados por el auditor):**
  - G0 → sólo 9 archivos nuevos en `test/`; `lib/` intacto.
  - G1 → `Formatted 340 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → `+56 -30`. Cada rojo falla por la razón descrita:
    - **UI-01, 20 rojos:** `FontManifest.json must declare "Inter"; it declares [MaterialIcons]`. Los 5 helpers de `theme.dart` usan Helvetica Neue, New York o `null`. Los 8 helpers boutique piden un peso que el manifiesto no declara. Los temas, en Android y en iOS, usan Roboto, `CupertinoSystemText` o Helvetica Neue. No hay licencia registrada.
    - **UI-02, 4 rojos:** a k = 1.3, 2.0 y 3.1 y en el cambio en caliente hay 92, 220, 229 y 229 violaciones, porque la escala es lineal (`MediaQuery scale(14.0) = 43.4, expected 21.0 at k=3.1`). A 0.85 y 1.0 ya pasa, como se esperaba.
    - **UI-03, 6 rojos, todos overflows reales:**
      - 4 en `Column@lib/features/catalog/product_tile.dart:316`: Inicio @1.5 en los dos teléfonos, y Colección y Búsqueda 440×956 @1.5. El texto es Inter, registrada.
      - 2 en Inicio @1.3: `customer_experiences_section.dart:704` (31 px) y `home_account_invitation.dart:146` (5 px). Ese texto usa `sans()`, sin familia, y hoy se dibuja con la fuente de pruebas.
  - Suite completa → `+1174 ~5 -30`. Los 30 fallos son exactamente los rojos nuevos; las 1118 previas siguen verdes.
- **Hallazgos:**
  - [Media, corregido en la iteración 2] anclas débiles en UI-03.
  - [Alta para el paso 3] Las alturas reservadas con `textScaler.scale(<alto>)` chocan con D-12: una altura grande cuenta como titular y queda topada en 1.2× mientras su texto crece 1.5×. Pasó a requisito del paso 3 en `PLAN.md`.
  - [Media para el paso 3] Los `OFL.txt` no son assets, y `rootBundle` no puede leerlos. También pasó a requisito.
  - [Baja] UI-02 observa pocos párrafos, porque el arnés monta un catálogo vacío. UI-03 cubre los párrafos con datos reales.
- **Decisión del orquestador:** las pruebas de tema cubren también iOS (`CupertinoSystemText`), más allá del encargo. Se aceptan, porque la app corre en iOS.
- **Commit:** sólo este registro y el plan. Las pruebas rojas siguen sin commit hasta el paso 3.
- **Siguiente paso:** el paso 3 espera las capturas DEV-03 de la persona («antes de cualquier cambio de tipografía»).

### 2026-10-09 · RF-17 · inicio del paso 3 y trabajo fuera del plan · EN CURSO

- **Pedido de la persona** (antes de dormir): el máximo avance posible en lo que no la requiere.
- **Lo que no puede avanzar sin ella:**
  - el G6 de RF-14, RF-18, RF-20 y RF-22;
  - el G8 de RF-14;
  - la verificación de RF-23;
  - las capturas DEV-03.
  - Las fases 3 y siguientes esperan el lanzamiento (E1); no se empiezan sin su permiso.
- **Decisión del orquestador: el paso 3 de RF-17 empieza antes de las capturas, sin perder el «antes».**
  - El plan pide las capturas «antes de cualquier cambio de tipografía». Para que eso siga siendo posible se creó el worktree `.claude/worktrees/rf-17-antes`, separado en `e14d2e6`, con la receta del sandbox (sin `.claude/`) y `flutter pub get --offline`.
  - Su `lib/` es idéntico al de RF-22, y trae el test de capturas con `--flavor staging`.
  - La persona corre ahí los comandos de la cabecera del test.
  - El paso 3 avanza en el checkout principal, sobre `refactor/rf-17-tipografia`.
- **Asignación de familias del paso 3** (se deriva del plan: «roles unificados» con la serif y la sans de los tokens boutique):
  - cada helper conserva su carácter: `editorial` pasa a Playfair Display y `display`, `wordmark`, `eyebrow` y `sans` pasan a Inter;
  - no cambian ni pesos ni métricas;
  - es reversible línea por línea, y la persona la revisa con DEV-03.
- **Hecho técnico verificado:**
  - `flutter test` arranca `flutter_tester` con `--disable-asset-fonts` (`flutter_tools/lib/src/test/flutter_tester_device.dart:119`), así que declarar las fuentes en `pubspec.yaml` no cambia ninguna prueba ni golden existente;
  - UI-03 registra las fuentes reales con `FontLoader`.
- **Trabajo fuera del plan: quitar el envío gratis desde $1,499**, pedido por la persona el 2026-10-08.
  - Va en el worktree `.claude/worktrees/sin-envio-gratis-main`, rama `fix/sin-envio-gratis-main`, que sale de `origin/main` (`6b91639`). Commit `0703176`, sin push. El push y el PR los hace la persona.
  - Pruebas SHIP-01 a SHIP-07 primero, con las dos pruebas viejas convertidas de forma explícita y la unitaria de las funciones retiradas quitada; después, la implementación.
  - Gates del auditor en el worktree: G0 en alcance; G1 `Formatted 331 files (0 changed)`; G2 «No issues found!»; G4 `+1097 ~5: All tests passed!` (base 1077, +21, −1); G5 catálogo válido y secretos OK.
  - **Integración futura (D-06):** la simulación `git merge-tree e14d2e6 0703176` da un solo conflicto, en `lib/features/checkout/checkout_screen.dart`. RF-18 reemplazó `_SummaryRow` por `CheckoutSummaryRow`, y el cambio del envío hace que esa fila parta un valor largo. Al integrar `main`, ese comportamiento pasa a `CheckoutSummaryRow`.

### 2026-10-09 · RF-17 · paso 3, iteración 1 · APROBADO (PENDIENTE DE G6, G8 Y UI-04)

- **Agente:** `flutter-implementer`. El orquestador auditó.
- **Base:** `4310b07`, rama `refactor/rf-17-tipografia`.
- **Diff:**
  - **`pubspec.yaml`:** sección `fonts:` con Inter (300, 400, 500, 600 y 700) y Playfair Display (400 y 700), más los dos `OFL.txt` en `assets:`, declarados uno por uno. `pubspec.lock` no cambia.
  - **`lib/app/theme.dart`:**
    - las familias tienen una sola fuente: `kSansFontFamily` (Inter) y `kSerifFontFamily` (Playfair Display), con sus listas de respaldo;
    - `display`, `wordmark`, `eyebrow` y `sans` pasan a Inter, y `editorial` a Playfair; firmas, pesos y métricas intactos;
    - `kEditorialFontFamily` apunta a la serif;
    - `buildTheme` fija `fontFamily` y `fontFamilyFallback`.
  - **`boutique_tokens.dart`:** sus cuatro constantes públicas pasan a ser alias, con los mismos valores.
  - **`lib/app/text_scale_policy.dart`** (nuevo):
    - `BoundedTextScaler` aplica `min(sistema, s ≥ 20 ? 1.2·s : min(1.5·s, 24))`;
    - el getter obsoleto `textScaleFactor` se estima con `scale()` a 14 px, para no leer un miembro obsoleto ni usar `// ignore`;
    - `textScaleFactorFor` da el factor que se aplica a un tamaño de texto.
  - **`lib/app/font_licenses.dart`** (nuevo): `registerFontLicenses()`, idempotente, lee los `OFL.txt` con `rootBundle`.
  - **`lib/main.dart`:**
    - `initState` registra las licencias;
    - el `builder` del `MaterialApp` envuelve todo en `MediaQuery(textScaler: BoundedTextScaler(...))`.
  - **Alturas reservadas:** los 7 sitios usan `alto × textScaleFactorFor(escala, tamaño del texto que contienen)`. El encargo decía 8, pero `grep` confirma que son 7. Con un escalador lineal el resultado es idéntico.
    - Ficha de producto, rail de novedades del inicio y rail de búsqueda: el `nameSize` del producto (13 o 14).
    - Etiquetas de «Compra por estilo» del inicio: 13.
    - Chips y pestañas de marca: 14.
    - Rail de la ficha: 14.
  - **Extra declarado: `home_screen.dart`.**
    - El rail de ofertas tenía alto fijo de 430 y su texto desbordaba a 1.3 y a 1.5 (`Column@home_screen.dart:808`, 17 y 25 px).
    - Ahora crece con lo que crece su texto (eyebrow 11, título 22 de dos líneas y descripción 13 de dos líneas), repartido en las 21 partes de la tarjeta. Las constantes coinciden con `_OfferCard`; lo verificó el auditor.
- **Verificación del auditor:**
  - las 9 pruebas rojas no se modificaron: su fecha es anterior a `e14d2e6`;
  - el diff completo se leyó.
- **Gates (ejecutados por el auditor):**
  - G0 → 11 archivos modificados y 2 nuevos en `lib/`, más `pubspec.yaml`; `git diff --check` limpio.
  - G1 → `Formatted 342 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → UI-01, UI-02 y UI-03: `+86: All tests passed!`.
  - G4 → `+1204 ~5: All tests passed!` (base 1118 + 86).
  - G5 → catálogo válido (103 productos, 340 imágenes); secretos OK.
  - G6 → **no ejecutado**: cambia `pubspec.yaml` y empaqueta fuentes; le toca a la persona.
  - G8 → **no ejecutado**: DEV-03; le toca a la persona.
  - UI-04 → **no empezado**. Con fuentes reales, un golden hecho en macOS no coincide con el del CI de Ubuntu, y la regla prohíbe `skip:`. La estrategia (por ejemplo, una etiqueta sólo para macOS con tolerancia) la decide la persona.
- **Tamaño:** las fuentes suman 2 477 885 B sin comprimir (2.36 MiB) y 1 178 579 B con deflate (≈ 1.12 MiB, el crecimiento estimado de la descarga). El número real sale del G6 de la persona.
- **Filas de la matriz:** UI-01, UI-02 y UI-03 → verdes.
- **Hallazgos:**
  - [Baja] `home_screen.dart` (`_HomeOffersSection`): la altura del rail repite a mano los tamaños de `_OfferCard`; si cambia la tarjeta, puede desincronizarse.
  - [Baja] `_ConfigurationErrorApp` no aplica la política de escala. Es una pantalla de error de configuración y queda fuera del alcance.
  - [Baja] Las listas de respaldo conservan nombres de plataforma (`SF Pro Text`, `New York`). Sólo se usan si fallan las fuentes empaquetadas.
- **Cambio visible:** toda la app pasa a Inter y Playfair Display. La persona lo verifica con DEV-03: «antes» en `.claude/worktrees/rf-17-antes`, «después» en el checkout principal.
- **Commit:** autorizado. Van juntos el código, las pruebas UI-01 a UI-03 (ya verdes) y este registro.
- **Siguiente paso:** las fases 1 y 2 ya sólo dependen de la persona. Ella tiene que:
  - correr G6 sobre esta rama, que cubre RF-14, RF-18, RF-20, RF-22 y RF-17;
  - hacer las capturas DEV-03;
  - correr el G8 de RF-14;
  - decidir la estrategia de UI-04;
  - hacer la verificación de RF-23.

### 2026-10-09 · Ensayo de integración del envío gratis (D-06) · APROBADO COMO ENSAYO

- **Motivo:** dejar lista la integración de `fix/sin-envio-gratis-main` (`0703176`) para cuando la persona fusione su PR en `main`, y comprobar que la línea del refactor con RF-17 sigue verde con los textos nuevos.
- **Procedimiento:**
  - Worktree desechable en `168656b` y `git merge --no-commit 0703176`.
  - El ensayo no hizo ningún commit: el merge se abortó y el worktree se borró.
- **Conflictos:** dos trozos en `lib/features/checkout/checkout_screen.dart`, los dos por el renombre de RF-18.
  - La fila de total de `_OrderSummary` queda como `CheckoutSummaryRow(label: 'Total estimado', value: kMoney.format(subtotal), prominent: true)`.
  - La clase `_SummaryRow`, que la línea del refactor borró y la rama modificó, se borra.
  - Su ajuste (valor acotado al 65 % del ancho y partido en líneas) pasa a `CheckoutSummaryRow`, en `lib/features/checkout/checkout_summary_row.dart`. Ese widget también lo usa el resumen remoto.
  - Lo demás se fusionó solo.
- **Resultado sobre el árbol fusionado:**
  - formato → `Formatted 344 files (0 changed)`;
  - análisis → «No issues found!»;
  - suite → `+1224 ~5: All tests passed!`, es decir 1204 + 21 SHIP − 1 prueba unitaria retirada.
- **Parche de la resolución:** `scratch/sync-envio-gratis/resolucion_sobre_168656b.patch` (ignorado por git; 338 líneas, diff contra `168656b`).
- **Siguiente paso:** cuando el PR esté en `main`, integrar `main` en la línea del refactor (D-06) con esta resolución y registrar los gates.

### 2026-10-09 · RF-17 · documentación · APROBADO

- **Hallazgo del checklist** (Docs), que faltó en la auditoría del paso 3: RF-17 cambia la arquitectura (fuentes empaquetadas y política de escala en la raíz), y `docs/ARCHITECTURE.md` no lo decía.
- **Corrección del orquestador en `docs/ARCHITECTURE.md`:**
  - en el mapa de módulos, `app/` incluye ahora la tipografía;
  - la regla 4 fija las dos familias empaquetadas, `BoundedTextScaler` en la raíz y el uso de `textScaleFactorFor` para las alturas que contienen texto;
  - el registro de decisiones suma dos filas: tipografía (E-T2) y escala de texto (E-T1 y D-12).
- `docs/SYSTEM_IMPLEMENTATION.md` no trata la tipografía, así que no cambia.

### 2026-10-09 · RF-30 · paso 1 (ARCH-01, ARCH-04 y CHAR-15) · APROBADO

- **Decisión de la persona:** D-14. La fase 3 empieza en ramas aparte que salen de `38d97cb`.
- **Agente:** `test-engineer`. El orquestador auditó.
- **Base:** worktree `.claude/worktrees/rf-30`, rama `refactor/rf-30-composicion`, desde `38d97cb`.
- **Pruebas nuevas** (sin commit hasta que se implemente):
  - `test/architecture/features_main_import_test.dart` (ARCH-01, TRQ): fija los 17 archivos de `lib/features/` que importan `main.dart`, e incluye una autoprueba del detector de imports.
  - `test/architecture/composition_root_test.dart` (ARCH-04, TRQ):
    - **Qué cuenta como implementación concreta:** una clase pública, no abstracta ni sellada, declarada en `lib/data/**`, cuyo nombre termine en uno de 14 sufijos de rol (`Client`, `Repository`, `Store`, …).
    - **Mapa conocido:** 46 pares. Hay 31 en `lib/main.dart`, 8 en `catalog_store.dart`, 5 en `shopify_cart_composition.dart`, 1 en `customer_experiences_screen.dart` y 1 en `rewards_api.dart`.
    - **Guardas:** una impide que la prueba pase en vacío y otra es la autoprueba del detector.
  - `test/app/route_scopes_test.dart` (CHAR-15, OBJ): con `MonettaApp` montada, una ruta empujada debe ver cada scope que ve el inicio.
- **Gates (ejecutados por el auditor en el worktree):**
  - G0 → sólo 3 archivos nuevos en `test/`.
  - G1 → `Formatted 344 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → `+9 -1` en `test/architecture/` más CHAR-15. ARCH-01 y ARCH-04 pasan.
    - CHAR-15 falla por la razón descrita: a la ruta empujada le faltan `EditorialContentScope`, `HomeContentScope`, `FeaturedCatalogScope`, `AdminScope`, `AdminNotificationScope` y `OnboardingScope`.
    - `CartScope` no lo ve ni el inicio, porque el arnés no configura Storefront.
  - Suite → `+1209 ~5 -1`: sólo falla CHAR-15.
  - El agente demostró, con copias temporales ya borradas, que los dos trinquetes fallan ante una violación nueva y ante una entrada que ya no existe.
- **Hallazgos:**
  - [Baja] El comentario de ARCH-04 dice que RF-30 debe vaciar el mapa. El plan reparte ARCH-04 entre RF-30 y RF-33, y las construcciones internas de `CatalogStore` corresponden a RF-50. Se corrige en la implementación.
  - [Nota] Fuera de la definición de ARCH-04 quedan `MethodChannelCheckoutLauncher` (`lib/platform/`, que construye `shopify_cart_composition.dart:52`) y los clientes de Rewards de `lib/features/rewards/`. Se evalúan en RF-33.
- **Decisiones del orquestador para la implementación:**
  - `lib/app/shopify_cart_composition.dart` no se mueve en RF-30: `test/architecture_test.dart:83-120` (INV-12) exige esa ruta, y sus entradas de ARCH-04 quedan para RF-33.
  - `AppRouteScopes` conserva su constructor, porque lo montan `checkout_screen_test.dart` y `account_package_e_test.dart`.
- **Siguiente paso:** la implementación (`flutter-implementer`). Se espera `+1210 ~5`: ARCH-01 vacío, ARCH-04 sin `main.dart` y CHAR-15 en verde.

### 2026-10-09 · RF-30 · iteración 1 · APROBADO (PENDIENTE DE G6)

- **Agente:** `flutter-implementer`. El orquestador auditó.
- **Base:** `38d97cb`, rama `refactor/rf-30-composicion`, worktree `.claude/worktrees/rf-30`. Commits `ca474b4` (código y pruebas) y `80753e3` (documentación).
- **Diff:**
  - **`lib/main.dart`:** pasa de 1 028 a 12 líneas, con `main() => bootstrap()` y los `export` de los scopes y de `MonettaApp`.
  - **Nuevos:**
    - `lib/app/bootstrap.dart`: lo que hacía `main()`, más `_installTelemetryErrorHandlers` y `_ConfigurationErrorApp`.
    - `lib/app/monetta_app.dart`: `MonettaApp`, con el mismo constructor, más las rutas de notificación y `_ErrorScreen`.
    - `lib/app/composition/app_dependencies.dart`: la construcción, `load()`, el listener de capacidades y `dispose`.
    - `lib/app/composition/app_scopes.dart`: los 9 scopes y `AppRouteScopes`, que suma 6 controladores opcionales.
    - `lib/app/composition/platform_services.dart`: Firestore y el gateway de notificaciones.
  - **Las 17 features:** sólo cambia el import, de `main.dart` a `app/composition/app_scopes.dart` (+17 −17 líneas).
  - **`home:`** queda en `WelcomeGate(child: HomeScreen())`, y todos los scopes envuelven el Navigator.
- **Paridad verificada por el auditor** (diff normalizado de `_x` a `x` y de `widget.x` a `x`, contra `HEAD:lib/main.dart`):
  - `_load()` frente a `AppDependencies.load()`: 155 líneas contra 155, con 0 diferencias. Incluye el cambio de cuenta del invariante 9 (`setAccountScope`, `SearchHistory.setScope` e `invalidate()` del checkout).
  - `_openNotificationRoute`, `_openPendingNotificationRoute` y `_navigateToNotificationRoute`: 0 diferencias.
  - `main()` frente a `bootstrap()`: sólo cambian las dos construcciones, que pasan a `platform_services.dart`.
  - `dispose()`: igual, salvo `super.dispose()`, que ahora llama el `State`.
- **Pruebas:**
  - ARCH-01 se queda con la lista vacía.
  - ARCH-04 pierde la entrada de `lib/main.dart`, y su comentario reparte el resto entre RF-33 y RF-50.
  - CHAR-15 pasa sin cambios.
  - Ninguna otra prueba se tocó.
- **Gates (ejecutados por el auditor en el worktree):**
  - G0 → alcance esperado; `git diff --check` limpio.
  - G1 → `Formatted 349 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → los trinquetes, CHAR-15, CHAR-08 y CHAR-09, más INV-02, INV-07, INV-11, INV-12 e INV-13: `+86: All tests passed!`.
  - G4 → `+1210 ~5: All tests passed!` (1204 + 5 de los trinquetes + CHAR-15).
  - G5 → catálogo válido; secretos OK.
  - G6 → **no ejecutado**: cambia la composición del arranque; le toca a la persona, sobre esta rama.
- **Documentación:** `docs/ARCHITECTURE.md` describe la raíz de composición. La regla 3 pasa de «goal, not yet true» a «partly enforced».
- **Hallazgos:**
  - [Baja] `AppDatabase` sigue sin cerrarse en `dispose`, como antes; corresponde a RF-51.
  - [Baja] `AppDependencies` importa `features/catalog/search_history`, igual que antes `main.dart`. Se retoma en RF-32 o RF-33.
  - [Nota] `MonettaApp` vive en `lib/app/`, fuera de `composition/`, y no construye clases de `data/` (ARCH-04 verde).
- **Siguiente paso:** RF-31, sobre esta rama y con el criterio de D-14 (RF-14 tiene el código aprobado; su G6 y G8 siguen pendientes).

### 2026-10-09 · RF-17 · paso 4 (UI-04), iteración 1 · APROBADO (PENDIENTE DE LA APROBACIÓN DE LA PERSONA)

- **Decisión de la persona:** D-15, goldens con etiqueta, sólo en macOS y con tolerancia.
- **Agentes:** `test-engineer`, que hizo los goldens. El orquestador cambió el CI y auditó. El agente entregó un informe parcial, y el auditor ejecutó todo por su cuenta.
- **Base:** `820de0d`, rama `refactor/rf-17-tipografia`.
- **Diff:**
  - **`test/goldens/ui04_typography_goldens_test.dart`:** 10 casos `UI-04 <pantalla> <ancho>x<alto> golden` con `tags: ['golden']`.
    - Pantallas: inicio, colección, ficha, bolsa y cuenta, a 375×812 y 440×956 con DPR 3.
    - Escala 1.0 y tema claro.
    - En `setUpAll` se registran Inter, Playfair Display y `MaterialIcons` (desde `rootBundle`). El comparador tolerante se instala ahí y se restaura en `tearDownAll`.
  - **`test/goldens/ui04/*.png`:** 10 imágenes, unos 3.3 MB; la mayor es la del inicio a 440×956, con 1.08 MB.
  - **`test/support/tolerant_golden_comparator.dart`:** un `LocalFileComparator` que acepta un `diffPercent` de hasta 0.005. Si lo supera, falla con el informe estándar.
  - **`dart_test.yaml`** (orquestador): declara la etiqueta `golden`.
  - **`.github/workflows/quality.yml`** (orquestador): el job `flutter` (Ubuntu) corre `flutter test --exclude-tags golden`, y el job `ios-compile` (macos-15) añade `flutter test --tags golden`.
- **Revisión visual del auditor** (ficha y cuenta, 375×812):
  - se ven Inter en la sans, Playfair Display en la serif e iconos reales;
  - las fotos de producto quedan en su estado vacío, siempre igual.
  - Para la persona: en la ficha, el título del encabezado ocupa dos líneas en negrita y el nombre del producto (24 px), tres. Es el tamaño nominal que se juzga en DEV-03.
- **Gates (ejecutados por el auditor):**
  - G0 → archivos dentro del alcance.
  - G1 → `Formatted 344 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → `flutter test --tags golden test/goldens/` dos veces seguidas: `+10: All tests passed!` y `+10: All tests passed!`, deterministas.
  - G4 → `--exclude-tags golden`, el equivalente del CI en Ubuntu: `+1204 ~5: All tests passed!`. Suite completa en macOS: `+1214 ~5: All tests passed!`.
  - G5 → catálogo válido; secretos OK.
- **Riesgo:** los goldens se generaron en el macOS local. El job `macos-15` del CI puede superar el 0.5 % si CoreText dibuja distinto. Hay que mirarlo en el primer push; la tolerancia es un número dentro de `ui04_typography_goldens_test.dart`.
- **Commit:** autorizado (RF-17).
- **Siguiente paso:** la persona aprueba las 10 imágenes de `test/goldens/ui04/`. Con eso, el G6 y DEV-03, RF-17 se cierra.

### 2026-10-09 · RF-31 · paso 1 (CHAR-02) · APROBADO

- **Agente:** `test-engineer`. El orquestador auditó.
- **Base:** worktree de la fase 3 (`.claude/worktrees/rf-30`), rama `refactor/rf-31-destinos`, desde `80753e3`.
- **Prueba nueva** (sin commit): `test/app/destinations/destination_navigator_test.dart` (CHAR-02, OBJ), con 23 casos contra la API acordada:
  - 8 casos de `AppDestination.fromNotification`;
  - 15 de `DestinationNavigator.open`: en caché, búsqueda que encuentra, `upToDate` o `updated` sin el producto, `failed`, `skippedNotConfigured`, `skippedRealtimeAuthoritative`, excepción, tres variantes de «Reintentar», colección con y sin título, enlace no disponible e inicio.
- **Fase roja verificada por el auditor** (precedente de RF-15):
  - Sin la API, la prueba no compila (`uri_does_not_exist`, 46 issues de analyze, todos en ese archivo).
  - Con un stub temporal que reproduce la navegación de hoy, ya borrado, compila y da `+8 -15`, sin errores de compilación.
    - Pasan los 7 casos de `fromNotification` que hoy ya se cumplen y el de «inicio».
    - Fallan los que piden algo nuevo: `external:*` como enlace no disponible, la búsqueda fuera de caché, el reintento y la pantalla de enlace.
    - También fallan producto en caché y colección, por la razón esperada: la navegación de hoy empuja la ruta sin `StoreScope` («StoreScope is missing from the tree»), y el objetivo exige envolverla como hacen los helpers.
- **Suite sin la prueba nueva:** `+1210 ~5`, la base, según el agente.
- **Siguiente paso:** implementación (`flutter-implementer`).

### 2026-10-09 · RF-31 · iteración 1 · APROBADO (PENDIENTE DE G6 Y G8)

- **Agente:** `flutter-implementer`. El orquestador auditó.
- **Base:** `80753e3`, rama `refactor/rf-31-destinos`, worktree de la fase 3. Commit `1b44983`.
- **Diff:**
  - **Nuevo, `lib/app/destinations/`:**
    - `app_destination.dart`: el `AppDestination` sellado, con `NavigationOrigin` y `fromNotification`. Un id o un handle vacíos van al inicio.
    - `destination_navigator.dart`: `DestinationNavigator.open`. Todo `push` usa `monettaFadeRoute(StoreScope(...))`.
    - `destination_screens.dart`, con dos pantallas:
      - `ProductLookupScreen`: busca, queda «ya no disponible» con `ProductUnavailable` o «no se pudo comprobar» con «Reintentar». Un contador de intentos descarta las respuestas tardías.
      - `UnavailableLinkScreen`.
  - **`lib/app/monetta_app.dart`:** `_navigateToNotificationRoute` delega en el resolver. La ruta pendiente de arranque en frío no cambia.
  - **`lib/features/catalog/product_card.dart`:** `openProduct` sigue registrando `productView`, delega en el resolver y suma un `origin` opcional.
  - **`openCollection`:** no cambia, porque recibe una pantalla ya armada. Ajustarlo exigiría cambiar su firma.
  - **`docs/ARCHITECTURE.md`:** añade la sección «Navigation destinations».
- **Checklist:**
  - Invariante 5: la búsqueda sólo usa `syncWithShopify`, que pasa por el coordinador.
  - Invariante 9: la búsqueda no depende de la cuenta y no toca la bolsa ni los favoritos.
  - Textos en español; ausencia y fallo de comprobación son estados distintos.
- **Gates (ejecutados por el auditor en el worktree):**
  - G0 → alcance esperado; `git diff --check` limpio.
  - G1 → `Formatted 353 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → CHAR-02, CHAR-08, CHAR-09 y las pruebas de notificaciones: `+41: All tests passed!`.
  - G4 → `+1233 ~5: All tests passed!` (1210 + 23).
  - G5 → catálogo válido; secretos OK.
  - G6 → **no ejecutado**: le toca a la persona.
  - G8 → **no ejecutado**: los pasos de push de DEV-01 y DEV-02 en simuladores le tocan a la persona.
- **Hallazgos:**
  - [Baja] «No se pudo comprobar» dice «Revisa tu conexión» también cuando la causa es `skippedNotConfigured` o `skippedRealtimeAuthoritative`. Es el texto acordado en CHAR-02, y en producción esos casos casi no ocurren.
  - [Baja] Notificaciones y tarjetas comparten ahora la transición de desvanecido (antes la notificación usaba `MaterialPageRoute`).
  - [Nota] Si una tarjeta abre un producto que no está en caché, ahora sale la búsqueda en vez de una ficha vacía.
- **Siguiente paso:** RF-32, sobre esta rama.

### 2026-10-09 · RF-32 · paso 1 (CHAR-16) · APROBADO

- **Agente:** `test-engineer`. El orquestador auditó.
- **Base:** worktree de la fase 3, rama `refactor/rf-32-shopper-scope`, desde `1b44983`.
- **Prueba nueva** (sin commit): `test/app/account_scope_switch_test.dart` (CHAR-16, CAR), con 6 casos.
  - **Bolsa y favoritos:** 4 casos.
    - Primero, invitado → A → B lanzados uno tras otro, y luego B → invitado.
    - Después, las variantes con A o con B **retenidas**. Un `QueryInterceptor` de Drift sobre `AppDatabase(NativeDatabase.memory(...).interceptWith(...))` detiene los `SELECT` de esa cuenta hasta que la prueba los suelta, así que la respuesta tardía queda garantizada sin depender de tiempos.
  - **Historial de búsqueda:** 2 casos, con instancias aisladas y una persistencia controlada con `Completer`s.
- **Gates (ejecutados por el auditor):**
  - CHAR-16 → `+6: All tests passed!`.
  - Formato y análisis limpios, según el agente.
  - Suite → `+1239 ~5` (1233 + 6), según el agente.
- **Mutación del auditor:** se quitó a mano el guard de `catalog_store.dart:259` y se restauró con `git checkout`.
  - Fallan los 4 casos de bolsa y favoritos (`+2 -4`).
  - Los 2 de historial siguen verdes, porque los protege otro guard.
  - La prueba detecta la regresión del invariante 9.
- **Observación del agente** (sin corregir; es el comportamiento vigente): `setAccountScope` notifica aunque el guard haya descartado su hidratación. Durante un instante el listener puede ver el estado anterior, nunca el de A.
- **Siguiente paso:** la implementación (`ShopperScope` y `ChangeAccountScope`).

### 2026-10-09 · RF-32 · iteración 1 · CERRADO

- **Agente:** `flutter-implementer`. El orquestador auditó.
- **Base:** `1b44983`, rama `refactor/rf-32-shopper-scope`, worktree de la fase 3. Commit `732f9e8`.
- **Diff:**
  - `lib/domain/shopper_scope.dart` (nuevo, Dart puro): `ShopperScope`, con la tienda y la cuenta, `isGuest` y `bagAccountKey` (`''` para el invitado). No normaliza nada.
  - `lib/app/change_account_scope.dart` (nuevo): el caso de uso. Llama a `store.setAccountScope`, luego a `searchHistory.setScope` y luego invalida el checkout, en el mismo orden que antes. Las dependencias son inyectables.
  - `app_dependencies.dart`: el callback de `AccountController` delega en el caso de uso. La invalidación lee `shopifyCart` en el momento de la llamada, como antes.
  - Pruebas CHAR-16b: 5 de `ShopperScope` y 6 de `ChangeAccountScope`, que cubren el orden y la invalidación en login, logout y cambio A→B.
  - `docs/ARCHITECTURE.md` describe el caso de uso.
- **Gates (ejecutados por el auditor en el worktree):**
  - G0 → alcance esperado; `git diff --check` limpio.
  - G1 → `Formatted 358 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → CHAR-16, CHAR-16b, INV-02, INV-08 e INV-12: `+120: All tests passed!`.
  - G4 → `+1250 ~5: All tests passed!` (1233 + 6 + 11).
  - G5 → catálogo válido; secretos OK.
  - G6 a G8 → no aplican, según la matriz.
- **Hallazgos:** [Baja] `ChangeAccountScope` importa `features/catalog/search_history.dart`, el mismo acoplamiento que ya tenía la composición. Se revisa con ARCH-02 en RF-33.
- **Siguiente paso:** RF-33, sobre esta rama.

### 2026-10-09 · RF-33 · iteración 1 · CERRADO

- **Agente:** `test-engineer`. El orquestador auditó.
- **Base:** `732f9e8`, rama `refactor/rf-33-arquitectura`, worktree de la fase 3. Commit `e719391`.
- **Diff:**
  - **`test/architecture/features_data_imports_test.dart`** (ARCH-02, TRQ), con 4 pruebas: la autoprueba del detector, la de la lista de permitidos, la guarda contra el vacío y el trinquete.
    - **Permitidos:** `media_url.dart`, `normalize/`, `notification_models.dart`, `customer_auth_error.dart`, el puerto `checkout_launcher.dart`, `accounts_orders_config.dart` y `cart_attribution.dart` (puro, sin imports).
    - **Lista conocida:** 14 pares en 9 archivos, cada uno con su WP.
      - `catalog_cache_store` → RF-50.
      - `cart_session_store` → RF-51 y `cart_repository` → RF-52.
      - `database.dart` (`show OrderSummary`) y `order_history_repository` → RF-61. Es una reasignación del agente, aceptada: el modelo de pedidos es de RF-61.
      - `timeout_http_client` → RF-63.
      - `admin_notification_client` → RF-64.
      - `loox_reviews_repository` → RF-66.
  - **`test/architecture_test.dart`** (INV-12): suma 3 reglas y no quita ninguna.
    - `app/destinations/app_destination.dart` no importa Flutter.
    - Las features no importan `app_dependencies.dart` ni `platform_services.dart`.
    - Se confirma que `shopper_scope.dart` está dentro de la pureza de `lib/domain`.
  - **`test/architecture/composition_root_test.dart`** (ARCH-04): sólo cambian el comentario y el nombre de la prueba, que ahora dicen que RF-50, RF-51, RF-63 y RF-66 vacían el mapa. El mapa no cambia.
  - **`docs/ARCHITECTURE.md`:** la regla 3 describe ARCH-02 y la frontera de la composición.
- **Mutaciones del agente** (copias temporales, ya borradas): ARCH-02 falla ante un par nuevo (`order_status.dart -> database.dart`) y ante un par que ya no existe.
- **Gates (ejecutados por el auditor en el worktree):**
  - G0 → alcance esperado; `architecture_test.dart` sólo suma líneas.
  - G1 → `Formatted 359 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → `+23: All tests passed!`.
  - G4 → `+1257 ~5: All tests passed!` (1250 + 7).
  - G5 → catálogo válido; secretos OK.
- **Hallazgos:**
  - [Baja] `customer_auth_error.dart` importa `flutter_appauth` para mapear errores, y está entre los permitidos. Separar ese mapeo cuando RF-62 mueva el error a dominio.
  - [Nota] `admin_notification_client` podría ser de RF-65 (admin) en vez de RF-64. Se decide al detallar la fase 6.
- **Fase 3:**
  - RF-30 y RF-31 tienen el código aprobado y esperan G6, más G8 en el caso de RF-31.
  - RF-32 y RF-33 están cerrados.
  - La cadena de ramas es `refactor/rf-30-composicion` → `rf-31-destinos` → `rf-32-shopper-scope` → `rf-33-arquitectura` (`e719391`), sobre `38d97cb`.
- **Siguiente paso:** la fase 4 necesita tres cosas de la persona:
  - extender D-14, porque la fase 4 también es posterior al lanzamiento;
  - revisar el borrador de la fase 4;
  - tomar la decisión D-13, que bloquea RF-40.

### 2026-10-09 · RF-40 · paso 1 (CHAR-12, CHAR-13 e INV-12) · APROBADO

- **Decisiones de la persona:**
  - D-13: se conserva la regla de colección.
  - D-14 se amplía a la fase 4, con el borrador del plan.
- **Agente:** `test-engineer`. El orquestador auditó.
- **Base:** worktree de las fases 3–4, rama `refactor/rf-40-consultas`, desde `e719391`.
- **Pruebas nuevas** (sin commit):
  - `test/features/catalog/search_characterization_test.dart` (CHAR-12, CAR, 38 casos). Fija:
    - la normalización (mayúsculas, á é í ó ú ü ñ y espacios; no pliega `ç` ni `à`);
    - cada fuente de término;
    - que el `vendor` crudo no sirve para encontrar;
    - que una consulta vacía devuelve `[]`;
    - el orden de catálogo y la semántica de `productMatchesAnyTerm`.
  - `test/features/catalog/catalog_browse_filters_characterization_test.dart` (CHAR-13, CAR, 25 casos, por la UI). Fija:
    - los cuatro órdenes;
    - cada filtro, con unión dentro de una dimensión e intersección entre dimensiones, incluidas las aristas de las bandas de precio;
    - el color y el tipo de bolsa deducidos del título y la categoría;
    - que el navegador no tiene campo de texto.
  - Regla nueva de INV-12 en `test/architecture_test.dart` (OBJ): `lib/features/catalog/query/` existe, tiene archivos `.dart` y ninguno importa Flutter, `app/catalog_store.dart` ni `app/composition/`.
- **Verificación del auditor:**
  - CHAR-12 y CHAR-13 → `+63: All tests passed!`.
  - `architecture_test.dart` → `+10 -1`, con el fallo esperado: «lib/features/catalog/query does not exist yet».
  - Suite → `+1320 ~5 -1`, según el agente; sólo falla esa regla.
- **Hallazgo y decisión del orquestador:** `_filterCatalog` sólo se llama con `query: ''` (`catalog_browse_screen.dart:223-227`). Su rama de consulta es código muerto, con otra semántica (no quita acentos). La implementación la elimina al pasar el filtro al módulo puro.
- **Hallazgos vigentes que no se corrigen** (son comportamiento, y CHAR-13 los vigila):
  - el color del navegador sale del título y la categoría, no de `facets.colors`;
  - el tipo de bolsa sale de subcadenas.
- **Siguiente paso:** la implementación (`flutter-implementer`).

### 2026-10-09 · RF-40 · implementación interrumpida · EN CURSO

- La sesión llegó a su límite de uso, y el orquestador detuvo a `flutter-implementer` antes de que terminara. No hubo auditoría ni commit.
- **Para retomar:**
  1. En `.claude/worktrees/rf-30` (rama `refactor/rf-40-consultas`), descartar las ediciones parciales de `lib/` con `git checkout -- lib` y borrar `lib/features/catalog/query/` si existe.
  2. Conservar las pruebas sin commit de RF-40: CHAR-12, CHAR-13 y la regla nueva de INV-12 en `test/architecture_test.dart`.
  3. Relanzar el encargo de implementación de RF-40. Su diseño está en `PLAN.md`; la rama de consulta muerta de `_filterCatalog` se elimina.

### 2026-10-09 · RF-40 · iteración 1 · CERRADO

- **Agente:** `flutter-implementer`, relanzado tras el corte de uso. El orquestador auditó.
- **Base:** `e719391`, rama `refactor/rf-40-consultas`, worktree de las fases 3–4. Commit `4c4a063`.
- **Diff:**
  - **Nuevo, `lib/features/catalog/query/`:**
    - `search_text.dart`: `normalizeSearchText`.
    - `product_search.dart`: `searchTermsFor`, `matchesNormalizedQuery`, `searchProductList`, `matchesAnyTerm` y `FacetsLookup`.
    - `collection_filter.dart`: `CollectionFilter` y `filterCollectionProducts`, con la regla de D-13.
    - `browse_filters.dart`: `CatalogSort`, `CatalogBrowseFilters`, los ayudantes `browse*For`, las constantes y `filterAndSortCatalog`, ya sin consulta.
    - Sus imports son sólo `domain/`, `data/normalize/`, `app/shopper_copy.dart` y `reco/`.
  - **Envoltorios y reexportaciones:**
    - Las 4 funciones de `catalog_query.dart` conservan su firma y delegan en las puras.
    - `search_history.dart` reexporta `normalizeSearchText`.
    - `collection_screen.dart` reexporta `CollectionFilter` y filtra con la función pura.
    - `catalog_browse_screen.dart` pierde sus tipos y ayudantes privados (−242 líneas). Ahí se eliminó la rama de consulta muerta.
  - **Extra declarado:** `product_tile.dart`. `catalogBrowseBrand` delega en `browseBrandFor`, con el mismo cuerpo; así no se duplica la regla de marca.
  - **Pruebas nuevas:** CHAR-12b y CHAR-13b, 9 casos sobre el módulo, sin widgets ni store.
  - **`docs/ARCHITECTURE.md`:** describe el módulo puro.
- **Paridad verificada por el auditor** contra `HEAD`, con un diff normalizado:
  - `browseCategoryFor`, `browsePriceBandFor`, `browseColorsFor` y `browseBagTypeFor` son iguales a sus originales privados;
  - los mapas de términos son idénticos;
  - las bandas de precio conservan los cortes 1000, 2500 y 5000;
  - `browseBrandFor` tiene el cuerpo de `catalogBrowseBrand`.
  - La búsqueda y el filtro de colección los cubren CHAR-12 y CHAR-07.
- **Gates (ejecutados por el auditor en el worktree):**
  - G0 → alcance esperado más el extra declarado; `git diff --check` limpio.
  - G1 → `Formatted 366 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → catálogo y arquitectura, con la regla nueva de INV-12 en verde: `+298: All tests passed!`.
  - G4 → `+1330 ~5: All tests passed!` (1320 + la regla de INV-12 + 9).
  - G5 → catálogo válido; secretos OK.
  - G6 → no aplica: la matriz lo pide desde RF-41.
- **Hallazgos:**
  - [Baja] El orden por `updatedAt` y por precio sigue usando `List.sort`, que no es estable; es lo vigente.
  - [Nota] Las fachadas de `catalog_query.dart` y el `export` de `search_history.dart` se quitan en RF-41, cuando migren las pantallas.
- **Siguiente paso:** RF-41, los ViewModels del piloto.

### 2026-10-09 · RF-41 · paso 1 (PERF-01, línea base) · APROBADO

- **Agente:** `test-engineer`. El orquestador auditó.
- **Base:** `4c4a063`, rama `refactor/rf-41-viewmodels`. Commit `ba3faa4`.
- **Prueba nueva:** `test/features/catalog/pilot_rebuilds_test.dart` (PERF-01, TRQ), con el ayudante `test/support/rebuild_counter.dart`, que usa el gancho `debugOnRebuildDirtyWidget`.
  - Cada pantalla se monta sobre el catálogo del asset, a 375×812, y recibe 3 veces `store.record(galleryInteraction)` sobre otra pieza.
  - Se cuentan los elementos reconstruidos en total y los del propio `Element` de la pantalla.
- **Línea base** (3 corridas idénticas, y 0 en un frame de control sin notificación):

  | Pantalla | Elementos reconstruidos (3 notificaciones) | Reconstrucciones propias |
  |---|---|---|
  | `SearchScreen` | 939 | 3 |
  | `CollectionScreen` | 1044 | 3 |
  | `CatalogBrowseScreen` | 3 | 0 |
  | `ProductScreen` | 1413 | 3 |

- **Verificación del auditor:** la corrida da los mismos números. El agente comprobó que el trinquete falla al poner las constantes en 0.
- **Hallazgos para las partes siguientes:**
  - [Media] El navegador lee el store con `getInheritedWidgetOfExactType`, sin suscribirse (`catalog_browse_screen.dart:1020`), y `openCatalogBrowse` (`:344`) fija `bagCount` al abrir. Es posible que el contador de bolsa del navegador no siga a la bolsa. Se revisa en la parte C.
  - [Nota] R20: `record` llama a `_rebuildProfile`, que a su vez llama a `notifyListeners` (`catalog_store.dart:425-451`).
- **Siguiente paso:** la parte A (`SearchScreen`, el patrón y `Command`).

### 2026-10-09 · RF-41 · parte A (`SearchScreen` y `Command`) · APROBADO

- **Agente:** `flutter-implementer`. El orquestador auditó.
- **Base:** `ba3faa4`, rama `refactor/rf-41-viewmodels`. Commit de la parte A en esa rama.
- **Diff:**
  - **`lib/app/command.dart`** (nuevo, 109 líneas): `Command0` y `Command1`, con `running`, `completed`, `error` y `clearResult`. No admite ejecuciones concurrentes, y una ejecución que termina después de `dispose` no notifica.
  - **`lib/features/catalog/search_view_model.dart`** (nuevo, 309 líneas):
    - `SearchViewState` es inmutable, con igualdad por valor, y se calcula con las consultas puras de RF-40.
    - **Sólo notifica si el estado cambia** (`next == _state`).
    - Acciones: `submit`, `forget` y `clearHistory` como `Command`; `queryChanged`, `clear` y `edit` como métodos.
  - **`search_screen.dart`** (1 019 → 919 líneas):
    - el ViewModel se crea en `initState`, leyendo el store sin suscribirse, y se desecha en `dispose`;
    - la pantalla se reconstruye con `ListenableBuilder`;
    - la API pública no cambia.
  - **Pruebas nuevas** (33): 8 de `Command`, 23 del ViewModel y 2 de la pantalla (listeners liberados y reconstrucción con otros parámetros).
  - **Pruebas existentes:** ninguna adaptada. En PERF-01 sólo cambian las constantes de `SearchScreen`.
- **Evidencia para RF-43** (criterios de R05):
  - **Ciclo de vida por parámetro:** se conserva el comportamiento vigente. Los parámetros se capturan una vez y una reconstrucción con otros los ignora (fijado por prueba).
    - Matiz: el store también se captura una vez. Hoy da igual, porque `openSearch` reenvía la misma instancia.
  - **`dispose`:** el riesgo real era un listener colgado del historial, que es un singleton. Se evita quitando ambos listeners en `dispose`, y una prueba lo demuestra.
  - **Reconstrucciones:** el ViewModel lleva a 0 las reconstrucciones propias. El costo que queda (411) está en `ProductCard`, que se suscribe con `StoreScope.of`: el arreglo dominante está en los widgets hijos, no en la técnica de inyección.
- **Desviación aceptada:** los comandos no esperan el guardado del historial en disco (`unawaited`), igual que antes. Si lo esperaran, el «no concurrente» descartaría un segundo envío rápido. Lo fija una prueba.
- **Gates (ejecutados por el auditor en el worktree):**
  - G1 → `Formatted 373 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → `+566: All tests passed!`.
  - PERF-01 → `SearchScreen` pasa de 939/3 a 411/0.
  - G4 → `+1367 ~5: All tests passed!`.
  - G5 → catálogo válido; secretos OK.
- **Hallazgos:**
  - [Baja] `Command` guarda el error y la pantalla no lo lee. Hoy `remember` no lanza de forma síncrona.
  - [Nota] La parte B (`CollectionScreen`) usa el mismo patrón.
- **Siguiente paso:** la parte B.

### 2026-10-09 · RF-41 · parte B (`CollectionScreen`) · APROBADO

- **Agente:** `flutter-implementer`. El orquestador auditó.
- **Base:** `1b4fa1c`, rama `refactor/rf-41-viewmodels`. Commit `1a7710c`.
- **Diff** (5 archivos, +989 −160):
  - **`lib/features/catalog/collection_view_model.dart`** (nuevo, 268 líneas):
    - `CollectionSort`, `CollectionFilters` (con `==` y `hashCode`) y `CollectionViewState`. El estado es inmutable, con igualdad por valor: filtros aplicados, línea base, alcance, piezas visibles, marcas, siluetas y contador de bolsa.
    - Se calcula con el filtro puro de colección de RF-40. **Sólo notifica si el estado cambia.**
    - Acciones síncronas: `applyFilters`, `clearFilters`, `updateDestination` y `countFor`. No usan `Command` porque no hay trabajo asíncrono; `SearchViewModel` hace lo mismo con sus acciones síncronas.
  - **`collection_screen.dart`** (1 091 → 987 líneas):
    - lee el store sin suscribirse;
    - conserva el scroll, la navegación y la hoja de filtros;
    - `didUpdateWidget` llama a `updateDestination`.
  - **Pruebas nuevas** (22): 16 del ViewModel y 6 de la pantalla.
  - **Pruebas existentes:** ninguna adaptada. En PERF-01 sólo cambian las constantes de `CollectionScreen`.
- **Contraste (ejecutado por el auditor):** con el `collection_screen.dart` de `1b4fa1c`, las 6 pruebas de pantalla dan `+4 -2`. Fallan sólo las dos que miden la mejora (listeners liberados y cero reconstrucciones propias), así que el comportamiento se conserva. El archivo se restauró con `git checkout HEAD --` y el worktree quedó limpio.
- **Evidencia para RF-43** (criterios de R05):
  - **Ciclo de vida por parámetro:**
    - la `State` anterior no tenía `didUpdateWidget` y leía `widget.filter` en cada `build`;
    - con otro destino, las elecciones de la hoja se conservaban, y el alcance y la línea base seguían al filtro nuevo;
    - se conserva con `didUpdateWidget` → `updateDestination`, y un destino equivalente no notifica;
    - lo fijan pruebas que pasan con el código viejo y con el nuevo. En producción cada `openCollection` crea una `State` nueva, así que el caso sólo aparece con reconstrucciones en el sitio.
  - **`dispose`:** quedan cubiertos tres riesgos:
    - el listener del store se quita (lo mide un contador de listeners en el ViewModel y en la pantalla);
    - `_refresh` tiene un guard `_disposed` contra notificaciones tardías y contra la hoja que devuelve su resultado después de cerrar la pantalla;
    - el ViewModel se desecha antes que el `ScrollController`.
  - **Reconstrucciones:** las propias bajan de 3 a 0 y el total de 1044 a 435. Lo que queda son las tarjetas, que se suscriben con `StoreScope.of`, igual que en la parte A.
- **Gates (ejecutados por el auditor en el worktree, sobre `1a7710c`):**
  - G0 → 5 archivos, +989 −160; `git diff --check` limpio.
  - G1 → `Formatted 376 files (0 changed)`.
  - G2 → «No issues found!».
  - G3 → catálogo, ficha, navegación, boutique, escala de texto y arquitectura: `+521: All tests passed!`.
  - PERF-01 → `CollectionScreen` pasa de 1044/3 a 435/0. Las otras tres no cambian: 411/0, 3/0 y 1413/3.
  - G4 → `+1389 ~5: All tests passed!` (1367 + 22).
  - G5 → catálogo válido (103 productos, 340 imágenes); secretos OK.
- **Hallazgos:**
  - [Baja] La `State` captura el store en `initState` y no sigue un cambio de `StoreScope.notifier`. Es igual que en la parte A, y ningún caso de la app lo produce.
  - [Baja] Los productos no tienen igualdad por valor. Si el store reemplaza un producto por otro objeto con los mismos datos, el ViewModel notifica una vez. Es conservador.
  - [Nota] Que las elecciones de una colección sobrevivan a otro destino es raro, pero es lo vigente. Lo puede normalizar RF-43 o la fase 5.
- **Siguiente paso:** la parte C (`CatalogBrowseScreen`).
  - El hallazgo [Media] del paso 1 se confirma leyendo el código. `openCatalogBrowse` fija `bagCount` al abrir (`catalog_browse_screen.dart:344`) y la barra inferior lo pinta (`:308`). Después de agregar con «+», o de cambiar la bolsa en la ficha o en la bolsa, el contador del navegador queda viejo.
  - La colección (parte B) y el inicio sí siguen la bolsa. El defecto también existe en la línea de lanzamiento.
  - Decisión del orquestador: se corrige en la parte C, con una prueba objetivo primero (CHAR-17).

### 2026-10-09 · RF-41 · parte C, paso 1 (CHAR-17 primero) · EN CURSO

- **Encargo:** `test-engineer` escribe CHAR-17 en `test/features/catalog/catalog_browse_bag_count_test.dart`, en el worktree `.claude/worktrees/rf-30` (rama `refactor/rf-41-viewmodels`, base `1a7710c`). No toca `lib/`.
- **Qué se espera:**
  - dos casos objetivo, rojos hoy: el navegador abierto con `openCatalogBrowse` sigue la bolsa, y el contador sube después de un «+»;
  - dos casos de caracterización, verdes hoy: sin store, el contador muestra el `bagCount` recibido; y al abrir con piezas en la bolsa, las muestra.
- **Receta para retomar si se corta:**
  - si ese archivo existe sin commit en el worktree, es de este encargo;
  - ejecútalo con `flutter test --no-pub <archivo>` y comprueba que los casos objetivo fallan porque el contador conserva el valor de la apertura, no por otra causa;
  - después, encarga el ViewModel según `PLAN.md` (fila RF-41).

### 2026-10-09 · Validación del trabajo de otros modelos · VALIDADO CON HALLAZGOS

- **Pausa del bucle:** la persona lo detuvo para pedir esta validación. El encargo de CHAR-17 (RF-41 parte C) no se lanzó; la entrada «EN CURSO» anterior queda como plan.
- **Haiku 5.5: descripción del PR de `fix/sin-envio-gratis-main`** (`scratch/pr/sin-envio-gratis.md`):
  - lo que afirma es correcto;
  - le faltaban dos puntos, que el orquestador añadió y verificó: el ajuste de `_SummaryRow` y la evidencia del ensayo de integración (`+1224 ~5`);
  - `_SummaryRow` deja el valor al 65 % del ancho, con `TextAlign.end`; sin ese ajuste desbordaba 81 px a 1.3× y 360 px.
- **Muse Spark 3.1: inventario para RF-43** (`scratch/plan/rf43_inventario_scopes.md`, sobre `1a7710c`):
  - **Verificado por el auditor con un escaneo propio del commit:**
    - 13 scopes: 11 `InheritedNotifier` y 2 `InheritedWidget`;
    - 56 archivos montan u observan scopes: 42 a mano (lista idéntica, con 247 declaraciones), 7 por ayudante, 4 por la app real y 3 por la matriz;
    - hay 176 archivos de prueba;
    - las citas revisadas del §6 son exactas, salvo dos que el propio documento marca como aproximadas (`search_screen.dart:112` y `welcome_gate.dart:69`).
  - La cifra de 24 de la revisión cuenta archivos (`docs/REVISION_PROPUESTA_RECONSTRUCCION_MVVM.md:73`); hoy son 56.
  - **Hallazgos:**
    - [Media] Falta el antes y después en código que pedía el encargo; sólo trae un esquema. Se escribe al preparar RF-43, con las firmas verificadas.
    - [Baja] El resumen contradice al cuerpo en tres puntos:
      - dice que hay que editar 4 archivos de app real; el §5 dice 2;
      - cuenta 3 lecturas con `getInheritedWidgetOfExactType` fuera de build, pero una ocurre dentro de `build`;
      - habla de 3 ayudantes, y el §5, de 2 funciones.
    - [Baja] Los «casos» mezclan declaraciones con casos generados: la matriz cuenta ×6, pero `pilot_rebuilds_test` cuenta 1 aunque registra 4. Para RF-43 vale la cuenta de archivos.
- **GPT Sol 6.1: borrador de la fase 5** (`scratch/plan/fase5_borrador.md`, sobre `1b4fa1c`; los archivos que cita no cambian en `1a7710c`):
  - **Verificadas unas 30 citas: todas exactas.** El código confirma estos hechos nuevos:
    - `mergeDeviceItemsIntoAccount` lee las filas del invitado fuera de la transacción (`bag_store.dart:120-123`);
    - `addToBag` suma sin el tope de 10 que sí aplica `updateBagQuantity` (`catalog_store.dart:519,556`);
    - la hidratación sólo compara la cuenta (`catalog_store.dart:259`), así que en A→B→A puede aceptar una lectura vieja de A;
    - el callback de compra llama a `loadOrders`, que lee la cuenta activa al momento de invocarse (`checkout_screen.dart:268-269`, `account_controller.dart:353`);
    - la base la crea la composición (`app_dependencies.dart:82`), pero la cierra `CatalogStore.dispose`, sin `await` (`catalog_store.dart:707`).
  - **Hallazgos:**
    - [Media] Choque de IDs: propone CHAR-17, que ya es la fila de la parte C de RF-41. Al adoptarlo se renumeran todas sus filas.
    - [Media] No contempla la integración de la rama del envío gratis (D-06). En `1b4fa1c`, `checkout_screen.dart:1918` todavía tiene `_shippingFor`. RF-52 empieza después de esa integración, y sus citas van a cambiar.
    - [Media] RF-50 mezcla cambios de comportamiento con la extracción estructural: E4 con un aviso visible, y E10 si RF-42 no lo cubre. Propuesta del auditor: separar E4 en su propio WP antes de extraer, para que la extracción sea un refactor puro con paridad.
    - [Baja] Formato: trae unas 70 líneas densas por WP, con jerga en inglés. Hay que condensarlo al formato de `PLAN.md`.
    - [Nota] Se adoptan dos propuestas suyas:
      - RF-50 depende también de RF-42;
      - la fase 5 necesita que la persona decida la línea de integración, porque D-14 sólo cubre las fases 3 y 4.
- **Conclusión:** los dos documentos sirven como insumo, no como plan aprobado. El detalle de la fase 5 se escribe en `PLAN.md` a partir del borrador, con estos hallazgos aplicados, y se muestra a la persona antes de empezar.
