import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';
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
    child: ExternalCatalogScope(
      notifier: ExternalCatalogController(
        config: ExternalCatalogConfig.disabled,
      ),
      child: const HomeScreen(),
    ),
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

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.text('BÚSQUEDAS FRECUENTES'), findsOneWidget);
    expect(find.text('Piezas que buscan más'), findsOneWidget);
    expect(find.text('Coach'), findsWidgets);
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
    expect(find.text('Buscar una pieza'), findsOneWidget);
    expect(find.text('Bolsas'), findsOneWidget);
    expect(find.text('Carteras'), findsOneWidget);
    expect(find.text('Relojes'), findsOneWidget);
    expect(find.text('Perfumes'), findsOneWidget);
    expect(find.text('Maquillaje y skincare'), findsOneWidget);
    expect(find.text('Todas las marcas'), findsOneWidget);
    expect(find.text('Mayoreo'), findsOneWidget);
    expect(find.text('Contacto'), findsOneWidget);
    expect(find.text('Todo lo que buscas,\nen un solo lugar.'), findsNothing);
    expect(find.text('Explorar catálogo'), findsNothing);
    expect(find.text('Mi bolsa'), findsNothing);
    expect(find.text('Mi cuenta'), findsNothing);
    expect(find.text('Nuestra historia'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Bolsas')).style?.fontFamily,
      kEditorialFontFamily,
    );
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
    await tester.tap(find.byKey(const Key('side-menu-bags')));
    await tester.pumpAndSettle();

    expect(find.byType(CollectionScreen), findsOneWidget);
    expect(find.text('Bolsas'), findsOneWidget);
  });

  testWidgets('side-menu search shortcut opens the search experience',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('side-menu-search')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
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

    expect(find.text('ENVÍO GRATIS ESTE FIN DE SEMANA'), findsNothing);
    expect(find.text('Novedades'), findsNothing);
    expect(find.byKey(const Key('campaign-hero')), findsNothing);
  });
}
