/// Account-scoped shopping preferences from the client guide.
///
/// Mayoreo is a stated preference only. Nothing here changes a price, a cart,
/// Rewards, or checkout.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum ShopperPurchaseType { menudeo, mayoreo }

class ShopperPreferences {
  const ShopperPreferences({
    this.brands = const <String>{},
    this.styles = const <String>{},
    this.purchaseType,
  });

  static const empty = ShopperPreferences();

  final Set<String> brands;
  final Set<String> styles;
  final ShopperPurchaseType? purchaseType;

  Map<String, Object?> toJson() => <String, Object?>{
        'brands': brands.toList()..sort(),
        'styles': styles.toList()..sort(),
        'purchaseType': purchaseType?.name,
      };

  factory ShopperPreferences.fromJson(Map<String, Object?> json) {
    ShopperPurchaseType? purchaseType;
    switch (json['purchaseType']) {
      case 'menudeo':
        purchaseType = ShopperPurchaseType.menudeo;
      case 'mayoreo':
        purchaseType = ShopperPurchaseType.mayoreo;
    }
    return ShopperPreferences(
      brands: _strings(json['brands']),
      styles: _strings(json['styles']),
      purchaseType: purchaseType,
    );
  }

  static Set<String> _strings(Object? value) {
    if (value is! List) return const <String>{};
    return <String>{
      for (final item in value)
        if ('$item'.trim().isNotEmpty) '$item'.trim(),
    };
  }
}

abstract class ShopperPreferenceStore {
  Future<ShopperPreferences> read(String accountId);

  Future<void> write(String accountId, ShopperPreferences value);
}

class MemoryShopperPreferenceStore implements ShopperPreferenceStore {
  final Map<String, ShopperPreferences> _values =
      <String, ShopperPreferences>{};

  @override
  Future<ShopperPreferences> read(String accountId) async =>
      _values[accountId] ?? ShopperPreferences.empty;

  @override
  Future<void> write(String accountId, ShopperPreferences value) async {
    _values[accountId] = value;
  }
}

class SharedPreferencesShopperPreferenceStore
    implements ShopperPreferenceStore {
  SharedPreferencesShopperPreferenceStore(this._preferences);

  final SharedPreferences _preferences;

  static const _prefix = 'shopper_preferences_v1:';

  @override
  Future<ShopperPreferences> read(String accountId) async {
    final raw = _preferences.getString('$_prefix$accountId');
    if (raw == null || raw.isEmpty) return ShopperPreferences.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return ShopperPreferences.empty;
      return ShopperPreferences.fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      return ShopperPreferences.empty;
    }
  }

  @override
  Future<void> write(String accountId, ShopperPreferences value) {
    return _preferences.setString(
      '$_prefix$accountId',
      jsonEncode(value.toJson()),
    );
  }
}
