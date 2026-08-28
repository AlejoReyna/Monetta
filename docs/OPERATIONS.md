# Operación de `catalog_monitor` en Texas

Este runbook opera únicamente el servicio de catálogo de Monetta en
`209.23.11.117` (`artisanalbrew@209.23.11.117`). El proyecto usa sus propios
contenedores y volumen de PostgreSQL. No se reinician ni se reconstruyen los
contenedores de ArtisanalBrew; la única integración con ellos es conectar
Caddy a la red de borde y recargar su configuración validada.

El monitor es un lector de páginas públicas para investigación y procurement
manual. No compra, no agrega productos externos al carrito, no inicia Shopify
checkout y no usa proxies, CAPTCHA bypass, evasión de bloqueos ni user agents
falsos. Si una fuente responde con bloqueo, se detiene esa fuente y se revisan
los términos antes de reintentar.

## Estado y preflight

Desde el repositorio:

```bash
git status --short
cd services/catalog_monitor
npm run typecheck
npm test
cd ../..
flutter analyze
flutter test
```

El preflight de esta entrega pasó: typecheck, 181 tests del monitor, análisis
de Flutter y 419 tests Flutter. El servidor no tenía contenedor de catálogo,
no escuchaba `8081` y `catalog.monetta.mx` aún no tenía un registro A al
momento de la preparación.

## Primera instalación

### 1. Preparar el árbol remoto sin copiar secretos

El archivo `.env` local nunca se transfiere. El contexto de build también lo
excluye mediante `.dockerignore`.

```bash
ssh -i /Users/alexis/.ssh/artisanalbrew-atlantic-codex artisanalbrew@209.23.11.117 \
  'install -d -m 0750 /opt/monetta-catalog/repo/services'
rsync -az \
  --exclude='.env' \
  --exclude='node_modules' \
  --exclude='dist' \
  services/catalog_monitor/ \
  artisanalbrew@209.23.11.117:/opt/monetta-catalog/repo/services/catalog_monitor/
```

En el servidor, instalar el compose y los archivos de operación desde la
copia transferida:

```bash
install -d -m 0750 /opt/monetta-catalog/backups
install -d -m 0750 /opt/monetta-catalog/selection
install -m 0644 /opt/monetta-catalog/repo/services/catalog_monitor/deploy/atlantic/compose.yml /opt/monetta-catalog/compose.yml
install -m 0644 /opt/monetta-catalog/repo/services/catalog_monitor/deploy/atlantic/Caddyfile.snippet /opt/monetta-catalog/Caddyfile.snippet
install -m 0750 /opt/monetta-catalog/repo/services/catalog_monitor/deploy/atlantic/monetta-catalog-healthcheck /usr/local/sbin/monetta-catalog-healthcheck
install -m 0750 /opt/monetta-catalog/repo/services/catalog_monitor/deploy/atlantic/monetta-catalog-backup /usr/local/sbin/monetta-catalog-backup
install -m 0644 /opt/monetta-catalog/repo/services/catalog_monitor/deploy/atlantic/monetta-catalog-api.service /etc/systemd/system/monetta-catalog-api.service
install -m 0644 /opt/monetta-catalog/repo/services/catalog_monitor/deploy/atlantic/monetta-catalog-monitor.service /etc/systemd/system/monetta-catalog-monitor.service
```

### 2. Crear el `.env` de producción

Crear `/opt/monetta-catalog/.env` con un editor root y asignar `0600`. Los
valores de password y correo son de ejemplo de forma, no valores para copiar.
Generar la contraseña fuera de los logs y usar una cadena hexadecimal para que
la URL de PostgreSQL no necesite escaping.

```dotenv
CATALOG_BUILD_CONTEXT=./repo/services/catalog_monitor
CATALOG_IMAGE_TAG=2026-08-28
POSTGRES_USER=monetta_catalog
POSTGRES_DB=monetta_catalog
POSTGRES_PASSWORD=<secret-hex-no-log>
DATABASE_URL=postgres://monetta_catalog:<secret-hex-no-log>@monetta-catalog-postgres:5432/monetta_catalog
PORT=8081
ENABLED_SOURCE_IDS=coach_us,michael_kors_us
LIVE_CRAWL_ENABLED=true
PLAYWRIGHT_FALLBACK_ENABLED=false
USER_AGENT=MonettaCatalogMonitor/0.1 (+https://monetta.mx; internal research prototype; contact: <real-monitored-mailbox>)
REQUEST_DELAY_MS=1000
CATALOG_CRON=17 3 * * *
```

