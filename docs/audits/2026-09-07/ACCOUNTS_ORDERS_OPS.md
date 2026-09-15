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

## PR7 R4 recovery update (supersedes the five-minute claim policy)

Delivery recovery uses **HTTP retries**, not an unimplemented inbox worker.
`tryClaim=false` means completed only. A live concurrent claim raises
`WebhookBusyError`; the route returns **503** with `Retry-After: 5`. No 200 is
sent before effects and the completion record finish successfully.

A transaction-scoped PostgreSQL advisory lock owns each webhook ID. A slow live
worker is not overtaken by a timer. Process/connection loss rolls back the claim
transaction and releases the lock; the next signed delivery can recover at once.
The former durable `processing` rows are reclaimable when there is no current
lock, without waiting five minutes. A dedicated claim pool (maximum four) keeps
capacity in the effects pool, including during bursts. Transaction pooling is
supported because an open transaction pins its backend connection. Do not set
an idle-in-transaction timeout shorter than the legitimate maximum handler work.

Completed and failed rows persist on commit. In-progress claim writes remain
uncommitted; inspecting `webhook_events.status` alone is not a live-worker monitor.
Use request errors/latency and PostgreSQL lock activity. Effects must retain
business-key idempotency: unique Shopify order upserts, ordered update guards,
privacy webhook keys, and catalog event/outbox deduplication. After a crash
between effect commit and acknowledgement, replay may repeat an idempotent write.
This is at-least-once delivery with idempotent effects, not a distributed exactly-
once transaction. A disconnected old claimant cannot commit completion through
its dead connection. Conflicting payload hash/shop for an existing delivery is
rejected rather than acknowledged.

Recovery drill: signed duplicate while processing -> 503; terminate the claim
connection -> deliver again; verify one mirrored order and completed row; replay
again -> 200 with no new row. The disposable PostgreSQL tests also check effect
failure, stale order events, and eight deliveries with a one-connection effects
pool. Keep HMAC and exact configured shop checks enabled.

If Shopify's delivery retries are exhausted, reconcile the failed/missing event
with the authorized development/Admin source and replay the original signed
payload through the normal path. Do not mark inbox rows completed manually.
No payload is retained as a durable replay queue in this design. Monitor failures
promptly and keep an operator recovery procedure; do not promise unattended
recovery after the upstream retry window has ended.

Rollout/rollback: no new server migration is needed; schema 010 remains readable.
Drain/stop old workers before installing this locking implementation because old
five-minute claims do not participate in the new locks. Never run mixed versions.
Rolling back reintroduces the busy-ACK defect and is not an acceptable recovery
for interrupted events. Reconcile in-flight deliveries before any rollback.
