/// ARCH-01 (ratchet): `lib/features/` must not import `lib/main.dart`.
///
/// Feature widgets reach the app scopes (`StoreScope`, `AccountScope`, ...)
/// through `main.dart`, which makes the composition root a dependency of every
/// screen. RF-30 moves the scopes out of `main.dart` and must leave
/// [_knownViolations] EMPTY.
///
/// The list is alive in both directions:
/// * a file that imports `main.dart` and is not listed fails the test (no new
///   violation may appear), and
/// * a listed file that no longer imports `main.dart` fails the test (delete
///   it from the list), so the list can only shrink.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files under `lib/features/` that import `main.dart` today (RF-30 baseline),
/// as paths relative to the repository root.
const List<String> _knownViolations = <String>[];

/// Matches `import '...main.dart'` and `import "...main.dart"`, relative or
/// `package:monetta_app/main.dart`, with any `show`/`hide`/`as` suffix. The
/// path must end exactly in `main.dart` (so `domain_main.dart` does not match).
final RegExp _mainImport = RegExp(
  r'''^\s*(?:import|export)\s+['"](?:[^'"]*/)?main\.dart['"]''',
  multiLine: true,
);

/// Pure function over a file's text, so the detector itself can be exercised.
bool importsMain(String source) => _mainImport.hasMatch(source);

String _normalize(String path) => path.replaceAll(r'\', '/');

List<String> _currentImporters() {
  final result = <String>[];
  for (final entity in Directory('lib/features').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (importsMain(entity.readAsStringSync())) {
      result.add(_normalize(entity.path));
    }
  }
  result.sort();
  return result;
}

void main() {
  test('ARCH-01 the import detector recognizes relative and package imports',
      () {
    expect(importsMain("import '../../main.dart';"), isTrue);
    expect(importsMain("import '../../main.dart' show StoreScope;"), isTrue);
    expect(importsMain("import 'package:monetta_app/main.dart';"), isTrue);
    expect(importsMain('import "../main.dart" as app;'), isTrue);
    expect(importsMain("import '../../app/catalog_store.dart';"), isFalse);
    expect(importsMain("import 'domain_main.dart';"), isFalse);
    expect(importsMain("// import '../../main.dart';"), isFalse);
  });

  test(
      'ARCH-01 features import main.dart only from the known list (RF-30 '
      'must empty it)', () {
    final current = _currentImporters();
    final known = _knownViolations.toSet();

    final added = current.where((path) => !known.contains(path)).toList();
    final stale =
        _knownViolations.where((path) => !current.contains(path)).toList();

    expect(
      added,
      isEmpty,
      reason: 'New imports of lib/main.dart from lib/features/. Feature code '
          'must read the app scopes from lib/app/, not from main.dart:\n'
          '${added.join('\n')}',
    );
    expect(
      stale,
      isEmpty,
      reason: 'These files no longer import lib/main.dart: delete them from '
          '_knownViolations so the list only shrinks:\n${stale.join('\n')}',
    );
    expect(
      _knownViolations.length,
      _knownViolations.toSet().length,
      reason: '_knownViolations has duplicate entries.',
    );
  });
}
