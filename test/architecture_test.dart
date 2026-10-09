/// Enforces the layering rule from `docs/ARCHITECTURE.md`.
///
/// `reco/`, `data/normalize/` and `domain/` must stay pure Dart. Their tests run
/// in milliseconds with no widget pump, and the scoring logic stays portable for
/// the Phase 2 move of collaborative filtering to the server. A convention
/// nobody checks is a convention that decays, so this is a test.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const List<String> _pureDartDirectories = <String>[
  'lib/reco',
  'lib/data/normalize',
  'lib/data/shopify',
  'lib/domain',
];

void main() {
  group('architecture', () {
    for (final directory in _pureDartDirectories) {
      test('$directory contains no Flutter imports', () {
        final offenders = <String>[];

        final dir = Directory(directory);
        expect(
          dir.existsSync(),
          isTrue,
          reason: '$directory is missing — did the layout change?',
        );

        for (final entity in dir.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (!line.startsWith('import ') && !line.startsWith('export ')) {
              continue;
            }
            if (line.contains('package:flutter/') ||
                line.contains('package:flutter_')) {
              offenders.add('${entity.path}:${i + 1}  $line');
            }
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'These files must stay Flutter-free (see docs/ARCHITECTURE.md '
              '§ "The two rules"):\n${offenders.join('\n')}',
        );
      });
    }

    test('INV-12 the destination vocabulary stays Flutter-free', () {
      // `AppDestination` is the typed vocabulary of the app's routes. It is
      // read by non-widget code (deep links, notification routing), so it must
      // not drag Flutter in. The navigator and the screens map live next to it
      // and are allowed to import Flutter.
      const path = 'lib/app/destinations/app_destination.dart';
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');

      final offenders = <String>[];
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }
        if (line.contains('package:flutter/') ||
            line.contains('package:flutter_')) {
          offenders.add('$path:${i + 1}  $line');
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('INV-12 features read the composition only through app_scopes', () {
      // `app_dependencies.dart` and `platform_services.dart` are the internals
      // of the composition root. A screen that imports them can construct or
      // reach concrete dependencies; screens go through `app_scopes.dart`.
      const internals = <String>[
        'app/composition/app_dependencies.dart',
        'app/composition/platform_services.dart',
      ];
      final offenders = <String>[];

      for (final entity
          in Directory('lib/features').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('import ') && !line.startsWith('export ')) {
            continue;
          }
          if (internals.any(line.contains)) {
            offenders.add('${entity.path}:${i + 1}  $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Features may import only app/composition/app_scopes.dart '
            'from the composition root:\n${offenders.join('\n')}',
      );
    });

    test('INV-12 the shopper scope is covered by the pure domain rule', () {
      // `lib/domain/shopper_scope.dart` has no test of its own on purpose: it
      // lives under `lib/domain`, which the loop over [_pureDartDirectories]
      // already checks for Flutter imports. This guards that the file stays
      // inside that directory and that the directory stays on the list.
      expect(_pureDartDirectories, contains('lib/domain'));
      expect(File('lib/domain/shopper_scope.dart').existsSync(), isTrue);
    });

    test('checkout UI does not import a Checkout Kit SDK', () {
      final offenders = <String>[];
      final dir = Directory('lib/features/checkout');

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (!line.startsWith('import ')) continue;
          if (line.contains('checkout_sheet_kit') ||
              line.contains('ShopifyCheckoutSheetKit') ||
              line.contains('checkout-sheet-kit')) {
            offenders.add('${entity.path}:${i + 1}  $line');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Checkout UI must depend on CheckoutLauncher, never an SDK:\n'
            '${offenders.join('\n')}',
      );
    });

    test('customer experiences stay out of checkout and cart', () {
      const reviewPaths = <String>[
        'lib/features/home/customer_experiences_section.dart',
        'lib/data/reviews/loox_reviews_repository.dart',
        'lib/app/home_content_controller.dart',
      ];
      const checkoutPaths = <String>[
        'lib/app/cart_controller.dart',
        'lib/app/shopify_cart_composition.dart',
        'lib/domain/cart.dart',
      ];
      final offenders = <String>[];

      for (final path in reviewPaths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        for (final line in file.readAsLinesSync()) {
          if (!line.trim().startsWith('import ')) continue;
          if (line.contains('/checkout/') ||
              line.contains('cart_controller') ||
              line.contains('shopify_cart_composition') ||
              line.contains('domain/cart.dart') ||
              line.contains('data/shopify/cart')) {
            offenders.add('$path: $line');
          }
        }
      }

      final checkoutDir = Directory('lib/features/checkout');
      for (final entity in checkoutDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final line in entity.readAsLinesSync()) {
          if (!line.trim().startsWith('import ')) continue;
          if (line.contains('customer_experiences_section') ||
              line.contains('loox_reviews_repository')) {
            offenders.add('${entity.path}: $line');
          }
        }
      }

      for (final path in checkoutPaths) {
        final file = File(path);
        if (!file.existsSync()) continue;
        for (final line in file.readAsLinesSync()) {
          if (!line.trim().startsWith('import ')) continue;
          if (line.contains('customer_experiences_section') ||
              line.contains('loox_reviews_repository')) {
            offenders.add('$path: $line');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('feature UI does not use legacy light-only semantic colors', () {
      const forbidden = <String>[
        'kInkMuted',
        'kMist',
        'kSearchFill',
        'kLine',
        'kHairline',
        'kSale',
      ];
      final offenders = <String>[];
      final dir = Directory('lib/features');

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          for (final token in forbidden) {
            if (lines[index].contains(token)) {
              offenders.add('${entity.path}:${index + 1} uses $token');
            }
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Use context.monettaColors for theme-dependent UI:\n'
            '${offenders.join('\n')}',
      );
    });
  });
}
