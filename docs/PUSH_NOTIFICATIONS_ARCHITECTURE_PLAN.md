# Plan arquitectónico de notificaciones y personalización

**Estado:** implementado en el repositorio; apagado por configuración hasta
completar credenciales y pruebas físicas de staging

**Fecha:** 25 de agosto de 2026

La infraestructura, APIs, worker, App Check, consentimiento Flutter, perfil
resumido, “Avísame”, panel del dueño, webhooks de Shopify y outbox del monitor
ya están construidos. La activación externa se documenta en
`docs/PUSH_NOTIFICATIONS_RUNBOOK.md`.

**Alcance:** Flutter iOS/Android, `services/accounts_orders`, panel del dueño,
Shopify y `services/catalog_monitor`

## 1. Resultado esperado

El dueño podrá crear, probar, programar y medir notificaciones desde el panel
administrativo de Monetta. Nunca elegirá tokens ni clientes uno por uno: elegirá
un segmento o una automatización y el backend resolverá los dispositivos
elegibles.

La personalización conservará la postura de privacidad que ya tiene el proyecto:

- El historial crudo de impresiones, vistas, búsquedas y permanencia seguirá en
  Drift, dentro del teléfono.
- El dispositivo sincronizará solamente un perfil reducido y revocable:
  afinidades principales, banda de precio, nivel de intención y vigencia.
- Las acciones explícitas que necesitan seguimiento exacto, como **Avísame
  cuando vuelva**, sí registrarán el identificador del producto en el backend.
- Firebase Cloud Messaging (FCM) será el transporte. Postgres y el servicio de
  Monetta serán la fuente de verdad de consentimiento, campañas, segmentación,
  envíos y auditoría.

El objetivo operativo es este:

```text
Navegación local ──▶ TasteProfile local ──▶ resumen de afinidad ──┐
                                                                  │
Favorito / Avísame ──▶ suscripción exacta a producto ─────────────┤
                                                                  ▼
Panel del dueño ──▶ campaña/segmento ──▶ Engagement Orchestrator
Shopify/monitor ──▶ evento de catálogo ──▶        │
                                                   ▼
                                        cola Postgres + worker
                                                   │
                                                   ▼
                                                FCM/APNs
                                                   │
                                                   ▼
                                    app ──▶ producto ──▶ atribución
```

## 2. Estado actual y brechas

La base existente es aprovechable:

- `lib/reco/events.dart` y `lib/reco/profile.dart` ya modelan señales y generan
  `TasteProfile` con decaimiento temporal.
- `lib/data/local/tables.dart` guarda interacciones y dispositivos localmente.
- `services/accounts_orders` ya contiene cuentas, sesiones, clientes, pedidos,
  cumplimiento de redacción y una tabla de tokens FCM.
- `lib/data/shopify/cart_attribution.dart` ya admite `campaignId`.
- El panel nativo y su contrato administrativo existen como cliente y diseño.
- `catalog_monitor` ya compara snapshots completos y detecta cambios de precio,
  disponibilidad y productos nuevos.

Las brechas que impiden usar push en producción son:

1. Firebase no se inicializa en `main.dart` y no existen configuraciones de
   producción por flavor.
2. La app no solicita permiso, registra token, renueva token ni procesa mensajes
   en foreground/background/terminated.
3. `POST /push-tokens` ya deriva el cliente desde un bearer verificado en la
   implementación actual, pero sigue siendo un registro limitado a cuentas Shopify:
   falta el ciclo Flutter, soporte invitado, consentimiento y renovación.
4. Las interacciones nunca salen del dispositivo; el backend no puede segmentar.
5. No hay consentimiento propio para finalidades de notificación.
6. No hay campañas, reglas, cola, worker FCM, métricas ni limpieza de tokens.
7. El panel actual no tiene un módulo de notificaciones y el servicio
   administrativo documentado todavía no está implementado.
8. Shopify no publica todavía webhooks de productos/inventario hacia este
   backend, y el monitor no emite eventos durables de sus diffs.
