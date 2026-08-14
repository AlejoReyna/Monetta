import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/shopper_copy.dart';

void main() {
  test('stripHtml drops tags and collapses space', () {
    expect(stripHtml('<p>Bolsa <b>Guess</b>&nbsp;negra</p>'), 'Bolsa Guess negra');
  });

  test('factualDescription is inventory language, not poetry', () {
    final text = factualDescription(
      title: 'Bolsa Guess Crossbody',
      brandSlug: 'guess',
      categorySlug: 'bolsa',
      silhouetteSlug: 'crossbody',
      colorSlug: 'negro',
    );
    expect(text, 'Bolsa crossbody Guess en negro. Original, importada de Estados Unidos.');
    expect(text, isNot(contains('irresistible')));
    expect(text, isNot(contains('temporada')));
  });
}
