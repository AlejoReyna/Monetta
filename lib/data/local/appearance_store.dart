/// Persistence for the device-wide appearance preference.
library;

import 'package:drift/drift.dart';

import 'database.dart';

class AppearanceStore {
  AppearanceStore(this._db);

  final AppDatabase _db;

  Future<String> readThemeMode() async {
    final row = await (_db.select(_db.appPreferences)
          ..where((table) => table.id.equals(0)))
        .getSingleOrNull();
    return row?.themeMode ?? 'system';
  }

  Future<void> writeThemeMode(String value) {
    return _db.into(_db.appPreferences).insertOnConflictUpdate(
          AppPreferencesCompanion.insert(
            id: const Value(0),
            themeMode: Value(value),
          ),
        );
  }
}