9. El checkout actual aún no crea un Shopify Cart real. La apertura y el
   `add_to_cart` podrán medirse primero, pero la supresión por compra y la
   conversión final requieren completar esa integración o correlacionar el
   pedido de WhatsApp con la atribución existente.

## 3. Decisiones arquitectónicas

### D1. `engagement` será un módulo de `accounts_orders`

La primera versión no será un microservicio nuevo. El contexto `engagement`
vivirá dentro de `services/accounts_orders` porque allí ya están la identidad,
las sesiones, los dispositivos, los pedidos y los webhooks de privacidad.

Se separará internamente mediante puertos (`MessagingProvider`, repositorios,
reloj y cola) y se ejecutará con dos procesos:

- `api`: registro de dispositivo, preferencias, panel y recepción de eventos.
- `notification-worker`: evaluación, envío, reintentos y limpieza.

Esto evita otra base de datos y coordinación distribuida antes de tener volumen.
El módulo podrá extraerse sin cambiar sus contratos si la carga futura lo exige.

### D2. FCM no decidirá la audiencia

No se usarán Firebase Analytics Audiences ni topics de FCM como fuente de verdad
de segmentación. El evaluador de Monetta seleccionará registros individuales y
el worker enviará a su `registrationId`.

Razones:

- permite auditar por qué un dispositivo fue elegible;
- respeta preferencias y límites de frecuencia propios;
- permite excluir compras, productos agotados y perfiles vencidos;
- evita entregar a Firebase nombres de segmentos de comportamiento;
- topics están optimizados para difusión y throughput, no para personalización
  precisa o entrega rápida a instancias individuales.

Un topic general como `announcements_es_mx` podría añadirse después para avisos
públicos no personalizados, pero no es necesario para el lanzamiento.

### D3. El dispositivo es la unidad primaria de selección

La navegación actual es device-scoped. Por eso el perfil y su endpoint de push
pertenecen al `deviceId`, no al correo ni al `shopifyCustomerId`.

- Invitado: `deviceId → endpoint FCM → perfil`.
- Con sesión: el servidor deriva `appAccountId` desde la sesión y vincula el
  mismo dispositivo; nunca acepta un id de cliente declarado por el body.
- Vinculado a Shopify: `shopifyCustomerId` se agrega como identidad secundaria.
- Varias instalaciones de una misma cuenta: una campaña de marketing usa sólo
  el endpoint activo visto más recientemente para evitar duplicados. Una alerta
  creada explícitamente en un dispositivo vuelve a ese dispositivo.

### D4. Datos crudos locales; resumen mínimo en servidor

El teléfono seguirá calculando `TasteProfile`. Cada cambio material, o como
máximo una vez al día, enviará una instantánea como:

```json
{
  "profileVersion": 18,
  "generatedAt": "2026-08-25T17:10:00Z",
  "topBrands": [
    {"key": "coach", "score": 82},
    {"key": "guess", "score": 56}
  ],
  "topCategories": [{"key": "crossbody", "score": 74}],
  "priceBand": "2000_4000_mxn",
  "intentTier": "high",
  "signalCountBucket": "10_24"
}
```

No se enviarán búsquedas textuales, secuencias de páginas, permanencia exacta ni
listas de productos vistos. Las puntuaciones se cuantizan a enteros y sólo se
conservan las tres marcas y dos categorías más relevantes. El backend descartará
perfiles más viejos que la versión guardada y dejará de usarlos después de 30
días sin actualización.

### D5. Cola durable en Postgres

Campañas, receptores y entregas se materializarán transaccionalmente en
Postgres. El worker reclamará filas con bloqueo (`FOR UPDATE SKIP LOCKED`). No se
introducirán Redis, Kafka ni tareas en memoria.

La garantía será **al menos una vez** entre base y proveedor, con deduplicación
por `UNIQUE(campaign_id, push_endpoint_id)`. El cliente también deduplicará
interacciones por `deliveryId`.

### D6. Recordatorios puramente personales serán locales

El recordatorio de carrito y, opcionalmente, “continúa donde te quedaste” se
programarán como notificaciones locales en el dispositivo y se cancelarán al
vaciar/comprar. No es necesario subir el carrito o el historial para producirlos.
El dueño sólo podrá habilitar la regla y su plantilla; no verá esa actividad.

