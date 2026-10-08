/// Fig.15 — confirmación. Solo se presenta con evidencia [CheckoutCompleted].
///
/// Nunca inventa número de pedido: [orderLabel] es el `displayNumber` real
/// (`#1001`) correlacionado con el checkout recién completado, o null cuando
/// aún no hay evidencia (guest sin cuenta, refresh pendiente). Sin etiqueta
/// muestra un estado honesto que dirige a Mis pedidos en vez de un
/// `#MON12345` falso o del primer pedido de la lista.
///
/// La entrega muestra la política comercial `3 a 5 días hábiles` sin fabricar
/// fechas: sumar días naturales no es días hábiles y no hay calendario ni
/// estimación logística por envío en este punto.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
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

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          icon: const Icon(Icons.close, size: 20),
        ),
        centerTitle: true,
        title: Text(
          'Confirmación',
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Container(height: .5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.gold, width: 1.5),
                      color: Colors.transparent,
                    ),
                    child: Icon(Icons.check, size: 40, color: palette.gold),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '¡Listo!',
                    textAlign: TextAlign.center,
                    style: boutiqueDisplay(34, color: palette.ink),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tu pedido ha sido confirmado.',
                    textAlign: TextAlign.center,
                    style: boutiqueText(size: 14, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Número de pedido'.toUpperCase(),
                    style: boutiqueEyebrow(size: 11, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  if (label != null && label.isNotEmpty)
                    Text(
                      label,
                      style: boutiqueText(
                        size: 16,
                        weight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    )
                  else ...[
                    Text(
                      'Confirmado en Shopify',
                      style: boutiqueText(
                        size: 15,
                        weight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'El número aparecerá en Mis pedidos en cuanto termine de sincronizarse.',
                      textAlign: TextAlign.center,
                      style: boutiqueText(size: 12, color: palette.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Fecha estimada de entrega'.toUpperCase(),
                    style: boutiqueEyebrow(size: 11, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    estimatedDeliveryLabel(),
                    style: boutiqueText(size: 14, color: palette.ink),
                  ),
                  Text(
                    'La fecha exacta se confirma con tu envío.',
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                  if (email != null && email!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Enviamos la confirmación a ${email!.trim()}',
                      textAlign: TextAlign.center,
                      style: boutiqueText(size: 12, color: palette.inkMuted),
                    ),
                  ],
                  const SizedBox(height: 32),
                  BoutiqueButton(
                    label: 'Ver pedido',
                    onPressed: onViewOrder ??
                        () => Navigator.of(context).popUntil((r) => r.isFirst),
                  ),
                  const SizedBox(height: 12),
                  BoutiqueButton(
                    label: 'Seguir comprando',
                    filled: false,
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
