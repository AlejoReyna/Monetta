import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/onboarding_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/onboarding_preference_store.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/welcome/welcome_gate.dart';
import 'package:monetta_app/main.dart';

/// First-visit behaviour, skipping, and what survives a relaunch.
///
/// These assert the *decisions* the package makes — who sees the welcome, what
/// a shopper is left with after each exit — not the pixels those decisions are
/// drawn with.
void main() {
  late AppDatabase db;
  late CatalogStore store;
  late OnboardingController onboarding;

  Future<void> boot() async {
    db = openTestDatabase();
    store = CatalogStore(database: db);
    onboarding = OnboardingController(store: OnboardingPreferenceStore(db));
    await store.loadFromAsset();
    await onboarding.restore();
  }

  setUp(() async {
    await boot();
  });

  tearDown(() async {
    store.dispose();
    onboarding.dispose();
    await db.close();
  });

  Widget app() {
    return MaterialApp(
      theme: buildLightTheme(),
      home: StoreScope(
        notifier: store,
        child: OnboardingScope(
          notifier: onboarding,
          child: const WelcomeGate(child: HomeScreen()),
        ),
      ),
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pump();
  }

  testWidgets('a first visit opens on the welcome', (tester) async {
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('welcome-screen')), findsOneWidget);
    expect(find.text('COMENZAR'), findsOneWidget);
    expect(find.byType(MonettaWordmark), findsWidgets);
  });

  testWidgets('a returning shopper goes straight to the store', (
    tester,
  ) async {
    await onboarding.complete();
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('welcome-screen')), findsNothing);
    expect(find.byKey(const ValueKey('home-search-bar')), findsOneWidget);
  });

  testWidgets('a shopper who skipped earlier is not asked again', (
    tester,
  ) async {
    await onboarding.skip();
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('welcome-screen')), findsNothing);
  });

  testWidgets('Comenzar opens the optional personalisation panel', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('welcome-start-button')));
    await tester.pumpAndSettle();

    expect(find.text('Personaliza tu experiencia'), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-continue')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);
  });

  testWidgets('continuing without a selection leaves everything browsable', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('welcome-start-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(onboarding.state, OnboardingState.completed);
    // No taste was expressed, so nothing narrows the feed.
    expect(store.profile.weights, isEmpty);
    expect(store.feed(), isNotEmpty);
    expect(find.byKey(const ValueKey('welcome-screen')), findsNothing);
    expect(find.byKey(const ValueKey('home-search-bar')), findsOneWidget);
  });

  testWidgets('skipping never leaves the shopper on an empty app', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('welcome-start-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(onboarding.state, OnboardingState.skipped);
    expect(store.feed(), isNotEmpty);
    expect(find.byKey(const ValueKey('welcome-screen')), findsNothing);
  });

  testWidgets('a selection seeds the taste profile', (tester) async {
    final brand = store.availableBrands.first;
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('welcome-start-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('onboarding-brand-$brand')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();

    expect(store.profile.weights, contains('brand:$brand'));
    expect(store.feed(), isNotEmpty);
  });

  testWidgets('the decision survives a relaunch', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('welcome-start-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();

    // A fresh controller over the same device database — what the next cold
    // start actually reads.
    final relaunched = OnboardingController(
      store: OnboardingPreferenceStore(db),
    );
    addTearDown(relaunched.dispose);
    await relaunched.restore();

    expect(relaunched.state, OnboardingState.skipped);
    expect(relaunched.shouldShow, isFalse);
  });

  testWidgets('the welcome never becomes a launch delay', (tester) async {
    // The home is built underneath from the first frame, so dismissing the
    // welcome reveals a settled store rather than a cold start.
    await pumpApp(tester);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-screen')), findsOneWidget);
  });
}
