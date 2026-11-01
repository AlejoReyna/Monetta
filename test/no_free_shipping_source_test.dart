/// SHIP-05 to SHIP-07: the copy tables, the default announcement and the
/// source of `lib/` carry no free-shipping promise by amount.
///
/// The free shipping that stays is the owner's own: the Rewards benefit and
/// the wholesale terms of the client guide. They are the explicit exceptions
/// below; the test fails if one stops existing so the list cannot rot. (The
/// first-order offer on the account invitation left with the client guide.)
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/domain/admin_control.dart';

/// Free shipping the owner does offer, each with its reason. Anything else
/// that says "gratis" in lib/ fails SHIP-07.
const List<({String file, String literal, String why})> _exceptions = [
  (
    file: 'lib/features/rewards/rewards_guide_screen.dart',
    literal: 'Envío gratis',
    why: 'Rewards benefit from the client guide, not an amount threshold',
  ),
  (
    file: 'lib/features/boutique/client_guide_sections.dart',
    literal: 'Envío gratis',
    why: 'wholesale terms from the client guide (\$1,999), not the store',
  ),
  (
    file: 'lib/features/wholesale/wholesale_content.dart',
    literal: 'Envío gratis en compras mayores a \$1,999 MXN.',
    why: 'wholesale terms from the client guide (\$1,999), not the store',
  ),
];

const List<String> _removedSymbols = <String>[
  'kFreeShippingThreshold',
  'kStandardShippingFee',
  'shippingFor',
  'remainingForFreeShipping',
  'FreeShippingBar',
];

typedef _Literal = ({String file, int line, String text});

/// Extracts the string literals of a Dart source, skipping comments. Handles
/// raw strings, triple quotes, escapes and `${...}` interpolation (whose own
/// literals are extracted too). The interpolated expression text itself is
/// never part of a literal.
class _LiteralScanner {
  _LiteralScanner(this.file, this.source);

  final String file;
  final String source;
  final List<_Literal> literals = <_Literal>[];
  int _i = 0;
  int _line = 1;

  List<_Literal> scan() {
    _code(nested: false);
    return literals;
  }

  bool _at(String token) => source.startsWith(token, _i);

