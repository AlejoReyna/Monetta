# Paquete F — Entrega: Mayoreo, Creador de catálogo y Monetta Rewards

Fecha: 2026-09-14 · Responsable: paquete F · Estado: **implementado y
verificado localmente; NO listo para producción** (canje e incentivos
restringidos tras bandera; §6–§7).

Referencias: `docs/MONETTA_REWARDS_V1_PLAN.md` (sustituye figura 12),
`docs/design-reference/monetta-client-layout.png` (figs. 10 y 11),
`docs/redesign/REWARDS_CONTRACT_V1.md` v1.0.0,
`docs/redesign/PAQUETE_F_INTEGRACION.md` (parche global no aplicado),
`docs/redesign/PAQUETE_F_CATALOGO_EJEMPLO.md`.

## 1. Implementación y migraciones preparadas

### Backend (`services/accounts_orders`, reutilizado; sin microservicio nuevo)

| Pieza | Archivo |
|---|---|
| Migración aditiva 013 | `src/db/migrations/013_rewards.sql` (aplica limpio; re-ejecución no-op verificada) |
| Reglas puras | `src/rewards/rules.ts`, `money.ts`, `types.ts` |
| Config/banderas | `src/rewards/rewardsConfig.ts`, `src/config.ts` (`REWARDS_*`), `.env.example` |
| Ledger transaccional | `src/rewards/pgRewardsRepository.ts` (+ `repository.ts`) |
| Servicio | `src/rewards/service.ts` (quotes, reservas, eventos, mantenimiento) |
| Adaptador descuento | `src/rewards/shopifyDiscountAdapter.ts` (deshabilitado + cupón único Basic documentado) |
| Rutas cliente | `src/rewards/routes.ts` (montadas en `src/api/server.ts` tras `express.json()`) |
| Webhooks | `orders/cancelled`, `refunds/create`, `fulfillment_events/create` en `server.ts`; puentes en `src/rewards/webhookBridge.ts` |
| Worker | `src/rewards/worker.ts` (`npm run worker:rewards`: vencimientos, reservas abandonadas, reintento inbox) |

Tablas 013: `rewards_program_versions` (v1 semilla: 3%, 20%, 12 m, canje
apagado, bonos apagados), `rewards_accounts`, `rewards_credit_lots`,
`rewards_ledger_entries`, `rewards_redemptions`, `rewards_lot_allocations`,
`rewards_quotes`, `rewards_order_snapshots`, `rewards_fulfillment_events`,
`rewards_bonus_claims`, `rewards_referrals`, `rewards_inbox`,
`rewards_outbox`, `rewards_admin_audit`. Claves únicas por
(cuenta, origen, regla) y (cuenta, clave idempotente); bloqueo por cuenta +
`SELECT … FOR UPDATE` en orden estable; reservas y asiento en la misma
transacción. Sin migraciones en producción ni despliegues (solo local).

### Flutter (archivos nuevos, propiedad F; cero ediciones a pantallas de E/A–D)

| Pieza | Archivo |
|---|---|
| Mayoreo fig. 10 | `lib/features/wholesale/wholesale_screen.dart`, `wholesale_content.dart` |
| Creador fig. 11 | `lib/features/catalog_creator/catalog_creator_screen.dart`, `catalog_creator_document.dart` |
| Cliente/DTOs | `lib/features/rewards/rewards_api.dart`, `rewards_models.dart` |
| Presentación pura | `lib/features/rewards/rewards_components.dart` |
| Servicio p/E | `lib/features/rewards/rewards_account.dart` |
| Tarjeta p/E | `lib/features/rewards/rewards_balance_card.dart` |

Mayoreo: portada editorial, condiciones reales (3 modelos, $800 anticipo,
20 días, 100% originales, pagos/envíos/devoluciones publicados), precio por
volumen **cualitativo sin tabla de tramos inventada** (tramos se confirman al
cotizar), proceso en 3 pasos, CTA WhatsApp y nota “mayoreo no genera
Rewards”. Creador: selección con búsqueda, variantes/cantidades, resumen con
total real, vista previa, compartir por hoja del sistema (acción explícita) y
copiar; **sin enlaces públicos sin alojamiento**; layout de una columna en
móvil (390×844 verificado). Estética: marfil/negro/dorado de `theme.dart`,
tipografía editorial, iconos lineales, sin gamificación.

## 2. Contrato de integración para E y A–D

`docs/redesign/REWARDS_CONTRACT_V1.md` v1.0.0 (endpoints, JSON, errores,
fórmulas, eventos/outbox, tabla de componentes, historial). E ya integra
Cuenta/Pedidos/Notificaciones contra `rewards_account.dart` +
`rewards_balance_card.dart` (suministrados por F) y su `rewards_section.dart`
compila contra `rewards_api/models/components` de F. Parche global sin
aplicar: `docs/redesign/PAQUETE_F_INTEGRACION.md` (F1–F7 con snippets).

**Nota para E** (archivo de E, no tocado por F): en
`lib/features/rewards/rewards_section.dart`, `FutureBuilder<OrderRewardsState>`
debe ser `FutureBuilder<OrderRewardsState?>` (el futuro admite null).

