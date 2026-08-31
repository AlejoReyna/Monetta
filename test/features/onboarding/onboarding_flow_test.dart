import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/onboarding_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/onboarding_preference_store.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets('first run offers optional onboarding and persists skip', (
    tester,
  ) async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    final onboarding = OnboardingController(
      store: OnboardingPreferenceStore(db),
    );
    addTearDown(() async {
      store.dispose();
      onboarding.dispose();
      await db.close();
    });
    await store.loadFromAsset();
    await onboarding.restore();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: OnboardingScope(
            notifier: onboarding,
            child: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Elige marcas'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(onboarding.state, OnboardingState.skipped);
    expect(find.text('Elige marcas'), findsNothing);
  });
}
