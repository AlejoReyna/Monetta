# Deploy de staging: backend, migración 015, webhooks y APK

Este runbook aplica solo a staging:

- tienda Shopify `monetta-staging.myshopify.com`;
- app Fly `monetta-accounts-staging` (`https://monetta-accounts-staging.fly.dev`);
- app Shopify **monetta-staging** (`shopify/shopify.app.staging.toml`).

Parte de `main` con los PR #14, #16 y #18 ya integrados. Escribir o revisar
este documento no ejecuta nada: los comandos de deploy, migración y registro
son pasos para Alexis (ver el checklist del apartado 6).

Límites que no cambian:

- Nunca apuntar a producción (`monetta.mx`, `fakcei-n9`, admin `monetta-2`),
  ni usar `shopify.app.toml` o `shopify.app.production.toml`.
- `kCheckoutTokenCorrelationAvailable` sigue en `false`.
- Ningún secreto, token, `DATABASE_URL`, CLABE ni `dart_defines` reales en
  archivos, commits, PR, issues o capturas. En este documento aparecen como
  placeholders (`<SHOPIFY_ADMIN_TOKEN>`).
- Si un paso pide un login, una verificación o un dato que no tienes,
  detente y anótalo para Alexis.
- No usar `--verbose`, `set -x` ni volcar el entorno (`env`, `printenv`).

## 1. Backend en Fly (`monetta-accounts-staging`)

### 1.1 Secretos que deben existir en Fly (solo nombres)

`fly.toml` no contiene secretos. Fija `NODE_ENV=production` y `PORT=8082`
en `[env]`; el resto se lee de `fly secrets` (`services/accounts_orders/src/config.ts`).

| Secreto | ¿Requerido? | Para qué |
| --- | --- | --- |
| `DATABASE_URL` | Sí | PostgreSQL de staging en Neon (`?sslmode=require`). Sin él, el servicio intenta `localhost` y `/readyz` falla. |
| `SHOPIFY_STORE_DOMAIN` | Sí | Debe ser `monetta-staging.myshopify.com`. Valida el dominio de los webhooks y de los tokens de Customer Account. |
| `SHOPIFY_APP_CLIENT_SECRET` | Sí | Secreto de la app **monetta-staging**. Verifica el HMAC de los webhooks; vacío = todas las rutas de webhook responden `401`. |
| `SHOPIFY_APP_CLIENT_ID` | Sí, para Admin | `client_id` de la misma app; junto con el secreto y `SHOPIFY_HEADLESS_PUBLICATION_ID` habilita las lecturas Admin. |
| `SHOPIFY_HEADLESS_PUBLICATION_ID` | Sí, para Admin | Publicación headless usada por el panel del dueño. |
| `SHOPIFY_FEATURED_COLLECTION_ID` | Opcional | Colección destacada del panel. |
| `SHOPIFY_ADMIN_API_VERSION` | Opcional | Versión de lecturas Admin; por defecto `2026-07`. No definirla salvo que se cambie a propósito. |
| `OWNER_ADMIN_EMAILS`, `OWNER_SHOPIFY_CUSTOMER_IDS` | Opcional | Candidatos y IDs del dueño para el panel admin. |
| `ADMIN_ENVIRONMENT`, `ADMIN_MUTATIONS_ENABLED`, `ADMIN_SHOPIFY_WRITES_ENABLED`, `ADMIN_EXTERNAL_WRITES_ENABLED` | Opcional | Banderas del panel admin (apagadas por defecto). |
| `REWARDS_ENABLED`, `REWARDS_REDEMPTION_ENABLED`, `REWARDS_RESERVATION_TTL_MINUTES`, `REWARDS_QUOTE_TTL_MINUTES` | Opcional | Rewards (canje apagado por defecto). |
| `LEGACY_ACCOUNT_REGISTRATION_ENABLED` | Opcional | Registro de cuentas propias (encendido por defecto). |
| `INTERNAL_CATALOG_EVENT_SECRET` | Opcional | Eventos internos de catálogo. |
| `NOTIFICATIONS_ENABLED`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `PUSH_TOKEN_ENCRYPTION_SECRET` | Solo si se encienden notificaciones | Con `NODE_ENV=production` y notificaciones encendidas, el arranque falla si falta alguno. En staging siguen apagadas. |

