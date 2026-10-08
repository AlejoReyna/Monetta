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
