import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/app/theme_controller.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/data/local/appearance_store.dart';
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

Widget _themedApp(CatalogStore store, ThemeController themeController) {
  final home = StoreScope(
    notifier: store,
    child: const HomeScreen(),
  );
  return ListenableBuilder(
    listenable: themeController,
    builder: (context, _) => ThemeScope(
      notifier: themeController,
      child: MaterialApp(
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: themeController.mode,
        home: home,
      ),
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

    await tester.tap(find.byKey(const ValueKey('home-search-bar')));
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
    expect(menuText('Buscar una pieza'), findsNothing);
    expect(menuText('Bolsas'), findsOneWidget);
    expect(menuText('Carteras'), findsOneWidget);
    expect(menuText('Relojes'), findsOneWidget);
    expect(menuText('Perfumes'), findsOneWidget);
    expect(menuText('Maquillaje y skincare'), findsOneWidget);
    expect(menuText('Todas las marcas'), findsOneWidget);
    expect(menuText('Vende con Monetta'), findsOneWidget);
    expect(menuText('Contacto'), findsOneWidget);
    expect(menuText('TIENDA'), findsNothing);
    expect(menuText('MÁS DE MONETTA'), findsNothing);
    expect(menuText('Mis notificaciones'), findsNothing);
    // Links are plain icon rows with no separators; settings live behind
    // the "Ajustes" gear row.
    expect(menuText('Ajustes'), findsOneWidget);
    expect(find.byKey(const Key('side-menu-settings')), findsOneWidget);
    expect(
      find.descendant(of: menu, matching: find.byIcon(Symbols.settings)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menu, matching: find.byIcon(Symbols.shopping_bag)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menu, matching: find.byType(Divider)),
      findsNothing,
    );
    // Signed out: the drawer offers a sign-in entry instead of user data.
    expect(menuText('Inicia sesión'), findsOneWidget);
    expect(find.text('Todo lo que buscas,\nen un solo lugar.'), findsNothing);
    expect(find.text('Explorar catálogo'), findsNothing);
    expect(find.text('Mi bolsa'), findsNothing);
    expect(find.text('Mi cuenta'), findsNothing);
    expect(menuText('Nuestra historia'), findsOneWidget);
    expect(
      tester.widget<Text>(menuText('Bolsas')).style?.fontFamily,
      kSerifFontFamily,
    );
  });

  testWidgets('side-menu ajustes open the appearance options', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    final appearanceDatabase = openTestDatabase();
    final themeController = ThemeController(
      store: AppearanceStore(appearanceDatabase),
    );
    addTearDown(store.dispose);
    addTearDown(themeController.dispose);
    addTearDown(appearanceDatabase.close);
    await themeController.setMode(ThemeMode.light);

    await tester.pumpWidget(_themedApp(store, themeController));
    await tester.pump();
    await tester.tap(find.byKey(const Key('home-menu-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('side-menu-settings')));
    await tester.pumpAndSettle();

    expect(find.text('Preferencias de la app'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-appearance')));
    await tester.pumpAndSettle();

    expect(find.text('Elige cómo se ve Monetta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('appearance-dark')));
    await tester.pumpAndSettle();

    expect(themeController.mode, ThemeMode.dark);
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
    // showHero:false hides the marketing banner, not the search entry: the
    // discovery header (and its in-page search field, also used as the
    // collapse-transition drag handle) stays so navigation never loses
    // search; only the hero goes away.
    expect(
      find.byKey(const ValueKey('home-discovery-header')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-compact-hero')), findsNothing);
  });
}
