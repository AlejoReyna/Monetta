/// Estado y filtros de "Mis pedidos" (paquete E).
///
/// Funciones puras sobre [OrderSummary], el caché real de
/// [OrderHistoryRepository]: CAA de Shopify como fuente primaria y apartados
/// de WhatsApp como enriquecimiento. No inventa líneas, importes ni
/// seguimiento: lo que no está en el resumen no se presenta.
///
/// Regla central: **el pago gana al envío**. "En camino" y "Entregado" solo
/// aplican cuando `financial_status` es `paid`. Un pedido reembolsado,
/// cancelado o sin pagar no se muestra como enviado ni entregado, aunque
/// Shopify ya tenga `fulfillmentStatus`.
///
/// Enviado no es entregado: con el pago cubierto, solo `delivered` es
/// "Entregado". Un `fulfilled` sin entrega es "En camino". Un `paid` sin
/// preparación es "Confirmado".
///
/// `pending` es "Esperando tu transferencia" solo si cada token de
/// [OrderSummary.paymentMethod] es exactamente `bank_deposit` o `manual`.
/// Ese estado lleva la acción "Ver datos de pago" en la lista, que abre el
/// pedido. El detalle pide los datos por WhatsApp con su propio rótulo.
/// PayPal, Mercado Pago, tarjeta, `other:…` y un método ausente quedan en
/// "Pago en proceso".
///
/// Un pedido cancelado en Shopify (`cancelledAt`, `cancelReason` o estado
/// `cancelled`) es "Cancelado" aunque el pago figure como `paid` o
/// `pending`. `refunded` y `voided` conservan su regla. Un cancelado con
/// `partially_refunded` (OST-13d) es "Reembolso parcial" y deja "Cancelado"
/// como línea secundaria, sin el envío. La línea de WhatsApp aparece en un
/// cancelado `paid` y en ese reembolso parcial cancelado.
library;

import '../../app/shopper_copy.dart' show conciergeWhatsAppUri;
import '../../app/theme.dart' show kMoney;
import '../../data/local/database.dart' show OrderSummary;

/// Filtros pertinentes con datos reales. Sin "Más vendidos" ni rangos
/// inventados: cada filtro corresponde a un subconjunto verificable.
enum OrderFilter {
  all,
  inTransit,
  delivered,
  apartado,
}

String orderFilterLabel(OrderFilter filter) => switch (filter) {
      OrderFilter.all => 'Todos',
      OrderFilter.inTransit => 'En camino',
      OrderFilter.delivered => 'Entregados',
      OrderFilter.apartado => 'Apartados',
    };

/// Línea de WhatsApp bajo un cancelado pagado y bajo un reembolso parcial
/// cancelado. Una sola copia: la lista y el detalle la leen de aquí.
const String paidCancelledRefundHelp =
    'Si ya pagaste y tienes dudas sobre tu reembolso, escríbenos por WhatsApp.';

/// WhatsApp con el número de pedido. Aplica a un cancelado `paid` y a
/// OST-13d (`partially_refunded` cancelado). Nulo en pending, voided,
/// `refunded` y el resto de cancelaciones.
Uri? paidCancelledRefundWhatsAppUri(OrderSummary order) {
  if (!_isShopifyCancelled(order)) return null;
  final financial = _normalizeFinancial(order.status);
  if (financial != 'paid' && financial != 'partially_refunded') return null;
  return conciergeWhatsAppUri(
    productTitle: 'mi pedido ${orderLabelOf(order)}',
  );
}

/// Etiqueta de pedido real: `displayNumber` (`#1001`) cuando existe;
/// código de apartado (`MN-XXXX`) para WhatsApp; nunca un `#MON12345`
/// inventado ni el primer pedido del historial.
String orderLabelOf(OrderSummary order) {
  final display = order.displayNumber?.trim();
  if (display != null && display.isNotEmpty) return display;
  final attribution = order.attributionCode?.trim();
  if (attribution != null && attribution.isNotEmpty) return attribution;
  final id = order.id;
  final short = id.length > 12 ? '…${id.substring(id.length - 8)}' : id;
  return 'Pedido $short';
}

/// Cápsula de estado verificable. `label` es lo que se muestra; `detail`
/// es el cuerpo, sin prometer una notificación. [actionLabel] es el
/// enlace de la tarjeta cuando el estado pide uno. [success] queda en
/// falso para reembolsos y cancelaciones: no usan color de éxito.
class OrderDisplayStatus {
  const OrderDisplayStatus({
    required this.key,
    required this.label,
    required this.detail,
    this.actionLabel,
    this.secondaryLabel,
    this.success = false,
  });

  final String key;
  final String label;
  final String detail;
  final String? actionLabel;

  /// Texto neutro bajo la etiqueta, sin acento. Envío de un reembolso
  /// parcial, o "Cancelado" cuando ese reembolso también está cancelado.
  final String? secondaryLabel;
  final bool success;
}

