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
    await tester.pumpAndSettle();

    expect(find.text('OBTEN TU PRIMER ENVÍO GRATIS'), findsOneWidget);
    expect(find.text('Porque tú lo vales :)'), findsOneWidget);
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
    expect(find.text('OBTEN TU PRIMER ENVÍO GRATIS'), findsNothing);
  });

  double opacity(WidgetTester tester, Key key) => tester
      .widget<FadeTransition>(find.byKey(key, skipOffstage: false))
      .opacity
      .value;

  const revealKey = ValueKey('home-account-invitation-reveal');

  testWidgets(
      'waits for first visibility and does not replay after scrolling away',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final invitationKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
          body: ListView(
        controller: scroll,
        cacheExtent: 500,
        children: [
          const SizedBox(height: 900),
          HomeAccountInvitation(
              key: invitationKey, scrollController: scroll, onRegister: () {}),
          const SizedBox(height: 2000),
        ],
      )),
    ));
    await tester.pump(const Duration(seconds: 2));
    expect(opacity(tester, revealKey), 0);
    final firstState = invitationKey.currentState;
    scroll.jumpTo(900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(opacity(tester, revealKey), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(opacity(tester, revealKey), 1);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    scroll.jumpTo(900);
    await tester.pump();
    expect(invitationKey.currentState, same(firstState));
    expect(opacity(tester, revealKey), 1);
  });

  testWidgets('payment methods appear one by one after the invitation starts',
      (tester) async {
    await tester.pumpWidget(app(onRegister: () {}));
    await tester.pump();
    for (var i = 0; i < 7; i++) {
      expect(opacity(tester, ValueKey('home-payment-reveal-$i')), 0);
    }
    await tester.pump(const Duration(milliseconds: 320));
    expect(opacity(tester, const ValueKey('home-payment-reveal-0')),
        greaterThan(0));
    expect(opacity(tester, const ValueKey('home-payment-reveal-1')), 0);
    await tester.pump(const Duration(milliseconds: 120));
    expect(opacity(tester, const ValueKey('home-payment-reveal-1')),
        greaterThan(0));
    expect(opacity(tester, const ValueKey('home-payment-reveal-2')), 0);
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      expect(opacity(tester, ValueKey('home-payment-reveal-$i')), 1);
    }
  });

  for (final accessibleNavigation in [false, true]) {
    testWidgets(
        'shows everything immediately when motion is reduced (accessible=$accessibleNavigation)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: !accessibleNavigation,
            accessibleNavigation: accessibleNavigation,
          ),
          child: child!,
        ),
        home: Scaffold(body: HomeAccountInvitation(onRegister: () {})),
      ));
      expect(opacity(tester, revealKey), 1);
      for (var i = 0; i < 7; i++) {
        expect(opacity(tester, ValueKey('home-payment-reveal-$i')), 1);
      }
    });
  }

  testWidgets('keeps every payment method on a narrow home viewport', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(onRegister: () {}, width: 320));
    await tester.pumpAndSettle();

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
