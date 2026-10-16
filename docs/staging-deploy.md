# Deploy de pagos y webhooks en staging

Este procedimiento es solo para `monetta-staging.myshopify.com` y la app Fly
`monetta-accounts-staging` (`https://monetta-accounts-staging.fly.dev`). No hace
merge de los PR #16/#18, no cambia pagos en Shopify y no habilita
`kCheckoutTokenCorrelationAvailable`: debe seguir en `false`. Los comandos de
deploy de este documento son pasos para ejecutar posteriormente; escribir este
runbook no significa que se hayan ejecutado.

## 1. Requisitos y límites

- Usar un checkout limpio de la rama del PR #18, basado en el #16 actualizado.
  Revisar `git rev-parse HEAD` y `git status --short` antes del deploy.
- Tener acceso ya autenticado a Fly y al Dev Dashboard de la app Shopify
  **monetta-staging**. Si aparece un login, verificación, permiso o dato faltante,
  detenerse y pedir a Alexis que lo resuelva; no improvisar credenciales.
- Confirmar en Dev Dashboard que esa app está instalada **solo en la tienda de
  staging**. Una versión de app afecta sus instalaciones; si hay otra tienda,
  detenerse. No usar la configuración predeterminada ni la de producción.
- Alexis debe confirmar que el `DATABASE_URL` de Fly corresponde al PostgreSQL
  aislado de staging y disponer de un snapshot recuperable de Neon antes de
  migrar. No mostrar ni copiar esa URL, secretos o contenidos de tokens.
- El host debe tener ya `SHOPIFY_STORE_DOMAIN=monetta-staging.myshopify.com` y
  `SHOPIFY_APP_CLIENT_SECRET` de **esa misma app**. El receptor valida HMAC y el
  dominio de la tienda. No usar la firma de webhooks manuales de Notificaciones.
- Node 22 o superior, Flutter del repo, Shopify CLI del lockfile y Fly CLI
  instalados. No usar `--verbose`, trazas de shell ni volcar el entorno.

## 2. Declaración y registro de webhooks

La fuente es `shopify/shopify.app.staging.toml`, no un registro automático por
API al arrancar el backend. No hay una llamada `webhookSubscriptionCreate` en
`services/accounts_orders/src`. La configuración declara:

| Topic | Destino HTTPS | Versión del payload |
| --- | --- | --- |
| `orders/create` | `https://monetta-accounts-staging.fly.dev/webhooks/orders/create` | `2026-07` |
| `orders/updated` | `https://monetta-accounts-staging.fly.dev/webhooks/orders/updated` | `2026-07` |

La versión procede de `[webhooks].api_version`. `SHOPIFY_ADMIN_API_VERSION`
controla las lecturas Admin por separado (su valor predeterminado también es
`2026-07`). `src/api/server.ts` monta ambas rutas; `src/webhooks/handlers.ts`
actualiza el mirror. La app requiere `read_orders`; conservar los demás scopes
y suscripciones existentes, sin agregar permisos en este procedimiento.

Primero desplegar el backend del apartado 3. Después, desde la raíz del repo:

```bash
cd shopify
npm ci
npx shopify app config validate --config staging
npx shopify app info --config staging
shopify_stage_version="staging-orders-$(git rev-parse --short HEAD)"
npx shopify app deploy --config staging --no-release --version "$shopify_stage_version"
npx shopify app versions list --config staging
```

Revisar en Dev Dashboard la versión recién creada: app **monetta-staging**,
versión `2026-07`, los dos topics/destinos de la tabla y ausencia de cambios
inesperados en scopes, metaobjetos o las demás suscripciones. `--no-release`
solo prepara la versión; todavía no cambia la versión activa. Si falta la
instalación o `read_orders`, Alexis debe resolverlo únicamente en staging y
después repetir la revisión.

Liberar **esa** versión para registrar/aplicar las suscripciones de la app:

```bash
npx shopify app release --config staging --version "$shopify_stage_version"
npx shopify app versions list --config staging
```

Confirmar en Dev Dashboard que esa versión es la activa. Estos son webhooks
administrados por la app: una lista vacía en Configuración > Notificaciones >
Webhooks no demuestra que falten. No crear duplicados desde esa pantalla ni
mediante una mutación Admin API. Tampoco `app deploy` despliega el servidor Fly.

## 3. Backend y migración 015

Desde la raíz del checkout del PR #18, ejecutar los checks locales:

```bash
flutter pub get
flutter analyze
flutter test test/features/orders test/data/accounts_orders/order_history_client_test.dart test/data/repositories/order_history_repository_test.dart test/data/local/order_summary_store_test.dart
cd services/accounts_orders
npm ci
npm test
npm run typecheck
npm run build
```

