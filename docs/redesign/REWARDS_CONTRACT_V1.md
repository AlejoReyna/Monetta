# Contrato Rewards V1 — integración para E y A–D

Versión: `1.0.0` · Fecha: 2026-09-14 · Propietario: paquete F.
Estado: implementado y verificado localmente; **canje deshabilitado tras
bandera** (`REWARDS_REDEMPTION_ENABLED=false`). No declarar listo para
producción (ver §8).

Este documento es el contrato. El código que lo cumple:

- Backend: `services/accounts_orders/src/rewards/` + migración `013_rewards.sql`.
- Reglas puras: `src/rewards/rules.ts` (`eligibleSubtotal`, `maxRedeemableCents`,
  `estimatedEarnCents`, `expiryFromRelease`, `detectWholesale`).
- Flutter: `lib/features/rewards/` (`rewards_api.dart`, `rewards_models.dart`,
  `rewards_components.dart`, `rewards_account.dart`, `rewards_balance_card.dart`).

## 1. Reglas confirmadas (única fuente para UI)

- Menudeo genera **3%** sobre la base elegible; **pendiente** hasta entrega
  confirmada; después **disponible**.
- Canje máximo: **20%** del subtotal elegible de la siguiente compra.
- Vigencia: **12 meses calendario** desde liberación (fin de mes recortado).
- Primera compra +$50 (mínimo sin definir), reseña +$20, referido +$50 por
  parte: **deshabilitados** hasta cerrar mínimos/autoridad (§8).
- **Mayoreo no genera** en V1. Uso en mayoreo sin definir → canje bloqueado
  en carritos de mayoreo (`wholesale_redeem_undecided`).
- Estados: `pending`, `available`, `used` (`utilizado` en UI), `expired`,
  `reversed`. Canjes: `quoted`, `reserved`, `provisioning`, `applied`,
  `order_committed`, `settled`, `releasing`, `released`,
  `reconciliation_required`.
- Presentación: “Tienes $184 Monetta disponibles”. Importes en **centavos
  enteros**; el cliente nunca calcula saldo autoritativo.

## 2. Base y transporte

- Base: `ACCOUNTS_ORDERS_BASE_URL` (mismo servicio `accounts_orders`).
- Auth: `Authorization: Bearer <token>`. La cuenta se deriva del credential;
  **ninguna ruta acepta customer id del llamador**.
- Contenido: JSON. Errores: `{ "error": "<codigo>", "message"?: "..." }`
  con códigos estables (§4). `401` sin credencial, `404` ajeno/inexistente
  (sin fuga entre cuentas).
- **Programa apagado** (`REWARDS_ENABLED` ausente o `false`): toda ruta de §3 responde
  `404 {"error":"feature_disabled","requestId":"req_…"}`, sin autenticar.
  - La app lo muestra como «Monetta Rewards aún no está disponible», nunca como un error de conexión (decisión E7).
- **Ruta desconocida** (con el programa encendido o apagado): `404 {"error":"not_found","requestId":"req_…"}`.
- En ambos casos, `requestId` es el mismo valor que la cabecera `X-Request-Id`.
- Contrato CONTRACT-02: un mismo fixture (`test/fixtures/contracts/rewards_disabled.json`) en
  `test/features/rewards/rewards_disabled_contract_test.dart` y en
  `services/accounts_orders/test/rewardsDisabledContract.test.ts`.

## 3. Endpoints cliente

### `GET /customers/me/rewards`

```json
{
  "program": { "enabled": true, "redemptionEnabled": false, "currency": "MXN",
    "earnBps": 300, "maxRedeemBps": 2000, "expiryMonths": 12,
    "wholesaleEarns": false, "ruleVersion": 1 },
  "balance": { "availableCents": 18400, "pendingCents": 5400,
    "reservedCents": 0,
    "nextExpiry": { "cents": 5400, "at": "2027-03-02T12:00:00.000Z" },
    "asOf": "2026-09-14T08:00:00.000Z" },
  "incentives": {
    "firstPurchase": { "enabled": false, "amountCents": 5000, "reason": "minimum_undecided" },
    "review": { "enabled": false, "amountCents": 2000, "reason": "verification_integration_pending" },
    "referral": { "enabled": false, "amountCents": 5000, "reason": "minimum_undecided" }
  }
}
```

### `GET /customers/me/rewards/activity?limit=20&cursor=...`

```json
{ "movements": [
  { "id": 41, "type": "earn_released", "state": "available",
    "amountCents": 5400, "orderShopifyId": "8001",
    "reason": "delivered", "createdAt": "..." }
], "nextCursor": "40" }
```

