import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/onboarding_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/onboarding_preference_store.dart';

void main() {
  late AppDatabase db;
  late OnboardingPreferenceStore store;

  setUp(() {
    db = openTestDatabase();
    store = OnboardingPreferenceStore(db);
  });
  tearDown(() => db.close());

  test('completion survives a controller restart', () async {
    final first = OnboardingController(store: store);
    await first.restore();
    expect(first.shouldShow, isTrue);

    await first.complete();
    final restored = OnboardingController(store: store);
    await restored.restore();

    expect(restored.state, OnboardingState.completed);
    expect(restored.shouldShow, isFalse);
  });

  test('skip is persisted independently from completion', () async {
    final controller = OnboardingController(store: store);
    await controller.skip();

    expect(await store.readState(), 'skipped');
    expect(controller.state, OnboardingState.skipped);
  });
}
