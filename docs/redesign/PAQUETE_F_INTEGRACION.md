# Parche de integración global — paquete F (SEPARADO, NO APLICADO)

Propósito: puntos exactos donde A–D y E conectan Mayoreo, Creador de catálogo
y Rewards **sin que F edite sus pantallas en paralelo**. El orquestador o cada
paquete aplica su fragmento. Todo es aditivo; nada aquí cambia conducta
existente cuando el backend no está configurado.

Contrato: `docs/redesign/REWARDS_CONTRACT_V1.md` v1.0.0.

## F1. Navegación a Mayoreo y Creador (A / navegación)

En el destino que defina A (tarjeta “Conocer mayoreo”, menú o ruta):

```dart
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';
import 'package:monetta_app/features/catalog_creator/catalog_creator_screen.dart';

// Mayoreo (figura 10): portada, condiciones reales, volumen, proceso, CTA.
Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => const WholesaleScreen()),
);

// Creador de catálogo (figura 11): usa precios/disponibilidad/imágenes reales.
await openCatalogCreator(context); // lee StoreScope; alternativamente:
// Navigator.of(context).push(MaterialPageRoute<void>(
//   builder: (_) => CatalogCreatorScreen(products: store.products)));
```

`openCatalogCreator` vive en `catalog_creator_screen.dart` (propiedad F).

## F2. Home — tarjeta breve de saldo (A, tras el bloque comercial)

```dart
import 'package:monetta_app/features/rewards/rewards_section.dart'; // pegamento E
import 'package:monetta_app/features/rewards/rewards_api.dart';

// donde A resuelva el token de la sesión Shopify:
final api = resolveRewardsApi(
  config: accountsOrdersConfig, // AccountsOrdersConfig.fromEnvironment()
  tokenProvider: () => accountController.shopifyAccessToken(),
);
// En el árbol, tras el bloque comercial principal:
RewardsSection(controller: accountController, reader: api == null ? null : ApiRewardsReader(api)),
```

Sin sesión o sin backend: `reader: null` muestra explicación del beneficio,
nunca cifras. No prometer bonos con mínimo indefinido.

## F3. Producto — beneficio estimado (C, debajo del precio)

```dart
import 'package:monetta_app/features/rewards/rewards_components.dart';

// estimatedCents lo calcula EL SERVIDOR (quote) o una estimación marcada:
// 3% de la base elegible de la variante seleccionada con promociones.
RewardsEstimateLabel(estimatedCents: estimatedCents, isWholesale: esMayoreo),
```

Recalcular con variante y promociones; texto ya aclara que es estimación
pendiente de entrega. En mayoreo (`isWholesale: true`) no renderiza.

## F4. Checkout — control de canje con límite 20% (D)

```dart
import 'package:monetta_app/features/rewards/rewards_api.dart';
import 'package:monetta_app/features/rewards/rewards_components.dart';
import 'package:uuid/uuid.dart';

// 1. Antes de presentar Shopify, cotizar con el carrito REAL:
final quote = await api.quote(
  cartRevision: cartRevision, // id del carrito + hash de líneas/descuentos
  lines: [for (final l in lineas) {
    'variantId': l.variantId, 'quantity': l.cantidad,
    'unitPriceCents': l.precioUnitarioCentavos,
    'discountCents': l.descuentoCentavos, 'eligible': l.elegible,
  }],
);
// 2. Presentar el control; el máximo lo define el servidor:
RewardsRedemptionControl(
  quote: quote,
  selectedCents: seleccion,
  onAmountChanged: (v) => setState(() => seleccion = v),
  onConfirm: () async {
    final res = await api.redeem(
      quoteId: quote.quoteId, amountCents: seleccion,
      idempotencyKey: const Uuid().v4(), // una por intento de pago
    );
    // res['discount']['code'] → aplicar en Shopify según adaptador vigente.
  },
  busy: ocupado, errorCode: codigoError, // p.ej. 'exceeds_limit'
);
// 3. Si el carrito cambia dentro o fuera de Shopify (cantidades, líneas,
//    promociones, cuenta): RECOTIZAR e invalidar el checkout precargado.
//    Nunca confiar en el máximo calculado antes del cambio.
```

Mientras `redemptionEnabled == false`, el control muestra el estado
deshabilitado; D no debe ofrecer canje por otra vía.

## F5. Cuenta / Pedidos / Notificaciones (E — ya integrado por E)

E consume `RewardsService` + `RewardsBalanceCard(accountId:, service:)`
(`rewards_account.dart`, `rewards_balance_card.dart`, propiedad F) y su
propio `RewardsSection`/`OrderRewardsLine`. Referencia de cableado real:

```dart
import 'package:monetta_app/features/rewards/rewards_account.dart';
import 'package:monetta_app/features/rewards/rewards_api.dart';

// Producción (cuando el backend esté configurado en el build):
final service = api == null
    ? const UnavailableRewardsService()
    : ApiRewardsService(api);
// Fila Invitar: oculta hasta definir referidos (onOpenInvite null).
```

Eventos para Notificaciones (cuando el worker se active): outbox
`notify_release` / `notify_expiry` / `notify_adjustment` / `notify_bonus`
con `{ account_id, payload: { orderShopifyId?, releasedCents?|… } }`.

## F6. Invitados y referidos (E + F, pendiente de reglas)

`onOpenInvite` queda `null` (fila oculta) hasta cerrar ventana de atribución
y compra mínima. El esquema `rewards_referrals` (código opaco, una
atribución por invitado, sin autoreferidos) ya existe en la migración 013.

## F7. Verificación del parche

- Sin `ACCOUNTS_ORDERS_BASE_URL`: todas las superficies muestran estados
  honestos; cero llamadas fallidas visibles.
- Con staging: resumen, actividad, estado por pedido, cotización y control
  responden según contrato; canje bloqueado con `redemption_disabled`.
- Ningún fragmento recalcula saldos en cliente ni presenta estimaciones
  como liberadas.
