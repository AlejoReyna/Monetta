/// Client guide page 17 — confirmación. Solo se presenta con evidencia [CheckoutCompleted].
///
/// Nunca inventa número de pedido: [orderLabel] es el `displayNumber` real
/// (`#1001`) correlacionado con el checkout recién completado, o null cuando
/// aún no hay evidencia (guest sin cuenta, refresh pendiente). Sin etiqueta
/// muestra un estado honesto que dirige a Mis pedidos en vez de un
/// `#MON12345` falso o del primer pedido de la lista.
///
/// The presentation never substitutes local bag estimates for an authoritative
/// order summary. Missing product lines and totals stay explicit.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/monetta_tokens.g.dart';
import '../boutique/client_guide_scaffold.dart';
import '../boutique/client_guide_components.dart';
import 'purchase_notices.dart';
import '../boutique/boutique_tokens.dart';

/// Política comercial de entrega. Se conserva el parámetro [now] para
/// compatibilidad con llamadas existentes; la política no depende del reloj
/// local y nunca fabrica un rango de fechas específico.
String estimatedDeliveryLabel({DateTime? now}) {
  return '3 a 5 días hábiles';
}

Future<void> showOrderConfirmation(
  BuildContext context, {
  String? orderLabel,
  String? email,
  VoidCallback? onViewOrder,
}) {
  return Navigator.of(context).push(
    monettaFadeRoute(
      OrderConfirmationScreen(
        orderLabel: orderLabel,
        email: email,
        onViewOrder: onViewOrder,
      ),
    ),
  );
}

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    this.orderLabel,
    this.email,
    this.onViewOrder,
    super.key,
  });

  /// Etiqueta real del pedido (`#1001`), null = aún sin evidencia.
  final String? orderLabel;
  final String? email;
  final VoidCallback? onViewOrder;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final label = orderLabel?.trim();

    return ClientGuideScaffold(
      current: ClientGuideDestination.bag,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: MonettaTokens.breakpointMedium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: MonettaTokens.tapTarget * 2,
                    height: MonettaTokens.tapTarget * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.gold, width: 1),
                    ),
                    child: Icon(
                      Icons.check,
                      size: MonettaTokens.tapTarget,
                      color: palette.goldText,
                    ),
                  ),
                  SizedBox(height: MonettaTokens.space[4]),
                  Text(
                    '¡Gracias por tu compra!',
                    textAlign: TextAlign.center,
                    style: clientGuideStyle(context, MonettaTokens.screenTitle),
                  ),
                  SizedBox(height: MonettaTokens.space[1]),
                  Text(
                    'Tu pedido ha sido confirmado.',
                    textAlign: TextAlign.center,
                    style: clientGuideStyle(
                      context,
                      MonettaTokens.body,
                      color: palette.inkMuted,
                    ),
                  ),
                  SizedBox(height: MonettaTokens.space[4]),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(MonettaTokens.space[3]),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(MonettaTokens.radiusCard),
                      ),
                      border: Border.all(color: palette.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumen del pedido',
                          style: clientGuideStyle(
                            context,
                            MonettaTokens.sectionTitle,
                          ),
                        ),
                        SizedBox(height: MonettaTokens.space[3]),
                        Text(
                          'El detalle de productos y el total aún no están disponibles aquí. Consulta la confirmación de Shopify o Mis pedidos.',
                          style: clientGuideStyle(
                            context,
                            MonettaTokens.body,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MonettaTokens.space[4]),
                  if (label != null && label.isNotEmpty)
                    Text(
                      label,
                      style: clientGuideStyle(context, MonettaTokens.price),
                    )
                  else ...[
                    Text(
                      'Confirmado en Shopify',
                      style: clientGuideStyle(context, MonettaTokens.price),
                    ),
                    SizedBox(height: MonettaTokens.space[0]),
                    Text(
                      'El número aparecerá en Mis pedidos en cuanto termine de sincronizarse.',
                      textAlign: TextAlign.center,
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.cardLabel,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                  SizedBox(height: MonettaTokens.space[4]),
                  const PurchasePolicyNotice(),
                  if (email != null && email!.trim().isNotEmpty) ...[
                    SizedBox(height: MonettaTokens.space[2]),
                    Text(
                      'Te llegará un correo con los detalles de tu compra.',
                      textAlign: TextAlign.center,
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.cardLabel,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                  SizedBox(height: MonettaTokens.space[5]),
                  ClientGuideButton(
                    label: 'Ver detalles del pedido',
                    onPressed: onViewOrder ??
                        () => Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                  SizedBox(height: MonettaTokens.space[2]),
                  ClientGuideButton(
                    label: 'Volver al inicio',
                    outlined: true,
                    onPressed: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
