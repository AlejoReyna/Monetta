/// Fails before Flutter starts when a catalog build is missing its authority.
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Uso: dart run bin/validate_dart_defines.dart <archivo.json> <entorno>',
    );
    exitCode = 64;
    return;
  }

  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('Falta ${file.path}. Créalo desde el archivo .example.');
    exitCode = 2;
    return;
  }

  late final Map<String, Object?> values;
  try {
    values = Map<String, Object?>.from(
      jsonDecode(file.readAsStringSync()) as Map,
    );
  } catch (error) {
    stderr.writeln('${file.path} no contiene JSON válido: $error');
    exitCode = 2;
    return;
  }

  final expectedEnvironment = args[1];
  final errors = <String>[];
  if (!const {'local', 'staging', 'production'}.contains(expectedEnvironment)) {
    errors.add('El entorno debe ser local, staging o production.');
  }
  if (_text(values, 'APP_ENV') != expectedEnvironment) {
    errors.add('APP_ENV debe ser "$expectedEnvironment".');
  }

  if (expectedEnvironment == 'staging') {
    if (!_flag(values, 'FIRESTORE_CATALOG_ENABLED')) {
      errors.add('FIRESTORE_CATALOG_ENABLED debe ser true.');
    }
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
    if (_flag(values, 'ENABLE_EXTERNAL_CATALOG')) {
      errors.add(
        'El catálogo externo sigue en hold y debe permanecer deshabilitado.',
      );
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

  if (errors.isNotEmpty) {
    stderr.writeln('Configuración de catálogo inválida:');
    for (final error in errors) {
      stderr.writeln('  - $error');
    }
    exitCode = 2;
    return;
  }

  stdout.writeln('Configuración $expectedEnvironment válida.');
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
      !normalized.contains('firebase_ios_app_id');
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
