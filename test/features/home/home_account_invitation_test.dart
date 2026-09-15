import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/home/home_account_invitation.dart';

void main() {
  Widget app({
    required VoidCallback onRegister,
    double width = 390,
    bool isSignedIn = false,
  }) {
    return MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: HomeAccountInvitation(
              onRegister: onRegister,
              isSignedIn: isSignedIn,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('presents the first-order benefit and account action', (
    tester,
  ) async {
    var registerCalls = 0;
    await tester.pumpWidget(app(onRegister: () => registerCalls++));

    expect(find.text('REGÍSTRATE'), findsOneWidget);
    expect(find.text('Obtén envío gratis en tu primer pedido'), findsOneWidget);
    expect(find.text('ENVÍOS RÁPIDOS Y PAGOS SEGUROS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-register-button')));
    expect(registerCalls, 1);
  });

  testWidgets('uses account copy instead of registration copy when signed in', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(onRegister: () {}, isSignedIn: true),
    );

    expect(find.text('TU CUENTA'), findsOneWidget);
    expect(find.text('VER MI CUENTA'), findsOneWidget);
    expect(find.text('REGÍSTRATE'), findsNothing);
  });

  testWidgets('keeps every payment method on a narrow home viewport', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(onRegister: () {}, width: 320));

    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('home-payment-methods')))
          .label,
      contains(
        'Apple Pay, Google Pay, Maestro, Mastercard, PayPal, Shop Pay y Visa',
      ),
    );
    semantics.dispose();
  });
}
