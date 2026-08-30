/// Release gate for snapshot freshness, shape and optional remote media health.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _catalogPath = 'assets/catalog/catalog.json';

Future<void> main(List<String> args) async {
  final remote = args.contains('--remote');
  final maxAge = _maxAge(args);
  final catalog = jsonDecode(await File(_catalogPath).readAsString())
      as Map<String, dynamic>;
  final errors = <String>[];
  final snapshotAt = DateTime.tryParse('${catalog['_snapshot'] ?? ''}');
  if (snapshotAt == null) {
    errors.add('Falta una fecha _snapshot válida.');
  } else if (DateTime.now().toUtc().difference(snapshotAt.toUtc()).inDays >
      maxAge) {
    errors.add('El snapshot excede $maxAge días de antigüedad.');
  }
  final source = Uri.tryParse('${catalog['_source'] ?? ''}');
  if (source == null || source.scheme != 'https') {
    errors.add('_source debe ser una URL HTTPS.');
  }

  final products = (catalog['products'] as List<dynamic>? ?? const []);
  if (products.isEmpty) errors.add('El snapshot no contiene productos.');
  final handles = <String>{};
  final imageUrls = <Uri>[];
  for (final value in products) {
    final product = Map<String, dynamic>.from(value as Map);
    final handle = '${product['handle'] ?? ''}'.trim();
    if (handle.isEmpty || !handles.add(handle)) {
      errors.add('Handle vacío o duplicado: "$handle".');
    }
    final images = product['images'] as List<dynamic>? ?? const [];
    if (images.isEmpty) {
      errors.add('$handle no tiene imágenes.');
    }
    for (final image in images) {
      final uri = Uri.tryParse('$image');
      if (uri == null || uri.scheme != 'https') {
        errors.add('$handle contiene una imagen no HTTPS.');
      } else {
        imageUrls.add(uri);
      }
    }
  }

  if (remote && errors.isEmpty) {
    errors.addAll(await _deadImages(imageUrls));
  }
  if (errors.isNotEmpty) {
    stderr.writeln('Catálogo inválido (${errors.length} problemas):');
    for (final error in errors.take(30)) {
      stderr.writeln('  - $error');
    }
    if (errors.length > 30) {
      stderr.writeln('  - …y ${errors.length - 30} más');
    }
    exitCode = 2;
    return;
  }
  stdout.writeln(
    'Catálogo válido: ${products.length} productos, ${imageUrls.length} '
    'imágenes${remote ? ' remotas verificadas' : ''}.',
  );
}

int _maxAge(List<String> args) {
  const prefix = '--max-age-days=';
  String? value;
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      value = arg;
      break;
    }
  }
  return int.tryParse(value?.substring(prefix.length) ?? '') ?? 14;
}

Future<List<String>> _deadImages(List<Uri> urls) async {
  final client = http.Client();
  final errors = <String>[];
  try {
    const concurrency = 12;
    for (var offset = 0; offset < urls.length; offset += concurrency) {
      final batch = urls.skip(offset).take(concurrency);
      final results = await Future.wait(
        batch.map((uri) async {
          try {
            final response =
                await client.head(uri).timeout(const Duration(seconds: 10));
            return response.statusCode >= 200 && response.statusCode < 400
                ? null
                : '${uri.host}${uri.path} respondió HTTP '
                    '${response.statusCode}.';
          } catch (error) {
            return '${uri.host}${uri.path} no respondió '
                '(${error.runtimeType}).';
          }
        }),
      );
      errors.addAll(results.whereType<String>());
    }
  } finally {
    client.close();
  }
  return errors;
}
