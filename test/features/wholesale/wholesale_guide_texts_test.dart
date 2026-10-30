/// Guide v2, part A: Mayoreo shows the guide's own texts and no longer says
/// «pendiente» about minimums, deposit or wholesale price.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/boutique/guide_art.dart';
import 'package:monetta_app/features/wholesale/wholesale_screen.dart';

import '../../support/client_guide_capture.dart';

void main() {
  testWidgets('hero, steps, banners, services and the WhatsApp banner', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpClientGuide(
      tester,
      WholesaleScreen(
        openUri: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
      size: const Size(390, 1600),
    );
    // The banner titles are `Text.rich` runs: the style is on the span.
    String? styleFamily(String text) =>
        tester.widget<Text>(find.text(text)).textSpan?.style?.fontFamily;

    // Hero: MAYOREO in italic serif; the subtitle closes with an underlined
    // «marcas favoritas».
    expect(find.text('MAYOREO'), findsOneWidget);
    final mayoreo = tester.widget<Text>(find.text('MAYOREO')).style!;
    expect(mayoreo.fontFamily, kGuideSerifFamily);
    expect(mayoreo.fontStyle, FontStyle.italic);
    expect(
      find.textContaining('marcas favoritas', findRichText: true),
      findsOneWidget,
    );

    // «¿Cómo comprar?»: the guide's three steps.
    for (final text in [
      'Elige tus productos',
      'Bolsas, carteras y perfumes.',
      'Agrega mínimo 3 piezas',
      'a tu carrito o mándanos captura de los modelos de tu interés por '
          'WhatsApp.',
      'Liquida o aparta',
      r'Aparta por 20 días con $800 pesos por pedido.',
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }

    // The old «pendiente» notes are gone.
    for (final text in [
      'Mínimo de piezas: pendiente de confirmación.',
      'Precios de mayoreo: pendientes de confirmación.',
      'Anticipo y plazo de liquidación: pendientes de confirmación.',
      'Costo, cobertura y plazo de envío: pendientes de confirmación.',
      'Consulta el mínimo',
    ]) {
      expect(find.text(text), findsNothing, reason: text);
    }
    expect(find.textContaining('de confirmación'), findsNothing);

    // Banners: serif title, italic subtitle, pill buttons.
    expect(find.text('BOLSAS Y CARTERAS'), findsNothing);
    for (final title in ['BOLSOS Y CARTERAS', 'PERFUMES']) {
      expect(styleFamily(title), kGuideSerifFamily, reason: title);
    }
    expect(
      tester
          .widget<Text>(find.text('Explora nuestro catálogo de mayoreo'))
          .style!
          .fontStyle,
      FontStyle.italic,
    );
    for (final category in ['bolsa', 'perfume']) {
      final pill = find.byKey(ValueKey('wholesale-catalog-$category'));
      expect(tester.widget(pill), isA<GuidePillButton>());
    }
    expect(find.text('VER CATÁLOGO'), findsNWidgets(2));

    // Services: the first entry is the free-shipping threshold.
    expect(find.text('Envío gratis'), findsOneWidget);
    expect(find.text(r'En compras mayores a $1,999 MXN'), findsOneWidget);
    // The loose line under the services repeated the first service; the
    // guide does not carry it.
    expect(
      find.text(r'Envío gratis en compras mayores a $1,999 MXN.'),
      findsNothing,
    );

    // «¿Tienes dudas?»: WhatsApp icon, the photograph and the same action.
    final banner = find.byKey(const ValueKey('wholesale-quote-bottom'));
    await tester.ensureVisible(banner);
    await tester.pumpAndSettle();
    expect(find.text('¿Tienes dudas?'), findsOneWidget);
    expect(find.text('Escríbenos por WhatsApp'), findsOneWidget);
    expect(find.text('ESCRÍBENOS'), findsNothing);
    final images = [
      for (final image in tester.widgetList<Image>(
        find.descendant(of: banner, matching: find.byType(Image)),
      ))
        (image.image as AssetImage).assetName,
    ];
    expect(images, contains(kGuideIconContactWhatsApp));
    expect(images, contains(kGuideWholesaleBags));
    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(opened.single.host, 'wa.me');
  });
}
