import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/navigation/monetta_side_menu.dart';

import '../../support/client_guide_capture.dart';

void main() {
  testWidgets('shows only navigation links and a direct theme toggle', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    void doNothing() {}
    var themeToggleCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonettaSideMenu(
            onSearch: doNothing,
            onCatalog: doNothing,
            onBags: doNothing,
            onWallets: doNothing,
            onWatches: doNothing,
            onPerfumes: doNothing,
            onBeauty: doNothing,
            onToggleTheme: () => themeToggleCalls++,
            onAbout: doNothing,
            onPartner: doNothing,
            onSupport: doNothing,
          ),
        ),
      ),
    );

    expect(find.text('Bolsas'), findsOneWidget);
    expect(find.text('Nuestra historia'), findsNothing);
    expect(find.text('TIENDA'), findsNothing);
    expect(find.text('MÁS DE MONETTA'), findsNothing);
    expect(find.text('Mis notificaciones'), findsNothing);
    expect(find.text('Apariencia'), findsNothing);
    expect(find.byKey(const Key('side-menu-appearance')), findsOneWidget);
    expect(find.byTooltip('Activar modo oscuro'), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);

    await tester.tap(find.byKey(const Key('side-menu-appearance')));
    expect(themeToggleCalls, 1);
  });

  testWidgets('shows identity, categories, sharing, WhatsApp and social links',
      (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    final opened = <String>[];
    final social = <Uri>[];
    Widget menu() => MonettaSideMenu(
          onSearch: () {},
          onCatalog: () {},
          onCategories: () => opened.add('categories'),
          onBags: () {},
          onWallets: () {},
          onWatches: () {},
          onPerfumes: () {},
          onBeauty: () {},
          onToggleTheme: () {},
          onAbout: () {},
          onPartner: () {},
          onSupport: () {},
          identityName: 'Ana',
          identityDetail: 'ana@example.com',
          onNotifications: () => opened.add('notifications'),
          onShare: () => opened.add('share'),
          onWhatsApp: () => opened.add('whatsapp'),
          socialLinks: HomeContent.fallback.socialLinks,
          onOpenSocial: social.add,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(body: menu()),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    Future<void> open() async {
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsWidgets);
    expect(find.text('Categorías'), findsNothing);
    expect(find.text('Comparte'), findsOneWidget);
    expect(find.text('y gana'), findsOneWidget);
    expect(find.text('Contacto por WhatsApp'), findsOneWidget);
    expect(find.byKey(const Key('side-menu-social-instagram')), findsOneWidget);

    expect(find.byKey(const Key('side-menu-categories')), findsNothing);
    await tester.tap(find.byKey(const Key('side-menu-notifications')));
    await tester.pumpAndSettle();
    expect(opened, ['notifications']);

    await open();
    await tester.tap(find.byKey(const Key('side-menu-share-button')));
    await tester.pumpAndSettle();
    expect(opened, ['notifications', 'share']);

    await open();
    await tester.ensureVisible(find.byKey(const Key('side-menu-whatsapp')));
    await tester.tap(find.byKey(const Key('side-menu-whatsapp')));
    await tester.pumpAndSettle();
    expect(opened, ['notifications', 'share', 'whatsapp']);

    await open();
    await tester
        .ensureVisible(find.byKey(const Key('side-menu-social-instagram')));
    await tester.tap(find.byKey(const Key('side-menu-social-instagram')));
    await tester.pumpAndSettle();
    expect(social.single.toString(), contains('instagram.com'));
  });

  testWidgets('MENU-GUIDE the menu holds exactly the guide items, in order', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    final calls = <String>[];
    final social = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonettaSideMenu(
            onSearch: () => calls.add('search'),
            onCatalog: () => calls.add('brands'),
            onCategories: () => calls.add('categories'),
            onBags: () => calls.add('bags'),
            onWallets: () => calls.add('wallets'),
            onWatches: () => calls.add('watches'),
            onPerfumes: () => calls.add('perfumes'),
            onBeauty: () => calls.add('beauty'),
            onToggleTheme: () {},
            onAbout: () => calls.add('about'),
            onPartner: () => calls.add('partner'),
            onSupport: () => calls.add('support'),
            identityName: 'Ana',
            identityDetail: 'ana@example.com',
            onNotifications: () => calls.add('notifications'),
            onShare: () => calls.add('share'),
            onWhatsApp: () => calls.add('whatsapp'),
            socialLinks: HomeContent.fallback.socialLinks,
            onOpenSocial: social.add,
          ),
        ),
      ),
    );

    // Top: wordmark and the bell; the user row shows initial, name, email.
    expect(find.byKey(const Key('side-menu-notifications')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);

    // The five links, top to bottom.
    final labels = [
      'Bolsas',
      'Carteras',
      'Relojes',
      'Perfumes',
      'Todas las marcas',
    ];
    var previous = -1.0;
    for (final label in labels) {
      final top = tester.getTopLeft(find.text(label)).dy;
      expect(top, greaterThan(previous), reason: label);
      previous = top;
    }
    // Then the share banner, WhatsApp and the three networks, in guide order.
    final share =
        tester.getTopLeft(find.byKey(const Key('side-menu-share'))).dy;
    final whatsapp = tester.getTopLeft(find.text('Contacto por WhatsApp')).dy;
    expect(share, greaterThan(previous));
    expect(whatsapp, greaterThan(share));
    final xs = [
      for (final id in ['tiktok', 'instagram', 'facebook'])
        tester.getCenter(find.byKey(Key('side-menu-social-$id'))).dx,
    ];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));
    expect(
      tester.getCenter(find.byKey(const Key('side-menu-social-tiktok'))).dy,
      greaterThan(whatsapp),
    );

    // What the guide dropped.
    for (final gone in [
      'Buscar una pieza',
      'Categorías',
      'Maquillaje y skincare',
      'Mayoreo',
      'Contacto',
      'Nuestra historia',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.byKey(const Key('side-menu-search')), findsNothing);

    // The share pill keeps the share action.
    final pill = find.byKey(const Key('side-menu-share-button'));
    expect(
      find.descendant(of: pill, matching: find.text('VER CATÁLOGO')),
      findsOneWidget,
    );
    await tester.tap(pill);
    await tester.pump();
    await tester.pump();
    expect(calls, ['share']);
  });

  for (final (size, brightness) in [
    (const Size(390, 1400), Brightness.light),
    (const Size(390, 1400), Brightness.dark),
    (const Size(834, 1400), Brightness.light),
  ]) {
    testWidgets('menu capture ${size.width} ${brightness.name}',
        (tester) async {
      await pumpClientGuide(
        tester,
        MonettaSideMenu(
          onSearch: () {},
          onCatalog: () {},
          onCategories: () {},
          onBags: () {},
          onWallets: () {},
          onWatches: () {},
          onPerfumes: () {},
          onBeauty: () {},
          onToggleTheme: () {},
          onAbout: () {},
          onPartner: () {},
          onSupport: () {},
          identityName: 'Ana',
          identityDetail: 'ana@example.com',
          onNotifications: () {},
          onShare: () {},
          onWhatsApp: () {},
          socialLinks: HomeContent.fallback.socialLinks,
          onOpenSocial: (_) {},
        ),
        size: size,
        brightness: brightness,
      );
      await captureClientGuide(
        tester,
        'menu-${size.width.toInt()}-${brightness.name}',
      );
      expect(find.text('Bolsas'), findsOneWidget);
    });
  }
}