`nextCursor: null` = fin. Tipos: `earn_pending`, `earn_released`,
`earn_reversed`, `redeem_reserved`, `redeem_settled`, `redeem_released`,
`expired`, `adjustment`, `bonus_*`.

### `GET /customers/me/orders/:id/rewards`

`:id` = **Shopify order id** numérico (`8001`), como un solo segmento de la ruta. La app lo envía siempre así.

- El servidor también acepta el GID de pedido codificado como segmento (`gid%3A%2F%2Fshopify%2FOrder%2F8001`) y lo normaliza al numérico guardado.
- Cualquier otro formato → `400 {"error":"invalid_request"}`.
- Sin snapshot o de otra cuenta → `404`.
- Contrato CONTRACT-01: un mismo fixture (`test/fixtures/contracts/rewards_order_id.json`) en `test/features/rewards/rewards_order_id_contract_test.dart` y en `services/accounts_orders/test/rewardsOrderIdContract.test.ts`.

```json
{ "orderShopifyId": "8001", "isWholesale": false,
  "earnedPendingCents": 5400, "earnedReleasedCents": 0,
  "earnedReversedCents": 0, "usedCents": 0, "state": "pending" }
```

### `POST /customers/me/rewards/quotes`

```json
// request
{ "cartRevision": "cart_abc:7", "isWholesaleCart": false,
  "lines": [{ "variantId": "gid://…", "productId": "…",
    "quantity": 2, "unitPriceCents": 649000,
    "discountCents": 0, "eligible": true }] }
// response 201
{ "quoteId": "uuid", "cartRevision": "cart_abc:7",
  "subtotalEligibleCents": 90000, "availableCents": 18400,
  "maxAllowedCents": 18000, "estimatedEarnCents": 2160,
  "isWholesaleCart": false, "redemptionEnabled": false,
  "expiresAt": "…",
  "estimateDisclaimer": "Estimación pendiente de entrega; no es saldo liberado." }
```

Fórmulas: `Rmax = min(disponible, floor(S·20%))`;
`G = round((S−R)·3%)` sobre base neta propuesta. TTL 10 min. Un cambio de
carrito/descuento/cuenta invalida la cotización: **recotizar**.

### `POST /customers/me/rewards/redemptions`

```json
// request — idempotencyKey cliente (8–128 chars); doble toque = misma reserva
{ "quoteId": "uuid", "amountCents": 18000,
  "idempotencyKey": "uuid-cliente", "isWholesaleCart": false }
// response 201 (200 si reused:true); hoy con bandera apagada → 409
{ "redemption": { "redemptionId": "uuid", "state": "reserved",
    "requestedCents": 18000, "maxAllowedCents": 18000,
    "subtotalEligibleCents": 90000, "cartRevision": "cart_abc:7",
    "quoteId": "uuid", "expiresAt": "…", "orderShopifyId": null },
  "reused": false, "discount": { "code": "…" } }
```

Hoy: con `REWARDS_REDEMPTION_ENABLED=false` responde
`409 redemption_disabled` (la reserva NO se crea por esta ruta cuando el
adaptador no está disponible; ver servicio: reserva + `pendingProvision`).
TTL de reserva 30 min.

### `POST /customers/me/rewards/redemptions/:id/release`

Libera una reserva **verificando no-uso** en Shopify. Si el descuento ya se
usó → `409 discount_already_used`; si no se puede verificar →
`409 reconciliation_required` (incertidumbre conservada, nunca liberación
prematura).

## 4. Códigos de error

`redemption_disabled` (409), `wholesale_redeem_undecided` (409),
`exceeds_limit` (422), `insufficient_balance` (422), `quote_expired` (409),
`quote_not_found` (404), `not_found` (404), `already_settled` (409),
`discount_already_used` (409), `reconciliation_required` (409),
`invalid_idempotency_key` (400), `invalid_cart` (400),
`feature_disabled` (404, programa apagado), `invalid_request` (400).

Si la respuesta no trae un `error` en JSON, el cliente lo clasifica así:
- `401`/`403` → `unauthorized`;
- `404` → `not_found`;
- `5xx` → `service_unavailable`;
- fallo de transporte → `network`.

Textos UI en `RewardsApiError.friendly` / `RewardsException.friendly`.

## 5. Flutter: lo que F entrega (listo para importar)

