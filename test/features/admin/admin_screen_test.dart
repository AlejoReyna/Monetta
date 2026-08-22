import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/admin/admin_screen.dart';

void main() {
  testWidgets('owner panel uses Monetta navigation and exposes source policy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final database = openTestDatabase();
    addTearDown(database.close);
    final catalog = CatalogStore(database: database);
    final external = ExternalCatalogController(
      config: ExternalCatalogConfig.disabled,
    );
    addTearDown(external.dispose);
    final admin = AdminController(
      config: const AdminConfig(
        baseUrl: null,
        ownerEmails: {'duena@monetta.mx'},
        previewEnabled: true,
      ),
    );
    addTearDown(admin.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: AdminScreen(
          controller: admin,
          catalogStore: catalog,
          externalCatalogController: external,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todo Monetta,\nen un solo lugar.'), findsOneWidget);
    expect(find.text('VISTA PREVIA'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-sync-all')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('admin-section-3')));
    await tester.pumpAndSettle();

    expect(find.text('Fuentes'), findsWidgets);
    expect(find.text('Marc Jacobs'), findsOneWidget);
    expect(find.text('GP McAllen · Perfumes'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('admin-source-marc_jacobs_us')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Monitorear esta fuente'), findsOneWidget);
    expect(find.text('Comisión alta gama'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-save-source')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
