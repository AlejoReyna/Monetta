/// Estado y filtros de "Mis pedidos" (paquete E).
///
/// Funciones puras sobre [OrderSummary], el caché real de
/// [OrderHistoryRepository]: CAA de Shopify como fuente primaria y apartados
/// de WhatsApp como enriquecimiento. No inventa líneas, importes ni
/// seguimiento: lo que no está en el resumen no se presenta.
///
/// Regla central: **enviado no es entregado**. Solo `fulfillmentStatus` con
/// evidencia de entrega (`delivered`) se rotula "Entregado". Un `fulfilled`
/// sin entrega es "En camino" (enviado), y un pedido pagado sin preparación
/// es "Confirmado", no "En camino".
///
/// El pago se lee solo de `financial_status` (campo [OrderSummary.status]).
/// Únicamente `paid` es "Confirmado". `pending` (transferencia o depósito
/// en espera) es "Esperando tu transferencia". Reembolsos y anulaciones
/// conservan "Con ajuste". Cualquier otro valor, vacío o desconocido, es
/// "Pago en proceso" — nunca "Confirmado".
library;

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
/// explica la evidencia sin prometer seguimiento inexistente.
class OrderDisplayStatus {
  const OrderDisplayStatus({
    required this.key,
    required this.label,
    required this.detail,
  });

  final String key;
  final String label;
  final String detail;
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
  final fulfillment = order.fulfillmentStatus?.toLowerCase().trim();
  switch (fulfillment) {
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
  }
  return _statusFromFinancial(order.status);
}

/// Clasificación estricta de `financial_status` de Shopify.
///
/// `paid`, `pending`, `adjusted` o `in_progress`. No usa subcadenas: así
/// `partially_paid` no cuenta como pagado ni un valor desconocido como
/// confirmado. Vacío, `null` y `unknown` (el valor que persiste el
/// repositorio cuando Shopify no manda estado) son `in_progress`.
String orderFinancialBucket(String? raw) {
  switch (_normalizeFinancial(raw)) {
    case 'paid':
      return 'paid';
    case 'partially_refunded':
    case 'refunded':
    case 'voided':
    case 'cancelled':
    case 'canceled':
      return 'adjusted';
    case 'pending':
      return 'pending';
    default:
      return 'in_progress';
  }
}

String _normalizeFinancial(String? raw) =>
    (raw ?? '').toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');

OrderDisplayStatus _statusFromFinancial(String? raw) {
  switch (orderFinancialBucket(raw)) {
    case 'paid':
      return const OrderDisplayStatus(
        key: 'confirmed',
        label: 'Confirmado',
        detail: 'Tu pedido está confirmado y en preparación. Te avisaremos '
            'cuando se envíe.',
      );
    case 'adjusted':
      return const OrderDisplayStatus(
        key: 'adjusted',
        label: 'Con ajuste',
        detail: 'Este pedido tiene una cancelación o devolución registrada. '
            'El importe final está en tu confirmación de Shopify.',
      );
    case 'pending':
      return const OrderDisplayStatus(
        key: 'awaiting_transfer',
        label: 'Esperando tu transferencia',
        detail: 'El pago por transferencia o depósito sigue pendiente. '
            'El pedido no queda confirmado hasta que Shopify registre el pago.',
      );
    default:
      // authorized, partially_paid, expired, unknown, vacío y cualquier
      // valor que Shopify no liste: el pago no está confirmado.
      return const OrderDisplayStatus(
        key: 'payment_in_progress',
        label: 'Pago en proceso',
        detail: 'Shopify todavía no reporta el pago de este pedido.',
      );
  }
}

bool _isDelivered(OrderSummary order) =>
    order.source != 'whatsapp_apartado' &&
    order.fulfillmentStatus?.toLowerCase().trim() == 'delivered';

bool _isInTransit(OrderSummary order) {
  if (order.source == 'whatsapp_apartado') return false;
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
