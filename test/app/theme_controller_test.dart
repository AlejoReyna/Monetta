import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme_controller.dart';
import 'package:monetta_app/data/local/appearance_store.dart';
import 'package:monetta_app/data/local/database.dart';

void main() {
  late AppDatabase database;
  late AppearanceStore store;

  setUp(() {
    database = openTestDatabase();
    store = AppearanceStore(database);
  });

  tearDown(() => database.close());

  test('defaults to system and persists a device-wide override', () async {
    final controller = ThemeController(store: store);
    await controller.restore();
    expect(controller.mode, ThemeMode.system);

    await controller.setMode(ThemeMode.dark);
    expect(controller.mode, ThemeMode.dark);

    final restored = ThemeController(store: store);
    await restored.restore();
    expect(restored.mode, ThemeMode.dark);
  });

  test('invalid stored values safely fall back to system', () async {
    await store.writeThemeMode('unexpected');
    final controller = ThemeController(store: store);
    await controller.restore();
    expect(controller.mode, ThemeMode.system);
  });
}