Comprobar que existen sin ver sus valores (`fly secrets list` muestra nombre
y digest, nunca el valor):

```bash
fly secrets list --app monetta-accounts-staging
```

Si falta uno requerido, Alexis lo define desde su terminal, escribiendo él
mismo el valor (nunca pegarlo en un chat ni en un archivo):

```bash
fly secrets set --app monetta-accounts-staging --stage SHOPIFY_APP_CLIENT_SECRET='<SHOPIFY_APP_CLIENT_SECRET>'
```

`--stage` deja el secreto listo para el próximo `fly deploy` sin reiniciar
máquinas.

### 1.2 Checks locales antes del deploy

Desde un checkout limpio de `main` (comprobar `git rev-parse HEAD` y
`git status --short`):

```bash
flutter pub get
flutter analyze
flutter test
cd services/accounts_orders
npm ci
npm test
npm run typecheck
npm run build
```

### 1.3 Deploy

Antes de desplegar, anotar en privado la imagen de la última release sana,
anterior a 015, para poder volver a ella (apartado 2.3). Una referencia de
imagen no es una credencial.

```bash
cd services/accounts_orders
fly releases --app monetta-accounts-staging --image
read -r staging_previous_image   # pegar la referencia de imagen anotada
fly deploy --app monetta-accounts-staging --config fly.toml
fly status --app monetta-accounts-staging
curl --fail --silent --show-error https://monetta-accounts-staging.fly.dev/livez
curl --fail --silent --show-error https://monetta-accounts-staging.fly.dev/readyz
```

`/readyz` debe reportar `database: up`. `fly deploy` construye el
`Dockerfile` del servicio y ejecuta el `release_command` (`node
dist/db/migrate.js`) antes de que una máquina nueva reciba tráfico; si la
migración falla, la release no se activa.

## 2. Migración 015 (`015_order_checkout_tokens.sql`)

Añade a `orders_mirror` dos columnas `TEXT` anulables, `checkout_token` y
`cart_token`, y dos índices parciales para valores no nulos:
`idx_orders_mirror_checkout_token` e `idx_orders_mirror_cart_token`. No
rellena pedidos antiguos. Los tokens se tratan como credenciales: nunca se
registran ni se muestran.

### 2.1 Aplicarla

No hay un paso manual: el `release_command` del apartado 1.3 aplica todos
los SQL pendientes en orden de nombre y registra cada archivo en
`schema_migrations` dentro de la misma transacción que su SQL. Por eso:

- no ejecutar `npm run migrate` dentro de la imagen (no incluye `tsx`);
- no marcar 015 como aplicada a mano ni omitir 014;
- no lanzar migradores en paralelo.

Antes de migrar, Alexis confirma que el `DATABASE_URL` de Fly es la base
aislada de staging y que existe un snapshot recuperable en Neon.

En `fly logs` la primera vez debe aparecer `migration applied` con
`015_order_checkout_tokens.sql`. Si ya estaba registrada, el runner la omite
sin log.

### 2.2 Verificarla

Abrir una consola en la máquina de staging:

```bash
fly ssh console --app monetta-accounts-staging
cd /app
```

Ejecutar esta consulta de solo lectura. Muestra identificadores, estados y
si los tokens existen, nunca sus valores:

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

Resultado esperado:

- una fila en `schema_migrations` para `015_order_checkout_tokens.sql`;
- dos columnas, `checkout_token` y `cart_token`, con `data_type = text` e
  `is_nullable = YES`;
- dos índices cuyo `indexdef` termina en `WHERE (… IS NOT NULL)`.

### 2.3 Revertirla

**Primera opción: revertir solo el código** y conservar las columnas, que son
aditivas. Con la imagen anotada en el apartado 1.3:

```bash
cd services/accounts_orders
fly deploy --app monetta-accounts-staging --config fly.toml --image "$staging_previous_image" --skip-release-command
fly status --app monetta-accounts-staging
curl --fail --silent --show-error https://monetta-accounts-staging.fly.dev/readyz
```

