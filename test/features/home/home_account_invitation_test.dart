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

  testWidgets('presents account action without unapproved shipping promises', (
    tester,
  ) async {
    var registerCalls = 0;
    await tester.pumpWidget(app(onRegister: () => registerCalls++));

    expect(find.text('REGÍSTRATE'), findsOneWidget);
    expect(find.text('Consulta tus pedidos y datos de compra'), findsOneWidget);
    expect(
      find.textContaining('contenido pendiente de aprobación'),
      findsOneWidget,
    );
    expect(find.text('Pagos seguros con Shopify.'), findsOneWidget);

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

  testWidgets('keeps payment logos off and never guesses active methods', (
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
        'Pagos seguros con Shopify.',
      ),
    );
    expect(find.byIcon(Icons.apple), findsNothing);
    expect(find.textContaining('Visa'), findsNothing);
    expect(find.textContaining('PayPal'), findsNothing);
    semantics.dispose();
  });
}
