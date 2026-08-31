# Runbook de notificaciones push

La implementación permanece apagada por defecto. Firebase sólo transporta el
mensaje; `accounts_orders` calcula la audiencia desde consentimiento, alertas
explícitas y el perfil compacto que el teléfono decide sincronizar. Los eventos
detallados de navegación nunca salen de Drift.

## 1. Infraestructura externa

Crear proyectos Firebase separados para staging y producción, registrar los
bundle/application IDs de cada ambiente y:

1. habilitar Cloud Messaging y configurar la llave APNs de la cuenta del negocio;
2. habilitar App Check con Play Integrity en Android y App Attest/DeviceCheck en iOS;
3. crear una service account restringida al envío FCM y verificación App Check;
4. conservar su JSON sólo como secretos del backend, nunca en Flutter.

Para desarrollo se puede compilar con `FIREBASE_APP_CHECK_DEBUG=true`, registrar
el token debug que imprime Firebase y nunca usar ese proveedor en release.

## 2. Backend `accounts_orders`

Aplicar migraciones y configurar:

```text
NOTIFICATIONS_ENABLED=true
FIREBASE_PROJECT_ID=...
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...          # una línea con secuencias literales \n
PUSH_TOKEN_ENCRYPTION_SECRET=...  # 32+ caracteres aleatorios
INTERNAL_CATALOG_EVENT_SECRET=... # mismo valor que catalog_monitor
OWNER_ADMIN_EMAILS=duena@ejemplo.com
OWNER_SHOPIFY_CUSTOMER_IDS=...
```

Ejecutar dos procesos desde la misma imagen:

```bash
node dist/api/server.js
node dist/engagement/worker.js
```

En Fly, `fly.toml` define los grupos `app` y `worker`; provisionar uno de cada
uno con `fly scale count app=1 worker=1`. En local, `docker-compose.yml` contiene
el servicio `notification-worker`; se debe cambiar su switch a `true` y pasarle
los secretos antes de iniciarlo.

## 3. Flutter

Compilar cada flavor con un archivo no versionado de dart-defines:

```text
NOTIFICATIONS_ENABLED=true
ACCOUNTS_ORDERS_BASE_URL=https://accounts.example.com
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_PROJECT_ID=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_STORAGE_BUCKET=...
NOTIFICATIONS_TIMEZONE=America/Monterrey
```

El API key y los identificadores Firebase son configuración pública del cliente;
la clave privada de la service account no debe aparecer aquí. iOS ya declara
`aps-environment` y `remote-notification`; el perfil de firma debe incluir la
capacidad Push Notifications. Android ya declara permiso, canales, receptores de
recordatorios y desugaring.

La app no muestra el prompt al arrancar. Aparece sólo cuando la persona guarda
una preferencia activa o toca `AVÍSAME CUANDO VUELVA`.

## 4. Eventos de catálogo

`accounts_orders` recibe `products/create` y `products/update` firmados por
Shopify. Después de desplegar las configuraciones de `shopify/`, reinstalar o
actualizar la app de Shopify para aceptar `read_products` y registrar las nuevas
suscripciones.

Para fuentes externas, configurar el monitor:

```text
NOTIFICATION_EVENTS_URL=https://accounts.example.com/internal/catalog-events
NOTIFICATION_EVENTS_SECRET=... # igual al backend, 32+ caracteres
```

Los cambios se insertan en `notification_event_outbox` dentro de la misma
transacción que el producto. El monitor firma cada intento con HMAC y reintenta
con backoff; `accounts_orders` deduplica por `eventId`.

## 5. Activación gradual

1. Mantener todas las reglas automáticas apagadas.
2. Completar el onboarding en un dispositivo staging y aceptar el permiso
   nativo de notificaciones.
3. En el panel `Avisos`, crear un borrador, revisar el conteo y enviar una prueba.
4. Confirmar ruta al producto, horario silencioso, apertura y token inválido.
5. Activar primero `restock`; simular agotado → disponible en Shopify.
6. Activar baja de precio y nueva llegada después de revisar audiencias.
7. Vigilar cola, fallos y aperturas en el panel antes de producción.

No se considera exitosa una prueba donde FCM solamente acepta el mensaje: se
debe ver en un dispositivo físico iOS y Android y abrir la ruta interna esperada.
