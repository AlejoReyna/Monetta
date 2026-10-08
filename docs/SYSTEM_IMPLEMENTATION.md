# Implementación integral del sistema Monetta

Estado documentado: 27 de agosto de 2026

Código de referencia: rama `agent/shopify-production`, a partir del commit
`422559640caf17b285ebb652383af96f4054e547`.

Este documento describe lo que está implementado en el repositorio, cómo se
conectan sus componentes y qué partes fueron verificadas contra sistemas reales.
Se concentra especialmente en dos preguntas:

1. ¿Cómo se mantiene el catálogo que ve la app igual al catálogo real de
   `monetta.mx`?
2. ¿Cómo se relaciona el login de la app con la identidad real de un cliente de
   Shopify?

No se usa la conversación como fuente de verdad para afirmar comportamiento. Las
afirmaciones técnicas se enlazan al código que las implementa y, cuando algo sólo
está preparado pero no validado extremo a extremo, se indica expresamente.

## 1. Resumen ejecutivo

Monetta no copia productos manualmente dentro de Flutter. Shopify sigue siendo la
fuente comercial de verdad. El sistema crea un espejo público, de sólo lectura,
en Firestore:

```text
Shopify real (monetta.mx / fakcei-n9.myshopify.com)
        │
        ├── webhook firmado ───────────────┐
        │   create/update/delete/inventory │
        │                                  ▼
        └── Admin GraphQL ──────────► Vercel Catalog Mirror
                  ▲                  /api + /api/reconcile
                  │                          │
                  └── client credentials    ▼
                                    Firestore staging
                                         products
                                            │ snapshot en tiempo real
                                            ▼
                                      Flutter CatalogStore
                                            │
                                            ▼
                                      Drift / monetta.sqlite
```

El flujo normal es automático:

- El dueño cambia un producto o inventario en Shopify.
- Shopify envía un webhook firmado al backend.
- El backend vuelve a consultar el producto por Admin GraphQL; no confía en que
  el payload reducido del webhook contenga todo el catálogo.
- El backend crea, reemplaza o elimina el documento correspondiente en
  Firestore.
- Firestore emite un snapshot y la app reemplaza atómicamente su caché Drift.
- Los widgets reciben la nueva lista desde `CatalogStore`.

Una reconciliación protegida y periódica vuelve a recorrer Shopify para reparar
cualquier webhook perdido y eliminar documentos obsoletos.

La identidad tiene dos rutas distintas:

- **Login Shopify real:** OAuth 2.0 + PKCE contra Customer Account API. Shopify
  autentica a la persona y devuelve un `gid://shopify/Customer/...` real.
- **Cuenta propia Monetta:** correo/contraseña contra `accounts_orders`. Es una
  identidad propia de la app. No se convierte por sí sola en cliente Shopify;
  requiere un vínculo explícito `shopify_customer_id` en el backend para acceder
  a pedidos reales de Shopify.

Catálogo y login son subsistemas independientes. Se puede consultar el catálogo
como invitado; iniciar sesión no cambia qué productos existen ni es requisito
para comprar.

## 2. Fuentes de verdad y copias derivadas

| Información | Fuente de verdad | Copias/cache | Quién escribe |
|---|---|---|---|
| Productos, variantes, precios, imágenes, publicación e inventario | Shopify | Firestore `products`, Drift | Shopify; backend sólo refleja |
| Identidad de cliente Shopify | Customer Account API | Drift `accounts` | Shopify; Flutter guarda referencia |
| Cuenta propia Monetta | Postgres `app_accounts` | Drift `accounts` | `accounts_orders` |
| Sesión Shopify | Token endpoint de Shopify | refresh token en Keychain/Keystore; metadatos en Drift | Shopify/AppAuth |
| Sesión Monetta | Postgres `app_sessions` | token opaco en Keychain/Keystore; metadatos en Drift | `accounts_orders` |
| Pedidos reales | Shopify | Postgres `orders_mirror`, Drift `order_summaries` | Shopify; webhooks reflejan |
| Bolsa y wishlist del dispositivo | Drift | memoria de `CatalogStore` | Flutter |
| Preferencias y entregas de notificaciones | Postgres/FCM | estado local Flutter | app + servicio de engagement |

Firestore no reemplaza Shopify como sistema comercial. Drift tampoco reemplaza
Firestore: es una caché persistente para abrir rápido y tolerar desconexiones.

## 3. Sincronización automática del catálogo real

### 3.1 Origen autorizado y permisos mínimos

