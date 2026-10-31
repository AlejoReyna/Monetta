/// UI-01 (objective state, red until RF-17 step 3): the app ships Inter and
/// Playfair Display, every typography helper and both themes use only those two
/// families at weights the bundle actually declares, and the app registers
/// their SIL Open Font License with the license page.
///
/// "The bundle declares it" is read from `FontManifest.json`, which
/// `flutter test` generates from `pubspec.yaml` exactly as `flutter build` does.
/// Today the manifest only lists `MaterialIcons`, so every check fails: the
/// families are not declared, the helpers still name Helvetica Neue / New York
/// or no family at all, and no license is registered.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';

import '../support/monetta_app_harness.dart';

const String _inter = 'Inter';
const String _playfair = 'Playfair Display';
const Set<String> _bundledFamilies = <String>{_inter, _playfair};

/// manifest family -> declared (asset, weight) pairs. A face without `weight`
/// counts as 400.
late final Map<String, List<({String asset, int weight})>> _manifest;

/// Loads `FontManifest.json` from the bundle `flutter test` builds.
Future<Map<String, List<({String asset, int weight})>>> _loadManifest() async {
  final raw = await rootBundle.loadString('FontManifest.json');
  final decoded = jsonDecode(raw) as List<dynamic>;
  final families = <String, List<({String asset, int weight})>>{};
  for (final entry in decoded.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    final fonts =
        (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>();
    families[family] = [
      for (final font in fonts)
        (
          asset: font['asset'] as String,
          weight: (font['weight'] as num?)?.toInt() ?? 400,
        ),
    ];
  }
  return families;
}

/// Why [style] is not backed by a bundled face, or null when it is.
String? _unbackedReason(String name, TextStyle style) {
  final family = style.fontFamily;
  if (!_bundledFamilies.contains(family)) {
    return '$name uses fontFamily "$family"; expected "$_inter" or '
        '"$_playfair".';
  }
  final weight = style.fontWeight?.value ?? 400;
  final faces = _manifest[family] ?? const [];
  if (!faces.any((face) => face.weight == weight)) {
    final declared = [for (final face in faces) face.weight];
    return '$name asks for $family w$weight but the font manifest declares '
        '${declared.isEmpty ? 'no faces' : 'only w$declared'} for it.';
  }
  return null;
}

void _expectBacked(String name, TextStyle style) {
  final reason = _unbackedReason(name, style);
  expect(reason, isNull, reason: reason);
}

/// Every style slot of [theme], by name. A [TextTheme] has no iterator.
Map<String, TextStyle?> _slots(String prefix, TextTheme theme) => {
      '$prefix.displayLarge': theme.displayLarge,
      '$prefix.displayMedium': theme.displayMedium,
      '$prefix.displaySmall': theme.displaySmall,
      '$prefix.headlineLarge': theme.headlineLarge,
      '$prefix.headlineMedium': theme.headlineMedium,
      '$prefix.headlineSmall': theme.headlineSmall,
      '$prefix.titleLarge': theme.titleLarge,
      '$prefix.titleMedium': theme.titleMedium,
      '$prefix.titleSmall': theme.titleSmall,
      '$prefix.bodyLarge': theme.bodyLarge,
      '$prefix.bodyMedium': theme.bodyMedium,
      '$prefix.bodySmall': theme.bodySmall,
      '$prefix.labelLarge': theme.labelLarge,
      '$prefix.labelMedium': theme.labelMedium,
      '$prefix.labelSmall': theme.labelSmall,
    };

void _expectThemeFamilies(String label, ThemeData theme) {
  final slots = <String, TextStyle?>{
    ..._slots('$label.textTheme', theme.textTheme),
    ..._slots('$label.primaryTextTheme', theme.primaryTextTheme),
  };
  final offenders = <String>[
    for (final entry in slots.entries)
      if (entry.value != null &&
          !_bundledFamilies.contains(entry.value!.fontFamily))
        '${entry.key}: "${entry.value!.fontFamily}"',
  ];
  expect(
    offenders.isEmpty,
    isTrue,
    reason: 'Every non-null text style of $label must use "$_inter" or '
        '"$_playfair". Off-family: $offenders',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _manifest = await _loadManifest();
  });

  group('UI-01 font manifest', () {
    for (final family in [_inter, _playfair]) {
      test('UI-01 manifest declares $family and every asset exists', () {
        final faces = _manifest[family];
        expect(
          faces,
          isNotNull,
          reason: 'FontManifest.json must declare "$family"; it declares '
              '${_manifest.keys.toList()} (pubspec.yaml has no fonts: section).',
        );
        expect(faces, isNotEmpty);
        for (final face in faces!) {
          expect(
            File(face.asset).existsSync(),
            isTrue,
            reason: '$family declares ${face.asset}, which is not on disk.',
          );
        }
      });
    }
  });

  group('UI-01 typography helpers', () {
    final helpers = <String, TextStyle Function()>{
      'display': () => display(24),
      'editorial': () => editorial(24),
      'wordmark': () => wordmark(),
      'eyebrow': () => eyebrow(),
      'sans': () => sans(),
      'boutiqueDisplay': () => boutiqueDisplay(24),
      'boutiqueTitle': () => boutiqueTitle(),
      'boutiqueScreenTitle': () => boutiqueScreenTitle(),
      'boutiqueHeaderName': () => boutiqueHeaderName(),
      'boutiqueProductName': () => boutiqueProductName(),
      'boutiqueSectionHeading': () => boutiqueSectionHeading(),
      'boutiqueText': () => boutiqueText(),
      'boutiqueEyebrow': () => boutiqueEyebrow(),
    };
    for (final entry in helpers.entries) {
      test(
        'UI-01 ${entry.key}() uses a bundled family at a declared weight',
        () => _expectBacked('${entry.key}()', entry.value()),
      );
    }
  });

  group('UI-01 themes', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('UI-01 light theme text styles use Inter or Playfair on $platform',
          () {
        debugDefaultTargetPlatformOverride = platform;
        try {
          _expectThemeFamilies('buildLightTheme()', buildLightTheme());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      test('UI-01 dark theme text styles use Inter or Playfair on $platform',
          () {
        debugDefaultTargetPlatformOverride = platform;
        try {
          _expectThemeFamilies('buildDarkTheme()', buildDarkTheme());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  });

  group('UI-01 license', () {
    const holders = <String, String>{
      _inter: 'The Inter Project Authors',
      _playfair: 'The Playfair Display Project Authors',
    };

    testWidgets(
      'UI-01 MonettaApp registers the SIL OFL of Inter and Playfair Display',
      (tester) async {
        await withMonettaApp(tester, () async {
          final entries = await tester.runAsync(
            () => LicenseRegistry.licenses.toList(),
          );
          expect(entries, isNotNull);

          for (final entry in holders.entries) {
            final family = entry.key;
            final matches = [
              for (final license in entries!)
                if (license.packages.any((p) => p.contains(family))) license,
            ];
            final texts = [
              for (final license in matches)
                license.paragraphs.map((p) => p.text).join('\n'),
            ];
            expect(
              texts.any((text) => text.contains('SIL Open Font License')),
              isTrue,
              reason: 'LicenseRegistry must hold an entry for "$family" whose '
                  'text contains "SIL Open Font License"; found '
                  '${matches.length} entries for it.',
            );
            expect(
              texts.any((text) => text.contains(entry.value)),
              isTrue,
              reason: 'The "$family" license must carry the copyright holder '
                  '"${entry.value}"; found ${matches.length} entries for it.',
            );
          }
        });
      },
    );
  });
}