Restock, baja de precio, productos nuevos y campañas del dueño sí usarán push
remoto porque dependen de cambios del catálogo o de una decisión central.

## 4. Componentes

### 4.1 Flutter: `data/notifications`

Responsabilidades:

- inicializar Firebase por flavor;
- pedir permiso en contexto, no al primer frame;
- obtener y renovar el identificador/token de registro;
- registrar la instalación y reportar estado de permiso;
- sincronizar preferencias, perfil reducido y alertas de producto;
- manejar foreground, background y app terminada;
- validar el payload y traducirlo a navegación interna;
- registrar apertura/conversión sin bloquear la experiencia;
- programar/cancelar recordatorios locales.

Clases propuestas:

```text
NotificationBootstrapper
PushPermissionGateway
PushRegistrationRepository
InterestProfileSync
ProductAlertRepository
NotificationRouter
NotificationInteractionReporter
LocalReminderScheduler
```

`NotificationController` coordinará estas piezas desde `lib/app/`, sin mezclar
SDKs de Firebase con widgets ni con `CatalogStore`.

### 4.2 Backend: `services/accounts_orders/src/engagement`

```text
engagement/
  domain/
    campaigns.ts
    consent.ts
    segments.ts
    deliveries.ts
  application/
    registerDevice.ts
    syncInterestProfile.ts
    previewAudience.ts
    scheduleCampaign.ts
    processCatalogEvent.ts
    dispatchDeliveries.ts
  infrastructure/
    firebaseMessagingProvider.ts
    pg*.ts
  api/
    deviceRoutes.ts
    adminNotificationRoutes.ts
    internalCatalogRoutes.ts
  worker.ts
```

`MessagingProvider` tendrá al menos:

```ts
interface MessagingProvider {
  validate(message: OutboundMessage): Promise<void>;
  send(target: PushTarget, message: OutboundMessage): Promise<SendResult>;
}
```

Los tests usarán un fake; únicamente el adaptador de infraestructura conocerá
Firebase Admin SDK o FCM HTTP v1.

### 4.3 Panel del dueño

Se añadirá una pestaña **Notificaciones** con cuatro vistas:

1. **Resumen:** instalaciones activas, permisos, últimos envíos y fallos.
2. **Nueva campaña:** contenido, producto/colección, audiencia y horario.
3. **Automatizaciones:** restock, baja de precio, novedades y recordatorios.
4. **Resultados:** elegibles, aceptados por FCM, aperturas y conversiones.

El panel mostrará conteos agregados. No mostrará “Alexis vio este producto” ni
permitirá descargar perfiles individuales.

### 4.4 Entradas de catálogo

**Shopify propio**

- Agregar scopes mínimos `read_products` y `read_inventory` después de validar
  la tienda de staging.
- Suscribir `products/create`, `products/update` e
  `inventory_levels/update`.
- Reutilizar verificación HMAC y ledger idempotente de webhooks existente.
- Mantener un mapa servidor de producto/variante/inventory-item para resolver
  la transición `agotado → disponible`.

**Catálogo externo**

- Extender `snapshotDiff` para producir eventos `catalog.product.created`,
  `catalog.product.restocked` y `catalog.product.price_dropped` con antes/después.
- Sólo emitirlos después de un crawl completo y exitoso; una ejecución parcial
  nunca debe generar una falsa baja/restauración.
- Guardarlos en un outbox de la base de `catalog_monitor` y entregarlos a
  `/internal/catalog-events` con id, timestamp y firma HMAC.
- El receptor conserva `eventId` único para tolerar reintentos.

Las alertas de catálogo externo quedarán desactivadas inicialmente hasta
confirmar que el destino y la disponibilidad se pueden volver a validar justo
antes de enviar.

## 5. Modelo de datos servidor

Las siguientes tablas sustituyen gradualmente la tabla prototipo `push_tokens`.
La migración debe copiar datos válidos y conservar la tabla anterior durante
una versión de rollback.

### `device_installations`

