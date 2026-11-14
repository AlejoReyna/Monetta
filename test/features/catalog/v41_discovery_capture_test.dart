// Local, fixed-viewport fixture captures. No golden approvals or live services.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/brands_screen.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/categories_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/navigation/monetta_side_menu.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/main.dart';
import '../../support/client_guide_capture.dart';
import 'v41_discovery_fixture.dart';
import 'v41_discovery_test.dart' show tapVisible;

const _out = 'docs/remediation/v41/evidence/A04';
Future<void> captureDiscovery(WidgetTester tester, String name) async {
  await tester.pump();
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    final image = await (view.debugLayer! as OffsetLayer)
        .toImage(view.paintBounds, pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_out).create(recursive: true);
    await File('$_out/$name-fixture.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

MonettaSideMenu fixtureMenu() => MonettaSideMenu(
      onSearch: () {},
      onCatalog: () {},
      onBags: () {},
      onWallets: () {},
      onWatches: () {},
      onPerfumes: () {},
      onBeauty: () {},
      onToggleTheme: () {},
      onAbout: () {},
      onPartner: () {},
      onSupport: () {},
      onAccount: () {},
      identityName: 'Ana',
      balanceLabel: r'$123 Monetta',
      onWhatsApp: () {},
      onOpenSocial: (_) {},
      socialLinks: const [
        HomeSocialLink(
          id: 'instagram',
          label: 'Instagram',
          url: 'https://fixture.invalid/instagram',
        ),
        HomeSocialLink(
          id: 'tiktok',
          label: 'TikTok',
          url: 'https://fixture.invalid/tiktok',
        ),
        HomeSocialLink(
          id: 'facebook',
          label: 'Facebook',
          url: 'https://fixture.invalid/facebook',
        ),
      ],
    );
void main() {
  for (final (width, height, scale) in [
    (390.0, 844.0, 1.0),
    (320.0, 900.0, 2.0),
    (768.0, 1024.0, 1.0),
    (1440.0, 1000.0, 1.0),
  ]) {
    for (final surface in [
      'categories',
      'categories-open',
      'brands',
      'collection',
      'brand',
      'catalog',
      'search',
      'filters',
      'sort',
      'filtered',
      'empty',
      'error',
      'sidebar',
    ]) {
      if (width > 390 &&
          !['categories-open', 'brands', 'filters', 'sidebar']
              .contains(surface)) {
        continue;
      }
      testWidgets('A04 $surface $width text $scale', (tester) async {
        final store = await discoveryStore();
        if (surface == 'error') {
          store.realtimeStatus = CatalogRealtimeStatus.invalid;
        }
        final Widget screen = switch (surface) {
          'categories' || 'categories-open' => const CategoriesScreen(),
          'brands' => const BrandsScreen(),
          'brand' => const BrandScreen(brandSlug: 'guess'),
          'catalog' => CatalogBrowseScreen(items: store.catalogItems),
          'search' => const SearchScreen(initialQuery: 'guess'),
          'sidebar' => Scaffold(body: fixtureMenu()),
          _ => const CollectionScreen(
              title: 'Bolsos',
              filter: CollectionFilter(category: 'bolsa'),
            ),
        };
        await pumpClientGuide(
          tester,
          StoreScope(notifier: store, child: screen),
          size: Size(width, height),
          textScale: scale,
        );
        if (surface == 'categories-open') {
          await tapVisible(
            tester,
            find.byKey(const PageStorageKey('category-bags')),
          );
          await tapVisible(
            tester,
            find.byKey(const PageStorageKey('category-bags-women')),
          );
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
        }
        if (surface == 'filters') {
          await tapVisible(
            tester,
            find.byKey(const Key('collection-filter-button')),
          );
        }
        if (surface == 'sort') {
          await tapVisible(
            tester,
            find.byKey(const Key('collection-sort-button')),
          );
        }
        if (surface == 'filtered') {
          await tapVisible(
            tester,
            find.byKey(const Key('collection-filter-button')),
          );
          await tapVisible(
            tester,
            find.byKey(const Key('collection-filter-offers')),
          );
          await tapVisible(
            tester,
            find.byKey(const Key('collection-filter-apply')),
          );
        }
        if (surface == 'empty') {
          await tester.enterText(
            find.byKey(const Key('collection-local-search')),
            'no such piece',
          );
          await tester.pumpAndSettle();
        }
        await captureDiscovery(
          tester,
          '$surface-${width.toInt()}-${scale.toInt()}x',
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final surface in ['filters', 'sidebar', 'brands']) {
    testWidgets('A04 dark $surface 390', (tester) async {
      final store = await discoveryStore();
      final screen = surface == 'sidebar'
          ? Scaffold(body: fixtureMenu())
          : surface == 'brands'
              ? const BrandsScreen()
              : const CollectionScreen(
                  title: 'Bolsos',
                  filter: CollectionFilter(category: 'bolsa'),
                );
      await pumpClientGuide(
        tester,
        StoreScope(notifier: store, child: screen),
        brightness: Brightness.dark,
      );
      if (surface == 'filters') {
        await tapVisible(
          tester,
          find.byKey(const Key('collection-filter-button')),
        );
      }
      await captureDiscovery(tester, '$surface-dark-390-1x');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('A04 keyboard and sidebar tail 320/200', (tester) async {
    final store = await discoveryStore();
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: const CollectionScreen(title: 'Bolsos'),
      ),
      size: const Size(320, 900),
      textScale: 2,
    );
    await tapVisible(tester, find.byKey(const Key('collection-filter-button')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await captureDiscovery(tester, 'filters-keyboard-320-2x');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding();
    await pumpClientGuide(
      tester,
      StoreScope(notifier: store, child: Scaffold(body: fixtureMenu())),
      size: const Size(320, 900),
      textScale: 2,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('side-menu-whatsapp')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await captureDiscovery(tester, 'sidebar-tail-320-2x');
    expect(tester.takeException(), isNull);
  });
}
