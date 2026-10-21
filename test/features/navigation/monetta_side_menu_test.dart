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
    expect(find.text('Nuestra historia'), findsOneWidget);
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
    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Comparte el catálogo y gana'), findsOneWidget);
    expect(find.text('Contacto por WhatsApp'), findsOneWidget);
    expect(find.byKey(const Key('side-menu-social-instagram')), findsOneWidget);

    await tester.tap(find.byKey(const Key('side-menu-categories')));
    await tester.pumpAndSettle();
    expect(opened, ['categories']);

    await open();
    await tester.tap(find.byKey(const Key('side-menu-notifications')));
    await tester.pumpAndSettle();
    expect(opened, ['categories', 'notifications']);

    await open();
    await tester.tap(find.byKey(const Key('side-menu-share-button')));
    await tester.pumpAndSettle();
    expect(opened, ['categories', 'notifications', 'share']);

    await open();
    await tester.ensureVisible(find.byKey(const Key('side-menu-whatsapp')));
    await tester.tap(find.byKey(const Key('side-menu-whatsapp')));
    await tester.pumpAndSettle();
    expect(opened, ['categories', 'notifications', 'share', 'whatsapp']);

    await open();
    await tester
        .ensureVisible(find.byKey(const Key('side-menu-social-instagram')));
    await tester.tap(find.byKey(const Key('side-menu-social-instagram')));
    await tester.pumpAndSettle();
    expect(social.single.toString(), contains('instagram.com'));
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