OrderDisplayStatus orderDisplayStatus(OrderSummary order) {
  if (order.source == 'whatsapp_apartado') {
    return const OrderDisplayStatus(
      key: 'apartado',
      label: 'Apartado',
      detail: 'Apartado manual por WhatsApp. Monetta confirma '
          'disponibilidad y registra tu anticipo.',
    );
  }
  final payment = orderPaymentStatus(order);
  if (payment.key == 'partial_refund') {
    if (_isShopifyCancelled(order)) {
      return _withSecondary(payment, 'Cancelado');
    }
    return _withSecondaryFulfillment(order, payment);
  }
  if (payment.key != 'confirmed') return payment;
  return _fulfillmentStatus(order) ?? payment;
}

/// Estado de pago, sin mirar el envío. Un reembolso o un impago no
/// cambia porque el pedido figure como enviado.
OrderDisplayStatus orderPaymentStatus(OrderSummary order) {
  final financial = _normalizeFinancial(order.status);
  if (financial == 'refunded') {
    return OrderDisplayStatus(
      key: 'refunded',
      label: 'Reembolsado',
      detail: _refundedBody(order),
      actionLabel: 'Ver pedido',
    );
  }
  if (financial == 'partially_refunded') {
    return OrderDisplayStatus(
      key: 'partial_refund',
      label: 'Reembolso parcial',
      detail: _partialRefundBody(order),
    );
  }
  if (financial == 'voided' || _isShopifyCancelled(order)) {
    return const OrderDisplayStatus(
      key: 'cancelled',
      label: 'Cancelado',
      detail: 'Este pedido fue cancelado.',
    );
  }
  switch (financial) {
    case 'paid':
      return const OrderDisplayStatus(
        key: 'confirmed',
        label: 'Confirmado',
        detail: 'Aquí verás cuando tu pedido salga.',
      );
    case 'pending_refund':
    case 'refund_pending':
    case 'refund_in_progress':
      return const OrderDisplayStatus(
        key: 'refund_in_progress',
        label: 'Reembolso en proceso',
        detail: 'Lo verás aquí cuando se complete.',
      );
    case 'pending':
      if (orderPaymentMethodIsBankTransfer(order.paymentMethod)) {
        return const OrderDisplayStatus(
          key: 'awaiting_transfer',
          label: 'Esperando tu transferencia',
          detail: 'Estamos esperando tu transferencia. '
              'Lo verás aquí cuando se confirme.',
          actionLabel: 'Ver datos de pago',
        );
      }
      return _paymentInProgress;
    default:
      return _paymentInProgress;
  }
}

/// Cancelación de Shopify distinta de `refunded` y `voided`.
///
/// `cancelledAt`, un `cancelReason` presente, o el estado `cancelled` /
/// `canceled`. No se infiere por el envío ni por un pago pendiente.
bool _isShopifyCancelled(OrderSummary order) {
  if (order.cancelledAt != null) return true;
  final reason = order.cancelReason?.trim();
  if (reason != null && reason.isNotEmpty) return true;
  final financial = _normalizeFinancial(order.status);
  return financial == 'cancelled' || financial == 'canceled';
}

const OrderDisplayStatus _paymentInProgress = OrderDisplayStatus(
  key: 'payment_in_progress',
  label: 'Pago en proceso',
  detail: 'Lo verás aquí cuando se confirme.',
);

/// True solo cuando cada token es `bank_deposit` o `manual`.
///
/// Un nombre parecido (`transferencia`, `deposito`, `other:bank_deposit`)
/// no entra. Vacío o ausente tampoco.
bool orderPaymentMethodIsBankTransfer(String? raw) {
  final tokens = _paymentTokens(raw);
  if (tokens.isEmpty) return false;
  return tokens.every(
    (token) => token == 'bank_deposit' || token == 'manual',
  );
}

List<String> _paymentTokens(String? raw) {
  final folded = (raw ?? '')
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
  if (folded.isEmpty) return const [];
  return folded
      .split(RegExp(r'[\s,;/|]+'))
      .map((token) => token.replaceAll('-', '_'))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
}

String _refundedBody(OrderSummary order) {
  if (order.totalAmount <= 0) return 'Te devolvimos tu pago.';
  return 'Te devolvimos ${_money(order.totalAmount, order.currencyCode)} '
      'a tu método de pago.';
}

/// Copia del Designer. El monto reembolsado es `totalRefunded`. Si no
/// está, o no hay total contra el cual leerlo, se usa el fallback
/// aprobado en lugar de armar una cifra.
String _partialRefundBody(OrderSummary order) {
  final refunded = order.refundedAmount;
  final total = order.totalAmount;
  if (refunded == null || refunded <= 0 || total <= 0 || refunded > total) {
    return 'Te devolvimos una parte de tu pago a tu método de pago.';
  }
  final currency = order.currencyCode;
  return 'Te devolvimos ${_money(refunded, currency)} de '
      '${_money(total, currency)} a tu método de pago.';
}

