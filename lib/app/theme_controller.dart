/// Owns the shopper's device-wide appearance preference.
library;

import 'package:flutter/material.dart';

import '../data/local/appearance_store.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({required AppearanceStore store}) : _store = store;

  final AppearanceStore _store;

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> restore() async {
    try {
      _mode = _decode(await _store.readThemeMode());
    } catch (error) {
      debugPrint('Appearance preference could not be restored: $error');
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode next) async {
    if (_mode == next) return;
    _mode = next;
    notifyListeners();
    try {
      await _store.writeThemeMode(next.name);
    } catch (error) {
      // Appearance is non-critical. Keep the selected mode for this session
      // even if local persistence is temporarily unavailable.
      debugPrint('Appearance preference could not be saved: $error');
    }
  }

  static ThemeMode _decode(String value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    required ThemeController super.notifier,
    required super.child,
    super.key,
  });

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope?.notifier != null, 'ThemeScope is missing from the tree');
    return scope!.notifier!;
  }
}
