import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/navigation/monetta_side_menu.dart';

Widget _menu({
  bool isSignedIn = false,
  String? accountName,
  String? accountEmail,
  VoidCallback? onAccount,
  VoidCallback? onSettings,
}) {
  void doNothing() {}
  return MaterialApp(
    home: Scaffold(
      body: MonettaSideMenu(
        onCatalog: doNothing,
        onBags: doNothing,
        onWallets: doNothing,
        onWatches: doNothing,
        onPerfumes: doNothing,
        onBeauty: doNothing,
        onAbout: doNothing,
        onPartner: doNothing,
        onSupport: doNothing,
        isSignedIn: isSignedIn,
        accountName: accountName,
        accountEmail: accountEmail,
        onAccount: onAccount,
        onSettings: onSettings,
      ),
    ),
  );
}

void main() {
  testWidgets('links are plain icon rows with no separators', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(_menu(onSettings: () {}));

    final menu = find.byKey(const Key('monetta-side-menu'));
    for (final label in [
      'Bolsas',
      'Carteras',
      'Relojes',
      'Perfumes',
      'Maquillaje y skincare',
      'Todas las marcas',
      'Vende con Monetta',
      'Contacto',
      'Nuestra historia',
      'Ajustes',
    ]) {
      expect(
        find.descendant(of: menu, matching: find.text(label)),
        findsOneWidget,
        reason: 'missing link $label',
      );
    }
    for (final icon in [
      Symbols.shopping_bag,
      Symbols.account_balance_wallet,
      Symbols.watch,
      Symbols.spa,
      Symbols.face,
      Symbols.storefront,
      Symbols.handshake,
      Symbols.chat_bubble,
      Symbols.auto_stories,
      Symbols.settings,
    ]) {
      expect(
        find.descendant(of: menu, matching: find.byIcon(icon)),
        findsOneWidget,
        reason: 'missing icon $icon',
      );
      final glyph = tester.widget<Icon>(
        find.descendant(of: menu, matching: find.byIcon(icon)),
      );
      expect(glyph.weight, 300, reason: 'light stroke for $icon');
    }
    for (final label in ['Bolsas', 'Ajustes']) {
      final style = tester
          .widget<Text>(find.descendant(of: menu, matching: find.text(label)))
          .style!;
      expect(style.fontFamily, kBoutiqueSerifFamily);
      expect(style.fontWeight, FontWeight.w400);
    }
    expect(find.text('Mayoreo'), findsNothing);
    // "Vende con Monetta" follows "Todas las marcas".
    expect(
      tester.getTopLeft(find.text('Vende con Monetta')).dy,
      greaterThan(tester.getTopLeft(find.text('Todas las marcas')).dy),
    );
    // Contacto, Nuestra historia and Ajustes form the block at the foot.
    final footer = find.byKey(const Key('side-menu-footer'));
    for (final label in ['Contacto', 'Nuestra historia', 'Ajustes']) {
      expect(
        find.descendant(of: footer, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      tester.getBottomLeft(footer).dy,
      greaterThan(tester.getBottomLeft(menu).dy - 60),
    );
    expect(find.text('Buscar una pieza'), findsNothing);
    expect(find.byKey(const Key('side-menu-search')), findsNothing);
    expect(
      find.descendant(of: menu, matching: find.byType(Divider)),
      findsNothing,
    );
    expect(find.text('TIENDA'), findsNothing);
    expect(find.text('MÁS DE MONETTA'), findsNothing);
  });

  testWidgets('ajustes gear row delegates to the settings callback', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    var settingsCalls = 0;
    await tester.pumpWidget(_menu(onSettings: () => settingsCalls++));

    await tester.tap(find.byKey(const Key('side-menu-settings')));
    await tester.pump();
    expect(settingsCalls, 1);
  });

  testWidgets('without a settings callback there is no ajustes row', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(_menu());

    expect(find.text('Ajustes'), findsNothing);
    expect(find.byKey(const Key('side-menu-settings')), findsNothing);
  });

  testWidgets('signed out shows a sign-in entry that opens the account flow',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    var accountCalls = 0;
    await tester.pumpWidget(
      _menu(isSignedIn: false, onAccount: () => accountCalls++),
    );

    expect(find.text('Inicia sesión'), findsOneWidget);
    expect(find.byKey(const Key('side-menu-account')), findsNothing);

    await tester.tap(find.byKey(const Key('side-menu-sign-in')));
    await tester.pump();
    expect(accountCalls, 1);
  });

  testWidgets('signed in shows the shopper data that opens the account hub',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    var accountCalls = 0;
    await tester.pumpWidget(
      _menu(
        isSignedIn: true,
        accountName: 'Alexis Reyna',
        accountEmail: 'alexis@example.com',
        onAccount: () => accountCalls++,
      ),
    );

    expect(find.text('Inicia sesión'), findsNothing);
    expect(find.text('Alexis Reyna'), findsOneWidget);
    expect(find.text('alexis@example.com'), findsOneWidget);

    await tester.tap(find.byKey(const Key('side-menu-account')));
    await tester.pump();
    expect(accountCalls, 1);
  });

  testWidgets('without an account callback there is no account header', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(_menu());

    expect(find.text('Inicia sesión'), findsNothing);
    expect(find.byKey(const Key('side-menu-account')), findsNothing);
    expect(find.byKey(const Key('side-menu-sign-in')), findsNothing);
  });
}
