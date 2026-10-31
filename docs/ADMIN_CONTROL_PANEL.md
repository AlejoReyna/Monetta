# Panel administrativo nativo de Monetta

Este documento explica la arquitectura y la operación del control plane. La
guía de uso diario, escrita para la persona propietaria de la tienda, está en
[`OWNER_ADMIN_GUIDE.md`](OWNER_ADMIN_GUIDE.md).

El plan histórico y la matriz de aceptación están en
[`ADMIN_CONTROL_PLANE_IMPLEMENTATION_PLAN.md`](ADMIN_CONTROL_PLANE_IMPLEMENTATION_PLAN.md).

## Qué resuelve

La administración vive dentro de la misma app Flutter que usa el escaparate.
La app del propietario nunca recibe secretos de Shopify ni de Postgres. Envía únicamente su sesión de Monetta o su token de Shopify
Customer al servicio `accounts_orders`, que vuelve a autenticar y autorizar
cada petición.

```text
Mi cuenta → AdminScreen → accounts_orders
                              ├─ Postgres: principal, auditoría, idempotencia y jobs
                              └─ Shopify Admin API: productos, publicación y metaobjetos

Clientes → Storefront API / caché local
              ├─ productos canónicos de Shopify
              ├─ colección manual monetta-todays-picks
              └─ metaobjeto $app:storefront_config / monetta
```

El catálogo externo de EE. UU. y su monitor (`catalog_monitor`) se retiraron
(decisión E2; RF-20 en la app y RF-21 en el backend). Ya no existen las rutas
`/admin/external-policy/*` ni el canal de sync `external-status`, y
`CATALOG_MONITOR_*` ya no se lee.

El panel no es la fuente de verdad del escaparate. Después de una mutación, el
backend lee la representación canónica y la app refresca sus repositorios
normales. Los demás clientes reciben el cambio en su siguiente refresh o al
vencer su caché.

## Fuentes de verdad

| Dato | Fuente canónica | Qué puede cambiar el panel |
|---|---|---|
| Nombre y precio de producto | Shopify | Título y precio de una variante explícita |
| Visibilidad Monetta | Publicación Headless de Shopify | Publicar o despublicar |
| Catálogo de hoy | Colección manual de Shopify | Membresía y orden, máximo 12 |
| Aviso y secciones de portada | Metaobjeto app-owned de Shopify | Mensaje y cuatro interruptores |
| Campañas y automatizaciones | `accounts_orders` + Postgres | Borrador, audiencia, prueba y envío |
| Historial administrativo | Postgres | Sólo lectura desde el panel |

Los artículos externos son candidatos de investigación y compra manual. El
panel no los crea en Shopify, no compra, no abre checkout y no intenta evadir
CAPTCHA o bloqueos del proveedor.

## Autenticación y autorización

Hay dos capas deliberadamente separadas:

1. Flutter muestra la entrada sólo a una sesión iniciada cuyo correo esté en
   `OWNER_ADMIN_EMAILS`, o en un build de preview. Esta lista es comodidad de
   interfaz, no una frontera de seguridad.
2. El servidor resuelve el bearer token como `app_account`,
   `shopify_customer` o `shopify_staff`, busca un registro activo en
   `admin_principals` y exige el rol `owner` en cada endpoint protegido. Las
   rutas de avisos exigen la capacidad `manageNotifications`, que también tiene
   el panel de Shopify Admin (ver abajo).

`GET /admin/me` devuelve las capacidades efectivas. Un correo o rol enviado
por Flutter nunca concede acceso. No se enlazan identidades sólo porque sus
correos coincidan.

El primer propietario se debe provisionar por ID estable. La opción preferida
es registrar/iniciar sesión con la cuenta de staging, obtener su UUID de
`app_accounts` y crear un `admin_principals` con:

```text
subject_type = app_account
subject_id   = <UUID estable de la cuenta>
role         = owner
active       = true
created_by   = operator:<referencia auditable>
```

