import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/home/home_account_invitation.dart';

void main() {
  testWidgets('validates and retains email after access failure',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: HomeAccountInvitation(
                    onRegister: null,
                    onEmailRegister: (email) async {
                      calls++;
                      return 'No disponible';
                    })))));
    await tester.tap(find.text('Registrarme'));
    await tester.pump();
    expect(find.text('Introduce un correo válido.'), findsOneWidget);
    expect(calls, 0);
    await tester.enterText(find.byType(TextField), 'shopper@example.com');
    await tester.tap(find.text('Registrarme'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('shopper@example.com'), findsOneWidget);
  });
}
