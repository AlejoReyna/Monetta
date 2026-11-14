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

  testWidgets('presents the Correction 5 invitation and real access callback', (
    tester,
  ) async {
    var registerCalls = 0;
    await tester.pumpWidget(app(onRegister: () => registerCalls++));

    expect(find.text('Regístrate en MONETTA REWARDS'), findsOneWidget);
    expect(find.textContaining('ENVÍO GRATIS', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('GANA CASHBACK', findRichText: true),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-register-button')));
    expect(registerCalls, 1);
  });

  testWidgets('uses account copy instead of registration copy when signed in', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(onRegister: () {}, isSignedIn: true),
    );

    expect(find.text('Ver mi cuenta'), findsOneWidget);
    expect(find.text('Regístrate en MONETTA REWARDS'), findsOneWidget);
  });

  testWidgets('keeps payment logos off and never guesses active methods', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(onRegister: () {}, width: 320));

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.apple), findsNothing);
    expect(find.textContaining('Visa'), findsNothing);
    expect(find.textContaining('PayPal'), findsNothing);
    semantics.dispose();
  });
}
