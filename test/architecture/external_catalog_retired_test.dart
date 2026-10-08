/// ARCH-03: the external (US) catalog is gone from the app.
///
/// No `.dart` file under `lib/` or `test/` may name the retired catalog, its
/// feed, its screens, its facets or the source-independent `CatalogItem`
/// model, except for the explicit allowances below:
///
/// * the permanent guard that keeps `ENABLE_EXTERNAL_CATALOG` rejected
///   (invariant 10), and
/// * the admin channel enum value that labels the historical `external_source`
///   audit entries.
///
/// The allowance list is alive: an entry that no longer matches anything in
/// its file fails the test and must be deleted from the list, so the list
/// can only shrink.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _selfPath = 'test/architecture/external_catalog_retired_test.dart';

/// Case-sensitive substrings that must not appear outside the allowances.
const List<String> _forbidden = <String>[
  // The external catalog itself.
  'external_catalog',
  'ExternalCatalog',
  'externalCatalog',
  'ENABLE_EXTERNAL_CATALOG',
  // The mixed feed.
  'mixed_feed',
  'MixedRecommendation',
  'unifiedRecommendations',
  'mixedFeed',
  'fullDeduplicatedCatalog',
  // The external product screen.
  'external_product_screen',
  'ExternalProductScreen',
  'showExternalProductDetail',
  // External facets.
  'external_facets',
  'externalPriceBandFor',
  'externalItemFacets',
  // External copy and link helpers.
  'externalProductName',
  'isValidExternalDetailUrl',
  'kAllowedExternalDetailHosts',
  'sourceLinkLabel',
  // The source-independent catalog model and its mapper.
  'CatalogItem',
  'catalog_item',
  'catalogItems',
  'catalogItemFromShopifyProduct',
  'CatalogSourceType',
  'PurchaseMode',
  'MarketRestriction',
  'CatalogVariant',
  'CatalogAvailability',
  'CatalogVertical',
  // The retired monitor service.
  'catalog_monitor',
  'catalogMonitor',
  // The admin's external source management (decision E2, RF-21). Each name is
  // exclusive to it: the source policy model, its client contract, the
  // capability flag, the health status, the policy endpoint and the response
  // keys. Generic words such as `sources` are deliberately not listed.
  'AdminSourcePolicy',
  'ExternalSourceAdminClient',
  'updateSourceCanonical',
  'updateSource',
  'saveSource',
  '_sourceFromJson',
  'manageExternalSources',
  'sourcesHealthStatus',
  'external-policy',
  "['sources']",
];

/// One explicit exception: [file] may contain the spans [spans] finds.
class _Allowance {
  const _Allowance(this.file, this.what, this.spans);

  final String file;
  final String what;

  /// Character ranges of [text] this allowance covers.
  final List<({int start, int end})> Function(String text) spans;
}

/// An identifier-anchored token, so `ExternalCatalogConfig` never excuses
/// `ExternalCatalogConfigurator`-style names or `external_catalog_controller`.
_Allowance _token(String file, String token) => _Allowance(
      file,
      token,
      (text) => [
        for (final match in RegExp(
          '(?<![A-Za-z0-9_])${RegExp.escape(token)}(?![A-Za-z0-9_])',
        ).allMatches(text))
          (start: match.start, end: match.end),
      ],
    );

/// `externalCatalog` as the value declared in `enum AdminChannel { ... }`.
_Allowance _adminChannelEnumValue(String file) => _Allowance(
      file,
      'externalCatalog as a value of enum AdminChannel',
      (text) {
        final spans = <({int start, int end})>[];
        final enumBody = RegExp(r'enum\s+AdminChannel\s*\{[^}]*\}');
        final value = RegExp(
          r'(?<![A-Za-z0-9_])externalCatalog(?![A-Za-z0-9_])',
        );
        for (final body in enumBody.allMatches(text)) {
          for (final hit in value.allMatches(body.group(0)!)) {
            final start = body.start + hit.start;
            spans.add((start: start, end: start + hit.end - hit.start));
          }
        }
        return spans;
      },
    );

/// The explicit exceptions. Delete an entry as soon as its test fails as
/// stale; never add one without a decision recorded in the refactor plan.
final List<_Allowance> _allowances = <_Allowance>[
  // Guard that keeps ENABLE_EXTERNAL_CATALOG rejected (invariant 10).
  for (final token in const [
    'external_catalog_config',
    'ExternalCatalogConfig',
    'externalCatalogRequested',
    'ENABLE_EXTERNAL_CATALOG',
  ])
    _token('lib/app/runtime_config.dart', token),
  for (final token in const [
    'ExternalCatalogConfig',
    'ENABLE_EXTERNAL_CATALOG',
  ])
    _token('lib/app/external_catalog_config.dart', token),
  _token('lib/tooling/dart_defines_validation.dart', 'ENABLE_EXTERNAL_CATALOG'),
  _token('test/app/runtime_config_test.dart', 'externalCatalogRequested'),
  for (final token in const [
    'ExternalCatalogConfig',
    'external_catalog_config',
  ])
    _token('test/app/external_catalog_config_test.dart', token),
  _token(
    'test/tooling/dart_defines_validation_test.dart',
    'ENABLE_EXTERNAL_CATALOG',
  ),
  // Admin channel value that labels the historical `external_source` audit
  // entries; it is not a way to manage external sources.
  _adminChannelEnumValue('lib/domain/admin_control.dart'),
  _token('lib/data/admin/admin_client.dart', 'AdminChannel.externalCatalog'),
  _token('test/app/admin_controller_test.dart', 'AdminChannel.externalCatalog'),
];