El código anterior a 015 no lee ni escribe esas columnas. El rollback de
imagen no revierte SQL.

**Segunda opción, solo si hace falta revertir el esquema.** Requisitos: el
snapshot de Neon confirmado y todas las máquinas ya con código anterior a 015
(nunca quitar columnas mientras una máquina use el código nuevo). En la misma
consola del apartado 2.2:

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

Borra los valores de esas dos columnas, no los pedidos. Repetir la consulta
del apartado 2.2: las tres consultas deben volver vacías. La siguiente release
que incluya 015 la aplicará de nuevo, con valores nulos; recuperar los
anteriores requiere el snapshot.

## 3. Webhooks `orders/create` y `orders/updated` en Shopify staging

### 3.1 Qué espera el backend

| Topic | Destino | Versión del payload |
| --- | --- | --- |
| `orders/create` | `https://monetta-accounts-staging.fly.dev/webhooks/orders/create` | `2026-07` |
| `orders/updated` | `https://monetta-accounts-staging.fly.dev/webhooks/orders/updated` | `2026-07` |

- Formato JSON (payload REST del pedido). El backend lee, entre otros,
  `financial_status`, `payment_gateway_names`, `gateway`, `transactions`,
  `current_total_price`, `note_attributes`, `checkout_token` y `cart_token`.
- La versión del payload sale de `[webhooks].api_version` en
  `shopify/shopify.app.staging.toml`. `SHOPIFY_ADMIN_API_VERSION` (por defecto
  también `2026-07`) controla solo las lecturas Admin.
- Cada entrega se valida con HMAC usando `SHOPIFY_APP_CLIENT_SECRET` y con el
  dominio `SHOPIFY_STORE_DOMAIN`. Por eso la suscripción tiene que pertenecer a
  la app **monetta-staging**: una suscripción creada por otra app firma con
  otro secreto y recibe `401`.
- La app necesita el scope `read_orders` (ya declarado).

### 3.2 Opción A, recomendada: configuración de la app

Es la fuente de verdad del repo: `shopify/shopify.app.staging.toml` ya
declara ambos topics. El backend no registra webhooks al arrancar. Primero el
deploy del backend (apartado 1); después, desde la raíz del repo:

```bash
cd shopify
npm ci
npx shopify app config validate --config staging
npx shopify app info --config staging
shopify_stage_version="staging-orders-$(git rev-parse --short HEAD)"
npx shopify app deploy --config staging --no-release --version "$shopify_stage_version"
npx shopify app versions list --config staging
```

Revisar en Dev Dashboard la versión creada: app **monetta-staging**,
`api_version` `2026-07`, los dos destinos de la tabla y sin cambios
inesperados en scopes, metaobjetos u otras suscripciones. Confirmar que la
app está instalada **solo** en `monetta-staging.myshopify.com`. Después,
liberar esa versión:

```bash
npx shopify app release --config staging --version "$shopify_stage_version"
npx shopify app versions list --config staging
```

Estas suscripciones las administra la app: no aparecen en Configuración >
Notificaciones > Webhooks, y la lista vacía ahí no significa que falten. No
crearlas también desde esa pantalla.

### 3.3 Opción B: Admin API (solo si no se usa la opción A)

No mezclar con la opción A: se duplicarían las entregas. El token tiene que
ser un token Admin de la app **monetta-staging** instalada en la tienda de
staging, con `read_orders`; un token de otra app produce `401` en el backend
(apartado 3.1).

```bash
SHOP=monetta-staging.myshopify.com
API_VERSION=2026-07
for topic in ORDERS_CREATE ORDERS_UPDATED; do
  path=$(echo "$topic" | tr 'A-Z_' 'a-z/')   # orders/create, orders/updated
  curl --fail --silent --show-error \
    "https://$SHOP/admin/api/$API_VERSION/graphql.json" \
    -H 'Content-Type: application/json' \
    -H 'X-Shopify-Access-Token: <SHOPIFY_ADMIN_TOKEN>' \
    -d "{\"query\":\"mutation(\$topic: WebhookSubscriptionTopic!, \$sub: WebhookSubscriptionInput!) { webhookSubscriptionCreate(topic: \$topic, webhookSubscription: \$sub) { webhookSubscription { id topic uri } userErrors { field message } } }\",\"variables\":{\"topic\":\"$topic\",\"sub\":{\"uri\":\"https://monetta-accounts-staging.fly.dev/webhooks/$path\"}}}"
  echo
done
```

