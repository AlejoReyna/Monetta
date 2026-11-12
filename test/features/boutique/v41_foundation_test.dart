import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:monetta_app/features/boutique/client_guide_components.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/navigation/guide_chrome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import '../../support/client_guide_capture.dart';

void main() {
  test('all supplied assets resolve by ID with matching hashes and dimensions',
      () async {
    final manifest =
        jsonDecode(File('design-system/v41-assets.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final (kind, key) in [
      ('banner', 'banners'),
      ('homePhoto', 'home_photos'),
      ('icon', 'icons')
    ]) {
      for (final row in manifest[key] as List<dynamic>) {
        final item = row as Map<String, dynamic>;
        final id = '$kind:${item['id']}';
        final spec = guideAsset(id, forHome: true)!;
        final bytes = File(spec.path).readAsBytesSync();
        expect(sha256.convert(bytes).toString(), spec.sha256, reason: id);
        if (kind == 'homePhoto') expect(guideAsset(id), isNull);
        if (kind == 'banner') {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          expect([frame.image.width, frame.image.height], [1280, 533]);
          frame.image.dispose();
          codec.dispose();
        }
      }
    }
    expect(guideAsset('banner:unknown'), isNull);
  });

  testWidgets('button wraps enlarged copy and supports keyboard activation',
      (tester) async {
    var taps = 0;
    await pumpClientGuide(
        tester,
        Scaffold(
            body: Center(
                child: ClientGuideButton(
          label: 'Comenzar a vender con MONETTA',
          onPressed: () => taps++,
        ))),
        size: const Size(320, 1000),
        textScale: 2);
    final semantics = tester.ensureSemantics();
    expect(
        tester.getSemantics(find.byType(OutlinedButton)),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Comenzar a vender con MONETTA',
        ));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('shared assets and opaque reduced-motion controls render',
      (tester) async {
    await pumpClientGuide(
        tester,
        Builder(
            builder: (context) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(highContrast: true, disableAnimations: true),
                  child: Scaffold(
                      appBar: guideAppBar(context, onSearch: () {}),
                      body: SingleChildScrollView(
                          child: Column(children: [
                        const GuideBanner(id: 'B01'),
                        const GuideBanner(id: 'B02'),
                        const GuideBanner(id: 'B03'),
                        const GuideSemanticImage(
                            id: 'homePhoto:F01',
                            forHome: true,
                            width: 120,
                            height: 120),
                        GuideGlassSurface(
                            opaque: true,
                            child: ClientGuideButton(
                                label: 'Comenzar a vender', onPressed: () {})),
                      ]))),
                )),
        size: const Size(390, 1000));
    await captureClientGuide(tester, 'shared-assets-opaque-reduced-motion');
    expect(tester.takeException(), isNull);
    expect(boutiqueRowLabel().fontFamily, 'DM Sans');
    expect(boutiqueProductName().fontFamily, 'DM Sans');
  });

  for (final name in ['contact', 'wholesale']) {
    for (final width in [320.0, 768.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('hero readable $width/$scale', (tester) async {
          await pumpClientGuide(
              tester,
              Scaffold(
                  body: SingleChildScrollView(
                      child: GuideHero(
                asset:
                    name == 'contact' ? kGuideContactHero : kGuideWholesaleHero,
                title: 'Tu boutique y proveedor de',
                titleAccent: 'confianza.',
                textWidthFactor: .52,
                height: 200,
                subtitle:
                    'Bienvenida a nuestro paraíso de modelos originales de marcas que amas, importados y con envíos garantizados a todo México.',
              ))),
              size: Size(width, 1000),
              textScale: scale);
          await captureClientGuide(
              tester, '$name-${width.toInt()}-${scale.toInt()}x');
          expect(tester.takeException(), isNull);
          expect(find.byType(FittedBox), findsNothing);
          if (scale == 2) {
            expect(
                find.text(name == 'contact'
                    ? 'Tu boutique y proveedor de confianza.'
                    : 'MAYOREO'),
                findsOneWidget);
            expect(tester.getSize(find.byType(GuideHero)).height,
                greaterThan(name == 'contact' ? 200 : 100));
          }
        });
      }
    }
  }
}