  bool _isIdentChar(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

  void _code({required bool nested}) {
    var depth = 0;
    while (_i < source.length) {
      final c = source[_i];
      if (c == '\n') {
        _line++;
        _i++;
      } else if (_at('//')) {
        while (_i < source.length && source[_i] != '\n') {
          _i++;
        }
      } else if (_at('/*')) {
        _i += 2;
        while (_i < source.length && !_at('*/')) {
          if (source[_i] == '\n') _line++;
          _i++;
        }
        _i += 2;
      } else if (c == "'" || c == '"') {
        _string(raw: false);
      } else if (c == 'r' &&
          _i + 1 < source.length &&
          (source[_i + 1] == "'" || source[_i + 1] == '"') &&
          (_i == 0 || !_isIdentChar(source[_i - 1]))) {
        _i++;
        _string(raw: true);
      } else if (nested && c == '{') {
        depth++;
        _i++;
      } else if (nested && c == '}') {
        _i++;
        if (depth == 0) return;
        depth--;
      } else {
        _i++;
      }
    }
  }

  void _string({required bool raw}) {
    final quote = source[_i];
    final triple = _at(quote * 3);
    final startLine = _line;
    _i += triple ? 3 : 1;
    final text = StringBuffer();
    while (_i < source.length) {
      if (triple ? _at(quote * 3) : source[_i] == quote) {
        _i += triple ? 3 : 1;
        break;
      }
      final c = source[_i];
      if (c == '\n') {
        _line++;
        text.write(c);
        _i++;
      } else if (!raw && c == r'\') {
        if (_i + 1 < source.length) {
          text.write(source[_i + 1]);
          if (source[_i + 1] == '\n') _line++;
        }
        _i += 2;
      } else if (!raw && c == r'$' && _i + 1 < source.length) {
        final next = source[_i + 1];
        if (next == '{') {
          _i += 2;
          _code(nested: true);
        } else if (RegExp(r'[A-Za-z_]').hasMatch(next)) {
          _i++;
          while (_i < source.length &&
              RegExp(r'[A-Za-z0-9_]').hasMatch(source[_i])) {
            _i++;
          }
        } else {
          text.write(c);
          _i++;
        }
      } else {
        text.write(c);
        _i++;
      }
    }
    literals.add((file: file, line: startLine, text: text.toString()));
  }
}

List<File> _dartFilesUnder(String directory) => [
      for (final entity in Directory(directory).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity,
    ]..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test(
      'SHIP-05 trust rows name shipping to all Mexico and promise nothing free',
      () {
    expect(kTrustRows, contains('Envío a todo México'));
    for (final row in kTrustRows) {
      expect(
        row.toLowerCase(),
        isNot(contains('gratis')),
        reason: 'trust row "$row" must not promise free shipping',
      );
    }
  });

  test('SHIP-06 the default storefront announcement is empty', () {
    expect(AdminStorefrontSettings.defaults.announcement, '');
  });

  group('SHIP-07 source', () {
    test(
        'SHIP-07 lib/ no longer defines or uses the amount-based shipping '
        'symbols', () {
      final offenders = <String>[];
      for (final file in _dartFilesUnder('lib')) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final symbol in _removedSymbols) {
            if (lines[i].contains(symbol)) {
              offenders.add('${file.path}:${i + 1}  $symbol');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'These symbols implemented the removed promotion:\n'
            '${offenders.join('\n')}',
      );
    });

    test('SHIP-07 "gratis" in lib/ is only the listed owner offers', () {
      final freeLiterals = <_Literal>[
        for (final file in _dartFilesUnder('lib'))
          for (final literal in _LiteralScanner(
            file.path,
            file.readAsStringSync(),
          ).scan())
            if (literal.text.toLowerCase().contains('gratis')) literal,
      ];

      bool matches(
        _Literal literal,
        ({String file, String literal, String why}) exception,
      ) =>
          literal.file == exception.file &&
          literal.text.toLowerCase() == exception.literal.toLowerCase();
      bool isException(_Literal literal) =>
          _exceptions.any((exception) => matches(literal, exception));

      final unexpected = [
        for (final literal in freeLiterals)
          if (!isException(literal))
            '${literal.file}:${literal.line}  "${literal.text}"',
      ];
      expect(
        unexpected,
        isEmpty,
        reason: 'Only the listed exceptions may mention "gratis":\n'
            '${unexpected.join('\n')}',
      );
      for (final exception in _exceptions) {
        expect(
          freeLiterals.where((literal) => matches(literal, exception)),
          hasLength(1),
          reason: 'The exception "${exception.literal}" in ${exception.file} '
              '(${exception.why}) no longer exists. Remove it from this test.',
        );
      }
    });

    test(
        'SHIP-07 literal scanner ignores comments and reads raw, escaped '
        'and interpolated strings', () {
      const sample = r'''
// 'gratis in a line comment'
/* "gratis in a block comment" */
const a = r'ENVÍO GRATIS DESDE $1,499';
const b = 'cuesta \$ gratis';
final c = 'sin ${flag ? 'Gratis' : kMoney.format(x)} fin';
const d = """
triple gratis
""";
const e = 'nada';
''';
      final found = _LiteralScanner('sample.dart', sample).scan();
      expect(
        [for (final l in found) (l.line, l.text)],
        [
          (3, r'ENVÍO GRATIS DESDE $1,499'),
          (4, r'cuesta $ gratis'),
          (5, 'Gratis'),
          (5, 'sin  fin'),
          (6, '\ntriple gratis\n'),
          (9, 'nada'),
        ],
      );
    });
  });
}
