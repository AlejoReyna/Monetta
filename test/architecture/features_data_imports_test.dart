/// ARCH-02 (ratchet): `lib/features/` does not import implementations of
/// `lib/data/`.
///
/// A screen that imports a repository, a store, a database or a client is
/// coupled to persistence and the network, and cannot be tested without them.
/// Screens must receive their collaborators through the scopes in
/// `lib/app/composition/app_scopes.dart` and talk to ports and domain types.
///
/// The rule has two parts:
///
/// * [_allowedModules] is the explicit list of `lib/data/` modules a feature
///   may import, because each one is a pure helper, a model, an error, a
///   configuration value or a port. Every entry carries its reason.
/// * [_knownImports] is the baseline of everything else (pairs of file ->
///   module), each with the WP that retires it. It must reach EMPTY.
///
/// The list is alive in both directions:
/// * a (file, module) pair that is neither allowed nor listed fails the test
///   (no new coupling), and
/// * a listed pair that no longer exists fails the test (delete it), so the
///   list can only shrink.
///
/// Both relative imports and `package:monetta_app/data/...` are detected, and
/// relative paths are resolved against the importing file, so `../../data/x`
/// and `../../../lib/data/x` are the same module.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Modules (paths relative to the repository root) that `lib/features/` may
/// import. A trailing `/` allows the whole directory.
const List<String> _allowedModules = <String>[
  // Pure helper: builds and validates image URLs. No I/O, no state.
  'lib/data/media/media_url.dart',

  // `data/normalize/` is pure Dart by INV-12 (no Flutter): facet and text
  // normalization helpers and their value types (`FacetValue`).
  'lib/data/normalize/',

  // Model: notification preferences, route data and envelope types, plus
  // `NotificationException`. Value types and a pure error, no transport.
  'lib/data/notifications/notification_models.dart',

  // Error: `CustomerAuthException` is what the auth flow throws and screens
  // catch to show a message. Only a type, nothing is executed.
  'lib/data/customer_auth/customer_auth_error.dart',

  // Port: `CheckoutLauncher` (plus its result types and URL policy). Invariant
  // 8 requires the UI to depend on this port and never on the Checkout Kit SDK.
  'lib/data/shopify/cart/checkout_launcher.dart',

  // Configuration value: `AccountsOrdersConfig` holds the backend base URL
  // and flags; it makes no calls.
  'lib/data/accounts_orders/accounts_orders_config.dart',

  // Model and pure function: `CartAttribution`, `RecoSource` and the
  // attribution code generator. Pure Dart (the file has no imports) and
  // invariant 11 needs the screens to pass `_rec_source` along. RF-67
  // (attribution) may move it to `lib/domain/`; it stays allowed until then.
  'lib/data/shopify/cart_attribution.dart',
];

/// Baseline: file (relative to the repository root) -> `lib/data/` module it
/// imports and is not allowed to. Each entry names the WP that retires it.
const Map<String, List<String>> _knownImports = <String, List<String>>{
  'lib/features/admin/admin_screen.dart': <String>[
    // RF-50: CatalogStore facade replaces the direct cache store.
    'lib/data/local/catalog_cache_store.dart',
    // RF-64: the notification client goes behind a port in the admin flow.
    'lib/data/notifications/admin_notification_client.dart',
  ],
  'lib/features/account/account_screen.dart': <String>[
    // RF-61: OrderSummary becomes a domain order model.
    'lib/data/local/database.dart',
    // RF-61: order history goes behind a domain port.
    'lib/data/repositories/order_history_repository.dart',
  ],
  'lib/features/checkout/checkout_screen.dart': <String>[
    // RF-52: the checkout ViewModel owns the cart repository.
    'lib/data/shopify/cart/cart_repository.dart',
    // RF-51: CompleteCheckout owns the cart session; its scope type moves out.
    'lib/data/shopify/cart/cart_session_store.dart',
  ],
  'lib/features/checkout/shopify_cart_summary.dart': <String>[
    // RF-52: the checkout ViewModel owns the cart repository.
    'lib/data/shopify/cart/cart_repository.dart',
    // RF-51: CompleteCheckout owns the cart session; its scope type moves out.
    'lib/data/shopify/cart/cart_session_store.dart',
  ],
  'lib/features/home/customer_experiences_screen.dart': <String>[
    // RF-66: niche features (E9); the Loox reviews go behind a port.
    'lib/data/reviews/loox_reviews_repository.dart',
  ],
  'lib/features/orders/order_detail_screen.dart': <String>[
    // RF-61: OrderSummary becomes a domain order model.
    'lib/data/local/database.dart',
  ],
  'lib/features/orders/order_status.dart': <String>[
    // RF-61: OrderSummary becomes a domain order model.
    'lib/data/local/database.dart',
  ],
  'lib/features/orders/orders_screen.dart': <String>[
    // RF-61: OrderSummary becomes a domain order model.
    'lib/data/local/database.dart',
    // RF-61: order history goes behind a domain port.
    'lib/data/repositories/order_history_repository.dart',
  ],
  'lib/features/rewards/rewards_api.dart': <String>[
    // RF-63: Rewards gets its own client; the HTTP wrapper leaves the feature.
    'lib/data/http/timeout_http_client.dart',
  ],
};

