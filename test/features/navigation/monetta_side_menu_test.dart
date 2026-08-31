import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/navigation/monetta_side_menu.dart';

void main() {
  testWidgets('shows only navigation links and an appearance icon', (
    tester,
  ) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;

    void doNothing() {}

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
            onAppearance: doNothing,
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
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
  });
}