```text
device_id                 PK
app_account_id            nullable FK
shopify_customer_id       nullable
device_credential_hash    nullable, para invitados
platform                  ios | android
locale                    ej. es-MX
timezone                  IANA
app_version
last_seen_at
created_at
disabled_at               nullable
```

### `push_endpoints`

```text
id                        UUID PK
device_id                 unique FK
provider                  fcm
registration_kind         token | fid
registration_id_ciphertext
registration_id_hash      unique, para igualdad sin descifrar
permission_state          not_determined | provisional | granted | denied
token_updated_at
last_success_at
failure_count
status                    active | stale | invalid | revoked
```

El identificador de FCM es un secreto operativo: se cifra de forma reversible,
se excluye de logs y nunca se devuelve al panel.

### `notification_consents`

```text
device_id
purpose                   product_alerts | personalized_offers | announcements
granted
policy_version
source                    settings | permission_prompt | product_alert
recorded_at
PRIMARY KEY (device_id, purpose)
```

El permiso del sistema operativo y el consentimiento de finalidad son estados
distintos. Tener permiso de iOS/Android no autoriza automáticamente campañas.

### `device_interest_profiles`

```text
device_id                 PK
profile_version
top_brands                JSONB
top_categories            JSONB
price_band                nullable
intent_tier
signal_count_bucket
generated_at
expires_at
```

### `product_alerts`

```text
id                        UUID PK
device_id
product_key               namespaced: shopify:<gid> | external:<source>:<id>
kind                      restock | price_drop
active
created_at
last_triggered_cycle      nullable
UNIQUE (device_id, product_key, kind)
```

### `notification_campaigns`

```text
id                        UUID PK
kind                      manual | restock | price_drop | new_arrival
status                    draft | scheduled | targeting | sending | complete | cancelled
title
body
image_url                 nullable
route                     JSONB validado
segment_definition        JSONB validado
scheduled_at              nullable
created_by
created_at
published_at              nullable
cancelled_at              nullable
```

### `notification_deliveries`

```text
id                        UUID PK
campaign_id
push_endpoint_id
eligibility_snapshot      JSONB sin PII
status                    queued | sending | accepted | retry | failed | invalid_token | suppressed
attempt_count
next_attempt_at
provider_message_id       nullable
provider_error_code       nullable
created_at
accepted_at               nullable
UNIQUE (campaign_id, push_endpoint_id)
```

`accepted` significa que FCM aceptó el mensaje; no se etiquetará como
“entregado” porque esa confirmación no existe de forma universal por instancia.

### `notification_interactions`

```text
delivery_id
event                     opened | product_viewed | add_to_cart | checkout_started | purchased
occurred_at
idempotency_key
PRIMARY KEY (delivery_id, event, idempotency_key)
```

### `automation_rules`, `catalog_events`, `admin_audit_events`

- `automation_rules`: estado, plantilla, umbrales, TTL y frequency caps.
- `catalog_events`: inbox idempotente de cambios Shopify/monitor.
- `admin_audit_events`: quién creó, probó, programó, canceló o cambió una regla.

## 6. Contratos HTTP

### 6.1 App/instalación

| Método | Ruta | Uso |
|---|---|---|
| `POST` | `/v1/device-installations` | Bootstrap protegido por App Check; devuelve credencial opaca de instalación invitada. |
| `PUT` | `/v1/device-installations/me/push-endpoint` | Alta/rotación/revocación del registro FCM y estado de permiso. |
| `PUT` | `/v1/device-installations/me/preferences` | Consentimientos y preferencias. |
| `PUT` | `/v1/device-installations/me/interest-profile` | Snapshot idempotente y versionado del perfil reducido. |
| `GET` | `/v1/notification-config` | Plantillas y demoras cacheables para recordatorios locales. |
| `POST` | `/v1/product-alerts` | Alta explícita de “Avísame”/baja de precio. |
| `DELETE` | `/v1/product-alerts/:id` | Cancelación de alerta. |
| `POST` | `/v1/notification-interactions` | Apertura y conversión con idempotency key. |

