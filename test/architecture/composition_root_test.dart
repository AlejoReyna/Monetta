/// ARCH-04 (ratchet): only `lib/app/composition/` builds concrete `data/`
/// implementations outside `lib/data/` itself.
///
/// RF-30 moved every construction of `lib/main.dart` into
/// `lib/app/composition/`. [_knownConstructions] records what remains outside
/// it, as a map from file to the concrete classes it builds. Each entry is
/// emptied by the WP that owns it:
///
/// * `lib/app/catalog_store.dart`: RF-50 (the `CatalogStore` facade);
/// * `lib/app/shopify_cart_composition.dart`: RF-51 (`CompleteCheckout` and
///   the cart wiring move to the composition root);
/// * `lib/features/home/customer_experiences_screen.dart`: RF-66 (niche
///   features, the Loox reviews);
/// * `lib/features/rewards/rewards_api.dart`: RF-63 (Rewards).
///
/// Together they must leave the map EMPTY.
///
/// The map is alive in both directions:
/// * a (file, class) pair that is not listed fails the test (no new
///   construction outside the composition root), and
/// * a listed pair that no longer exists fails the test (delete it), so the
///   map can only shrink.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What counts as a "concrete implementation" of `data/`:
///
/// * a PUBLIC class (name not starting with `_`),
/// * declared in a `.dart` file under `lib/data/` (generated `*.g.dart` files
///   are skipped),
/// * NOT `abstract` and NOT `sealed` (an `abstract interface class` is a
///   port, not an implementation), and
/// * whose name ends in one of [_suffixes].
///
/// The suffixes name the roles that touch the outside world or own
/// persistence: a client talks to a server, a repository/store/database
/// persists, a transport/gateway/api/discovery/source/sync/launcher/scheduler
/// reaches a platform or network edge, a service and a coordinator orchestrate
/// those edges. Plain value types (`CartMoney`, `OrderSummary`, `*Config`,
/// `*Result`, `*Exception`) are deliberately excluded: building them is not
/// wiring. Adding a suffix widens the net; removing one narrows it. Either
/// must be justified here:
///
/// * `Client`, `Transport`, `Gateway`, `Api`, `Discovery`, `Source`: network
///   or platform edges.
/// * `Repository`, `Store`, `Database`, `Sync`: persistence and
///   synchronization.
/// * `Service`, `Coordinator`: orchestration of the above.
/// * `Launcher`, `Scheduler`: platform side effects (checkout, local
///   notifications).
const List<String> _suffixes = <String>[
  'Client',
  'Repository',
  'Store',
  'Transport',
  'Service',
  'Gateway',
  'Coordinator',
  'Source',
  'Sync',
  'Database',
  'Launcher',
  'Scheduler',
  'Discovery',
  'Api',
];

/// Baseline: file (relative to the repository root) -> concrete `data/`
/// classes it constructs today, outside `lib/data/` and
/// `lib/app/composition/`. Includes named constructors and static factories
/// such as `AppDatabase.connect()`.
const Map<String, List<String>> _knownConstructions = <String, List<String>>{
  'lib/app/catalog_store.dart': <String>[
    'BagStore',
    'CatalogCacheStore',
    'CatalogRepository',
    'CatalogWriteCoordinator',
    'InteractionEventStore',
    'RealtimeCatalogRepository',
    'SyncCursorStore',
    'WishlistStore',
  ],
  'lib/app/shopify_cart_composition.dart': <String>[
    'CartRepository',
    'SecureCartSessionStore',
    'SerialCartWriteCoordinator',
    'StorefrontCartApi',
    'StorefrontClient',
  ],
  'lib/features/home/customer_experiences_screen.dart': <String>[
    'LooxReviewsRepository',
  ],
  'lib/features/rewards/rewards_api.dart': <String>[
    'TimeoutHttpClient',
  ],
};

/// Declaration of a class: modifiers, then `class`, then the name.
final RegExp _classDeclaration = RegExp(
  r'^\s*((?:(?:abstract|base|final|interface|sealed|mixin)\s+)*)class\s+([A-Za-z]\w*)',
  multiLine: true,
);

