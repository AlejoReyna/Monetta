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