Una llamada autenticada con cuenta deriva identidad desde el bearer token. Una
llamada invitada usa la credencial opaca de instalación más App Check. App Check
reduce abuso, pero no sustituye la autorización del dueño o del usuario.

### 6.2 Panel

| Método | Ruta | Uso |
|---|---|---|
| `GET` | `/admin/notifications/overview` | Resumen agregado. |
| `POST` | `/admin/notification-campaigns` | Crear borrador. |
| `POST` | `/admin/notification-campaigns/:id/preview` | Conteo estimado y motivos de exclusión. |
| `POST` | `/admin/notification-campaigns/:id/test` | Enviar sólo al dispositivo actual del dueño. |
| `POST` | `/admin/notification-campaigns/:id/schedule` | Confirmar y programar/publicar. |
| `POST` | `/admin/notification-campaigns/:id/cancel` | Cancelar filas aún no enviadas. |
| `GET` | `/admin/notification-campaigns/:id/report` | Resultado agregado. |
| `GET/PATCH` | `/admin/notification-rules` | Automatizaciones y plantillas. |

Todos repiten autorización del dueño en servidor, usan `Idempotency-Key` en
mutaciones, tienen rate limit y escriben auditoría. La lista local de correos
autorizados sólo muestra la entrada; no concede permisos.

### 6.3 Eventos internos

`POST /internal/catalog-events` recibe:

```json
{
  "eventId": "uuid",
  "eventType": "catalog.product.restocked",
  "source": "external:coach_us",
  "productKey": "external:coach_us:abc",
  "occurredAt": "2026-08-25T18:00:00Z",
  "before": {"available": false, "price": 3200},
  "after": {"available": true, "price": 3200}
}
```

La firma incluye timestamp y digest del body; el receptor rechaza replay fuera
de ventana y deduplica `eventId`.

## 7. Segmentación y relevancia

El panel no enviará SQL ni expresiones libres. Usará una DSL cerrada que el
backend compila a consultas parametrizadas:

```json
{
  "all": [
    {"trait": "brand", "operator": "in", "values": ["coach"], "minimumScore": 60},
    {"trait": "lastSeen", "operator": "withinDays", "value": 30}
  ],
  "none": [
    {"trait": "purchasedProduct", "operator": "equals", "value": "shopify:123"}
  ]
}
```

El evaluador aplica siempre, aunque el dueño no los seleccione:

1. endpoint activo y perfil no vencido cuando la campaña es personalizada;
2. permiso del sistema y consentimiento para la finalidad;
3. producto disponible y destino válido;
4. exclusión de compradores cuando corresponda;
5. quiet hours según timezone;
6. límite global de marketing y cooldown por producto/campaña;
7. deduplicación entre dispositivos de la misma cuenta;
8. exclusión del dueño y cuentas de prueba salvo en “Enviar prueba”.

El MVP usará reglas comprensibles, no ML servidor:

| Señal | Uso |
|---|---|
| Afinidad de marca/categoría | Novedades y campañas editoriales. |
| `intentTier` | Evitar insistir a perfiles de señal débil. |
| Alerta explícita | Restock/baja de precio exacta. |
| Compra | Supresión y atribución. |
| Última actividad | Vigencia y reactivación. |

Los pesos locales actuales continúan produciendo el perfil. Se calibrarán con
CTR y conversión agregados después de tener suficiente tráfico; no se debe
introducir filtrado colaborativo en esta fase.

## 8. Flujos principales

### 8.1 Registro y permiso

1. La app arranca con recolección remota deshabilitada.
2. Tras un momento de valor —favorito, “Avísame” o primera sesión útil— explica
   el beneficio y pide permiso al sistema.
3. Si se concede, obtiene el registro FCM y crea/actualiza el endpoint.
4. Escucha rotaciones y vuelve a hacer `PUT` con timestamp.
5. En cada arranque relevante actualiza `last_seen_at` y el estado real de
   permiso. Si el usuario lo revoca, el endpoint queda `revoked`.

### 8.2 Campaña manual