La app Shopify `Monetta Catalog Mirror` declara como origen de sólo lectura la
tienda real `fakcei-n9.myshopify.com`, cuyo escaparate público es `monetta.mx`.
El destino sigue siendo el proyecto aislado de Vercel/Firebase staging. Esto está
declarado en
[`shopify/shopify.app.catalog-mirror.toml:2`](../shopify/shopify.app.catalog-mirror.toml#L2-L24).

Los únicos scopes son:

- `read_products`
- `read_inventory`

No se solicita permiso para escribir productos, inventario, pedidos, clientes ni
pagos. Por diseño, el espejo no puede modificar el catálogo real.

La misma configuración registra cuatro topics contra
`https://monetta-catalog-staging.vercel.app/api`:

- `products/create`
- `products/update`
- `products/delete`
- `inventory_levels/update`

Referencia:
[`shopify.app.catalog-mirror.toml:10`](../shopify/shopify.app.catalog-mirror.toml#L10-L24).

### 3.2 Obtención segura de datos completos desde Shopify

El backend no guarda permanentemente un Admin API token. Intercambia el client ID
y client secret de la app instalada mediante `client_credentials`, valida que el
token incluya los scopes de lectura y lo conserva en memoria sólo hasta cinco
minutos antes de expirar:
[`ShopifyAdminClient.accessToken`](../server/catalog/shopifyAdmin.ts#L145-L193).

Después consulta Admin GraphQL con ese token:
[`ShopifyAdminClient.query`](../server/catalog/shopifyAdmin.ts#L112-L143).

El fragmento `MobileProduct` pide los campos que consume el móvil:

- identidad GID y legacy;
- handle, título, proveedor, tipo, tags y descripción;
- estado y fechas de publicación;
- hasta 20 imágenes;
- hasta 10 colecciones;
- hasta 20 variantes con precio, compare-at price, SKU, disponibilidad,
  cantidad, política e inventory item;
- metafields opcionales para corregir marca y categoría.

Referencia:
[`PRODUCT_FIELDS`](../server/catalog/shopifyAdmin.ts#L3-L35).

La ampliación a `images(first: 20)` es importante: durante la validación real,
el límite anterior de seis imágenes produjo diferencias aunque los productos y
variantes fueran correctos.

### 3.3 Recepción y autenticación del webhook

El endpoint es `POST /api`, implementado en
[`api/index.ts:124`](../api/index.ts#L124-L265).

Orden de validación:

1. Lee configuración obligatoria y falla cerrado con `503` si falta.
2. Limita el cuerpo a 2 MB.
3. Lee los bytes crudos del request.
4. Verifica `X-Shopify-Hmac-Sha256` antes de confiar en topic, tienda o payload.
5. Acepta sólo los cuatro topics declarados.
6. Valida el ID de entrega y exige que `X-Shopify-Shop-Domain` coincida con la
   tienda configurada.

La verificación HMAC ocurre en
[`api/index.ts:149`](../api/index.ts#L149-L163), usando
[`server/catalog/hmac.ts`](../server/catalog/hmac.ts).

Esto impide que un tercero publique documentos en Firestore enviando JSON al
endpoint público. La prueba HTTP sin firma devuelve `401 invalid_signature`.

### 3.4 Qué hace cada evento

La selección de comportamiento se encuentra en
[`api/index.ts:172`](../api/index.ts#L172-L202):

- **`products/create` y `products/update`:** valida el ID y consulta el producto
  completo por GID con `getProduct`.
- **`inventory_levels/update`:** convierte el inventory item a GID, busca la
  variante y de ahí recupera el producto completo con
  `getProductForInventoryItem`. Así el documento recalcula todas las variantes y
  el estado de existencias, no sólo una cantidad aislada.
- **`products/delete`:** no consulta un producto que ya no existe; calcula su
  identidad y elimina el documento.

Incluso en create/update, si Shopify devuelve un producto no publicado, draft o
archivado, el resultado correcto es eliminarlo del espejo público. La regla de
publicación es exactamente `status == ACTIVE && publishedAt != null`:
[`isPublicProduct`](../server/catalog/catalog.ts#L9-L11).

### 3.5 Transformación al esquema móvil

[`toCatalogProduct`](../server/catalog/catalog.ts#L13-L57) convierte Admin
GraphQL a un documento pequeño y estable:

```text
schemaVersion, source
id (Product GID), shopifyLegacyId
handle, title, vendor, productType, tags, descriptionHtml
images, collectionHandles
brandOverride, categoryOverride
variants[]
createdAt, updatedAt, publishedAt
isPublished, isInStock, minPrice
```

Los precios se convierten a números finitos no negativos. `isInStock` se deriva
de las variantes y `minPrice` del mínimo de sus precios. Cada variante conserva
su GID, precio, SKU, disponibilidad e identidad de inventario.

Los documentos se guardan con el ID legacy numérico como ruta
`products/{shopifyLegacyId}`. Dentro del documento, la identidad de dominio sigue
siendo el GID canónico. La ruta numérica facilita correlacionar webhooks legacy
sin sacrificar identidad global en la app.

### 3.6 Escritura atómica y deduplicación

Shopify puede reintentar la misma entrega. El backend usa
`X-Shopify-Webhook-Id` como llave de
`_shopifyWebhookDeliveries/{webhookId}`.

Producto y ledger se escriben dentro de la misma transacción Firestore:
[`api/index.ts:208`](../api/index.ts#L208-L242).

Por lo tanto:

- si ya existe el ID, responde `200 duplicate`;
- si la transacción falla, no queda una entrega marcada como procesada sin su
  mutación de catálogo;
- si se procesa, el producto y el ledger se confirman juntos;
- el ledger recibe `expiresAt` a 30 días para limpieza TTL.

El TTL está declarado en
[`firestore.indexes.json:4`](../firestore.indexes.json#L4-L9), pero su activación
remota sigue pendiente porque Firebase Billing no pudo habilitarse. La ausencia
de TTL no rompe la sincronización; sólo impide la limpieza automática del
ledger.

### 3.7 Reconciliación completa: reparar lo que un webhook no cubra

Los webhooks dan baja latencia, pero no son la única garantía. `GET
/api/reconcile` recorre todas las páginas de productos de Shopify, vuelve a
escribir los publicables y elimina documentos que ya no existen:
[`api/reconcile.ts:37`](../api/reconcile.ts#L37-L127).

Seguridad:

- sólo acepta `GET`;
- requiere `Authorization: Bearer <CRON_SECRET>`;
- compara el secreto con `timingSafeEqual`;
- exige un secreto de al menos 32 caracteres.

El endpoint está pensado para Vercel Cron, evitando colocar el secreto en el
historial del shell. El runbook operativo está en
[`docs/VERCEL_CATALOG_WEBHOOK_SETUP.md`](VERCEL_CATALOG_WEBHOOK_SETUP.md).

La reconciliación evita pisar un webhook más reciente. Toma `startedAt` y, al
procesar cada documento, omite cualquier fila cuyo `syncedAt` sea posterior al
inicio del recorrido:
[`api/reconcile.ts:65`](../api/reconcile.ts#L65-L87).

Al final busca todos los documentos con `source == shopify` y elimina sólo los
que no fueron vistos y no fueron actualizados concurrentemente:
[`api/reconcile.ts:96`](../api/reconcile.ts#L96-L106).

Resultado: webhooks y reconciliación se complementan. El primero es rápido; el
segundo corrige pérdidas, despublicaciones y divergencias acumuladas.

### 3.8 Aislamiento y reglas de Firestore

El Admin SDK contiene un guard explícito: la cuenta de servicio debe pertenecer
a `monetta-catalog-staging-edfb8`, o el runtime se niega a inicializar:
[`server/catalog/firebaseAdmin.ts:5`](../server/catalog/firebaseAdmin.ts#L5-L49).

Las reglas permiten lectura pública únicamente de `products` y prohíben todas
las escrituras desde clientes. El ledger y cualquier colección futura quedan
privados:
[`firestore.rules`](../firestore.rules).

Esto separa responsabilidades:

- Vercel, autenticado con Admin SDK, escribe.
- Flutter, usando opciones públicas Firebase, sólo escucha.
- El móvil nunca recibe el service account ni el Shopify client secret.

### 3.9 Inicialización del listener en Flutter

`main()` habilita Firestore sólo cuando:

- `FIRESTORE_CATALOG_ENABLED` es verdadero; y
- existen opciones públicas Firebase válidas.

Después inicializa Firebase una sola vez y construye
`FirestoreCatalogSource`:
[`lib/main.dart:65`](../lib/main.dart#L65-L99).

Notificaciones y catálogo comparten un inicializador single-flight. Las llamadas
concurrentes reciben el mismo `Future`; si falla, se limpia para permitir otro
intento:
[`FirebaseAppBootstrap`](../lib/data/firebase/firebase_app_bootstrap.dart#L7-L42).

El source escucha `.collection('products').snapshots()` con cambios de metadata:
[`FirestoreCatalogSource.watchProducts`](../lib/data/firestore/firestore_catalog_source.dart#L12-L24).

### 3.10 Validación estricta antes de tocar la caché

`RealtimeCatalogRepository` no aplica documentos individualmente. Recibe el
snapshot completo, valida todos sus documentos y sólo entonces reemplaza la
caché:
[`RealtimeCatalogRepository.applySnapshot`](../lib/data/repositories/realtime_catalog_repository.dart#L94-L117).

Entre otras cosas verifica:

- `schemaVersion == 1`;
- `source == shopify`;
- ruta legacy igual a `shopifyLegacyId`;
- `isPublished == true`;
- tipos y presencia de campos;
- precios finitos y no negativos;
- fechas parseables;
- GID de producto coherente con el ID legacy;
- GIDs válidos para variantes.

El parser está en
[`realtime_catalog_repository.dart:119`](../lib/data/repositories/realtime_catalog_repository.dart#L119-L252).

Si el snapshot está vacío o contiene siquiera un documento inválido, conserva el
último catálogo válido. No interpreta un fallo remoto como una orden de borrar la
tienda. Ante error o desconexión, vuelve a suscribirse con backoff exponencial de
1 a 32 segundos:
[`RealtimeCatalogRepository.watch`](../lib/data/repositories/realtime_catalog_repository.dart#L76-L91).

### 3.11 Reemplazo atómico en Drift

Después de validar el snapshot, el repositorio llama
`CatalogCacheStore.replaceProducts`. La función elimina variantes y productos y
recrea todo dentro de una sola transacción SQLite:
[`catalog_cache_store.dart:199`](../lib/data/local/catalog_cache_store.dart#L199-L209).

La app nunca debe observar “mitad del catálogo viejo y mitad del nuevo”. Si la
transacción falla, Drift revierte el reemplazo.

La metadata de cada snapshot registra la tienda configurada como procedencia
(ver §3.12).

Luego `CatalogStore` publica la lista en memoria, recalcula facetas normalizadas y
marca el estado `live`:
[`CatalogStore._applyRealtimeUpdate`](../lib/app/catalog_store.dart#L370-L406).

### 3.12 Arranque offline, snapshot incluido y delta fallback

El arranque es cache-first:

1. Carga reglas de normalización.
2. Si Drift está vacío, inserta `assets/catalog/catalog.json` como semilla.
3. Añade productos faltantes del asset sin sobreescribir filas remotas.
4. Lee Drift y permite pintar la UI.
5. Inicia el listener Firestore.

Referencia:
[`CatalogStore.loadFromAsset`](../lib/app/catalog_store.dart#L169-L219) y
[`CatalogRepository.seedFromAssetIfEmpty`](../lib/data/repositories/catalog_repository.dart#L89-L111).

El asset es una red de seguridad de primer arranque, no la fuente que mantiene el
catálogo actualizado.

**Procedencia de tienda.** Antes de sembrar y antes de cada sync, la app compara
el dominio configurado, con igualdad exacta, contra la tienda del cursor y la de
la metadata del catálogo. Si alguna difiere, borra el estado de la tienda
anterior: catálogo, bolsa, favoritos, eventos, sesiones, pedidos y cuentas.

Para que el propio catálogo de monetta.mx no cuente como «otra tienda»:

- la semilla registra la tienda de su `_source` (`https://monetta.mx/products.json`);
- cada snapshot de Firestore registra la tienda configurada;
- una instalación nueva guarda su tienda en el cursor desde el primer arranque.

Así, un primer sync fallido ya no borra la semilla.

Referencias:
- [`CatalogRepository._cursorForConfiguredShop`](../lib/data/repositories/catalog_repository.dart#L295-L327);
- las pruebas CHAR-03 de
  [`shop_scope_characterization_test.dart`](../test/data/local/shop_scope_characterization_test.dart).

Existe además un delta sync Storefront con cursor `updated_at`. Relee un segundo
de solapamiento para no perder cambios con igual precisión temporal y fuerza una
sincronización completa cada siete días para descubrir eliminaciones:
[`SyncCursor.deltaFilter`](../lib/data/shopify/catalog_sync.dart#L25-L59) y
[`CatalogSync`](../lib/data/shopify/catalog_sync.dart#L81-L163).

La política de escritores es explícita:

- sin Firestore, Storefront delta es el escritor remoto normal;
- mientras Firestore conecta o está live, delta se omite;
- si Firestore falla, delta queda habilitado como fallback;
- sólo hay un delta en curso;
- Firestore y delta pasan por una cola exclusiva;
- si Firestore vuelve durante un delta, espera y después recupera autoridad.

Código:
[`CatalogWriteCoordinator`](../lib/data/repositories/catalog_write_coordinator.dart#L6-L62) y
[`CatalogStore.syncWithShopify`](../lib/app/catalog_store.dart#L234-L310).

### 3.13 Identidad canónica y migración de instalaciones existentes

Toda identidad de dominio usa:

- `gid://shopify/Product/<id>`
- `gid://shopify/ProductVariant/<id>`

La función central que acepta un GID válido o convierte un decimal está en
[`shopify_gid.dart`](../lib/data/shopify/shopify_gid.dart).

Drift pasó de schema v1 a v2. La migración transforma productos, variantes,
wishlist, bolsa y eventos de recomendación. Si una instalación parcialmente
migrada ya contiene una fila GID y otra numérica, gana la GID:
[`AppDatabase._migrateShopifyIdsToGids`](../lib/data/local/database.dart#L48-L126).

Esto evita que el mismo producto exista dos veces por haber llegado desde un
snapshot legacy, Storefront o Firestore.

### 3.14 Evidencia real de sincronización

El 27 de agosto de 2026 se ejecutó una reconciliación protegida contra la tienda
real de Monetta y se comparó exhaustivamente Shopify con Firestore:

- 139 productos;
- 345 variantes;
- 386 imágenes;
- 0 IDs faltantes o extra;
- 0 diferencias de campos principales;
- 0 diferencias de imágenes;
- 0 diferencias de variantes.

Después, el simulador iOS leyó Firestore y persistió:

- 139 productos en `CatalogStore`/Drift;
- 345 variantes en Drift;
- 0 GIDs inválidos;
- ausencia de los productos de prueba de la development store anterior.

Esta evidencia demuestra la reconciliación completa y el consumo Flutter. La
entrega natural de un webhook real y su redelivery todavía deben observarse para
cerrar la prueba de aceptación de deduplicación en infraestructura, aunque esa
lógica sí está implementada y cubierta por pruebas locales.

## 4. Login y sincronización con clientes reales

### 4.1 No existe un solo “login”: existen dos proveedores

`AccountController` distingue `authProvider == shopify` de
`authProvider == monetta`:
[`AccountController`](../lib/app/account_controller.dart#L51-L135).

| Ruta | Autentica contra | Identidad resultante | Acceso a pedidos Shopify |
|---|---|---|---|
| Shopify Customer Account | Shopify OAuth/Customer Account API | GID real de Customer | Sí, validando token con Shopify |
| Cuenta Monetta | Postgres `app_accounts` | UUID propio de Monetta | Sólo si el backend ya tiene `shopify_customer_id` vinculado |

La pantalla puede ofrecer ambas cuando sus configuraciones existen. Ninguna es
necesaria para ver el catálogo.

### 4.2 Login Shopify real: OAuth 2.0 + PKCE

`CustomerAccountConfig` construye la configuración desde `--dart-define`, usa
discovery OIDC y deriva el callback `shop.{shopId}.oauth://callback`:
[`customer_account_config.dart:10`](../lib/data/customer_auth/customer_account_config.dart#L10-L119).

El cliente móvil es público: no contiene client secret. PKCE es el mecanismo de
seguridad apropiado para una app compilada.

`AppAuthCustomerGateway.login` delega a los SDK nativos AppAuth:

1. descubre endpoints OIDC desde el dominio público de la tienda;
2. abre el navegador/sheet de Shopify;
3. Shopify recoge credenciales, OTP, social o passkey según su configuración;
4. AppAuth genera y valida PKCE;
5. captura el custom-scheme callback;
6. intercambia el authorization code por tokens.

Código:
[`AppAuthCustomerGateway.login`](../lib/data/customer_auth/customer_auth_gateway.dart#L51-L83).

La app nunca ve la contraseña de Shopify. Tampoco implementa manualmente
`code_verifier`, `code_challenge` o el intercambio del código.

### 4.3 Resolver quién inició sesión

Un token no se convierte directamente en una fila local. Con el access token
nuevo, `HttpCustomerIdentityService` consulta:

```graphql
customer {
  id
  displayName
  emailAddress { emailAddress }
}
```

Referencia:
[`customer_identity.dart:69`](../lib/data/customer_auth/customer_identity.dart#L69-L138).

El endpoint GraphQL tampoco está hardcodeado: se descubre desde
`/.well-known/customer-account-api`, se valida que sea HTTPS y se cachea.
Las llamadas concurrentes comparten una sola petición y un fallo no se cachea.
Identidad y pedidos usan la misma instancia de `CustomerApiDiscoveryService`,
creada en `main.dart`, así que cada sesión de la app hace un solo discovery:
[`customer_api_discovery.dart:34`](../lib/data/customer_auth/customer_api_discovery.dart#L34-L117).

La identidad persistida proviene preferentemente de esa respuesta autenticada.
Sólo si la consulta falla por un problema no relacionado con rechazo del token,
el repositorio usa temporalmente los claims del id token como fallback. Un 401,
403 o error de sesión expirada no se degrada a fallback:
[`CustomerSessionRepository._resolveIdentity`](../lib/data/customer_auth/customer_session_repository.dart#L96-L177).

### 4.4 Persistencia local tras login

Después de obtener el Customer GID, `CustomerSessionRepository.login`:

1. busca si ya existe una cuenta por `shopifyCustomerId`;
2. reutiliza su `localAccountId` o crea un UUID;
3. guarda email/nombre/provider en Drift;
4. guarda el refresh token en Keychain/Keystore;
5. guarda en Drift únicamente la referencia a esa llave y expiración;
6. asocia el dispositivo a la cuenta;
7. mueve wishlist y bolsa de invitado hacia la cuenta.

Referencia completa:
[`customer_session_repository.dart:96`](../lib/data/customer_auth/customer_session_repository.dart#L96-L139).

La separación de secretos está materializada en las tablas:

- `Accounts`: identidad local y `shopifyCustomerId`;
- `Devices`: instalación y cuenta activa;
- `Sessions`: `secureStorageKeyRef`, nunca el token;
- el valor real queda en `flutter_secure_storage`.

Esquema:
[`lib/data/local/tables.dart:128`](../lib/data/local/tables.dart#L128-L203).

Wishlist y bolsa creadas como invitado no se pierden. Sólo se reasignan filas con
`accountId IS NULL`; los datos de otra cuenta que haya usado el mismo dispositivo
no se mezclan. La llamada está en
[`customer_session_repository.dart:125`](../lib/data/customer_auth/customer_session_repository.dart#L125-L132).

### 4.5 Restauración, refresh y cierre de sesión Shopify

Al arrancar, `AccountController.restore` lee la cuenta asociada al dispositivo y
verifica que exista una sesión local usable:
[`account_controller.dart:137`](../lib/app/account_controller.dart#L137-L175).

Después `main` carga pedidos desde caché y dispara una revalidación Shopify sin
bloquear el primer frame:
[`lib/main.dart:485`](../lib/main.dart#L485-L493).

Los access tokens viven sólo en memoria. Si faltan o están a menos de dos minutos
de expirar, el repositorio usa el refresh token guardado. El refresh es
single-flight porque Shopify puede rotar refresh tokens y dos intercambios
paralelos podrían invalidarse entre sí:
[`CustomerSessionRepository.refreshAccessToken`](../lib/data/customer_auth/customer_session_repository.dart#L179-L231).

Logout Shopify borra refresh token, metadata de sesión, asociación del
dispositivo y access token en memoria:
[`customer_session_repository.dart:243`](../lib/data/customer_auth/customer_session_repository.dart#L243-L266).

Límite actual: es logout local. No abre el endpoint de fin de sesión alojada de
Shopify, por lo que el próximo navegador de login puede reconocer todavía la
sesión de Shopify.

### 4.6 Cómo el backend confía en un login Shopify

El móvil envía su access token como Bearer a rutas propias, por ejemplo
`GET /customers/me/orders`. El backend no confía en un customer ID enviado por
el cliente. Pasa el token a `ShopifyCustomerTokenVerifier`, que descubre el
Customer Account GraphQL endpoint y ejecuta `customer { id }`:
[`customerTokenVerifier.ts:21`](../services/accounts_orders/src/auth/customerTokenVerifier.ts#L21-L99).

`authenticatedCustomerId` acepta la identidad sólo después de que Shopify la
resuelve y normaliza el GID a ID legacy para las tablas espejo:
[`server.ts:66`](../services/accounts_orders/src/api/server.ts#L66-L121).

Por eso un usuario no puede pedir los pedidos de otra persona cambiando un ID en
la URL. La única ruta es `/customers/me/orders`, cuyo customer se deriva del
token:
[`server.ts:432`](../services/accounts_orders/src/api/server.ts#L432-L458).

### 4.7 Cuenta propia Monetta

La segunda ruta permite registro y login con correo/contraseña contra el servicio
propio:

- `POST /accounts/register`
- `POST /accounts/login`
- `GET /accounts/me`
- `POST /accounts/logout`

Cliente Flutter:
[`HttpSystemAccountClient`](../lib/data/accounts_orders/system_account_client.dart#L49-L143).

Servidor:
[`server.ts:260`](../services/accounts_orders/src/api/server.ts#L260-L392).

En registro, el servidor:

- normaliza el correo;
- exige contraseña de 8 a 128 caracteres;
- genera un UUID de cuenta;
- hashea la contraseña con scrypt y salt aleatorio;
- genera un token opaco de 32 bytes;
- guarda sólo SHA-256 del token;
- asigna expiración de 180 días.

Implementación criptográfica:
[`server.ts:52`](../services/accounts_orders/src/api/server.ts#L52-L139).

Las tablas `app_accounts` y `app_sessions` están en
[`002_app_accounts.sql`](../services/accounts_orders/src/db/migrations/002_app_accounts.sql),
y el password hash/índice único de email en
[`003_app_account_passwords.sql`](../services/accounts_orders/src/db/migrations/003_app_account_passwords.sql).

El repositorio usa una transacción y advisory lock por dispositivo durante el
registro, y `ON CONFLICT(device_id)` para mantener una sesión actual por
dispositivo:
[`PgAppAccountsRepository.register`](../services/accounts_orders/src/db/pgAppAccountsRepository.ts#L33-L89).

Flutter guarda el token opaco en secure storage y en Drift sólo su referencia,
igual que en Shopify. También asocia dispositivo y fusiona bolsa/wishlist:
[`SystemAccountSessionRepository`](../lib/data/accounts_orders/system_account_session_repository.dart#L42-L129).

### 4.8 Punto crítico: una cuenta Monetta no es automáticamente una cuenta Shopify

`app_accounts.shopify_customer_id` es nullable por diseño:
[`002_app_accounts.sql:1`](../services/accounts_orders/src/db/migrations/002_app_accounts.sql#L1-L13).

Cuando una ruta de pedidos recibe un token Monetta, el backend encuentra la
sesión y exige que esa cuenta tenga vínculo Shopify. Si no lo tiene, responde
`403 shopify_customer_not_linked`:
[`authenticatedCustomerId`](../services/accounts_orders/src/api/server.ts#L83-L91).

En el código actual no existe una ruta pública que vincule por correo una cuenta
Monetta con Shopify, y eso es correcto: coincidencia de email por sí sola no
prueba que ambas identidades pertenezcan a la misma persona. El vínculo debe
crearse mediante un flujo explícito y autenticado que todavía no está
implementado.

Consecuencias:

- **Shopify login:** identidad Shopify y pedidos reales sí pueden sincronizarse.
- **Monetta login sin vínculo:** registro/login real en el backend propio, pero
  todavía no obtiene pedidos Shopify.
- **Monetta login con vínculo backend preexistente:** el token opaco resuelve el
  `shopify_customer_id` y puede consultar pedidos de ese cliente.

Además, la configuración pública staging de ejemplo mantiene
`ACCOUNTS_ORDERS_BASE_URL` vacío. Mientras un build real no configure y despliegue
ese servicio, `canRegister`/`canSystemLogin` quedan deshabilitados honestamente:
[`AccountsOrdersConfig`](../lib/data/accounts_orders/accounts_orders_config.dart#L13-L28)
y [`main.dart:410`](../lib/main.dart#L410-L434).

### 4.9 Sincronización de pedidos asociados al login

Shopify envía `orders/create` y `orders/updated` al servicio de cuentas. Antes de
parsear, el servidor valida HMAC sobre los bytes crudos:
[`shopifyWebhookRoute`](../services/accounts_orders/src/api/server.ts#L141-L175).

`handleOrdersWebhook`:

- deduplica por `X-Shopify-Webhook-Id`;
- crea/actualiza el customer mirror si el pedido trae cliente;
- distingue checkout Shopify de apartado WhatsApp mediante tag `MN-XXXX`;
- guarda estado financiero, fulfillment, total, moneda y atribución;
- relaciona el pedido con el customer ID real de Shopify.

Referencia:
[`handleOrdersWebhook`](../services/accounts_orders/src/webhooks/handlers.ts#L93-L147).

Postgres hace upsert por `shopify_order_id`:
[`PgOrdersRepository.upsertByShopifyOrderId`](../services/accounts_orders/src/db/pgOrdersRepository.ts#L43-L82).

En la app, `AccountController.loadOrders` primero pinta `order_summaries` de
Drift, obtiene un token del proveedor actual y actualiza desde
`/customers/me/orders`:
[`account_controller.dart:329`](../lib/app/account_controller.dart#L329-L359).

La respuesta remota reemplaza atómicamente la caché local de esa cuenta; un error
de red conserva la última lista válida:
[`OrderHistoryRepository.refresh`](../lib/data/repositories/order_history_repository.dart#L29-L63).

## 5. Qué pasa cuando se realiza una compra

### 5.1 Compra en `monetta.mx`

La compra web sigue siendo un checkout real de Shopify. Shopify controla pago,
pedido e inventario. Después:

1. Shopify actualiza inventario.
2. Catalog Mirror recibe `inventory_levels/update`.
3. Firestore y la app recalculan disponibilidad.
4. Si `accounts_orders` tiene sus webhooks instalados/desplegados, recibe el
   pedido y lo refleja en `orders_mirror`.
5. Un cliente autenticado con la identidad Shopify correspondiente puede verlo
   en “Mis pedidos”.

### 5.2 Compra desde la app

El límite actual debe quedar inequívoco: la UI construye un `CheckoutDraft`, pero
el árbol de producción no inyecta todavía un `SecureCheckoutLauncher`. El contrato
está en
[`checkout_screen.dart`](../lib/features/checkout/checkout_screen.dart#L21-L53).

Las queries `cartCreate` y `checkoutUrl` existen en la capa Shopify
([`queries.dart`](../lib/data/shopify/queries.dart#L200-L240)), pero el flujo
completo no está cableado desde la pantalla a una creación real de carrito.

Por lo tanto, este repositorio no debe anunciar todavía “compra real dentro de la
app”. La ruta real y operativa sigue siendo `monetta.mx`. Cuando se implemente el
launcher, la app deberá crear el Shopify Cart, adjuntar buyer identity si hay
login Shopify y abrir `cart.checkoutUrl`; Shopify seguirá manejando pago y PCI.

## 6. Notificaciones y engagement

La infraestructura añadida permite:

- registro de dispositivo y preferencias;
- verificación Firebase App Check;
- almacenamiento cifrado de tokens FCM;
- campañas administrativas;
- notificaciones locales programadas;
- eventos de producto creado, restock y caída de precio;
- outbox para entrega durable.

Puntos de entrada principales:

- cliente y estado Flutter:
  [`NotificationController`](../lib/app/notification_controller.dart) y
  [`lib/data/notifications`](../lib/data/notifications/);
- API:
  [`registerEngagementRoutes`](../services/accounts_orders/src/engagement/api/routes.ts#L23);
- reglas de negocio:
  [`EngagementService`](../services/accounts_orders/src/engagement/application/engagementService.ts#L16);
- transición de webhooks Shopify:
  [`PgShopifyCatalogEventProcessor`](../services/accounts_orders/src/engagement/infrastructure/pgShopifyCatalogEventProcessor.ts#L17);
- outbox del monitor externo:
  [`CatalogEventOutbox`](../services/catalog_monitor/src/notifications/catalogEventOutbox.ts#L10).

El catálogo visual no depende de que notificaciones funcionen. Firebase comparte
bootstrap, pero cada feature falla de manera aislada para no bloquear la tienda.
El runbook se encuentra en
[`docs/PUSH_NOTIFICATIONS_RUNBOOK.md`](PUSH_NOTIFICATIONS_RUNBOOK.md).

## 7. UI, contenido y personalización

Sobre el catálogo crudo se aplican tres capas que no cambian la fuente de verdad:

1. **Normalización:** interpreta vendor, product type, tags y overrides en
   facetas canónicas. No escribe Shopify.
2. **Contenido editorial/home:** puede leer Shopify/Loox y siempre conserva
   fallback incluido en la app.
3. **Recomendación local:** registra vistas, wishlist y bolsa en Drift y ordena
   el feed en el dispositivo.

`CatalogStore` mantiene getters síncronos para la UI y persistencia write-through
para wishlist, bolsa e interacciones:
[`lib/app/catalog_store.dart`](../lib/app/catalog_store.dart).

La personalización no altera productos, precios ni inventario; sólo decide orden
y explicación de tarjetas.

## 8. Configuración y secretos

### Flutter, valores públicos de compilación

Los nombres y ejemplos se documentan en
[`config/README.md`](../config/README.md) y
[`config/dart_defines.staging.json.example`](../config/dart_defines.staging.json.example).

El archivo real `config/dart_defines.staging.json` está ignorado por Git. Las API
keys Firebase de cliente y los app IDs son configuración pública de plataforma;
no conceden escritura porque Firestore Rules la niega.

### Vercel, valores privados de runtime

El backend requiere, entre otros:

- `SHOPIFY_SHOP_DOMAIN`
- `SHOPIFY_APP_CLIENT_ID`
- `SHOPIFY_APP_CLIENT_SECRET`
- `SHOPIFY_API_VERSION`
- `FIREBASE_SERVICE_ACCOUNT`
- `CRON_SECRET`

El secret y service account nunca deben pasar a Flutter, documentación, comandos
con historial o Git.

### Control preventivo

[`bin/check_no_secrets.sh`](../bin/check_no_secrets.sh) revisa tracked y untracked
no ignorados: exactamente lo que podría entrar con `git add --all`. Ante una
coincidencia imprime sólo el nombre del archivo, no su contenido.

## 9. Estado verificado y límites actuales

### Verificado

- Deployment Vercel del espejo en estado READY y alias estable activo.
- `GET /api` responde 405.
- `POST /api` sin firma responde 401, no 503.
- `GET /api/reconcile` sin bearer responde 401.
- App Catalog Mirror instalada con permisos de sólo lectura.
- Reconciliación protegida contra Shopify real.
- Igualdad exhaustiva 139 productos / 345 variantes / 386 imágenes.
- Firestore público para `products` y privado para ledger.
- Listener Flutter y persistencia Drift con 139/345 en simulador iOS.
- Guard de Firebase project ID desplegado.

### Implementado y probado localmente, pendiente de aceptación externa completa

- Entrega natural y redelivery de webhook para demostrar deduplicación real.
- Login Shopify extremo a extremo en un build/dispositivo con configuración de
  Customer Account válida.
- Servicio `accounts_orders` desplegado y sus webhooks de pedidos/compliance
  instalados en el entorno final.
- Vínculo explícito entre cuenta propia Monetta y Customer Shopify.
- Checkout real desde la app.
- Push notifications extremo a extremo en producción.

### Bloqueado externamente

- TTL remoto del ledger: Billing de Firebase devuelve `OR_BACR2_44`/billing
  disabled. La declaración permanece lista en `firestore.indexes.json`.

## 10. Pruebas que respaldan el diseño

Validación ejecutada antes del PR:

- `flutter analyze`: 0 issues.
- `flutter test --reporter compact`: 317/317.
- API Vercel: typecheck, build y 19/19 tests.
- Firebase Functions: typecheck, build y 13/13 tests.
- `accounts_orders`: typecheck, build y 42/42 tests.
- `catalog_monitor`: typecheck, build y 181/181 tests.
- escaneo de secretos: PASS.
- `git diff --check`: PASS.

Pruebas especialmente relevantes:

| Contrato | Prueba |
|---|---|
| HMAC, mapper y payload webhook | [`server/catalog/*.test.ts`](../server/catalog/) |
| Protección de `/api/reconcile` | [`reconcileRoute.test.ts`](../server/catalog/reconcileRoute.test.ts) |
| Snapshot válido/vacío/inválido y reconexión | [`realtime_catalog_repository_test.dart`](../test/data/repositories/realtime_catalog_repository_test.dart) |
| Autoridad Firestore vs delta | [`catalog_write_coordinator_test.dart`](../test/data/repositories/catalog_write_coordinator_test.dart) |
| Estado `CatalogStore` y fallback | [`catalog_store_realtime_test.dart`](../test/app/catalog_store_realtime_test.dart) |
| Migración v1 → GIDs | [`database_test.dart`](../test/data/local/database_test.dart) |
| OAuth session, refresh y merge local | [`customer_session_repository_test.dart`](../test/data/customer_auth/customer_session_repository_test.dart) |
| Verificación server-side del Customer token | [`customerTokenVerifier.test.ts`](../services/accounts_orders/test/customerTokenVerifier.test.ts) |
| Registro/login y autorización de pedidos | [`api.test.ts`](../services/accounts_orders/test/api.test.ts) |
| Idempotencia y rutas webhook | [`webhookRoutes.test.ts`](../services/accounts_orders/test/webhookRoutes.test.ts) |

## 11. Diagnóstico por síntoma

### La app muestra catálogo viejo

1. Revisar `CatalogStore.realtimeStatus`.
2. Confirmar que el build tiene `FIRESTORE_CATALOG_ENABLED=true` y opciones
   Firebase staging.
3. Comprobar que Firestore contiene el producto con ruta legacy correcta.
4. Revisar logs del webhook por topic/webhookId sin imprimir payloads.
5. Ejecutar una reconciliación protegida única si se sospecha entrega perdida.
6. Comparar Shopify Admin GraphQL con Firestore; no “arreglar” Drift manualmente.

### Firestore se vacía o trae un documento mal formado

La app debe conservar el catálogo anterior y marcar `empty` o `invalid`. Si lo
borra, se violó el contrato de
`RealtimeCatalogRepository.applySnapshot`/`CatalogCacheStore.replaceProducts`.

### El login Shopify parece correcto pero “Mis pedidos” falla

1. Confirmar que la cuenta local tiene `authProvider=shopify` y un
   `shopifyCustomerId` GID.
2. Forzar `accessTokenFor` para refresh silencioso.
3. Verificar que `accounts_orders` esté desplegado/configurado.
4. Confirmar que el backend pueda descubrir Customer Account API.
5. Confirmar webhooks de pedidos y filas `orders_mirror` para ese customer.

### El login Monetta funciona pero no aparecen pedidos Shopify

Es el comportamiento esperado si `app_accounts.shopify_customer_id` es null. No
se debe vincular automáticamente por email. Hace falta implementar y autorizar un
flujo explícito de enlace de identidad.

## 12. Mapa de código esencial

| Área | Archivo principal |
|---|---|
| Webhook de catálogo | [`api/index.ts`](../api/index.ts) |
| Reconciliación | [`api/reconcile.ts`](../api/reconcile.ts) |
| Cliente Admin Shopify | [`server/catalog/shopifyAdmin.ts`](../server/catalog/shopifyAdmin.ts) |
| Mapper Firestore | [`server/catalog/catalog.ts`](../server/catalog/catalog.ts) |
| Guard Firebase Admin | [`server/catalog/firebaseAdmin.ts`](../server/catalog/firebaseAdmin.ts) |
| Rules/TTL | [`firestore.rules`](../firestore.rules), [`firestore.indexes.json`](../firestore.indexes.json) |
| Listener Firestore | [`lib/data/firestore/firestore_catalog_source.dart`](../lib/data/firestore/firestore_catalog_source.dart) |
| Validación realtime | [`lib/data/repositories/realtime_catalog_repository.dart`](../lib/data/repositories/realtime_catalog_repository.dart) |
| Política de escritores | [`lib/data/repositories/catalog_write_coordinator.dart`](../lib/data/repositories/catalog_write_coordinator.dart) |
| Estado Flutter | [`lib/app/catalog_store.dart`](../lib/app/catalog_store.dart) |
| Caché Drift | [`lib/data/local/catalog_cache_store.dart`](../lib/data/local/catalog_cache_store.dart) |
| OAuth/PKCE | [`lib/data/customer_auth/customer_auth_gateway.dart`](../lib/data/customer_auth/customer_auth_gateway.dart) |
| Identidad Shopify | [`lib/data/customer_auth/customer_identity.dart`](../lib/data/customer_auth/customer_identity.dart) |
| Sesión Shopify | [`lib/data/customer_auth/customer_session_repository.dart`](../lib/data/customer_auth/customer_session_repository.dart) |
| Sesión Monetta | [`lib/data/accounts_orders/system_account_session_repository.dart`](../lib/data/accounts_orders/system_account_session_repository.dart) |
| Controlador de cuenta | [`lib/app/account_controller.dart`](../lib/app/account_controller.dart) |
| API cuentas/pedidos | [`services/accounts_orders/src/api/server.ts`](../services/accounts_orders/src/api/server.ts) |
| Webhooks de pedidos | [`services/accounts_orders/src/webhooks/handlers.ts`](../services/accounts_orders/src/webhooks/handlers.ts) |

## 13. Regla operativa final

Para actualizar productos, precios, imágenes o inventario se modifica Shopify,
no Firestore, Drift ni el asset. Firestore y Drift son proyecciones automáticas.

Para autenticar a una persona como cliente Shopify se usa Customer Account API,
no una coincidencia local de correo. Una cuenta propia Monetta sólo comparte
pedidos cuando existe un vínculo Shopify explícito y verificable.

Esas dos reglas mantienen al sistema coherente: Shopify continúa siendo dueño de
la verdad comercial y de identidad; Monetta conserva copias seguras, rápidas y
reparables para ofrecer una experiencia nativa.
