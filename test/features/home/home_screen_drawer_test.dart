import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore();
  await store.loadFromAsset();
  return store;
}

Widget _app(CatalogStore store) {
  return MaterialApp(
    home: StoreScope(
      notifier: store,
      child: ExternalCatalogScope(
        notifier: ExternalCatalogController(
          config: ExternalCatalogConfig.disabled,
        ),
        child: const HomeScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'the hamburger opens a lateral drawer with "Inicio" and "Ajustar mis gustos"',
      (tester) async {
    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    // The onboarding sheet opens on first frame; dismiss it before poking
    // at the menu underneath.
    await tester.tap(find.text('VER TODO'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Ajustar mis gustos'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets(
      'tapping "Ajustar mis gustos" closes the drawer and opens onboarding',
      (tester) async {
    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VER TODO'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajustar mis gustos'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
    expect(find.text('¿Qué le gusta?'), findsOneWidget);
  });

  testWidgets('tapping "Inicio" just closes the drawer', (tester) async {
    final store = await _loadedStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VER TODO'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsNothing);
    expect(find.text('¿Qué le gusta?'), findsNothing);
  });
}