1. El dueño crea borrador y selecciona producto/colección.
2. Elige segmento con controles cerrados.
3. `preview` devuelve conteo estimado, nunca PII.
4. `test` valida el payload con FCM y lo envía al dispositivo del dueño.
5. El dueño confirma y programa.
6. A la hora indicada, el backend reevalúa la audiencia y materializa filas de
   entrega. Ese snapshot queda auditado.
7. El worker aplica quiet hours/frequency cap y envía.
8. Resultados separan `elegible`, `aceptado por FCM`, `abierto` y `convertido`.

### 8.3 Restock

1. El cliente toca “Avísame”; se registra alerta exacta y consentimiento de
   producto.
2. Shopify o el monitor emite transición real `false → true`.
3. `processCatalogEvent` crea una campaña automática idempotente por
   `productKey + restockCycle`.
4. Se vuelve a comprobar stock justo antes de enviar.
5. Se envía a suscriptores activos, una vez por ciclo.
6. Si vuelve a agotarse y reingresa después, comienza otro ciclo.

### 8.4 Novedad personalizada

1. `products/create` o un diff completo genera `product.created`.
2. Sus facetas se comparan con perfiles vigentes.
3. Sólo se crea campaña si supera tamaño mínimo y score definido en la regla.
4. Se agrupan novedades cercanas en una sola notificación para evitar ráfagas.

### 8.5 Carrito abandonado local

1. Al agregar al carrito, la app programa recordatorio local si la preferencia
   está activa.
2. Al remover, comprar o iniciar checkout, lo cancela.
3. La plantilla y demora vienen de configuración remota/cacheada.
4. El backend no recibe los productos del carrito para este flujo.

## 9. Payload y navegación

Los campos `data` serán versionados y con rutas allowlisted; nunca se abrirá una
URL arbitraria recibida por push.

```json
{
  "schemaVersion": "1",
  "deliveryId": "uuid",
  "campaignId": "uuid",
  "type": "product",
  "productKey": "shopify:gid://shopify/Product/123",
  "source": "restock"
}
```

Tipos iniciales: `home`, `collection`, `product`, `wishlist` y `orders`.

- Foreground: banner in-app, sin duplicar la notificación del sistema.
- Background: `onMessageOpenedApp`.
- Terminada: `getInitialMessage`.
- Producto ya no disponible: fallback seguro a colección o inicio.
- Al abrir: guardar `campaignId` en la atribución de sesión existente para que
  carrito/pedido puedan relacionarse con la campaña.

## 10. Envío, reintentos y limpieza

- FCM se llama únicamente desde entorno confiable con credencial de mínimo
  privilegio; ningún secreto de envío entra al binario Flutter.
- Antes de publicar se usa validación del proveedor cuando esté disponible.
- 4xx no transitorios fallan sin reintento; registros inválidos se desactivan.
- `429` respeta `Retry-After`; 5xx/timeouts usan backoff exponencial con jitter.
- Cada regla define TTL. Una oferta expirada no se reintenta indefinidamente.
- Se distribuyen lotes en el tiempo para evitar ráfagas de tráfico.
- Un job diario marca registros viejos como `stale` y elimina inválidos según
  la política de retención.
- Las credenciales y registros FCM nunca aparecen en logs, auditoría o errores
  de UI.

## 11. Privacidad, seguridad y bajas

Consentimientos independientes:

- `product_alerts`: solicitado explícitamente por el usuario;
- `personalized_offers`: usa perfil reducido;
- `announcements`: campañas generales.

Rechazar personalización remota no desactiva la recomendación local. El cliente
podrá borrar su perfil local, desactivar cada finalidad y abrir la configuración
del sistema operativo.

Controles obligatorios:

- Firebase App Check en bootstrap/sync invitado y rate limit por IP/dispositivo.
- Bearer de cuenta para vinculación; el body no declara quién es el usuario.
- RBAC real de dueño en servidor y auditoría de cada mutación.
- cifrado de registros FCM y secretos sólo en el proceso worker;
- rutas y contenido validados, longitudes limitadas e imágenes HTTPS allowlisted;
- logs sin correo, token, búsqueda, perfil completo ni payload privado;
- `customers/redact`, eliminación de cuenta y revocación borran endpoints,
  perfiles, alertas e interacciones identificables;