/// [text] with every span in [spans] blanked out, keeping offsets and lines.
String _blank(String text, Iterable<({int start, int end})> spans) {
  final chars = text.split('');
  for (final span in spans) {
    for (var i = span.start; i < span.end; i++) {
      if (chars[i] != '\n') chars[i] = ' ';
    }
  }
  return chars.join();
}

/// `path:line: pattern` for every forbidden pattern left in [text].
List<String> _violationsIn(String path, String text) {
  final lines = text.split('\n');
  return <String>[
    for (var i = 0; i < lines.length; i++)
      for (final pattern in _forbidden)
        if (lines[i].contains(pattern)) '$path:${i + 1}: $pattern',
  ];
}

Map<String, String> _dartSources() {
  final sources = <String, String>{};
  for (final root in const ['lib', 'test']) {
    final dir = Directory(root);
    expect(dir.existsSync(), isTrue, reason: '$root/ is missing');
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == _selfPath) continue;
      sources[path] = entity.readAsStringSync();
    }
  }
  return sources;
}

/// Violations of [sources] after applying [allowances], sorted by path/line.
List<String> _scan(
  Map<String, String> sources,
  List<_Allowance> allowances,
) {
  final violations = <String>[];
  final paths = sources.keys.toList()..sort();
  for (final path in paths) {
    var text = sources[path]!;
    for (final allowance in allowances.where((a) => a.file == path)) {
      text = _blank(text, allowance.spans(sources[path]!));
    }
    violations.addAll(_violationsIn(path, text));
  }
  return violations;
}

void main() {
  test(
    'ARCH-03 no Dart file in lib/ or test/ references the retired external '
    'catalog',
    () {
      final sources = _dartSources();
      expect(sources.length, greaterThan(100), reason: 'scan found no sources');

      final violations = _scan(sources, _allowances);

      if (violations.isNotEmpty) {
        final files = violations.map((v) => v.split(':').first).toSet().length;
        final total = 'Total: ${violations.length} violation(s) in $files '
            'file(s).';
        fail(
          '$total\nReferences to the retired external catalog '
          '(path:line: pattern):\n${violations.join('\n')}\n$total',
        );
      }
    },
  );

  test('ARCH-03 every declared exception still appears in its file', () {
    final sources = _dartSources();
    final stale = <String>[];
    for (final allowance in _allowances) {
      final text = sources[allowance.file];
      if (text == null) {
        stale.add('${allowance.file}: file is gone (${allowance.what})');
      } else if (allowance.spans(text).isEmpty) {
        stale.add('${allowance.file}: no longer contains ${allowance.what}');
      }
    }
    expect(
      stale,
      isEmpty,
      reason: 'Remove these entries from _allowances in $_selfPath:\n'
          '${stale.join('\n')}',
    );
  });

  test('ARCH-03 an allowance covers only its own token and file', () {
    final allowances = <_Allowance>[
      _token('lib/a.dart', 'ExternalCatalogConfig'),
      _adminChannelEnumValue('lib/b.dart'),
    ];
    final violations = _scan(
      {
        'lib/a.dart': 'ExternalCatalogConfig.disabled;\n'
            'ExternalCatalogController();\n'
            'ExternalCatalogConfigurator();\n',
        'lib/b.dart': 'enum AdminChannel { shopify, externalCatalog }\n'
            'final x = externalCatalog;\n',
        'lib/c.dart': 'ExternalCatalogConfig.disabled;\n',
      },
      allowances,
    );
    expect(violations, <String>[
      'lib/a.dart:2: ExternalCatalog',
      'lib/a.dart:3: ExternalCatalog',
      'lib/b.dart:2: externalCatalog',
      'lib/c.dart:1: ExternalCatalog',
    ]);
  });

  test('ARCH-03 the admin external source management names are forbidden', () {
    final violations = _scan(
      {
        'lib/a.dart': 'class AdminSourcePolicy {}\n'
            'abstract interface class ExternalSourceAdminClient {}\n'
            'await client.updateSourceCanonical(next);\n'
            'await client.updateSource(next);\n'
            'await saveSource(next);\n'
            'final bool manageExternalSources = false;\n'
            'final String? sourcesHealthStatus;\n'
            "final path = '/admin/external-policy/\$id';\n"
            "final rows = root['sources'];\n"
            'AdminSourcePolicy _sourceFromJson(Map json) => throw 1;\n',
        'lib/b.dart': 'final sources = <Object>[];\n'
            "final status = 'external-status';\n"
            'final showExternalPicks = true;\n',
      },
      const <_Allowance>[],
    );
    expect(violations, <String>[
      'lib/a.dart:1: AdminSourcePolicy',
      'lib/a.dart:2: ExternalSourceAdminClient',
      'lib/a.dart:3: updateSourceCanonical',
      'lib/a.dart:3: updateSource',
      'lib/a.dart:4: updateSource',
      'lib/a.dart:5: saveSource',
      'lib/a.dart:6: manageExternalSources',
      'lib/a.dart:7: sourcesHealthStatus',
      'lib/a.dart:8: external-policy',
      "lib/a.dart:9: ['sources']",
      'lib/a.dart:10: AdminSourcePolicy',
      'lib/a.dart:10: _sourceFromJson',
    ]);
  });
}
