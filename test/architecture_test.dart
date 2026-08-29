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
  });
}
