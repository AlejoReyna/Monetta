import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/editorial_content.dart';

void main() {
  test('fallback content covers all public reseller catalogs', () {
    final catalogs = MonettaEditorialContent.fallback.partner.catalogs;

    expect(catalogs, hasLength(9));
    expect(
      catalogs.map((catalog) => catalog.category).toSet(),
      {'bags', 'beauty', 'perfume'},
    );
    expect(
      catalogs.map((catalog) => catalog.mode).toSet(),
      PartnerCatalogMode.values.toSet(),
    );
    expect(catalogs.every((catalog) => catalog.uri != null), isTrue);
  });

  test('client-facing share copy stays white label', () {
    final catalog = MonettaEditorialContent.fallback.partner.catalogs
        .firstWhere((item) => item.mode == PartnerCatalogMode.noPrices);

    expect(catalog.mode.isClientFacing, isTrue);
    expect(catalog.shareText, contains(catalog.url));
    expect(catalog.shareText.toLowerCase(), isNot(contains('monetta')));
  });

  test('catalog links fail closed outside approved https hosts', () {
    expect(
      isTrustedPartnerUri(Uri.parse('https://drive.google.com/file/1')),
      isTrue,
    );
    expect(
      isTrustedPartnerUri(Uri.parse('http://drive.google.com/file/1')),
      isFalse,
    );
    expect(
      isTrustedPartnerUri(Uri.parse('https://example.com/catalog.pdf')),
      isFalse,
    );
  });

  test('partner apartado FAQ does not claim WhatsApp reserves stock', () {
    final faq = MonettaEditorialContent.fallback.partner.faqs
        .firstWhere((item) => item.question.toLowerCase().contains('apartado'));
    expect(faq.answer.toLowerCase(), contains('manual'));
    expect(faq.answer.toLowerCase(), contains('no reserva'));
  });
}