`<SHOPIFY_ADMIN_TOKEN>` se escribe en la terminal en el momento; no se
guarda en el historial ni en archivos. `userErrors` debe venir vacío. Para
listar las suscripciones creadas así:

```bash
curl --fail --silent --show-error \
  "https://$SHOP/admin/api/$API_VERSION/graphql.json" \
  -H 'Content-Type: application/json' \
  -H 'X-Shopify-Access-Token: <SHOPIFY_ADMIN_TOKEN>' \
  -d '{"query":"{ webhookSubscriptions(first: 20) { nodes { id topic uri } } }"}'
```

Las suscripciones de la opción A se revisan en Dev Dashboard, no con esta
consulta.

### 3.4 Verificar que llegan

Alexis crea o autoriza un pedido **de prueba** en la tienda de staging y
después lo actualiza (por ejemplo, una nota o una etiqueta), sin cobrar ni
marcarlo pagado. `shopify app webhook trigger` no sirve como prueba: solo manda una
muestra y no demuestra que las suscripciones estén registradas.

Logs, solo en la terminal privada de Alexis:

```bash
fly logs --app monetta-accounts-staging
```

Líneas esperadas, en JSON, por cada entrega:

- `"message":"order mirrored"` con `shopifyOrderId` y
  `source: "shopify_checkout"`;
- `"message":"http request completed"` con `method: "POST"`,
  `path: "/webhooks/orders/create"` o `"/webhooks/orders/updated"` y
  `status: 200`.

Avisos posibles:

- `order_webhook_missing_checkout_tokens`: el payload no traía los tokens;
  el pedido se refleja igual y el aviso no imprime valores.
- `completed webhook delivery ignored`: reintento de una entrega ya
  procesada; responde `200` sin escribir de nuevo.
- `401`: HMAC o dominio no coinciden; revisar con Alexis el secreto y la app
  dueña de la suscripción.
- `5xx`: revisar la base de datos o el esquema; Shopify reintentará.

No pegar logs crudos, cuerpos de webhooks, cabeceras HMAC ni tokens en PR o
chats.

Fila en `orders_mirror` (misma consola del apartado 2.2, solo lectura):

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

Resultado esperado:

- en `webhook_events`, una entrega por topic para el pedido de prueba, con
  `status = completed` y `processed_at` no nulo;
- en `orders_mirror`, **una sola** fila con ese `shopify_order_id`; la
  actualización avanza `shopify_updated_at` sin duplicarla;
- un pago pendiente con la pasarela **Transferencia bancaria** guarda
  `payment_method = bank_deposit` y en la app se ve como
  «Esperando tu transferencia»;
- `has_checkout_token` y `has_cart_token` en `true` para pedidos nuevos del
  checkout; los pedidos anteriores a 015 quedan en `false`.

## 4. APK de staging

El archivo de defines vive en `config/dart_defines.staging.json` y
**nunca se sube al repo**: `.gitignore` lo excluye en esa ruta. No crearlo en
la raíz del repo, donde no está ignorado. Se crea a partir del ejemplo y
Alexis rellena los valores reales:

```bash
cp config/dart_defines.staging.json.example config/dart_defines.staging.json
# Editar los valores a mano. ACCOUNTS_ORDERS_BASE_URL apunta a
# https://monetta-accounts-staging.fly.dev y SHOPIFY_STORE_DOMAIN a la tienda de staging.
git check-ignore -v config/dart_defines.staging.json   # debe imprimir la regla de .gitignore
dart run bin/validate_dart_defines.dart config/dart_defines.staging.json staging
```

Compilar (equivale a `make build-staging-android`):

```bash
flutter pub get
flutter build apk --debug --flavor staging --dart-define-from-file=config/dart_defines.staging.json
```

