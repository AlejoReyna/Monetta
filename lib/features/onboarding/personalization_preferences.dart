/// Local, account-scoped preference choices. No prices or eligibility rules.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalizationPreferences {
  const PersonalizationPreferences({
    this.brands = const [],
    this.collections = const [],
    this.purchaseType,
  });
  final List<String> brands;
  final List<String> collections;
  final String? purchaseType;
  Map<String, dynamic> toJson() => {
        'brands': brands,
        'collections': collections,
        'purchaseType': purchaseType,
      };
  factory PersonalizationPreferences.fromJson(Map<String, dynamic> json) =>
      PersonalizationPreferences(
        brands:
            (json['brands'] as List?)?.whereType<String>().toList() ?? const [],
        collections:
            (json['collections'] as List?)?.whereType<String>().toList() ??
                const [],
        purchaseType: ['retail', 'wholesale'].contains(json['purchaseType'])
            ? json['purchaseType'] as String
            : null,
      );
}

abstract class PersonalizationPreferencesStore {
  Future<PersonalizationPreferences> load(String scope);
  Future<void> save(String scope, PersonalizationPreferences preferences);
}

class LocalPersonalizationPreferencesStore
    implements PersonalizationPreferencesStore {
  const LocalPersonalizationPreferencesStore();
  String _key(String scope) =>
      'monetta.personalization.v1.${Uri.encodeComponent(scope)}';
  @override
  Future<PersonalizationPreferences> load(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(scope));
    if (raw == null) return const PersonalizationPreferences();
    return PersonalizationPreferences.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> save(
    String scope,
    PersonalizationPreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(scope), jsonEncode(preferences.toJson()))) {
      throw StateError('Preferences were not saved');
    }
  }
}
