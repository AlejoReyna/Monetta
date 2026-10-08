import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';

/// Pumps a tiny app under [theme] and returns the palette the boutique layer
/// resolves for it, so the test reads exactly what the screens read.
Future<BoutiquePalette> _paletteUnder(
  WidgetTester tester,
  ThemeData theme,
) async {
  late BoutiquePalette palette;
  await tester.pumpWidget(
    MaterialApp(
      // A fresh element per brightness: a theme swap on the same app would
      // animate and the first frame would still read the previous one.
      key: ValueKey<Brightness>(theme.brightness),
      theme: theme,
      home: Builder(
        builder: (context) {
          palette = BoutiquePalette.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return palette;
}

bool _isNeutralGrey(Color color) {
  final r = (color.r * 255).round();
  final g = (color.g * 255).round();
  final b = (color.b * 255).round();
  return r == g && g == b;
}

String _hex(Color color) =>
    '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

void main() {
  group('boutique light palette', () {
    // One test per field so a red run names every colour that still has to
    // change, not only the first one.
    for (final target in <String, (Color, Color Function(BoutiquePalette))>{
      'canvas': (const Color(0xFFFFFFFF), (p) => p.canvas),
      'surface': (const Color(0xFFFAFAFA), (p) => p.surface),
      'surfaceDeep': (const Color(0xFFF0F0F0), (p) => p.surfaceDeep),
      'selectedFill': (const Color(0xFFF0F0F0), (p) => p.selectedFill),
    }.entries) {
      testWidgets(
        'UI-THEME-01 (objetivo) ${target.key} is ${_hex(target.value.$1)} '
        'and a neutral grey',
        (tester) async {
          final palette = await _paletteUnder(tester, buildTheme());
          final actual = target.value.$2(palette);

          expect(_hex(actual), _hex(target.value.$1));
          expect(
            _isNeutralGrey(actual),
            isTrue,
            reason: '${target.key} ${_hex(actual)} must have r == g == b '
                '(no warm tint)',
          );
        },
      );
    }

    test(
      'UI-THEME-01 (objetivo) the navigation surface that the bars share is '
      '0xFFF5F5F5',
      () {
        expect(
          _hex(MonettaColors.light.navigationSurface),
          _hex(const Color(0xFFF5F5F5)),
        );
      },
    );

    testWidgets(
      'UI-THEME-02 (caracterización) brand colours and the dark palette are '
      'untouched',
      (tester) async {
        final light = await _paletteUnder(tester, buildTheme());
        expect(light.ink, const Color(0xFF111111));
        expect(light.inkMuted, const Color(0xFF6B6660));
        expect(light.gold, const Color(0xFFC5A052));
        expect(light.goldText, const Color(0xFF8F6838));
        expect(light.hairline, const Color(0x1F111111));
        expect(light.selectedBorder, const Color(0xFF111111));
        expect(light.sale, const Color(0xFFA3342B));
        expect(light.onDark, const Color(0xFFF8F5EE));

        final dark = await _paletteUnder(tester, buildDarkTheme());
        const shared = MonettaColors.dark;
        expect(dark.canvas, shared.canvas);
        expect(dark.surface, shared.surfaceRaised);
        expect(dark.surfaceDeep, shared.surfaceMuted);
        expect(dark.ink, shared.contentPrimary);
        expect(dark.inkMuted, shared.contentMuted);
        expect(dark.gold, shared.accent);
        expect(dark.goldText, shared.accentContent);
        expect(dark.hairline, shared.divider);
        expect(dark.selectedFill, shared.surfaceMuted);
        expect(dark.selectedBorder, shared.contentPrimary);
        expect(dark.sale, shared.sale);
        expect(dark.onDark, const Color(0xFFF8F5EE));

        // MonettaColors.light: every field except navigationSurface.
        const l = MonettaColors.light;
        expect(l.canvas, const Color(0xFFFFFFFF));
        expect(l.surface, const Color(0xFFFFFFFF));
        expect(l.surfaceRaised, const Color(0xFFFFFFFF));
        expect(l.surfaceMuted, const Color(0xFFF5F5F5));
        expect(l.mediaPlaceholder, const Color(0xFFF5F5F5));
        expect(l.contentPrimary, const Color(0xFF111111));
        expect(l.contentMuted, const Color(0xFF737373));
        expect(l.divider, const Color(0x26111111));
        expect(l.inputFill, const Color(0xFFF1F1F1));
        expect(l.inverseSurface, const Color(0xFF111111));
        expect(l.onInverseSurface, const Color(0xFFFFFFFF));
        expect(l.accent, kGold);
        expect(l.accent, const Color(0xFFAA7D44));
        expect(l.accentContent, const Color(0xFF8F6838));
        expect(l.sale, kSale);
        expect(l.sale, const Color(0xFFA3342B));
        expect(l.success, const Color(0xFF3B7B4A));
        expect(l.warningSurface, const Color(0xFFF7F0E6));
        expect(l.successSurface, const Color(0xFFEAF4EC));
        expect(l.scrim, const Color(0x52000000));
        expect(l.navigationSelection, const Color(0x24AA7D44));
        expect(l.navigationForeground, const Color(0xFF222222));
        expect(l.navigationForegroundMuted, const Color(0xFF6E6E6E));

        // MonettaColors.dark: every field.
        const d = MonettaColors.dark;
        expect(d.canvas, const Color(0xFF11100F));
        expect(d.surface, const Color(0xFF171615));
        expect(d.surfaceRaised, const Color(0xFF201E1C));
        expect(d.surfaceMuted, const Color(0xFF282521));
        expect(d.mediaPlaceholder, const Color(0xFF242220));
        expect(d.contentPrimary, const Color(0xFFF5F2EC));
        expect(d.contentMuted, const Color(0xFFB9B3AA));
        expect(d.divider, const Color(0x33FFFFFF));
        expect(d.inputFill, const Color(0xFF242220));
        expect(d.inverseSurface, const Color(0xFFF5F2EC));
        expect(d.onInverseSurface, const Color(0xFF171615));
        expect(d.accent, const Color(0xFFC49A65));
        expect(d.accentContent, const Color(0xFFC49A65));
        expect(d.sale, const Color(0xFFE48176));
        expect(d.success, const Color(0xFF9ABC75));
        expect(d.warningSurface, const Color(0xFF33281D));
        expect(d.successSurface, const Color(0xFF1C3022));
        expect(d.scrim, const Color(0xA6000000));
        expect(d.navigationSurface, const Color(0xFF171615));
        expect(d.navigationSelection, const Color(0x3DC49A65));
        expect(d.navigationForeground, const Color(0xFFF5F2EC));
        expect(d.navigationForegroundMuted, const Color(0xFF8E8A85));
      },
    );
  });

  group('shared theme app bar', () {
    test(
      'UI-THEME-03 (objetivo) light appBarTheme paints the navigation grey',
      () {
        expect(
          _hex(buildTheme().appBarTheme.backgroundColor!),
          _hex(const Color(0xFFF5F5F5)),
        );
      },
    );

    test(
      'UI-THEME-03 (caracterización) dark appBarTheme stays on the dark '
      'surface',
      () {
        expect(
          buildDarkTheme().appBarTheme.backgroundColor,
          MonettaColors.dark.surface,
        );
        expect(
          buildDarkTheme().appBarTheme.backgroundColor,
          const Color(0xFF171615),
        );
      },
    );
  });
}
