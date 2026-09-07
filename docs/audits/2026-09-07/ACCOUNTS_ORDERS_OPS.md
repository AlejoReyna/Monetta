# accounts_orders — readiness, privacy, backup, rollback (F29)

## Readiness

- `GET /healthz` / `GET /livez`: proceso vivo (no prueba PostgreSQL).
- `GET /readyz`: falla si el check de DB (`SELECT 1`) no responde. Usar este endpoint en load balancers / deploy gates.

## Privacy requests

Migraciones `010` + `012` crean `privacy_requests` con estados `open|fulfilled|cancelled`, `export_artifact_ref` y `operator`.

- `customers/data_request` → abre fila `open` (no exporta PII en el webhook).
- `customers/redact` → borra espejo/engagement/tokens y registra fila `fulfilled` de evidencia.
- Owner API:
  - `GET /admin/privacy-requests` — cola abierta
  - `POST /admin/privacy-requests/:webhookId/fulfill` body `{ "notes"?, "exportArtifactRef"? }`

**Export:** el operador genera el paquete fuera de banda (ticket / object storage), guarda sólo una referencia en `export_artifact_ref`, nunca el payload PII en la fila. Retención: datos de pedidos/cuenta viven en Shopify + espejo PG + Drift local; redact del webhook no borra caches en dispositivos.

## Webhook lag / errores

Inbox durable (`webhook_events` pending/processing/completed/failed). Entregas fallidas se reintentan; completed no se reaplican. Alertar sobre:

- crecimiento de `status=failed` o `pending` viejos
- `/readyz` != 200
- cola de privacy `open` > umbral de días (Shopify: actuar data_request en ≤30 días)

## Backup / restore (ensayo)

1. `pg_dump` lógico del DB de staging a archivo cifrado fuera del host.
2. Restaurar en DB desechable.
3. Verificar conteos de `orders_mirror`, `privacy_requests`, `webhook_events`, `admin_principals`.
4. Apuntar un proceso local a esa DB y confirmar `/readyz` + una lectura admin.

No tratar un log de webhook como prueba de cumplimiento.

## Rollback

1. Revertir el release del servicio (`accounts_orders` image / Fly release).
2. Migraciones SQL son additive (`IF NOT EXISTS` / `ADD COLUMN IF NOT EXISTS`); no borrar tablas en rollback automático.
3. Si una migración nueva falló a medias, no marcar el deploy sano hasta `/readyz` verde y smoke de webhooks HMAC.
4. Feature flags: `NOTIFICATIONS_ENABLED`, `LEGACY_ACCOUNT_REGISTRATION_ENABLED`, writes admin — apagar antes de rollback de esquema si el binario viejo no entiende columnas nuevas (columnas nullable son seguras).