Antes del deploy, guardar privadamente la referencia de imagen de la última
release sana y compatible anterior a 015 que muestre el siguiente comando.
No confundir una release fallida con la imagen que está sirviendo tráfico.

```bash
fly releases --app monetta-accounts-staging --image
# Introducir solo la referencia de imagen, que no es una credencial.
read -r staging_previous_image
fly deploy --app monetta-accounts-staging --config fly.toml
fly status --app monetta-accounts-staging
curl --fail --silent --show-error https://monetta-accounts-staging.fly.dev/livez
curl --fail --silent --show-error https://monetta-accounts-staging.fly.dev/readyz
```

`fly.toml` ejecuta `node dist/db/migrate.js` como `release_command` antes de
cambiar el tráfico. El Dockerfile copia los SQL a `dist/db/migrations`.
No ejecutar `npm run migrate` en la imagen final: no incluye `tsx`.
El runner aplica todos los SQL pendientes en orden y registra cada archivo en
`schema_migrations`, dentro de la misma transacción que su SQL. No omitir 014
ni marcar manualmente 015 como aplicada. No ejecutar migradores concurrentes.

`015_order_checkout_tokens.sql` añade dos columnas `TEXT` anulables
(`checkout_token`, `cart_token`) e índices parciales
`idx_orders_mirror_checkout_token` / `idx_orders_mirror_cart_token` para valores
no nulos. No rellena pedidos antiguos. Los webhooks posteriores pueden aportar
esos campos; si los omiten, no borran valores ya almacenados.

Verificar la release, los logs y `/readyz` (`database: up`). El log esperado
cuando 015 es nueva contiene `migration applied` y su nombre; si ya estaba
registrada, el runner la omite. Usar la comprobación SQL siguiente como prueba
de aplicación, además de los logs.

## 4. Verificar migración y entregas sin exponer datos sensibles

Ver logs solo en la terminal privada de staging:

```bash
fly logs --app monetta-accounts-staging
```

Buscar `migration applied`, `order mirrored` con el ID de pedido, y
`http request completed` con `POST`, la ruta correspondiente y `status: 200`.
No adjuntar logs crudos, cuerpos de webhooks, cabeceras HMAC ni tokens a PRs.
Un `401` requiere revisar HMAC/dominio con Alexis; un `5xx` requiere revisar
DB/esquema y el reintento. Un `200` de una entrega repetida ya completada no
implica una nueva escritura.

Para probar el registro de extremo a extremo, Alexis debe generar o autorizar
un pedido **de prueba** de staging y una actualización posterior del mismo,
sin cobrar ni marcarlo pagado. Esperar ambos topics en las entregas/logs de la
app y un único `shopify_order_id` en el mirror. No crear pedidos como parte de
la ejecución documental de este runbook. El comando `shopify app webhook
trigger` solo manda una muestra y no prueba que las suscripciones estén
registradas; tampoco usarlo para introducir pedidos de muestra en el mirror.

Abrir una consola solo en la máquina del backend de staging:

```bash
fly ssh console --app monetta-accounts-staging
cd /app
```

En esa consola, ejecutar esta consulta de solo lectura. Muestra identificadores,
estados y presencia de campos; nunca sus valores sensibles:

```bash
node --input-type=module <<'JS'
import pg from 'pg';
if (process.env.SHOPIFY_STORE_DOMAIN !== 'monetta-staging.myshopify.com') {
  throw new Error('Abortado: no es staging');
}
const db = new pg.Client({ connectionString: process.env.DATABASE_URL });
try {
  await db.connect();
  await db.query('BEGIN READ ONLY');
  for (const sql of [
    `SELECT filename, applied_at FROM schema_migrations
     WHERE filename = '015_order_checkout_tokens.sql'`,
    `SELECT column_name, data_type, is_nullable FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'orders_mirror'
       AND column_name IN ('checkout_token', 'cart_token') ORDER BY column_name`,
    `SELECT indexname, indexdef FROM pg_indexes
     WHERE schemaname = 'public' AND tablename = 'orders_mirror'
       AND indexname IN ('idx_orders_mirror_checkout_token', 'idx_orders_mirror_cart_token')`,
    `SELECT webhook_id, topic, shopify_resource_id, status, attempt_count,
            received_at, processed_at FROM webhook_events
     WHERE shop_domain = 'monetta-staging.myshopify.com'
       AND topic IN ('orders/create', 'orders/updated')
     ORDER BY received_at DESC LIMIT 10`,
    `SELECT shopify_order_id, financial_status, payment_method, shopify_updated_at,
            checkout_token IS NOT NULL AS has_checkout_token,
            cart_token IS NOT NULL AS has_cart_token
     FROM orders_mirror WHERE source = 'shopify_checkout'
     ORDER BY updated_at DESC LIMIT 10`,
  ]) console.table((await db.query(sql)).rows);
  await db.query('COMMIT');
} catch {
  console.error('Verificación fallida; revisar acceso/esquema de staging sin volcar secretos');
  process.exitCode = 1;
} finally {
  await db.end();
}
JS
```

