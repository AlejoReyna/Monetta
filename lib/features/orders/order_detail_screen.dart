/// Detalle y seguimiento de pedido (paquete E).
///
/// Solo presenta datos respaldados por [OrderSummary] (identidad, importes,
/// fechas y estados reales de Shopify o del espejo de apartados). No inventa
/// líneas por pieza, desgloses de envío/impuestos ni números de guía: esas
/// secciones explican honestamente dónde consultarlos.
///
/// Tampoco atribuye a esta compra ningún otro pedido: el detalle recibe la
/// identidad ya correlacionada y la muestra tal cual.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/account_controller.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/local/database.dart' show OrderSummary;
import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import '../rewards/rewards_section.dart';
import 'order_status.dart';

Future<void> openOrderDetail(
  BuildContext context, {
  required OrderSummary order,
  RewardsReader? rewardsReader,
  AccountController? rewardsController,
  Future<bool> Function(Uri uri)? openUri,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => OrderDetailScreen(
        order: order,
        rewardsReader: rewardsReader,
        rewardsController: rewardsController,
        openUri: openUri,
      ),
    ),
  );
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({
    required this.order,
    this.rewardsReader,
    this.rewardsController,
    this.openUri,
    super.key,
  });

  final OrderSummary order;

  /// Lector Rewards fijo (fixtures). Nulo = el renglón intenta el backend
  /// configurado o no aparece; el pedido nunca depende de él.
  final RewardsReader? rewardsReader;

  /// Solo para resolver el token del lector automático. Nulo en pruebas.
  final AccountController? rewardsController;

  /// Inyectable para pruebas; por defecto abre la app externa real.
  final Future<bool> Function(Uri uri)? openUri;

  Future<void> _open(BuildContext context, Uri uri) async {
    final open =
        openUri ?? ((u) => launchUrl(u, mode: LaunchMode.externalApplication));
    final ok = await open(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final status = orderDisplayStatus(order);
    final label = orderLabelOf(order);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Detalle del pedido',
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Container(height: .5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccountPageHeader(
                kicker: status.label,
                title: label,
                subtitle: 'Realizado el ${orderDateLabel(order.placedAt)}.',
              ),
              const SizedBox(height: BoutiqueSpace.lg),
              ECard(
                children: [
                  const ESectionTitle(title: 'Estado'),
                  const SizedBox(height: BoutiqueSpace.sm),
                  EStatusCapsule.forOrderKey(
                    status.key,
                    label: status.label,
                  ),
                  const SizedBox(height: BoutiqueSpace.sm),
                  Text(
                    status.detail,
                    style: boutiqueText(
                      size: 13,
                      color: palette.inkMuted,
                    ),
                  ),
                  if (status.secondaryLabel != null) ...[
                    const SizedBox(height: BoutiqueSpace.sm),
                    Text(
                      status.secondaryLabel!,
                      style: boutiqueText(
                        size: 13,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                  if (status.key == 'in_transit') ...[
                    const SizedBox(height: BoutiqueSpace.sm),
                    Text(
                      'Enviado no significa entregado: la entrega se marca '
                      'solo con confirmación del transportista.',
                      style: boutiqueText(
                        size: 12,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: BoutiqueSpace.lg),
              ECard(
                children: [
                  const ESectionTitle(title: 'Identidad del pedido'),
                  const SizedBox(height: BoutiqueSpace.sm),
                  _FactRow(
                    label: order.source == 'whatsapp_apartado'
                        ? 'Código de apartado'
                        : 'Número de pedido',
                    value: label,
                  ),
                  _FactRow(
                    label: 'Origen',
                    value: order.source == 'whatsapp_apartado'
                        ? 'Apartado por WhatsApp'
                        : 'Compra en Shopify',
                  ),
                  if (order.attributionCode != null &&
                      order.attributionCode!.isNotEmpty)
                    _FactRow(
                      label: 'Atribución',
                      value: order.attributionCode!,
                    ),
                  _FactRow(
                    label: 'Fecha',
                    value: orderDateLabel(order.placedAt),
                  ),
                ],
              ),
              const SizedBox(height: BoutiqueSpace.lg),
              ECard(
                children: [
                  const ESectionTitle(title: 'Importe'),
                  const SizedBox(height: BoutiqueSpace.sm),
                  _FactRow(
                    label: 'Total cobrado',
                    value: '${kMoney.format(order.totalAmount)} '
                        '${order.currencyCode}',
                    strong: true,
                  ),
                  const SizedBox(height: BoutiqueSpace.sm),
                  Text(
                    'El desglose de envío, impuestos y descuentos está en tu '
                    'correo de confirmación de Shopify. Aquí mostramos el '
                    'total registrado, sin estimaciones.',
                    style: boutiqueText(
                      size: 12,
                      color: palette.inkMuted,
                    ),
                  ),
                  AutoOrderRewardsLine(
                    shopifyOrderId: order.shopifyOrderId,
                    reader: rewardsReader,
                    controller: rewardsController,
                  ),
                ],
              ),
              const SizedBox(height: BoutiqueSpace.lg),
              ECard(
                children: [
                  const ESectionTitle(title: 'Piezas'),
                  const SizedBox(height: BoutiqueSpace.sm),
                  Text(
                    'El detalle por pieza aún no está disponible en esta '
                    'versión de la app. Consulta las piezas en tu correo de '
                    'confirmación de Shopify.',
                    style: boutiqueText(
                      size: 13,
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: BoutiqueSpace.lg),
              ECard(
                children: [
                  const ESectionTitle(title: 'Seguimiento'),
                  const SizedBox(height: BoutiqueSpace.sm),
                  ..._timeline(context),
                  const SizedBox(height: BoutiqueSpace.sm),
                  Text(
                    'Cuando tu pedido se envíe recibirás la guía por correo. '
                    'Sin número de guía no mostramos fechas estimadas '
                    'inventadas.',
                    style: boutiqueText(
                      size: 12,
                      color: palette.inkMuted,
                    ),
                  ),
                ],
              ),
              if (order.source == 'whatsapp_apartado') ...[
                const SizedBox(height: BoutiqueSpace.lg),
                ENotice(
                  message: 'Este apartado se sigue por WhatsApp con tu código '
                      '${order.attributionCode ?? label}.',
                  actionLabel: 'Escribir por WhatsApp',
                  onAction: () => _open(
                    context,
                    conciergeWhatsAppUri(
                      productTitle:
                          'mi apartado ${order.attributionCode ?? label}',
                    ),
                  ),
                  icon: Icons.chat_outlined,
                ),
              ] else ...[
                const SizedBox(height: BoutiqueSpace.lg),
                ENotice(
                  message: '¿Dudas con este pedido? Escríbenos por WhatsApp '
                      'con tu número $label a la mano.',
                  actionLabel: 'Escribir por WhatsApp',
                  onAction: () => _open(
                    context,
                    conciergeWhatsAppUri(
                      productTitle: 'mi pedido $label',
                    ),
                  ),
                  icon: Icons.chat_outlined,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _timeline(BuildContext context) {
    final palette = context.boutique;
    final events = _verifiableEvents();
    return [
      for (var i = 0; i < events.length; i++)
        _TimelineRow(
          title: events[i].$1,
          body: events[i].$2,
          done: true,
          last: i == events.length - 1,
          dotColor: i == 0 ? palette.goldText : palette.inkMuted,
        ),
    ];
  }

  /// Solo eventos con evidencia en el resumen. Nunca "entregado" sin
  /// `delivered`, nunca fechas de envío inventadas.
  List<(String, String)> _verifiableEvents() {
    final events = <(String, String)>[
      (
        'Pedido realizado',
        'Registrado el ${orderDateLabel(order.placedAt)}.',
      ),
    ];
    // El pago se lee aparte del envío. Un reembolso o un impago no
    // agrega "enviado" ni "entregado" aunque haya fulfillment.
    final paid = order.source != 'whatsapp_apartado' &&
        orderPaymentStatus(order).key == 'confirmed';
    if (order.source != 'whatsapp_apartado') {
      if (paid) {
        events.add(('Pago confirmado', 'Shopify registró el pago.'));
      } else {
        final payment = orderPaymentStatus(order);
        events.add((payment.label, payment.detail));
      }
    }
    if (!paid && order.source != 'whatsapp_apartado') {
      return events;
    }
    final fulfillment = order.fulfillmentStatus?.toLowerCase().trim();
    switch (fulfillment) {
      case 'delivered':
        events.add(
          (
            'Pedido entregado',
            'El transportista confirmó la entrega.',
          ),
        );
      case 'fulfilled':
      case 'shipped':
      case 'in_transit':
      case 'in transit':
      case 'out_for_delivery':
        events.add(
          (
            'Pedido enviado',
            'Salió hacia tu domicilio. Aún no hay confirmación de entrega.',
          ),
        );
      case 'partial':
      case 'partially_fulfilled':
      case 'partially fulfilled':
        events.add(
          (
            'Envío parcial',
            'Parte del pedido va en camino; el resto sigue en preparación.',
          ),
        );
      default:
        if (order.source != 'whatsapp_apartado') {
          events.add(
            (
              'En preparación',
              'Tu pedido se está preparando para el envío.',
            ),
          );
        }
    }
    if (order.source == 'whatsapp_apartado') {
      events.add(
        (
          'Apartado registrado',
          'Anticipo y seguimiento manual por WhatsApp.',
        ),
      );
    }
    return events;
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: boutiqueText(size: 13, color: palette.inkMuted),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: boutiqueText(
                size: 13,
                weight: strong ? FontWeight.w700 : FontWeight.w500,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.body,
    required this.done,
    required this.last,
    required this.dotColor,
  });

  final String title;
  final String body;
  final bool done;
  final bool last;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: done ? dotColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 1.5),
              ),
            ),
            if (!last)
              Container(
                width: 1.5,
                height: 28,
                color: palette.hairline,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: boutiqueText(
                    size: 13,
                    weight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: boutiqueText(size: 12, color: palette.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