| Pieza | Archivo | Uso |
|---|---|---|
| Cliente HTTP | `rewards_api.dart` (`RewardsApi`, `RewardsTokenProvider`) | Todas las llamadas §3 |
| DTOs | `rewards_models.dart` (`RewardsSummary`, `RewardsQuote`, `OrderRewardsState`, `RewardsMovement`, `RewardsApiError`) | Parseo y textos |
| Presentación pura | `rewards_components.dart` (`RewardsBalanceCard(summary:…)`, `RewardsEstimateLabel`, `OrderRewardsStatus`, `RewardsRedemptionControl`) | Home/Producto/Checkout y composición |
| Servicio p/E | `rewards_account.dart` (`RewardsService`, `ApiRewardsService`, `UnavailableRewardsService`, `RewardsBalance`, `RewardsOrderBreakdown`, `RewardsException`, `formatRewardsMxn`) | Cuenta/Pedidos/Notificaciones |
| Tarjeta p/E | `rewards_balance_card.dart` (`RewardsBalanceCard(accountId:, service:, compact:)`) | Cuenta/Pedidos/Notificaciones |

Reglas de uso: no calcular saldos en cliente; estimaciones siempre
identificadas (`RewardsEstimateLabel`); estados de carga/error/vacío
independientes del contenido que los contiene; sin gamificación.

## 6. Puntos de integración A–D (parche separado, NO aplicado)

Ver `docs/redesign/PAQUETE_F_INTEGRACION.md` con snippets exactos:

- **Home (A)**: tarjeta breve tras el bloque comercial
  (`RewardsBalanceCard` vía `ApiRewardsReader`/`RewardsSection` de E).
- **Producto (C)**: `RewardsEstimateLabel` bajo el precio, recalculada por
  variante/promoción.
- **Checkout (D)**: `RewardsRedemptionControl` con `quote` del servidor antes
  de abrir Shopify; ante cualquier cambio de carrito, recotizar e invalidar
  el checkout precargado.
- **Cuenta/Pedidos/Notificaciones (E)**: ya integrados por E contra §5;
  eventos `notify_release` / `notify_expiry` / `notify_adjustment` /
  `notify_bonus` salen por `rewards_outbox` cuando el worker de
  notificaciones se active.

## 7. Eventos y mensajes de pedidos (backend)

- Fuentes: `orders/create|updated` (solo `financial_status=paid` genera
  pendiente), `orders/cancelled`, `refunds/create` (reversión proporcional
  al remanente; cancelación+reembolso no revierten dos veces),
  `fulfillment_events/create` (solo `DELIVERED` libera; `FULFILLED`/tránsitos
  no). HMAC + tienda + `X-Shopify-Webhook-Id` verificados; inbox propio con
  reintento + reconciliación; entrega anterior al pago se autolibera al
  llegar el pago (misma transacción).
- Mayoreo: detección server-side por tags/códigos/atributos
  (`detectWholesale`); el booleano del teléfono nunca decide.
- Notificaciones: `rewards_outbox` (`notify_release`, `notify_expiry`,
  `notify_adjustment`, `notify_bonus`). E consume el payload
  `{ orderShopifyId?, releasedCents?|reversedCents?|… }` + `account_id`.

## 8. Lo que falta para producción (no inventar, no activar)

1. **Adaptador de canje en plan real**: Basic verificado como plan actual por
   auditoría previa (CLI no disponible en este entorno para re-verificar).
   Store credit nativo descartado (sin parciales); cupón único con mínimo 5R
   no cubre carritos mixtos ni edición post-apertura → canje apagado hasta
   prueba acotada o app pública con Functions. Ver entrega F §“Shopify”.
2. **Mínimos**: primera compra y referido sin mínimo → incentivos
   deshabilitados (`incentives.*.enabled=false`); no asignar importes.
3. **Reseña verificada**: Loox Beginner sin API (auditoría previa); bono
   apagado hasta Merchant API/webhooks autenticados + reconciliación.
4. **Base del 3% con descuentos, IVA, devoluciones parciales finas,
   recuperación de saldo gastado y restitución de canjes**: propuesta
   calculable implementada y versionada (`ruleVersion`); falta acuerdo
   comercial — cambios futuros usan nueva versión de programa, nunca
   reescriben saldos.
5. **Infra**: backend Rewards de producción aislado, worker duradero
   (`npm run worker:rewards`), permisos (`read_fulfillments`,
   descuentos), backups/PITR probados, panel admin existente extendido.

## 9. Nota para E (corrección en archivo de E, no aplicada por F)

`lib/features/rewards/rewards_section.dart` (~línea 754):
`FutureBuilder<OrderRewardsState>(future: _safeLoad(…))` recibe
`Future<OrderRewardsState?>`. Corrección de una línea (propiedad de E):

```dart
return FutureBuilder<OrderRewardsState?>(
```

## 10. Historial

- `1.0.0` (2026-09-14): contrato inicial. Suma: resumen, actividad, estado
  por pedido, cotización, reserva/confirmación/liberación, errores,
  componentes y eventos. Canje e incentivos restringidos tras bandera.
