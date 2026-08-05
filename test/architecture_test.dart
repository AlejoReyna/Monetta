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
          reason: 'These files must stay Flutter-free (see docs/ARCHITECTURE.md '
              '§ "The two rules"):\n${offenders.join('\n')}',
        );
      });
    }
  });
}
