/// Shared dart-defines validation for Makefile scripts and unit tests.
library;

/// Validates catalog / release dart-defines for [expectedEnvironment].
List<String> validateDartDefines({
  required Map<String, Object?> values,
  required String expectedEnvironment,
}) {
  final errors = <String>[];
  if (!const {'local', 'staging', 'production'}.contains(expectedEnvironment)) {
    errors.add('El entorno debe ser local, staging o production.');
  }
  if (_text(values, 'APP_ENV') != expectedEnvironment) {
    errors.add('APP_ENV debe ser "$expectedEnvironment".');
  }

  if (_flag(values, 'ENABLE_EXTERNAL_CATALOG')) {
    errors.add(
      'El catálogo externo está retirado; ENABLE_EXTERNAL_CATALOG debe ser false.',
    );
  }

  if (expectedEnvironment == 'staging') {
    final firestoreEnabled = _flag(values, 'FIRESTORE_CATALOG_ENABLED');
    final hasShopify = _isConfigured(_text(values, 'SHOPIFY_STORE_DOMAIN')) &&
        _isConfigured(_text(values, 'SHOPIFY_STOREFRONT_ACCESS_TOKEN'));
    if (firestoreEnabled) {
      for (final key in const [
        'FIREBASE_ANDROID_API_KEY',
        'FIREBASE_ANDROID_APP_ID',
        'FIREBASE_IOS_API_KEY',
        'FIREBASE_IOS_APP_ID',
        'FIREBASE_PROJECT_ID',
        'FIREBASE_MESSAGING_SENDER_ID',
      ]) {
        if (!_isConfigured(_text(values, key))) errors.add('Falta $key.');
      }
    } else if (!hasShopify) {
      errors.add(
        'Staging Storefront-only requiere SHOPIFY_STORE_DOMAIN y '
        'SHOPIFY_STOREFRONT_ACCESS_TOKEN, o bien FIRESTORE_CATALOG_ENABLED=true '
        'con Firebase completo.',
      );
    }
  }

  if (expectedEnvironment == 'production') {
    if (_flag(values, 'ALLOW_OFFLINE_CATALOG')) {
      errors.add('Producción no permite ALLOW_OFFLINE_CATALOG=true.');
    }
    _requireHost(values, 'SHOPIFY_STORE_DOMAIN', errors);
    for (final key in const [
      'SHOPIFY_STOREFRONT_ACCESS_TOKEN',
      'CUSTOMER_ACCOUNT_SHOP_ID',
      'CUSTOMER_ACCOUNT_CLIENT_ID',
    ]) {
      if (!_isConfigured(_text(values, key))) errors.add('Falta $key.');
    }
    _requireHttpsUrl(values, 'ACCOUNTS_ORDERS_BASE_URL', errors);
    if (_flag(values, 'ENABLE_OWNER_ADMIN_PREVIEW')) {
      errors.add('Producción no permite ENABLE_OWNER_ADMIN_PREVIEW=true.');
    }
    if (_flag(values, 'FIRESTORE_CATALOG_ENABLED')) {
      for (final key in const [
        'FIREBASE_ANDROID_API_KEY',
        'FIREBASE_ANDROID_APP_ID',
        'FIREBASE_IOS_API_KEY',
        'FIREBASE_IOS_APP_ID',
        'FIREBASE_PROJECT_ID',
        'FIREBASE_MESSAGING_SENDER_ID',
      ]) {
        if (!_isConfigured(_text(values, key))) errors.add('Falta $key.');
      }
    }
  }

  if (expectedEnvironment == 'local' &&
      !_flag(values, 'ALLOW_OFFLINE_CATALOG') &&
      !_flag(values, 'FIRESTORE_CATALOG_ENABLED') &&
      !_isConfigured(_text(values, 'SHOPIFY_STOREFRONT_ACCESS_TOKEN'))) {
    errors.add(
      'Local requiere una fuente remota o ALLOW_OFFLINE_CATALOG=true.',
    );
  }

  return errors;
}

String _text(Map<String, Object?> values, String key) =>
    '${values[key] ?? ''}'.trim();

bool _flag(Map<String, Object?> values, String key) =>
    _text(values, key).toLowerCase() == 'true';

bool _isConfigured(String value) {
  if (value.isEmpty) return false;
  final normalized = value.toLowerCase();
  return !normalized.contains('replace') &&
      !normalized.contains('xxxxxxxx') &&
      !normalized.contains('public_firebase') &&
      !normalized.contains('firebase_android_app_id') &&
      !normalized.contains('firebase_ios_app_id') &&
      !normalized.contains('public_live_storefront') &&
      !normalized.contains('public_storefront');
}

void _requireHost(
  Map<String, Object?> values,
  String key,
  List<String> errors,
) {
  final value = _text(values, key);
  if (!_isConfigured(value) ||
      value.contains('://') ||
      value.contains('/') ||
      !value.contains('.')) {
    errors.add('$key debe ser un hostname configurado, sin esquema ni ruta.');
  }
}

void _requireHttpsUrl(
  Map<String, Object?> values,
  String key,
  List<String> errors,
) {
  final value = _text(values, key);
  final uri = Uri.tryParse(value);
  if (!_isConfigured(value) ||
      uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    errors.add('$key debe ser una URL HTTPS configurada y sin credenciales.');
  }
}
