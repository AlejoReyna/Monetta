import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/onboarding_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/onboarding_preference_store.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

/// The home is a store, not a questionnaire. Personalisation is reachable only
/// through the first-visit welcome — see `test/features/welcome/`.
void main() {
  testWidgets('the home never opens onboarding by itself', (tester) async {
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

    expect(find.text('Personaliza tu experiencia'), findsNothing);
    expect(find.byKey(const ValueKey('onboarding-continue')), findsNothing);
    expect(onboarding.state, OnboardingState.pending);
  });
}
