import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
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

String _hex(Color color) =>
    '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

void main() {
  group('boutique light palette', () {
    // One test per field so a red run names every colour that still has to
    // change, not only the first one. Values are the style guideline's
    // generated tokens (design-system/monetta.tokens.json).
    for (final target in <String, (Color, Color Function(BoutiquePalette))>{
      'canvas': (MonettaTokens.canvas, (p) => p.canvas),
      'surface (product tiles)': (MonettaTokens.surfaceTile, (p) => p.surface),
      'surfaceDeep (warm panels)': (
        MonettaTokens.surfaceWarm,
        (p) => p.surfaceDeep,
      ),
      'selectedFill': (MonettaTokens.surfaceWarm, (p) => p.selectedFill),
      'bar': (MonettaTokens.bar, (p) => p.bar),
      'action (brown)': (MonettaTokens.actionPrimary, (p) => p.action),
      'onAction': (MonettaTokens.onActionPrimary, (p) => p.onAction),
      'actionDark': (MonettaTokens.actionDark, (p) => p.actionDark),
      'borderControl': (MonettaTokens.borderControl, (p) => p.borderControl),
      'saleSurface': (MonettaTokens.saleSurface, (p) => p.saleSurface),
    }.entries) {
      testWidgets(
        'STYLE-01 ${target.key} is ${_hex(target.value.$1)}',
        (tester) async {
          final palette = await _paletteUnder(tester, buildTheme());
          expect(_hex(target.value.$2(palette)), _hex(target.value.$1));
        },
      );
    }

    test('STYLE-01 the page ground is a warm ivory, never pure white', () {
      expect(MonettaColors.light.canvas, isNot(const Color(0xFFFFFFFF)));
      expect(
        MonettaColors.light.canvas.r,
        greaterThan(MonettaColors.light.canvas.b),
      );
    });

    test('STYLE-01 the bars share one navigation surface', () {
      expect(
        _hex(MonettaColors.light.navigationSurface),
        _hex(MonettaTokens.bar),
      );
    });

    testWidgets(
      'STYLE-02 (caracterización) ink, sale, hairline roles and the dark '
      'palette',
      (tester) async {
        final light = await _paletteUnder(tester, buildTheme());
        expect(light.ink, MonettaTokens.ink);
        expect(light.inkMuted, MonettaTokens.inkMuted);
        expect(light.gold, const Color(0xFFC5A052));
        expect(light.goldText, MonettaTokens.accentText);
        expect(light.hairline, MonettaTokens.divider);
        expect(light.selectedBorder, MonettaTokens.actionPrimary);
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
        expect(dark.action, shared.actionPrimary);

        // MonettaColors.light: the semantic roles of the guideline.
        const l = MonettaColors.light;
        expect(l.canvas, MonettaTokens.canvas);
        expect(l.surface, MonettaTokens.surface);
        expect(l.surfaceRaised, MonettaTokens.surface);
        expect(l.surfaceMuted, MonettaTokens.surfaceWarm);
        expect(l.mediaPlaceholder, MonettaTokens.surfaceTile);
        expect(l.contentPrimary, MonettaTokens.ink);
        expect(l.contentMuted, MonettaTokens.inkMuted);
        expect(l.divider, MonettaTokens.divider);
        expect(l.inputFill, MonettaTokens.surface);
        expect(l.inverseSurface, MonettaTokens.ink);
        expect(l.onInverseSurface, MonettaTokens.canvas);
        expect(l.accent, kGold);
        expect(l.accentContent, MonettaTokens.accentText);
        expect(l.sale, kSale);
        expect(l.sale, const Color(0xFFA3342B));
        expect(l.success, const Color(0xFF3B7B4A));
        expect(l.warningSurface, MonettaTokens.surfaceWarm);
        expect(l.successSurface, const Color(0xFFEAF4EC));
        expect(l.navigationForeground, MonettaTokens.navigationActive);
        expect(l.navigationForegroundMuted, MonettaTokens.navigationInactive);

        // MonettaColors.dark: every pre-existing field, unchanged.
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
      'UI-THEME-03 (objetivo) light appBarTheme paints the shared bar surface',
      () {
        expect(
          _hex(buildTheme().appBarTheme.backgroundColor!),
          _hex(MonettaTokens.bar),
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