```bash
chmod 0600 /opt/monetta-catalog/.env
```

`USER_AGENT` debe llevar el correo real y monitoreado antes de arrancar el
monitor. El API recibe `LIVE_CRAWL_ENABLED=false` de forma fija; sólo el
monitor recibe `true`.

### 3. Red y primer arranque

Crear la red de borde una sola vez. PostgreSQL sólo queda en
`monetta_catalog_internal`; el API se conecta a ambas redes y el monitor sólo
a la interna.

```bash
docker network inspect monetta_catalog_edge >/dev/null 2>&1 || docker network create monetta_catalog_edge
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml config >/dev/null
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml build
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml up -d
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml ps
```

El compose no publica `8081` ni `5432` en el host. La imagen de producción
usa `node:22-slim`, no contiene el navegador Playwright y mantiene el fallback
desactivado.

### 4. Caddy y DNS

Conectar el Caddy existente a la red nueva, añadir el contenido de
`Caddyfile.snippet` a `/opt/artisanalbrew/Caddyfile`, y validar antes de
recargar:

```bash
docker network connect monetta_catalog_edge artisanalbrew-caddy-1
docker exec artisanalbrew-caddy-1 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec artisanalbrew-caddy-1 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

La zona DNS de `monetta.mx` usa actualmente los nameservers de GoDaddy. Crear
este registro A, sin un registro AAAA:

```text
catalog.monetta.mx.  A  209.23.11.117
```

Esperar la propagación y comprobar desde una red externa. Caddy obtendrá o
renovará el certificado HTTPS automáticamente una vez que el nombre resuelva.

## Despliegue de una nueva versión

Conservar el `.env` remoto y transferir únicamente una revisión aprobada del
servicio, siempre excluyendo `.env`, `dist` y `node_modules`:

```bash
rsync -az --exclude='.env' --exclude='node_modules' --exclude='dist' \
  services/catalog_monitor/ \
  artisanalbrew@209.23.11.117:/opt/monetta-catalog/repo/services/catalog_monitor/
install -m 0644 /opt/monetta-catalog/repo/services/catalog_monitor/deploy/atlantic/compose.yml /opt/monetta-catalog/compose.yml
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml build
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml up -d
```

Para el arranque al boot, después de confirmar el primer despliegue:

```bash
systemctl daemon-reload
systemctl enable monetta-catalog-api.service monetta-catalog-monitor.service
systemctl start monetta-catalog-api.service monetta-catalog-monitor.service
```

## Logs y estado

```bash
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml ps
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml logs --tail=200 monetta-catalog-api
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml logs --tail=200 monetta-catalog-monitor
/usr/local/sbin/monetta-catalog-healthcheck
```

El healthcheck sólo reinicia los dos contenedores de catálogo después de tres
fallos consecutivos de proceso/API. No toca los contenedores de ArtisanalBrew.

## Endpoints

`/livez` es liveness del proceso y debe devolver `200` aunque todavía no haya
un crawl exitoso. `/healthz` es freshness/readiness de datos y puede devolver
`503 degraded` antes del primer crawl completo; eso no significa que el API
esté caído. `/v1/external-catalog` debe validarse por `dataOrigin` antes de
declarar una entrega real.

```bash
curl -fsS https://catalog.monetta.mx/livez
curl -i https://catalog.monetta.mx/healthz
curl -i https://catalog.monetta.mx/v1/external-catalog
curl -fsS https://catalog.monetta.mx/v1/external-catalog | jq '{sources: [.sources[] | {source, liveItemCount, snapshotItemCount}], dataOrigins: ([.items[].dataOrigin] | unique)}'
```

No se considera éxito si el payload sólo contiene `curated_us_snapshot` o
datos de demo. La evidencia mínima es `dataOrigin: "live_crawl"`, precios y
enlaces HTTPS de Coach/Michael Kors, y un `lastSuccessfulRunAt` real.

## Primer crawl desde Texas

Ejecutar primero los dos smoke crawls limitados. `--dry-run` no escribe en la
base de datos, pero sí hace peticiones reales desde la IP del servidor:

```bash
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml \
  exec -T monetta-catalog-monitor node dist/cli/manualCrawl.js --brand coach --limit 5 --dry-run
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml \
  exec -T monetta-catalog-monitor node dist/cli/manualCrawl.js --brand michael_kors --limit 5 --dry-run