/// `import`/`export` directive with a plain string URI. Matches across line
/// breaks, with any `as`/`show`/`hide`/`deferred` suffix, and skips commented
/// out directives because they must start the line.
final RegExp _directive = RegExp(
  r'''^[ \t]*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

const String _packagePrefix = 'package:monetta_app/';

String _normalize(String path) => path.replaceAll(r'\', '/');

/// Repository-relative modules that [source], located at [filePath], imports
/// or exports from inside `lib/data/`. Pure function over text so the detector
/// can be exercised.
Set<String> dataModulesImportedBy(String filePath, String source) {
  final modules = <String>{};
  final base = Uri.parse(_normalize(filePath));
  for (final match in _directive.allMatches(source)) {
    final uri = match.group(1)!;
    String resolved;
    if (uri.startsWith(_packagePrefix)) {
      resolved = 'lib/${uri.substring(_packagePrefix.length)}';
    } else if (uri.contains(':')) {
      continue; // dart: or another package.
    } else {
      resolved = base.resolve(uri).path;
    }
    if (resolved.startsWith('lib/data/')) modules.add(resolved);
  }
  return modules;
}

bool isAllowed(String module) => _allowedModules.any(
      (allowed) => allowed.endsWith('/')
          ? module.startsWith(allowed)
          : module == allowed,
    );

List<File> _dartFiles(String root) => <File>[
      for (final entity in Directory(root).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ];

/// Every (file, module) pair under `lib/features/` that is not allowed.
Set<String> _currentPairs() {
  final pairs = <String>{};
  for (final file in _dartFiles('lib/features')) {
    final path = _normalize(file.path);
    for (final module in dataModulesImportedBy(path, file.readAsStringSync())) {
      if (!isAllowed(module)) pairs.add('$path -> $module');
    }
  }
  return pairs;
}

Set<String> _knownPairs() => <String>{
      for (final entry in _knownImports.entries)
        for (final module in entry.value) '${entry.key} -> $module',
    };

void main() {
  test('ARCH-02 the import detector resolves relative and package imports', () {
    const file = 'lib/features/checkout/checkout_screen.dart';
    expect(
      dataModulesImportedBy(file, "import '../../data/local/database.dart';"),
      <String>{'lib/data/local/database.dart'},
    );
    expect(
      dataModulesImportedBy(
        file,
        "import '../../data/local/database.dart' show OrderSummary;",
      ),
      <String>{'lib/data/local/database.dart'},
    );
    expect(
      dataModulesImportedBy(
        file,
        "import 'package:monetta_app/data/local/database.dart' as db;",
      ),
      <String>{'lib/data/local/database.dart'},
    );
    expect(
      dataModulesImportedBy(file, "export '../../data/media/media_url.dart';"),
      <String>{'lib/data/media/media_url.dart'},
    );
    // A directive split over several lines.
    expect(
      dataModulesImportedBy(
        file,
        "import\n    '../../data/local/database.dart'\n    show OrderSummary;",
      ),
      <String>{'lib/data/local/database.dart'},
    );
    // A path that climbs out and back in resolves to the same module.
    expect(
      dataModulesImportedBy(
        file,
        "import '../../../lib/data/local/database.dart';",
      ),
      <String>{'lib/data/local/database.dart'},
    );
    // Not data/: other layers, dart:, other packages, comments, strings.
    expect(
      dataModulesImportedBy(file, "import '../../domain/cart.dart';"),
      isEmpty,
    );
    expect(
      dataModulesImportedBy(file, "import 'package:flutter/material.dart';"),
      isEmpty,
    );
    expect(dataModulesImportedBy(file, "import 'dart:async';"), isEmpty);
    expect(
      dataModulesImportedBy(
        file,
        "// import '../../data/local/database.dart';",
      ),
      isEmpty,
    );
    expect(
      dataModulesImportedBy(file, "final s = 'import ../../data/x.dart';"),
      isEmpty,
    );
    // A sibling directory that merely starts with "data" is not data/.
    expect(
      dataModulesImportedBy(file, "import '../../database/x.dart';"),
      isEmpty,
    );
  });

  test('ARCH-02 the allowed list accepts files and directories exactly', () {
    expect(isAllowed('lib/data/media/media_url.dart'), isTrue);
    expect(isAllowed('lib/data/normalize/facets.dart'), isTrue);
    expect(isAllowed('lib/data/normalize/deep/x.dart'), isTrue);
    expect(isAllowed('lib/data/media/media_url.dart.bak'), isFalse);
    expect(isAllowed('lib/data/normalized/x.dart'), isFalse);
    expect(isAllowed('lib/data/local/database.dart'), isFalse);
    expect(isAllowed('lib/data/shopify/cart/cart_repository.dart'), isFalse);
  });

  test('ARCH-02 the lists are not vacuous and every module exists', () {
    // Guard against the ratchet passing because the scan found nothing.
    final features = _dartFiles('lib/features');
    expect(features.length, greaterThan(40));
    final allImports = <String>{
      for (final file in features)
        ...dataModulesImportedBy(
          _normalize(file.path),
          file.readAsStringSync(),
        ),
    };
    expect(
      allImports.where(isAllowed),
      isNotEmpty,
      reason: 'No allowed module is imported anymore: the scan is broken.',
    );
    expect(_knownPairs(), isNotEmpty);

    for (final module in _allowedModules) {
      final exists = module.endsWith('/')
          ? Directory(module).existsSync()
          : File(module).existsSync();
      expect(
        exists,
        isTrue,
        reason: '$module no longer exists: update the list.',
      );
    }
    for (final entry in _knownImports.entries) {
      expect(File(entry.key).existsSync(), isTrue, reason: entry.key);
      expect(
        entry.value.toSet().length,
        entry.value.length,
        reason: '${entry.key} lists a module twice.',
      );
      for (final module in entry.value) {
        expect(File(module).existsSync(), isTrue, reason: module);
        expect(
          isAllowed(module),
          isFalse,
          reason: '$module is allowed already: delete it from _knownImports.',
        );
      }
    }
  });

  test(
      'ARCH-02 features import data/ implementations only from the known list '
      '(RF-50 to RF-66 must empty it)', () {
    final current = _currentPairs();
    final known = _knownPairs();

    final added = (current.toList()..sort())
        .where((pair) => !known.contains(pair))
        .toList();
    final stale = (known.toList()..sort())
        .where((pair) => !current.contains(pair))
        .toList();

    expect(
      added,
      isEmpty,
      reason: 'New import of a lib/data/ implementation from lib/features/. '
          'Depend on a port or a domain type exposed through the scopes in '
          'lib/app/composition/app_scopes.dart, or justify a new entry in '
          '_allowedModules if it is a pure helper, model, error, config or '
          'port:\n${added.join('\n')}',
    );
    expect(
      stale,
      isEmpty,
      reason: 'These imports no longer exist: delete them from _knownImports '
          'so the list only shrinks:\n${stale.join('\n')}',
    );
  });
}