El APK queda en `build/app/outputs/flutter-apk/app-staging-debug.apk`, con
`applicationId` terminado en `.staging`. Un `--release` exige
`android/key.properties` (la firma de debug está prohibida para release);
si no existe, usar `--debug`. No adjuntar el APK ni el JSON a PR o issues:
los defines quedan embebidos en el binario.

## 5. Revisión después del deploy

- `/livez` y `/readyz` responden `200`; `/readyz` con `database: up`.
- La consulta del apartado 2.2 confirma 015.
- Las consultas del apartado 3.4 muestran el pedido de prueba.
- La app de staging lista el pedido de prueba con el estado correcto.
- `kCheckoutTokenCorrelationAvailable` sigue en `false` en `main`.

## 6. Checklist para Alexis

Solo Alexis puede ejecutar estos pasos, porque requieren sus sesiones o
credenciales. En orden:

1. [ ] Confirmar en Fly que `DATABASE_URL` de `monetta-accounts-staging` apunta a la base aislada de staging, y crear un snapshot recuperable en Neon.
2. [ ] `fly secrets list --app monetta-accounts-staging`: confirmar que existen `DATABASE_URL`, `SHOPIFY_STORE_DOMAIN`, `SHOPIFY_APP_CLIENT_SECRET`, `SHOPIFY_APP_CLIENT_ID` y `SHOPIFY_HEADLESS_PUBLICATION_ID`; definir con `fly secrets set --stage` los que falten.
3. [ ] Anotar en privado la imagen de la release sana actual (`fly releases --app monetta-accounts-staging --image`).
4. [ ] Desde `main` limpio, correr los checks del apartado 1.2.
5. [ ] `fly deploy --app monetta-accounts-staging --config fly.toml` desde `services/accounts_orders`; comprobar `fly status`, `/livez` y `/readyz`.
6. [ ] En `fly logs`, confirmar `migration applied` para `015_order_checkout_tokens.sql`; correr la consulta del apartado 2.2.
7. [ ] Confirmar en Dev Dashboard que la app **monetta-staging** está instalada solo en `monetta-staging.myshopify.com`.
8. [ ] Registrar los webhooks con la opción A (`shopify app deploy --config staging --no-release`, revisar la versión, `shopify app release`). Usar la opción B solo si se decide no usar la A, con un token Admin de esa misma app.
9. [ ] Crear un pedido de prueba en staging (sin cobrar) y actualizarlo; confirmar `order mirrored` y `status: 200` en los logs, y la fila única en `orders_mirror` (apartado 3.4).
10. [ ] Probar un pedido pendiente con «Transferencia bancaria»: `payment_method = bank_deposit` en el mirror y «Esperando tu transferencia» en la app.
11. [ ] Crear `config/dart_defines.staging.json` desde el ejemplo, validarlo y confirmar con `git check-ignore` que está ignorado.
12. [ ] Compilar el APK de staging (apartado 4) e instalarlo en un dispositivo de prueba.
13. [ ] Si algo falla: rollback de imagen (apartado 2.3, primera opción); revertir el esquema solo con el snapshot confirmado.

## Referencias

- [Shopify: suscripciones de webhooks de la app](https://shopify.dev/docs/apps/build/webhooks/get-started).
- [Shopify: `webhookSubscriptionCreate`](https://shopify.dev/docs/api/admin-graphql/latest/mutations/webhookSubscriptionCreate).
- [Shopify: preparar versiones](https://shopify.dev/docs/apps/launch/deployment/deploy-app-versions)
  y [liberarlas](https://shopify.dev/docs/api/shopify-cli/app/app-release).
- [Fly: `fly deploy`](https://docs.fly.io/flyctl/cmd/fly_deploy),
  [`fly releases`](https://docs.fly.io/flyctl/cmd/fly_releases),
  [`fly secrets set`](https://docs.fly.io/flyctl/cmd/fly_secrets_set) y
  [`fly ssh console`](https://docs.fly.io/flyctl/cmd/fly_ssh_console).
- `services/accounts_orders/README.md` § Deploy y `config/README.md`.