```

Confirmar en los resultados y logs, para cada fuente:

- `robots.txt` respondió y permite las URLs consultadas;
- la URL final conserva el host estadounidense correcto;
- hay productos extraídos con precios válidos;
- imágenes, `detailUrl` y URLs de variantes son HTTPS;
- los datos se identifican como listings externos, nunca como inventario propio;
- no hay `demo`, `seed-demo`, redirección a México, `wrong_market` ni bloqueo.

Si aparece CAPTCHA, `403/429/503` con señales de bloqueo o una redirección
regional, detener esa fuente. No aumentar evasivamente el user agent, no usar
proxy y no repetir el crawl hasta revisar y reportar la causa.

Después de un smoke crawl aceptable, ejecutar el crawl persistente sin límite
para que el run pueda ser un snapshot completo:

```bash
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml \
  exec -T monetta-catalog-monitor node dist/cli/manualCrawl.js --brand coach
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml \
  exec -T monetta-catalog-monitor node dist/cli/manualCrawl.js --brand michael_kors
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml logs --tail=200 monetta-catalog-monitor
```

Un crawl con `--limit` es deliberadamente parcial y no refresca la freshness
de `/healthz`. Sólo un snapshot completo, exitoso y con cobertura requerida
puede llevar ese endpoint a `200`.

## Detener una fuente

Editar sólo el `.env` remoto y quitar el source de
`ENABLED_SOURCE_IDS` (por ejemplo, dejar `michael_kors_us` para detener Coach).
Recrear sólo API y monitor para que el API deje de presentar esa fuente y el
monitor deje de solicitarla:

```bash
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml \
  up -d --force-recreate monetta-catalog-api monetta-catalog-monitor
```

Para detener todos los crawls, cambiar `LIVE_CRAWL_ENABLED=false` y recrear
sólo `monetta-catalog-monitor`. Si una fuente fue bloqueada, conservar el
último catálogo válido, registrar la evidencia y dejarla fuera hasta tener una
decisión explícita.

## Backups y restauración

El backup es un dump PostgreSQL custom y, si existe, una copia del documento de
selección. No incluye `.env`.

```bash
/usr/local/sbin/monetta-catalog-backup backup
ls -l /opt/monetta-catalog/backups
```

Para restaurar un dump exacto, primero detener API y monitor. La opción
`--confirm` es obligatoria porque reemplaza las tablas de la base de catálogo:

```bash
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml stop monetta-catalog-api monetta-catalog-monitor
/usr/local/sbin/monetta-catalog-backup restore --confirm /opt/monetta-catalog/backups/catalog-<timestamp>.dump
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml up -d monetta-catalog-api monetta-catalog-monitor
```

Después validar migraciones, `/livez`, `/healthz` y el origen real de los
items. La retención del script es de 14 días.

## Rollback

Cada despliegue debe usar un `CATALOG_IMAGE_TAG` distinto y conservar la
imagen anterior hasta validar la nueva. Para volver atrás, verificar que la
imagen anterior existe, cambiar sólo `CATALOG_IMAGE_TAG` en el `.env`, y
recrear los tres roles del proyecto:

```bash
docker image inspect monetta-catalog:<previous-tag> >/dev/null
docker compose --project-name monetta-catalog --env-file /opt/monetta-catalog/.env -f /opt/monetta-catalog/compose.yml up -d --force-recreate
```

No usar `git reset`, `git checkout` ni `git clean`. Si la revisión anterior no
entiende una migración ya aplicada, parar los servicios, restaurar el backup
compatible y luego arrancar la imagen anterior. No hacer rollback destructivo
de PostgreSQL sin un dump verificable.

## Conectar la app staging

Modificar únicamente el archivo local ignorado
`config/dart_defines.staging.json`:

```json
{
  "ENABLE_EXTERNAL_CATALOG": "true",
  "EXTERNAL_CATALOG_BASE_URL": "https://catalog.monetta.mx"
}
```

Conservar todos los demás defines staging existentes y no introducir tokens
secretos. Compilar e instalar en el iPhone 16e:

```bash
flutter run --release \
  -d 00008140-000954AA3ED0801C \
  --dart-define-from-file=config/dart_defines.staging.json
```

Validar en el dispositivo que la sección aparece, el payload llega por HTTPS,
se ven precio/fuente, el detalle abre, el CTA lleva al host original y el
producto externo no ofrece add-to-bag, apartado ni Shopify checkout. Con el API
detenido temporalmente, la app debe conservar el último snapshot válido en el
caché local y seguir navegable.