String _money(double amount, String currency) {
  final formatted = kMoney.format(amount);
  final code = currency.trim();
  return code.isEmpty ? formatted : '$formatted $code';
}

OrderDisplayStatus _withSecondaryFulfillment(
  OrderSummary order,
  OrderDisplayStatus payment,
) {
  return _withSecondary(payment, _secondaryFulfillmentLabel(order));
}

OrderDisplayStatus _withSecondary(
  OrderDisplayStatus payment,
  String? secondary,
) {
  if (secondary == null) return payment;
  return OrderDisplayStatus(
    key: payment.key,
    label: payment.label,
    detail: payment.detail,
    actionLabel: payment.actionLabel,
    secondaryLabel: secondary,
  );
}

/// Envío o entrega bajo el reembolso parcial. No sustituye la etiqueta.
String? _secondaryFulfillmentLabel(OrderSummary order) {
  switch (order.fulfillmentStatus?.toLowerCase().trim()) {
    case 'delivered':
      return 'Entregado';
    case 'fulfilled':
    case 'shipped':
    case 'in_transit':
    case 'in transit':
    case 'out_for_delivery':
      return 'En camino';
    default:
      return null;
  }
}

String _normalizeFinancial(String? raw) =>
    (raw ?? '').toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');

OrderDisplayStatus? _fulfillmentStatus(OrderSummary order) {
  switch (order.fulfillmentStatus?.toLowerCase().trim()) {
    case 'delivered':
      return const OrderDisplayStatus(
        key: 'delivered',
        label: 'Entregado',
        detail: 'El transportista confirmó la entrega de tu pedido.',
      );
    case 'fulfilled':
    case 'shipped':
    case 'in_transit':
    case 'in transit':
    case 'out_for_delivery':
      return const OrderDisplayStatus(
        key: 'in_transit',
        label: 'En camino',
        detail: 'Tu pedido fue enviado. Aún no hay confirmación de entrega.',
      );
    case 'partial':
    case 'partially_fulfilled':
    case 'partially fulfilled':
      return const OrderDisplayStatus(
        key: 'partial',
        label: 'Enviado parcial',
        detail: 'Parte de tu pedido fue enviada. Lo restante sigue en '
            'preparación.',
      );
    default:
      return null;
  }
}

bool _isPaid(OrderSummary order) =>
    _normalizeFinancial(order.status) == 'paid' && !_isShopifyCancelled(order);

bool _isDelivered(OrderSummary order) =>
    order.source != 'whatsapp_apartado' &&
    _isPaid(order) &&
    order.fulfillmentStatus?.toLowerCase().trim() == 'delivered';

bool _isInTransit(OrderSummary order) {
  if (order.source == 'whatsapp_apartado' || !_isPaid(order)) return false;
  return switch (order.fulfillmentStatus?.toLowerCase().trim()) {
    'fulfilled' ||
    'shipped' ||
    'in_transit' ||
    'in transit' ||
    'out_for_delivery' ||
    'partial' ||
    'partially_fulfilled' ||
    'partially fulfilled' =>
      true,
    _ => false,
  };
}

/// Subconjunto verificable para cada filtro. "En camino" exige evidencia de
/// envío; un pedido solo confirmado no entra ahí.
List<OrderSummary> filterOrders(
  List<OrderSummary> orders,
  OrderFilter filter,
) {
  return switch (filter) {
    OrderFilter.all => List<OrderSummary>.unmodifiable(orders),
    OrderFilter.inTransit => orders.where(_isInTransit).toList(growable: false),
    OrderFilter.delivered => orders.where(_isDelivered).toList(growable: false),
    OrderFilter.apartado =>
      orders.where((o) => o.source == 'whatsapp_apartado').toList(
            growable: false,
          ),
  };
}

/// Resumen honesto de la lista visible: conteo y suma de totales en MXN.
///
/// Solo suma filas con `currencyCode == 'MXN'`; otras monedas se cuentan
/// pero no se convierten ni se mezclan en el total.
class OrdersSummary {
  const OrdersSummary({
    required this.count,
    required this.totalMxn,
    required this.otherCurrencyCount,
  });

  final int count;
  final double totalMxn;
  final int otherCurrencyCount;
}

OrdersSummary summarizeOrders(List<OrderSummary> orders) {
  var total = 0.0;
  var others = 0;
  for (final order in orders) {
    if (order.currencyCode.toUpperCase() == 'MXN') {
      total += order.totalAmount;
    } else {
      others++;
    }
  }
  return OrdersSummary(
    count: orders.length,
    totalMxn: total,
    otherCurrencyCount: others,
  );
}

/// Fecha corta real del pedido, sin hora inventada de entrega.
String orderDateLabel(DateTime placedAt) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${placedAt.day} ${months[placedAt.month - 1]} ${placedAt.year}';
}
