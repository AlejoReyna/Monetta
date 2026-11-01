import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/navigation/monetta_side_menu.dart';

MonettaSideMenu _menu(List<String> calls) => MonettaSideMenu(
      onSearch: () => calls.add('search'),
      onCatalog: () => calls.add('brands'),
      onBags: () => calls.add('bags'),
      onWallets: () => calls.add('wallets'),
      onWatches: () => calls.add('watches'),
      onPerfumes: () => calls.add('perfumes'),
      onBeauty: () => calls.add('beauty'),
      onToggleTheme: () {},
      onAbout: () => calls.add('about'),
      onPartner: () => calls.add('partner'),
      onSupport: () => calls.add('support'),
      onShare: () => calls.add('share'),
    );

void main() {
  testWidgets(
      'MENU-MAYOREO lists Mayoreo right below Todas las marcas and before the share card',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _menu(<String>[]))),
    );

    final wholesale = find.byKey(const Key('side-menu-wholesale'));
    expect(wholesale, findsOneWidget);
    expect(
      find.descendant(of: wholesale, matching: find.text('Mayoreo')),
      findsOneWidget,
    );

    final brandsTop =
        tester.getTopLeft(find.byKey(const Key('side-menu-brands'))).dy;
    final wholesaleTop = tester.getTopLeft(wholesale).dy;
    final shareTop =
        tester.getTopLeft(find.byKey(const Key('side-menu-share'))).dy;
    expect(wholesaleTop, greaterThan(brandsTop));
    expect(shareTop, greaterThan(wholesaleTop));

    // No other menu link sits between «Todas las marcas» and «Mayoreo».
    final links = [
      for (final id in [
        'bags',
        'wallets',
        'watches',
        'perfumes',
        'brands',
        'wholesale',
      ])
        tester.getTopLeft(find.byKey(Key('side-menu-$id'))).dy,
    ];
    final sorted = [...links]..sort();
    expect(links, sorted, reason: 'links keep the guide order');
    expect(links.last, wholesaleTop);
    expect(links[links.length - 2], brandsTop);
  });

  testWidgets(
      'MENU-MAYOREO tapping Mayoreo closes the menu and calls onPartner',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(body: _menu(calls)),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monetta-side-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('side-menu-wholesale')));
    await tester.pumpAndSettle();

    expect(calls, ['partner']);
    expect(find.byKey(const Key('monetta-side-menu')), findsNothing);
  });
}
