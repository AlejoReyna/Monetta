import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/shopper_copy.dart';

void main() {
  test('stripHtml drops tags and collapses space', () {
    expect(
      stripHtml('<p>Bolsa <b>Guess</b>&nbsp;negra</p>'),
      'Bolsa Guess negra',
    );
  });

  test('Shopify descriptions preserve readable fact rows', () {
    expect(
      shopifyDescriptionText(
        '<p>Marca: Guess<br>Color: Negro</p><p>Medidas:<br>20 × 10 cm</p>',
      ),
      'Marca: Guess\nColor: Negro\nMedidas:\n20 × 10 cm',
    );
  });

  test('factualDescription is inventory language, not poetry', () {
    final text = factualDescription(
      title: 'Bolsa Guess Crossbody',
      brandSlug: 'guess',
      categorySlug: 'bolsa',
      silhouetteSlug: 'crossbody',
      colorSlug: 'negro',
    );
    expect(
      text,
      'Bolsa crossbody Guess en negro. Original, importada de Estados Unidos.',
    );
    expect(text, isNot(contains('irresistible')));
    expect(text, isNot(contains('temporada')));
  });

  test('cardPieceName folds colour in only when it is missing', () {
    expect(
      cardPieceName(title: 'Bolsa tote', colorSlug: 'negro'),
      'Bolsa tote negro',
    );
    expect(
      cardPieceName(title: 'Bolsa tote negra', colorSlug: 'negro'),
      'Bolsa tote negra',
    );
  });

  test('internal tokens never leak into shopper-facing names', () {
    expect(humanizeCatalogValue('michael_kors'), 'Michael Kors');
    expect(humanizeCatalogValue('coach_coach'), 'Coach');
    expect(shopperProductName('jet_set_jet_bag'), 'Jet Set Jet Bag');
    expect(shopperProductName('Bolsa  Bolsa Guess'), 'Bolsa Guess');
  });

  test('partner quote carries the wholesale terms and source', () {
    final uri = partnerQuoteWhatsAppUri(
      category: 'Perfumes',
      catalogMode: 'Sin precios',
    );
    final text = uri.queryParameters['text']!;

    expect(uri.host, 'wa.me');
    expect(text, contains('Perfumes'));
    expect(text, contains('Sin precios'));
    expect(text, contains(r'$800 MXN'));
    expect(text, contains('20 días'));
    expect(text, contains('Origen: app'));
    expect(text, contains('no aprueba mayoreo'));
  });
}
