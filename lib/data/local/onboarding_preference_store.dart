/// Persistence for the device-wide first-run onboarding decision.
library;

import 'package:drift/drift.dart';

import 'database.dart';

class OnboardingPreferenceStore {
  OnboardingPreferenceStore(this._db);

  final AppDatabase _db;

  Future<String> readState() async {
    final row = await (_db.select(_db.appPreferences)
          ..where((table) => table.id.equals(0)))
        .getSingleOrNull();
    return row?.onboardingState ?? 'pending';
  }

  Future<void> writeState(String value) {
    return _db.into(_db.appPreferences).insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            id: const Value(0),
            onboardingState: Value(value),
          ),
        );
  }
}
