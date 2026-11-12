/// Guide v2, part A: the guide's serif and script, the banner pill and the
/// services row.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/client_guide_sections.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/home/home_boutique_sections.dart';
import 'package:monetta_app/features/rewards/rewards_share_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';

/// Style of the first span whose text is exactly [text], inside any
/// [RichText] (a `Text.rich` run such as «fácil»).
TextStyle? _spanStyle(WidgetTester tester, String text) {
  TextStyle? found;
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.style;
        return false;
      }
      return true;
    });
    if (found != null) break;
  }
  return found;
}

TextStyle _textStyle(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
    debugMonettaFixtureImage = MemoryImage(
      File('test/support/fixture_product.jpg').readAsBytesSync(),
    );
  });
  tearDown(() => debugMonettaFixtureImage = null);

  Future<CatalogStore> store() async {
    final db = openTestDatabase();
    final catalog = CatalogStore(database: db);
    await catalog.loadFromAsset();
    addTearDown(() async {
      catalog.dispose();
      await db.close();
    });
    return catalog;
  }

  group('families', () {
    test('the guide fonts are the registered stand-ins', () {
      expect(kGuideSerifFamily, 'Cormorant Garamond');
      expect(kGuideScriptFamily, 'Mrs Saint Delafield');
    });

    testWidgets('the accent style is the script, underlined on request', (
      tester,
    ) async {
      late TextStyle plain;
      late TextStyle underlined;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              plain = guideAccentStyle(context, size: 30);
              underlined = guideAccentStyle(context, size: 30, underline: true);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(plain.fontFamily, kGuideScriptFamily);
      expect(plain.decoration, TextDecoration.none);
      expect(underlined.fontFamily, kGuideScriptFamily);
      expect(underlined.decoration, TextDecoration.underline);
    });

    testWidgets('COACH is upright Cormorant and TOTES is italic', (
      tester,
    ) async {
      final catalog = await store();
      await pumpClientGuide(
        tester,
        StoreScope(
          notifier: catalog,
          child: const CollectionScreen(
            title: 'Coach',
            filter: CollectionFilter(brand: 'coach'),
          ),
        ),
      );
      final coach = _textStyle(tester, 'COACH');
      expect(coach.fontFamily, kGuideSerifFamily);
      expect(coach.fontStyle, isNot(FontStyle.italic));

      await pumpClientGuide(
        tester,
        StoreScope(
          notifier: catalog,
          child: const CollectionScreen(
            title: 'Totes',
            filter: CollectionFilter(category: 'bolsa', silhouette: 'tote'),
          ),
        ),
      );
      final totes = _textStyle(tester, 'TOTES');
      expect(totes.fontFamily, kGuideSerifFamily);
      expect(totes.fontStyle, FontStyle.italic);
    });

    testWidgets('home banner: Compra in italic serif, fácil in script', (
      tester,
    ) async {
      await pumpClientGuide(
        tester,
        Scaffold(
          body: HomeEditorialBanner(playing: true, onOpenNew: () {}),
        ),
      );
      final compra = _spanStyle(tester, 'Compra ')!;
      expect(compra.fontFamily, kGuideSerifFamily);
      expect(compra.fontStyle, FontStyle.italic);
      expect(_spanStyle(tester, 'fácil')!.fontFamily, kGuideScriptFamily);
      final desde = _textStyle(tester, 'desde México');
      expect(desde.fontFamily, kGuideSerifFamily);
      expect(desde.fontStyle, FontStyle.italic);
    });

    testWidgets('Comparte y gana: script word, serif «y gana» and body', (
      tester,
    ) async {
      await pumpClientGuide(
        tester,
        const RewardsShareScreen(),
        size: const Size(390, 1200),
      );
      expect(_textStyle(tester, 'Comparte').fontFamily, kGuideScriptFamily);
      expect(_textStyle(tester, 'y gana').fontFamily, kGuideSerifFamily);
      final body = _textStyle(
        tester,
        'Explora nuestros catálogos, compártelos con el mundo y comienza a '
        'ganar desde tu primer pedido.',
      );
      expect(body.fontFamily, kGuideSerifFamily);
      expect(body.fontStyle, FontStyle.italic);
    });

    testWidgets(
        'B04 preserves delivered lettering rather than reconstructing fonts',
        (tester) async {
      await pumpClientGuide(
          tester,
          const SingleChildScrollView(
              child: ClientGuideEditorial(
            title: 'PRECIOS DE',
            titleAccent: 'mayoreo',
            subtitle: 'A partir de 3 piezas',
            imageAsset: kGuideHomeWholesale,
            overlaySide: GuideTextSide.right,
          )));
      expect(find.byType(GuideBanner), findsOneWidget);
      expect(find.text('PRECIOS DE'), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName,
          guideAsset('banner:B04-editorial')!.path);
    });
  });

  group('GuidePillButton', () {
    testWidgets('keeps its key and callback and a 48 px target', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GuidePillButton(
                key: const ValueKey('pill'),
                label: 'ver catálogo',
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byKey(const ValueKey('pill')));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
      // The label is set in capitals of the guide serif.
      expect(find.text('VER CATÁLOGO'), findsOneWidget);
      expect(
          tester
              .widget<OutlinedButton>(find.byType(OutlinedButton))
              .style!
              .textStyle!
              .resolve({})!.fontFamily,
          'DM Sans');
      await tester.tap(find.byKey(const ValueKey('pill')));
      expect(taps, 1);
    });

    testWidgets('without a callback it is disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: GuidePillButton(
                key: ValueKey('pill'),
                label: 'Conoce más',
                onPressed: null,
              ),
            ),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(find.byType(OutlinedButton));
      expect(node.flagsCollection.isEnabled, ui.Tristate.isFalse);
      semantics.dispose();
    });
  });

  group('services row', () {
    testWidgets('home: the guide texts with the four gold icons', (
      tester,
    ) async {
      await pumpClientGuide(
        tester,
        const SingleChildScrollView(child: ClientGuideServices()),
      );
      for (final text in [
        'Envíos seguros',
        'Seguros y garantizados a todo México',
        'Pagos seguros',
        'Compra con confianza',
        'Productos 100% originales',
        'Garantía de autenticidad',
        'Atención personalizada',
        'Estamos para ayudarte',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      expect(find.text('Costo y plazo por confirmar'), findsNothing);
      expect(find.text('Garantía sujeta a cada pieza'), findsNothing);
      final assets = [
        for (final image in tester.widgetList<Image>(find.byType(Image)))
          (image.image as AssetImage).assetName,
      ];
      expect(assets, [
        kGuideIconServiceShipping,
        kGuideIconServicePayments,
        kGuideIconServiceOriginals,
        kGuideIconServiceSupport,
      ]);
    });

    testWidgets(
        'wholesale uses safe shipping presentation without unapproved threshold',
        (
      tester,
    ) async {
      await pumpClientGuide(
        tester,
        SingleChildScrollView(
          child: ClientGuideServices(services: kClientGuideWholesaleServices),
        ),
      );
      expect(find.text('Envío gratis'), findsNothing);
      expect(find.text(r'En compras mayores a $1,999 MXN'), findsNothing);
      expect(find.text('Envíos seguros'), findsOneWidget);
      expect(find.text('Pagos seguros'), findsOneWidget);
      expect(find.text('Productos 100% originales'), findsOneWidget);
      expect(find.text('Atención personalizada'), findsOneWidget);
    });
  });
}