- exportación de datos incluye consentimientos y alertas vigentes;
- revisión legal de aviso de privacidad y conservación antes de producción.

`customers_mirror.marketing_consent` no se usará como único consentimiento de
push: actualmente no se actualiza y además representa otro canal/finalidad. Se
podrá consultar como señal adicional cuando el webhook correspondiente exista.

## 12. Observabilidad y métricas

Métricas técnicas:

- instalaciones/endpoint activos por plataforma y versión;
- rotaciones, stale e invalidaciones;
- cola pendiente y antigüedad de la fila más vieja;
- accepted/retry/failed/suppressed por campaña y error;
- latencia catálogo → campaña → aceptación FCM;
- fallos de deep link y payload desconocido.

Métricas de negocio:

- opt-in y revocación por finalidad;
- audiencia prevista vs. elegible final;
- aperturas únicas;
- vista de producto, carrito, checkout y compra atribuidos;
- frecuencia y bajas posteriores a campaña.

Alertas operativas:

- worker sin procesar durante 5 minutos;
- aumento de errores de autenticación FCM/APNs;
- invalidación anormal de registros después de una release;
- webhook de inventario sin actividad o outbox externo detenido;
- campaña bloqueada en `targeting`/`sending`.

## 13. Plan de implementación

### Fase 0 — propiedad, decisiones y contratos

- Crear proyecto Firebase de staging y producción bajo una organización/cuenta
  propiedad del negocio; registrar apps iOS/Android por flavor.
- Configurar APNs, Android, App Check y secretos del servidor.
- Aprobar textos de permiso, preferencias, retención y límites de frecuencia.
- Congelar contratos HTTP, payload v1 y migraciones.

**Aceptación:** el dueño tiene acceso administrativo; ningún activo crítico queda
en una cuenta personal del desarrollador; threat model y rollback revisados.

### Fase 1 — push técnico de extremo a extremo

- Inicialización Firebase por flavor y adición de `firebase_app_check`; los
  archivos generados/configurados se separan entre staging y producción.
- Permiso contextual, registro/rotación y recepción en tres estados de app.
- Evolucionar `POST /push-tokens` hacia el recurso de instalación, conservando
  la resolución autenticada de cliente y agregando el flujo invitado con App
  Check.
- Crear `device_installations`, `push_endpoints`, consentimientos y preferencias.
- Implementar `MessagingProvider`, worker y envío de prueba al dueño.

**Aceptación:** un dispositivo iOS y uno Android reciben una prueba, abren la ruta
correcta, rotan token y dejan de recibir tras revocación.

### Fase 2 — campañas manuales y panel

- Tab de notificaciones, composer, preview, test, schedule/cancel y reporte.
- Campañas, entregas, auditoría, frequency cap, quiet hours y reintentos.
- Atribución de apertura hasta carrito/checkout/pedido.
- Documentar como dependencia separada la conversión a compra cuando el
  checkout real de Shopify todavía no esté habilitado.

**Aceptación:** el dueño publica sin usar Firebase Console; no puede enviar sin
confirmación, consentimiento ni auditoría; el reporte no confunde aceptación
FCM con entrega.

### Fase 3 — personalización privada

- Instrumentar todas las señales previstas localmente.
- Derivar y sincronizar el snapshot reducido, versionado y con expiración.
- Implementar DSL, evaluador, preview y supresiones.
- Controles de usuario para personalización remota y borrado.

**Aceptación:** un perfil Coach/crossbody entra en esa audiencia sin que el
backend reciba productos vistos ni búsquedas; revocar excluye en el siguiente
envío.

### Fase 4 — alertas automáticas de catálogo

- Botón “Avísame”, `product_alerts` y ciclo de restock.
- Webhooks Shopify de productos/inventario y resolución de variantes.
- Outbox firmado desde `catalog_monitor`.
- Revalidación de stock y agrupación de novedades.

**Aceptación:** una transición real de staging genera exactamente una alerta; un
reintento de webhook/diff no duplica; un crawl parcial no genera nada.

