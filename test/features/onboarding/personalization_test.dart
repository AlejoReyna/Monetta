import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/onboarding/onboarding_sheet.dart';
import 'package:monetta_app/features/onboarding/personalization_preferences.dart';
import 'package:monetta_app/main.dart';
import '../../support/client_guide_capture.dart';

class MemoryPreferences implements PersonalizationPreferencesStore {
  final values = <String, PersonalizationPreferences>{};
  bool failSave = false;
  @override
  Future<PersonalizationPreferences> load(String scope) async =>
      values[scope] ?? const PersonalizationPreferences();
  @override
  Future<void> save(
    String scope,
    PersonalizationPreferences preferences,
  ) async {
    if (failSave) throw StateError('fixture disk error');
    values[scope] = preferences;
  }
}

void main() {
  test('choices survive a new store instance and stay scoped', () async {
    SharedPreferences.setMockInitialValues({});
    const first = LocalPersonalizationPreferencesStore();
    await first.save(
      'demo-a',
      const PersonalizationPreferences(
        brands: ['coach'],
        collections: ['crossbody'],
        purchaseType: 'wholesale',
      ),
    );
    const reopened = LocalPersonalizationPreferencesStore();
    final choices = await reopened.load('demo-a');
    expect(choices.collections, ['crossbody']);
    expect(choices.purchaseType, 'wholesale');
    expect((await reopened.load('demo-b')).brands, isEmpty);
    expect((await reopened.load('')).purchaseType, isNull);
  });

  testWidgets('save, reopen, edit, skip and write failure preserve choices',
      (tester) async {
    final db = openTestDatabase();
    final store = CatalogStore(database: db);
    await store.loadFromAsset();
    final preferences = MemoryPreferences();
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    await pumpClientGuide(
      tester,
      StoreScope(
        notifier: store,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Edit preferences'),
              onPressed: () => showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => StoreScope(
                  notifier: store,
                  child: OnboardingSheet(
                    scopeKey: 'demo',
                    preferencesStore: preferences,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.text('Edit preferences'));
      await tester.pumpAndSettle();
    }

    Future<void> tapChoice(String key) async {
      final choice = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(
        choice,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(choice);
      await tester.pumpAndSettle();
      await tester.tap(choice);
      await tester.pumpAndSettle();
    }

    await open();
    await tapChoice('onboarding-brand-coach');
    await tapChoice('onboarding-collection-crossbody');
    await tapChoice('onboarding-purchase-wholesale');
    preferences.failSave = true;
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingSheet), findsOneWidget);
    expect(preferences.values, isEmpty);
    preferences.failSave = false;
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(preferences.values['demo']!.brands, ['coach']);
    expect(preferences.values['demo']!.purchaseType, 'wholesale');
    expect(store.profile.weights, contains('silhouette:crossbody'));
    await open();
    expect(
      tester
          .widget<Semantics>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('onboarding-brand-coach')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
    await tapChoice('onboarding-brand-coach');
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();
    expect(preferences.values['demo']!.brands, ['coach']);
    await open();
    await tapChoice('onboarding-purchase-retail');
    await tester.tap(find.byKey(const ValueKey('onboarding-continue')));
    await tester.pumpAndSettle();
    expect(preferences.values['demo']!.purchaseType, 'retail');
    expect(tester.takeException(), isNull);
  });

  for (final (size, scale, brightness) in [
    (const Size(390, 1100), 1.0, Brightness.light),
    (const Size(320, 568), 2.0, Brightness.light),
    (const Size(834, 1194), 1.0, Brightness.light),
    (const Size(390, 1100), 1.0, Brightness.dark),
  ]) {
    testWidgets('personalization at $size / $scale / $brightness',
        (tester) async {
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      await store.loadFromAsset();
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await pumpClientGuide(
        tester,
        StoreScope(
          notifier: store,
          child: OnboardingSheet(preferencesStore: MemoryPreferences()),
        ),
        size: size,
        textScale: scale,
        brightness: brightness,
      );
      expect(find.text('Personalización'), findsOneWidget);
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'personalization-${size.width.toInt()}-${brightness.name}',
        );
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('onboarding-purchase-wholesale')),
        300,
      );
      if (scale == 1) {
        await captureClientGuide(
          tester,
          'personalization-choices-${size.width.toInt()}-${brightness.name}',
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