Como bootstrap controlado, el servidor también puede crear ese principal la
primera vez que una cuenta autenticada coincide con `OWNER_ADMIN_EMAILS` o
`OWNER_SHOPIFY_CUSTOMER_IDS` del servidor. Una revocación explícita nunca se
reactiva por bootstrap.

## Modos de interfaz

- **CONTROL EN VIVO**: existe `ADMIN_API_BASE_URL` y la app usa el backend.
  Cada cambio exige confirmación y puede estar bloqueado por los kill switches.
- **VISTA PREVIA**: `ENABLE_OWNER_ADMIN_PREVIEW=true`. Sirve para revisar la
  interfaz; los cambios sólo viven en memoria y no llegan a Shopify ni a los
  servicios.

La banda superior siempre indica el modo. Un build de producción no debe
habilitar preview.

## Contrato HTTP

Todas las rutas requieren `Authorization: Bearer <sesión>` salvo los probes de
salud. Las respuestas de error incluyen un código estable y `requestId` cuando
está disponible.

| Ruta | Propósito |
|---|---|
| `GET /admin/me` | Actor, entorno, rol y capacidades efectivas. |
| `GET /admin/control-plane` | Salud consolidada, productos, portada y actividad reciente. |
| `GET /admin/audit` | Historial paginado con cursor opaco. |
| `PATCH /admin/products/:productGid` | Cambia el título con control de versión. |
| `PATCH /admin/products/:productGid/variants/:variantGid` | Cambia sólo la variante indicada. |
| `PUT /admin/products/:productGid/publication` | Publica/despublica en la publicación Headless configurada. |
| `GET /admin/featured-catalog` | Colección de hoy, elegibles, orden y salud. |
| `PUT /admin/featured-catalog/products/:productGid` | Agrega o quita una pieza. |
| `PUT /admin/featured-catalog` | Reemplaza el orden completo; puede devolver un job. |
| `GET /admin/featured-catalog/jobs/:jobId` | Reconciliación de un reorder asíncrono. |
| `PUT /admin/storefront-config` | Upsert completo del metaobjeto con versión. |
| `POST /admin/sync` | Inicia sync de un canal permitido. |
| `GET /admin/sync/jobs/:jobId` | Consulta el resultado del sync. |

Las campañas y automatizaciones usan las rutas `/admin/notifications/*`,
`/admin/notification-campaigns/*` y `/admin/notification-rules`. Exigen la
capacidad `manageNotifications`: la tiene cualquier propietario y también un
`shopify_staff` activo desde el panel de Shopify Admin.

## Panel de avisos en Shopify Admin

Además de la pestaña **Avisos** de la app, la tienda de staging tiene un panel
embebido para enviar notificaciones push desde Shopify Admin
(**Apps → monetta-staging**). Lo sirve el mismo `accounts_orders`; no hay otra
app ni otro despliegue.

```text
Shopify Admin (iframe) → GET /shopify/app            HTML + App Bridge
                       → /admin/notification-* con  Authorization: Bearer <session token>
accounts_orders        → verifica el token HS256 con SHOPIFY_APP_CLIENT_SECRET
                       → admin_principals (shopify_staff, sub del token)
                       → capacidades: sólo manageNotifications
```

**Identidad.** App Bridge entrega un session token firmado por Shopify con el
client secret de la app. El servidor
(`services/accounts_orders/src/admin/shopifySessionToken.ts`) fija `HS256`,
verifica la firma, `aud` = `SHOPIFY_APP_CLIENT_ID`, `dest`/`iss` =
`SHOPIFY_STORE_DOMAIN` y la vigencia (`exp`/`nbf`, con 10 s de tolerancia). El
`sub` del token es el ID del usuario de staff de Shopify. Sin esas tres
variables, la ruta `/shopify/app` no existe y los session tokens no se aceptan.

**Autorización.** Abrir la app en Shopify no da acceso. Se necesita un
principal activo `shopify_staff` con ese ID, creado de una de dos formas:

- `OWNER_SHOPIFY_STAFF_IDS=<id>,<id>` en el servidor; el primer acceso crea el
  principal (`created_by = bootstrap:server-config`).