/// Returns [source] with `//` and `/* */` comments replaced by spaces of the
/// same length, keeping string literals (including `//` inside a URL) intact.
String stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      var depth = 1;
      out.write('  ');
      i += 2;
      while (i < n && depth > 0) {
        if (source[i] == '/' && i + 1 < n && source[i + 1] == '*') {
          depth++;
          out.write('  ');
          i += 2;
        } else if (source[i] == '*' && i + 1 < n && source[i + 1] == '/') {
          depth--;
          out.write('  ');
          i += 2;
        } else {
          out.write(source[i] == '\n' ? '\n' : ' ');
          i++;
        }
      }
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && source[i - 1] == 'r';
      final triple = source.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      while (i < n && !source.startsWith(quote, i)) {
        if (!raw && source[i] == r'\' && i + 1 < n) {
          out.write(source[i]);
          i++;
        }
        out.write(source[i]);
        i++;
        if (!triple && i < n && source[i - 1] == '\n') break;
      }
      if (i < n && source.startsWith(quote, i)) {
        out.write(quote);
        i += quote.length;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Names of the concrete classes declared in [source] that match [_suffixes].
List<String> concreteClassNames(String source) {
  final names = <String>[];
  for (final match in _classDeclaration.allMatches(stripComments(source))) {
    final modifiers = match.group(1)!;
    final name = match.group(2)!;
    if (name.startsWith('_')) continue;
    if (modifiers.contains('abstract') || modifiers.contains('sealed')) {
      continue;
    }
    if (modifiers.contains('mixin') && !modifiers.contains('class')) continue;
    if (!_suffixes.any(name.endsWith)) continue;
    names.add(name);
  }
  return names;
}

/// Whether [source] (comments stripped) constructs [className]: `Name(`,
/// `Name<T>(` or `Name.named(`, with or without `const`/`new`, and with an
/// optional lower-case import prefix (`shopify.Name(`).
bool constructs(String source, String className) {
  final pattern = RegExp(
    '(?<![\\w.\$])(?:[a-z_]\\w*\\s*\\.\\s*)?${RegExp.escape(className)}'
    r'\s*(?:<[^;(){}]*>)?\s*(?:\.\s*[A-Za-z_]\w*\s*)?\(',
  );
  return pattern.hasMatch(stripComments(source));
}

String _normalize(String path) => path.replaceAll(r'\', '/');

List<File> _dartFiles(String root) => <File>[
      for (final entity in Directory(root).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ];

Set<String> _concreteDataClasses() {
  final names = <String>{};
  for (final file in _dartFiles('lib/data')) {
    if (file.path.endsWith('.g.dart')) continue;
    names.addAll(concreteClassNames(file.readAsStringSync()));
  }
  return names;
}

/// Current map: file -> sorted concrete classes it constructs, scanning
/// `lib/` except `lib/data/` and `lib/app/composition/`.
Map<String, List<String>> _currentConstructions() {
  final classes = _concreteDataClasses();
  final result = <String, List<String>>{};
  for (final file in _dartFiles('lib')) {
    final path = _normalize(file.path);
    if (path.startsWith('lib/data/')) continue;
    if (path.startsWith('lib/app/composition/')) continue;
    if (path.endsWith('.g.dart')) continue;
    final source = file.readAsStringSync();
    final built = <String>[
      for (final name in classes)
        if (constructs(source, name)) name,
    ]..sort();
    if (built.isNotEmpty) result[path] = built;
  }
  return result;
}

Set<String> _pairs(Map<String, List<String>> map) => <String>{
      for (final entry in map.entries)
        for (final name in entry.value) '${entry.key} -> $name',
    };

void main() {
  test('ARCH-04 the detectors read declarations and constructions correctly',
      () {
    const declarations = '''
abstract interface class FooClient {}
abstract class BarStore {}
sealed class BazRepository {}
class HttpFooClient implements FooClient {}
final class SerialWriteCoordinator {}
class _PrivateStore {}
class CartMoney {}
// class CommentedStore {}
/* class BlockStore {} */
''';
    expect(
      concreteClassNames(declarations),
      <String>['HttpFooClient', 'SerialWriteCoordinator'],
    );

    const usage = '''
final a = HttpFooClient(base: 'https://x.test');
final b = const HttpFooClient.named();
final c = HttpFooClient<int>();
final d = shopify.HttpFooClient();
final e = MyHttpFooClient();
// final f = HttpFooClient();
final g = 'HttpFooClient(';
''';
    expect(constructs(usage, 'HttpFooClient'), isTrue);
    expect(constructs('x = HttpFooClient.named();', 'HttpFooClient'), isTrue);
    expect(constructs('x = HttpFooClient<int>();', 'HttpFooClient'), isTrue);
    expect(constructs('x = shopify.HttpFooClient();', 'HttpFooClient'), isTrue);
    expect(constructs('x = a.b.HttpFooClient();', 'HttpFooClient'), isFalse);
    expect(constructs('x = MyHttpFooClient();', 'HttpFooClient'), isFalse);
    expect(constructs('// x = HttpFooClient();', 'HttpFooClient'), isFalse);
    expect(constructs('/* HttpFooClient() */', 'HttpFooClient'), isFalse);
    expect(constructs('final HttpFooClient client;', 'HttpFooClient'), isFalse);
    expect(constructs('x = HttpFooClient.value;', 'HttpFooClient'), isFalse);
  });

  test('ARCH-04 data/ has concrete implementations to guard', () {
    final classes = _concreteDataClasses();
    // Sanity: the discovery must keep finding the well-known ones, otherwise
    // the ratchet below would pass vacuously.
    expect(
      classes,
      containsAll(<String>[
        'AppDatabase',
        'CatalogRepository',
        'HttpStorefrontTransport',
        'FlutterSecureTokenStore',
        'HttpAdminClient',
      ]),
    );
    expect(
      classes.where((name) => name.startsWith('_')),
      isEmpty,
    );
  });

  test(
      'ARCH-04 concrete data/ classes are built outside lib/data only in '
      'the known places (RF-50, RF-51, RF-63 and RF-66 must empty the map)',
      () {
    final current = _pairs(_currentConstructions());
    final known = _pairs(_knownConstructions);

    final added = (current.toList()..sort())
        .where((pair) => !known.contains(pair))
        .toList();
    final stale = (known.toList()..sort())
        .where((pair) => !current.contains(pair))
        .toList();

    expect(
      added,
      isEmpty,
      reason: 'New construction of a concrete data/ class outside lib/data/ '
          'and lib/app/composition/. Build it in the composition root and '
          'inject it:\n${added.join('\n')}',
    );
    expect(
      stale,
      isEmpty,
      reason: 'These constructions no longer exist: delete them from '
          '_knownConstructions so the map only shrinks:\n${stale.join('\n')}',
    );
  });
}
