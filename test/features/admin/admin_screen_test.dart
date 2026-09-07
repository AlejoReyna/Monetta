import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/admin/admin_screen.dart';

void main() {
  testWidgets('owner panel opens and syncs without external catalog (F22)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final database = openTestDatabase();
    addTearDown(database.close);
    final catalog = CatalogStore(database: database);
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Todo Monetta,\nen un solo lugar.'), findsOneWidget);
    expect(find.text('VISTA PREVIA'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-sync-all')), findsOneWidget);
    expect(find.text('Fuentes'), findsNothing);
    expect(find.text('externos'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('admin-sync-all')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sincronización'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
