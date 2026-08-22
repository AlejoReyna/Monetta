import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/about/about_monetta_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/partner/partner_hub_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets('home exposes the story and reseller hub without a new nav tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: ExternalCatalogScope(
            notifier: ExternalCatalogController(
              config: ExternalCatalogConfig.disabled,
            ),
            child: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-about-monetta')),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Conoce nuestra historia'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutMonettaScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final partnerButton = find.byKey(const ValueKey('home-open-partner'));
    await tester.scrollUntilVisible(
      partnerButton,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(partnerButton);
    await tester.pumpAndSettle();
    await tester.tap(partnerButton);
    await tester.pumpAndSettle();
    expect(find.byType(PartnerHubScreen), findsOneWidget);
  });
}
