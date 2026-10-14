import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/account/account_boutique.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';

OrderSummary _order({
  String id = 'gid://shopify/Order/1',
  String? displayNumber = '#1001',
  String? fulfillmentStatus = 'fulfilled',
  String? shopifyOrderId = 'gid://shopify/Order/1',
  String source = 'shopify_checkout',
  String? attributionCode,
  String status = 'paid',
  String? paymentMethod,
  double total = 11480,
}) =>
    OrderSummary(
      id: id,
      accountId: 'acct-1',
      displayNumber: displayNumber,
      fulfillmentStatus: fulfillmentStatus,
      shopifyOrderId: shopifyOrderId,
      source: source,
      attributionCode: attributionCode,
      status: status,
      paymentMethod: paymentMethod,
      totalAmount: total,
      currencyCode: 'MXN',
      placedAt: DateTime.utc(2026, 5, 12),
    );

Widget _host(OrderSummary order, {FakeRewardsReader? reader}) => MaterialApp(
      theme: buildTheme(),
      home: OrderDetailScreen(order: order, rewardsReader: reader),
    );

void main() {
  group('OrderDetailScreen', () {
    testWidgets('shows the real identity and total without inventing lines',
        (tester) async {
      await tester.pumpWidget(_host(_order()));
      await tester.pumpAndSettle();

      expect(find.text('#1001'), findsWidgets);
      expect(find.textContaining('11,480'), findsWidgets);
      expect(find.text('Compra en Shopify'), findsOneWidget);
      // Sin líneas por pieza: estado honesto, sin guías inventadas.
      expect(
        find.textContaining('El detalle por pieza aún no está disponible'),
        findsOneWidget,
      );
      expect(find.textContaining('guía'), findsWidgets);
      expect(find.textContaining('MON12345'), findsNothing);
      expect(find.textContaining('DHL'), findsNothing);
      expect(find.textContaining('Estafeta'), findsNothing);
    });

    testWidgets('pending transfer is not shown as paid', (tester) async {
      await tester.pumpWidget(
        _host(
          _order(
            fulfillmentStatus: null,
            status: 'pending',
            paymentMethod: 'bank_deposit',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Esperando tu transferencia'), findsWidgets);
      expect(
        find.textContaining('Lo verás aquí cuando se confirme.'),
        findsWidgets,
      );
      expect(find.text('Confirmado'), findsNothing);
      expect(find.text('Pago confirmado'), findsNothing);
    });

    testWidgets('pending card payment is Pago en proceso', (tester) async {
      await tester.pumpWidget(
        _host(
          _order(
            fulfillmentStatus: null,
            status: 'pending',
            paymentMethod: 'card',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pago en proceso'), findsWidgets);
      expect(find.text('Lo verás aquí cuando se confirme.'), findsWidgets);
      expect(find.text('Esperando tu transferencia'), findsNothing);
      expect(find.text('Confirmado'), findsNothing);
    });

    testWidgets('unknown financial status is payment in progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_order(fulfillmentStatus: null, status: 'unknown')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pago en proceso'), findsWidgets);
      expect(find.text('Confirmado'), findsNothing);
      expect(find.text('Pago confirmado'), findsNothing);
    });

    testWidgets('partially paid is not a confirmed payment', (tester) async {
      await tester.pumpWidget(
        _host(_order(fulfillmentStatus: null, status: 'partially_paid')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pago en proceso'), findsWidgets);
      expect(find.text('Pago confirmado'), findsNothing);
      expect(find.text('Confirmado'), findsNothing);
    });

    testWidgets('shipped refund is not shown as on the way', (tester) async {
      await tester.pumpWidget(
        _host(
          _order(
            fulfillmentStatus: 'shipped',
            status: 'refunded',
            total: 11480,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reembolsado'), findsWidgets);
      expect(find.textContaining('Te devolvimos'), findsWidgets);
      expect(find.textContaining('a tu método de pago.'), findsWidgets);
      expect(find.text('En camino'), findsNothing);
      expect(find.text('Pedido enviado'), findsNothing);
      expect(find.text('Confirmado'), findsNothing);

      final capsule = find.byType(EStatusCapsule);
      final box = tester.widget<Container>(
        find.descendant(of: capsule, matching: find.byType(Container)).first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, isNot(MonettaColors.light.success));
      expect(decoration.color, isNot(MonettaColors.light.successSurface));
    });

    testWidgets('shipped cancellation is not shown as on the way', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_order(fulfillmentStatus: 'shipped', status: 'cancelled')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancelado'), findsWidgets);
      expect(find.text('En camino'), findsNothing);
      expect(find.text('Pedido enviado'), findsNothing);
    });

    testWidgets('enviado is never presented as entregado', (tester) async {
      await tester.pumpWidget(_host(_order()));
      await tester.pumpAndSettle();

      expect(find.text('Pedido enviado'), findsOneWidget);
      expect(find.text('Pedido entregado'), findsNothing);
      expect(
        find.text(
          'Enviado no significa entregado: la entrega se marca solo con '
          'confirmación del transportista.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('delivered evidence renders the delivery event',
        (tester) async {
      await tester.pumpWidget(
        _host(_order(fulfillmentStatus: 'delivered')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pedido entregado'), findsWidgets);
      expect(
        find.text('El transportista confirmó la entrega de tu pedido.'),
        findsWidgets,
      );
    });

    testWidgets('apartado shows attribution and a WhatsApp follow-up',
        (tester) async {
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: OrderDetailScreen(
            order: _order(
              id: 'apartado:9',
              displayNumber: null,
              fulfillmentStatus: null,
              shopifyOrderId: null,
              source: 'whatsapp_apartado',
              attributionCode: 'MN-7K3Q',
              status: 'pending',
              total: 400,
            ),
            openUri: (uri) async {
              opened = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MN-7K3Q'), findsWidgets);
      expect(find.text('Apartado por WhatsApp'), findsOneWidget);
      expect(find.text('Apartado registrado'), findsOneWidget);

      final cta = find.text('Escribir por WhatsApp');
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(opened, isNotNull);
      expect(opened!.host, 'wa.me');
      expect(opened!.path, contains('528261066868'));
    });

    testWidgets('rewards relation is independent of the order', (
      tester,
    ) async {
      final reader = FakeRewardsReader(
        perOrder: {
          'gid://shopify/Order/1': const OrderRewardsState(
            orderShopifyId: 'gid://shopify/Order/1',
            isWholesale: false,
            earnedPendingCents: 5400,
            earnedReleasedCents: 0,
            usedCents: 0,
            state: 'pending',
          ),
        },
      );
      await tester.pumpWidget(_host(_order(), reader: reader));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('order-rewards-status')),
        findsOneWidget,
      );

      // Sin lector ni backend, el pedido sigue completo.
      await tester.pumpWidget(_host(_order()));
      await tester.pumpAndSettle();
      expect(find.text('#1001'), findsWidgets);
      expect(
        find.byKey(const ValueKey('order-rewards-status')),
        findsNothing,
      );
    });

    testWidgets('failed WhatsApp open explains itself', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: OrderDetailScreen(
            order: _order(),
            openUri: (_) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cta = find.text('Escribir por WhatsApp');
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
    });
  });
}
