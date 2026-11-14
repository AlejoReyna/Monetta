import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/domain/admin_control.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store, {AdminController? admin}) {
  final home = StoreScope(
    notifier: store,
    child: const HomeScreen(),
  );
  return MaterialApp(
    home: admin == null
        ? home
        : AdminScope(
            notifier: admin,
            child: home,
          ),
  );
}

void main() {
  testWidgets('search in the header opens a branded search page',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.byType(SearchScreen), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-appbar-search-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('search-query-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-empty-state')), findsOneWidget);
    expect(find.text('BÚSQUEDAS FRECUENTES'), findsNothing);
    expect(find.text('Piezas que buscan más'), findsNothing);
  });

  testWidgets('premium side menu exposes useful shopper shortcuts',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    expect(find.byKey(const Key('monetta-side-menu')), findsNothing);

    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('monetta-side-menu')), findsOneWidget);
    final menu = find.byKey(const Key('monetta-side-menu'));
    Finder menuText(String text) =>
        find.descendant(of: menu, matching: find.text(text));
    // UI v4.1 menu: the five families, all brands, wholesale, social and the
    // WhatsApp contact. No search, no theme switch, no story.
    for (final label in [
      'Bolsos',
      'Carteras',
      'Perfumes',
      'Calzado',
      'Accesorios',
      'Todas las marcas',
      'Mayoreo',
      'Contactar por WhatsApp',
    ]) {
      expect(menuText(label), findsOneWidget, reason: label);
    }
    expect(menuText('Buscar una pieza'), findsNothing);
    expect(menuText('Nuestra historia'), findsNothing);
    expect(menuText('Apariencia'), findsNothing);
    expect(find.byKey(const Key('side-menu-appearance')), findsNothing);
  });

  testWidgets('storefront menu opens its matching internal collection',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bolsos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-open-bags')));
    await tester.pumpAndSettle();

    expect(find.byType(CollectionScreen), findsOneWidget);
    expect(find.text('Bolsos'), findsWidgets);
  });

  testWidgets('side menu no longer carries a search field', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('side-menu-search')), findsNothing);
    expect(find.byKey(const Key('side-menu-categories')), findsNothing);
  });

  testWidgets('owner storefront settings are reflected in the app home', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final admin = AdminController(
      config: const AdminConfig(
        baseUrl: null,
        ownerEmails: {'owner@example.com'},
        previewEnabled: true,
      ),
    );
    addTearDown(admin.dispose);
    await admin.saveStorefront(
      const AdminStorefrontSettings(
        announcement: 'Envío gratis este fin de semana',
        showHero: false,
        showNewest: false,
        showExternalPicks: false,
      ),
    );

    await tester.pumpWidget(_app(store, admin: admin));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Sin resultados'), findsNothing);

    expect(find.text('ENVÍO GRATIS ESTE FIN DE SEMANA'), findsNothing);
    expect(find.text('Novedades'), findsNothing);
    // showHero:false hides the marketing banner. Search stays in the header.
    expect(
      find.byKey(const ValueKey('home-discovery-header')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-compact-hero')), findsNothing);
  });
}