- Alta manual, auditable:

  ```sql
  INSERT INTO admin_principals (id, subject_type, subject_id, role, active, created_by)
  VALUES (gen_random_uuid(), 'shopify_staff', '<ID de staff>', 'owner', TRUE, 'operator:<referencia>');
  ```

Cuando alguien sin acceso abre el panel, éste muestra su ID de staff para
poder darlo de alta. Revocar es igual que para los demás principals
(`active = FALSE`, `revoked_at = now()`), y el bootstrap nunca reactiva un
principal revocado.

**Alcance.** Un `shopify_staff` recibe sólo `manageNotifications`
(`openAdmin = false`). `GET /admin/me` lo reporta así, y las rutas de producto,
portada, Catálogo de hoy, sync y auditoría responden `403` a su token. La
capacidad cubre todas las rutas de avisos, incluidas `/admin/notification-rules`,
aunque el panel no muestra las reglas automáticas.

**Prueba en un teléfono.** **Enviar prueba** necesita el `device_id` de la
instalación. En staging se obtiene de la base:

```sql
SELECT device_id, platform, app_version, last_seen_at
  FROM device_installations
 WHERE disabled_at IS NULL
 ORDER BY last_seen_at DESC
 LIMIT 5;
```

**Encuadre.** `/shopify/app` responde con
`Content-Security-Policy: frame-ancestors https://<tienda>.myshopify.com https://admin.shopify.com`,
así que ningún otro sitio puede embeber el panel.

**Activación en staging.**

1. Desplegar `accounts_orders` (la migración `016_admin_shopify_staff.sql`
   corre en el `release_command`).
2. Confirmar que existen `SHOPIFY_APP_CLIENT_ID`, `SHOPIFY_APP_CLIENT_SECRET` y
   `SHOPIFY_STORE_DOMAIN=monetta-staging.myshopify.com` en Fly.
3. Dar de alta el staff: `fly secrets set OWNER_SHOPIFY_STAFF_IDS=<id>
   --app monetta-accounts-staging`, o el `INSERT` de arriba.
4. Publicar la configuración de la app (ya tiene `embedded = true` y
   `application_url = …/shopify/app`):

   ```bash
   cd shopify
   npx shopify app deploy --config staging
   ```

5. Abrir **Apps → monetta-staging** en Shopify Admin.

Para que un aviso llegue a un teléfono también deben estar activos
`NOTIFICATIONS_ENABLED`, Firebase y el worker
([`PUSH_NOTIFICATIONS_RUNBOOK.md`](PUSH_NOTIFICATIONS_RUNBOOK.md)). Si no lo
están, el panel carga y avisa que las notificaciones están apagadas.

Producción no cambia: `shopify.app.production.toml` sigue con
`embedded = false`, y un token de staging no valida con el secreto de otra app.

## Secuencia de una escritura

Una escritura normal sigue este orden:

1. Autenticar la sesión y resolver el principal activo.
2. Confirmar que la clase de mutación está habilitada.
3. Validar payload, límites y `Idempotency-Key`.
4. Aplicar rate limit por actor.
5. Leer el recurso actual y rechazar una versión obsoleta con `409`.
6. Ejecutar una sola mutación contra Shopify o el servicio interno.
7. Leer la representación canónica; no asumir éxito por un `200` parcial.
8. Registrar resultado y `requestId` en auditoría.
9. Devolver el estado canónico para refrescar Flutter.
10. Usar webhooks idempotentes como reconciliación posterior.

No se reintenta ciegamente una mutación Shopify cuyo resultado sea ambiguo.
Los `userErrors`, rate limits y fallos upstream se convierten en errores
acotados sin exponer payloads ni secretos.

## Guardas y kill switches

| Variable | Alcance |
|---|---|
| `ADMIN_MUTATIONS_ENABLED` | Interruptor maestro de toda escritura administrativa. |
| `ADMIN_SHOPIFY_WRITES_ENABLED` | Productos, publicación, Catálogo de hoy y portada. |
| `NOTIFICATIONS_ENABLED` | Campañas, entregas y automatizaciones. |