### Fase 5 — recordatorios locales y optimización

- Agregar un adaptador de notificaciones locales, carrito local, plantillas
  configurables y cancelación correcta.
- Métricas agregadas, cohortes y calibración de thresholds/frequency caps.
- Experimentos sólo después de volumen suficiente y consentimiento revisado.

**Aceptación:** el carrito no sale del dispositivo; comprar o vaciar cancela el
recordatorio; las métricas permiten medir conversión sin exponer navegación.

### Gate de lanzamiento

Para afirmar que Monetta ofrece notificaciones personalizadas deben estar
completas las fases 0–3. Para promocionar “Avísame cuando vuelva”, también debe
estar completa la fase 4. La fase 5 puede desplegarse después.

## 14. Estrategia de pruebas

- **Unidad:** DSL, score/threshold, consentimientos, quiet hours, caps,
  deduplicación, TTL, restock cycles y payload validation.
- **API:** cuenta vs. dispositivo invitado, App Check, owner RBAC, idempotency,
  rate limits y redacción.
- **Worker:** fake de FCM para 4xx/429/5xx, jitter, stale/invalid y concurrencia.
- **Contrato:** payload Flutter/backend y evento monitor/backend.
- **Integración:** Postgres real efímero, webhook Shopify firmado, outbox y dos
  workers compitiendo por la misma cola.
- **Dispositivo:** iOS/Android en foreground/background/terminated, permiso
  denegado, reinstalación, cambio de timezone, actualización y deep links.
- **E2E staging:** campaña manual, restock, apertura, carrito y pedido atribuido.

No se prueba producción con un broadcast. Toda primera prueba de una release se
limita a dispositivos allowlisted del equipo/dueño.

## 15. Operación y entrega al dueño

Activos que deben pertenecer al negocio:

- organización/proyecto Firebase de staging y producción;
- Apple Developer/APNs y Google Play Console;
- Shopify app, tienda y scopes;
- Fly/Neon, dominio, alertas y backups;
- cuenta de servicio/identidad de workload para el worker.

Runbooks mínimos:

1. enviar prueba sin publicar;
2. detener/cancelar campaña;
3. rotar credencial FCM/APNs;
4. atender cola detenida o cuota `429`;
5. desactivar automatización de inventario;
6. borrar/exportar datos de un cliente;
7. rollback de app/backend conservando registros.

El dueño opera únicamente el panel de Monetta. Firebase Console queda como
herramienta técnica de diagnóstico y administración, no como interfaz diaria.

## 16. Archivos previstos

```text
lib/
  app/notification_controller.dart
  data/notifications/*
  domain/notification_*.dart
  features/admin/notifications/*
  features/account/notification_preferences/*

services/accounts_orders/
  src/engagement/*
  src/db/migrations/004_engagement.sql
  src/db/migrations/005_campaigns.sql
  test/engagement/*

services/catalog_monitor/
  src/events/catalogEventOutbox.ts
  src/events/catalogEventDelivery.ts
  src/db/migrations/*_catalog_event_outbox.sql

shopify/
  shopify.app.staging.toml
  shopify.app.production.toml
```

Los números de migración son orientativos: antes de implementar se debe volver
a listar el directorio para evitar colisiones con trabajo concurrente.

## 17. Referencias técnicas

- [Entorno servidor y FCM](https://firebase.google.com/docs/cloud-messaging/server-environment)
- [Envío con FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api)
- [Gestión y frescura de registros](https://firebase.google.com/docs/cloud-messaging/manage-tokens)
- [Recepción de mensajes en Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [Verificación de App Check en backend propio](https://firebase.google.com/docs/app-check/custom-resource-backend)
- [Escalamiento y reintentos de FCM](https://firebase.google.com/docs/cloud-messaging/scale-fcm)
- [Permiso de notificaciones en Apple](https://developer.apple.com/documentation/UserNotifications/asking-permission-to-use-notifications)
- [Topics de webhooks Shopify](https://shopify.dev/docs/api/admin-graphql/latest/enums/WebhookSubscriptionTopic)