Esperar una fila de migración, dos columnas `text`/`YES`, dos índices con
predicado `IS NOT NULL`, y entregas `completed`/`processed_at` para el ID del
pedido probado. Comparar ese ID en `webhook_events` y `orders_mirror`; una
actualización más reciente debe avanzar `shopify_updated_at` sin duplicar la
fila. Un pago pendiente con gateway **Transferencia bancaria** debe almacenar
`payment_method=bank_deposit`. No es obligatorio que los campos de correlación
estén presentes en pedidos antiguos. `order_webhook_missing_checkout_tokens`
advierte de ausencia: no imprime sus valores y no impide por sí solo el mirror.
El backfill de métodos de pago no rellena los campos de 015.

## 5. Revertir 015

Primera opción: revertir solo la aplicación y conservar las columnas/índices
aditivos. Desde `services/accounts_orders`, con la referencia sana registrada
en el apartado 3 (sin sustituirla por una imagen del PR #18):

```bash
fly deploy --app monetta-accounts-staging --config fly.toml --image "$staging_previous_image" --skip-release-command
fly status --app monetta-accounts-staging
curl --fail --silent --show-error https://monetta-accounts-staging.fly.dev/readyz
```

Confirmar que todas las máquinas sirven código anterior a 015, que no lee ni
escribe esas columnas. El rollback de imagen no revierte SQL y una migración
confirmada permanece aunque falle el arranque posterior. No quitar columnas
mientras exista una máquina con código del PR #18.

Solo si se requiere revertir también el esquema, y después de confirmar el
snapshot recuperable y el código anterior en todas las máquinas, abrir la
misma consola de staging del apartado 4 y ejecutar:

```bash
node --input-type=module <<'JS'
import pg from 'pg';
if (process.env.SHOPIFY_STORE_DOMAIN !== 'monetta-staging.myshopify.com') {
  throw new Error('Abortado: no es staging');
}
const db = new pg.Client({ connectionString: process.env.DATABASE_URL });
try {
  await db.connect();
  await db.query('BEGIN');
  await db.query("SET LOCAL lock_timeout = '5s'");
  await db.query("SET LOCAL statement_timeout = '30s'");
  await db.query(`
    DROP INDEX IF EXISTS idx_orders_mirror_checkout_token;
    DROP INDEX IF EXISTS idx_orders_mirror_cart_token;
    ALTER TABLE orders_mirror DROP COLUMN IF EXISTS checkout_token,
                              DROP COLUMN IF EXISTS cart_token;
    DELETE FROM schema_migrations WHERE filename = '015_order_checkout_tokens.sql';
  `);
  await db.query('COMMIT');
  console.log('015 revertida en staging');
} catch {
  await db.query('ROLLBACK').catch(() => {});
  console.error('Rollback fallido; no volcar errores ni secretos');
  process.exitCode = 1;
} finally {
  await db.end();
}
JS
```

Esta operación elimina los datos de esas dos columnas; no elimina pedidos.
Verificar que ya no hay fila de 015, columnas ni índices (las primeras tres
consultas del apartado 4; no ejecutar la consulta de pedidos que usa las
columnas eliminadas). La siguiente release que incluya 015 la aplicará otra
vez y empezará con valores nulos: recuperar datos previos requiere el snapshot
privado. No se proporciona un comando de restauración global que sobrescriba
pedidos o cambios posteriores.

## Referencias verificadas

- [Shopify: suscripciones de app](https://shopify.dev/docs/apps/build/webhooks/get-started).
- [Shopify: preparar versiones](https://shopify.dev/docs/apps/launch/deployment/deploy-app-versions)
  y [liberarlas](https://shopify.dev/docs/api/shopify-cli/app/app-release).
- [Shopify: limitaciones de webhook trigger](https://shopify.dev/docs/api/shopify-cli/app/app-webhook-trigger).
- [Fly: deploy y skip-release-command](https://docs.fly.io/flyctl/cmd/fly_deploy),
  [releases](https://docs.fly.io/flyctl/cmd/fly_releases) y
  [consola SSH](https://docs.fly.io/flyctl/cmd/fly_ssh_console).