El orden seguro de activación es: lecturas, portada, Catálogo de hoy, producto,
publicación y notificaciones. Para apagar rápidamente, basta
deshabilitar el interruptor maestro; las lecturas y la auditoría permanecen
disponibles.

## Recursos Shopify

El app config declara estos scopes mínimos:

- `read_orders`, `read_customers`
- `read_products`, `write_products`
- `read_publications`, `write_publications`
- `read_metaobjects`, `write_metaobjects`

No se solicitan `write_inventory`, `write_orders` ni `write_customers`.

La portada usa la definición app-owned `$app:storefront_config`, handle
`monetta`, con `merchant_read_write` en Admin y `public_read` en Storefront.
Contiene `announcement`, `show_hero`, `show_newest`,
`show_todays_picks`, `show_external_picks` y `version`.

El Catálogo de hoy usa una sola colección manual:

```text
title:      Today's Picks
handle:     monetta-todays-picks
sortOrder:  MANUAL
channel:    Monetta Staging Headless (en staging)
```

Sólo son elegibles productos activos y ya publicados en Headless. Seleccionar
una pieza no la publica silenciosamente. El runtime falla de forma explícita
si faltan la colección o la publicación; nunca crea recursos desde un guardado
ordinario del propietario.

Los webhooks apuntan al backend estable, verifican HMAC con el client secret de
la app y procesan entregas de forma idempotente. El secreto vive sólo en
`SHOPIFY_WEBHOOK_SECRET` del servidor.

## Staging actual

| Componente | Valor |
|---|---|
| Backend | `https://monetta-accounts-staging.fly.dev` |
| Base de datos | Proyecto Neon separado `monetta-staging` |
| Tienda | `monetta-staging.myshopify.com` |
| App release | `monetta-staging-4` |
| Colección | `monetta-todays-picks`, manual y publicada a Headless |
| Portada | Metaobjeto `monetta`, creado con defaults seguros |

Las mutaciones administrativas de staging permanecen apagadas hasta
provisionar un propietario estable y completar la verificación owner/non-owner.
El monitor externo puede mostrarse degradado o no disponible sin romper las
secciones Shopify.

## Operación y diagnóstico

Pruebas rápidas del backend:

```bash
curl -fsS https://monetta-accounts-staging.fly.dev/livez
curl -fsS https://monetta-accounts-staging.fly.dev/healthz
flyctl status --app monetta-accounts-staging
flyctl secrets list --app monetta-accounts-staging
```

`flyctl secrets list` sólo debe usarse para nombres/digests; nunca imprimir
valores. Para diagnosticar una acción, buscar el `requestId` mostrado por la
app en los logs y en `admin_audit_events`.

Interpretación de errores comunes:

| Código/estado | Acción |
|---|---|
| `401 UNAUTHORIZED` | Renovar la sesión o volver a iniciar sesión. |
| `403 FORBIDDEN` | Revisar el principal estable; no ampliar permisos desde Flutter. |
| `409 STALE_RESOURCE` | Refrescar, revisar el valor nuevo y decidir otra vez. |
| `429` | Esperar; no repetir el botón rápidamente. |
| `FEATURED_COLLECTION_NOT_CONFIGURED` | Revisar IDs/handle y publicación Headless del deployment. |
| `503` de una integración | Mantener el resto del panel; revisar sólo ese upstream. |
| Escrituras deshabilitadas | Revisar kill switches y la fase del rollout. |

## Producción

Producción es un despliegue separado: app Shopify, base de datos, secretos,
colección, publicación, metaobjeto, propietarios y auditoría propios. No se
copian GIDs de staging. La ruta de bajo costo documentada usa un VPS Ubuntu con
Postgres privado, Caddy/TLS, backups cifrados fuera del host y health checks.
El detalle y el orden de habilitación están en la sección WP-10 de
[`ADMIN_CONTROL_PLANE_IMPLEMENTATION_PLAN.md`](ADMIN_CONTROL_PLANE_IMPLEMENTATION_PLAN.md).
