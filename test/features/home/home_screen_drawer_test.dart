import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
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

  testWidgets('footer "Elige marcas" opens onboarding', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 4000);
    tester.view.devicePixelRatio = 1.0;

    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Elige marcas'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elige marcas'));
    await tester.pumpAndSettle();

    expect(find.text('Elige marcas'), findsWidgets);
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

    expect(find.text('ENVÍO GRATIS ESTE FIN DE SEMANA'), findsOneWidget);
    expect(find.text('Novedades'), findsNothing);
    expect(find.byKey(const Key('campaign-hero')), findsNothing);
  });
}