## 3. Capturas y catálogo de ejemplo

- `docs/redesign/paquete-f-capturas/wholesale_cover.png`,
  `wholesale_terms.png`, `catalog_creator.png`: renders reales generados con
  `flutter test --update-goldens` (prueba temporal ya eliminada para no
  acoplar CI). En entorno de pruebas el texto se ve en bloques (fuente
  Ahem); la estructura —portada/CTA, condiciones, selección, steppers,
  resumen— es la real. Capturas en dispositivo físico pendientes.
- `docs/redesign/PAQUETE_F_CATALOGO_EJEMPLO.md`: selección de 5 productos
  reales (8 modelos, total $20,263.03 MXN) con precios, disponibilidad e
  imágenes de `assets/catalog/catalog.json`.

## 4. Pruebas ejecutadas y resultados

Backend (`services/accounts_orders`, `npx vitest run`): **22 archivos, 118
pruebas, 0 fallos** — incluye 25 nuevas de Rewards:
`rewardsRules` (8: 3%, 20%, vigencia, mayoreo, banderas, formato),
`rewardsService` (14: emisión única, pendiente→liberación, duplicados,
fuera de orden, cancel+reembolso sin doble reversión, parcial, mayoreo
excluido, 20%+carrito, doble toque sin sobregiro, expiración, reservas
abandonadas, separación de cuentas, incentivos apagados, bandera),
`rewardsApi` (3: 401/ceros honestos, quote+409, actividad/pedido con
aislamiento), `rewardsLedger.pg` (3 en **PostgreSQL real**: earn→liberación→
reserva→settle parcial, exceso→reconciliación, mayoreo excluido).
`tsc --noEmit` limpio; migración 013 aplicada en Postgres local y re-run no-op.

Flutter: `test/features/wholesale` + `test/features/catalog_creator` +
`test/features/rewards`: **20 pruebas, 0 fallos** (11 de F + 9 de E contra
el contrato de F, incluido `rewards_section_test.dart`). `flutter analyze`
limpio en todos los archivos de F. Cobertura de validación mínima del
encargo: emisión/liberación únicas, concurrencia, 20%+carrito, cancelación,
devolución parcial, fuera de orden, expiración, reservas abandonadas,
exclusión de mayoreo, separación de cuentas/permisos, incentivos
deshabilitados. Prueba que falta (requiere plan/permisos reales): §6.

## 5. Dependencias comerciales, Shopify, Loox e infraestructura pendientes

1. **Canje en plan real**: auditoría previa verificó Shopify Basic; en este
   entorno no hay CLI Shopify para re-verificar (se documenta, no se asume
   cambio). Store credit nativo descartado con fuente oficial (sin
   parciales). Cupón único Basic insuficiente para mixtos/edición
   post-apertura → `REWARDS_REDEMPTION_ENABLED=false` hasta prueba acotada
   documentada o app pública con Functions. **Prueba que falta**: cupón R de
   un solo uso en Basic con cambio de carrito y verificación de `usageCount`.
2. **Comerciales**: mínimo de primera compra y de referido; base del 3% con
   descuentos/IVA definitiva; carritos mixtos; devoluciones parciales finas;
   recuperación de saldo gastado; restitución de canjes; canje en mayoreo.
   Todo tras bandera o `NULL` versionado; propuesta calculable con
   `ruleVersion` para no reescribir historia.
3. **Loox**: plan Beginner sin API (auditoría previa; sin re-verificación
   posible aquí) → bono de reseña apagado hasta Merchant API + webhooks
   autenticados + reconciliación. Widget público nunca como autoridad.
4. **Infra**: backend Rewards de producción aislado, `worker:rewards`
   duradero, permisos (`read_fulfillments`, descuentos), secretos Loox solo
   en backend, backups/PITR probados, `NOTIFICATIONS_ENABLED` + outbox
   cuando E lo consuma. Staging Fly (`monetta-accounts-staging`, máquina
   `app` en dfw) existe; sin despliegues desde este encargo.

## 6. Distinción explícita

- **Implementado**: ledger, API v1, webhooks, worker, adaptador (apagado),
  pantallas Mayoreo/Creador, componentes/contrato, migraciones, pruebas.
- **Verificado localmente**: §4 completo (unitarias, API, pg real,
  widget, analyze, migración). Sin pedidos/reembolsos reales; sin dispositivo.
- **Habilitable en producción**: solo lectura/resumen con
  `REWARDS_ENABLED=true` tras desplegar migración + worker y configurar
  entorno. **Canje e incentivos NO habilitables** hasta cerrar §5
  (bandera + decisiones + prueba en plan real). No declarar Rewards listo.

## 7. Archivos tocados fuera de propiedad F (mínimos, compartidos)

- `services/accounts_orders/src/api/server.ts`, `src/config.ts`,
  `.env.example`, `package.json`: cableado aditivo tras bandera.
- Formato (`dart format`) alcanzó `test/features/rewards/rewards_section_test.dart`
  (prueba de E, solo espacios). Sin ediciones a pantallas de E/A–D ni
  reversiones de trabajo ajeno.
