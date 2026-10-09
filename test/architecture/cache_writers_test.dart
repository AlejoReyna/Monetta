library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _writers = {
  'lib/data/repositories/catalog_repository.dart',
  'lib/data/repositories/realtime_catalog_repository.dart',
  'lib/data/repositories/catalog_write_coordinator.dart',
  'lib/data/local/catalog_cache_store.dart',
};

const _knownViolations = {
  'lib/app/catalog_store.dart -> upsertProducts',
  'lib/app/catalog_store.dart -> saveMetadata',
};

final _mutation = RegExp(
  r'(?:\.|\?\.)\s*(resetShopState|upsertProducts|seedProducts|replaceProducts|clearCatalog|saveMetadata|upsertCollections)\s*(?:<[^>]+>)?\s*\(',
);

Set<String> _calls(String source) => {
      for (final match in _mutation.allMatches(source)) match.group(1)!,
    };

void main() {
  test(
      'ARCH-05 detects all cache mutations including cascades and multiline calls',
      () {
    expect(
      _calls(
        'cache.upsertProducts(p); cache..saveMetadata(m); cache?.clearCatalog(); cache\n .replaceProducts(p);',
      ),
      {'upsertProducts', 'saveMetadata', 'clearCatalog', 'replaceProducts'},
    );
    expect(
      _calls(
        'cache.resetShopState(s); cache.seedProducts(p,m); cache.upsertCollections(c);',
      ),
      {'resetShopState', 'seedProducts', 'upsertCollections'},
    );
    expect(_calls('cache.allProducts(); cache.metadata();'), isEmpty);
  });

  test(
      'ARCH-05 cache writers match the explicit ratchet with no new or stale violations',
      () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files.length, greaterThan(100));
    final current = <String>{};
    var allowedCalls = 0;
    for (final file in files) {
      final calls = _calls(file.readAsStringSync());
      if (_writers.contains(file.path)) {
        allowedCalls += calls.length;
      } else {
        current.addAll(calls.map((method) => '${file.path} -> $method'));
      }
    }
    expect(
      allowedCalls,
      greaterThan(0),
      reason: 'The scan must detect repository writes.',
    );
    expect(
      current.difference(_knownViolations),
      isEmpty,
      reason: 'New direct cache writers must delegate through the coordinator.',
    );
    expect(
      _knownViolations.difference(current),
      isEmpty,
      reason: 'Remove retired violations from the ratchet.',
    );
  });
}
