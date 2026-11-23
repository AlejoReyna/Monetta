/// Regression net for the normalizer, run against the real 271-product catalog.
///
/// The thresholds below are the measurement recorded in
/// `lib/data/normalize/README.md` § 5, set a few points under the achieved
/// figures. This is what catches a rules edit that fixes one product and quietly
/// breaks thirty — the failure mode hand-written unit tests do not see.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/domain/product.dart';

import '../fixtures/catalog_fixture.dart';

NormalizationRules loadBundledRules() {
  final raw = File('assets/rules/normalization_rules.json').readAsStringSync();
  return NormalizationRules.fromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
}

void main() {
  final products = loadCatalogFixture();
  final normalizer = Normalizer(loadBundledRules());
  final facets =
      products.map((p) => normalizer.normalize(p, now: kSnapshotDate)).toList();

  double rateOf(bool Function(int index) predicate) {
    var hits = 0;
    for (var i = 0; i < facets.length; i++) {
      if (predicate(i)) hits++;
    }
    return hits / facets.length;
  }

  group('golden catalog (271 products, snapshot 2026-08-05)', () {
    test('fixture is the expected size', () {
      expect(products, hasLength(271));
    });

    test('brand resolves for at least 95% of products', () {
      final rate = rateOf((i) => facets[i].brand != null);
      // Measured: 99.6%. Baseline using `vendor` alone: 86.7%.
      expect(
        rate,
        greaterThanOrEqualTo(0.95),
        reason:
            'brand resolution regressed to ${(rate * 100).toStringAsFixed(1)}%',
      );
    });

    test('brand beats the vendor-only baseline by a wide margin', () {
      final rules = loadBundledRules();
      var vendorOnly = 0;
      for (final product in products) {
        final vendor = product.vendor.trim().toLowerCase();
        if (vendor.isNotEmpty && !rules.storeVendorAliases.contains(vendor)) {
          vendorOnly++;
        }
      }
      final baseline = vendorOnly / products.length;
      final actual = rateOf((i) => facets[i].brand != null);

      // The whole justification for the title-fallback chain. If this margin
      // disappears, the module has stopped earning its complexity.
      expect(actual - baseline, greaterThan(0.10));
    });

    test('category resolves for at least 98% of products', () {
      final rate = rateOf((i) => facets[i].category != null);
      expect(rate, greaterThanOrEqualTo(0.98)); // measured: 100%
    });

    test('silhouette resolves for at least 95% of bags', () {
      final bags = facets.where((f) => f.category?.value == 'bolsa').toList();
      expect(bags.length, greaterThan(150));
      final resolved = bags.where((f) => f.silhouette != null).length;
      expect(resolved / bags.length, greaterThanOrEqualTo(0.95)); // 98.9%
    });

    test('every category collapses to the canonical vocabulary', () {
      const canonical = {
        'bolsa',
        'cartera',
        'tarjetero',
        'monedero',
        'reloj',
        'cosmetiquera',
        'set',
        'accesorio',
      };
      final seen =
          facets.map((f) => f.category?.value).whereType<String>().toSet();
      expect(seen.difference(canonical), isEmpty);
    });

    test('the store name never becomes a brand', () {
      // 36 products carry vendor 'Monetta ' (trailing space). If this leaks in,
      // 13% of the catalog collapses into one meaningless affinity.
      final brands = facets.map((f) => f.brand?.value).whereType<String>();
      expect(brands, isNot(contains('monetta')));
      expect(brands, isNot(contains('monetta_')));
    });

    test('health report flags the known bad records and stays small', () {
      final report = buildHealthReport(products, facets);

      // Real gaps in the source data, documented in the module README.
      expect(
        report.any((i) => i.title == 'Bolsa Tote Blanco Monograma'),
        isTrue,
        reason: 'the one product with no brand anywhere should be flagged',
      );

      // If this balloons, either the rules broke or the catalog degraded —
      // both are worth a human looking.
      expect(report.length, lessThan(20));
      expect(report.first.advice, isNotEmpty);
    });

    test(
        'normalizes new perfume brands, real product types and filters operational tags',
        () {
      final rules = loadBundledRules();
      final norm = Normalizer(rules);

      expect(isInternalOperationalTag('Proveedor-Perfume-Palace'), isTrue);
      expect(isInternalOperationalTag('MONETTA-lote-001'), isTrue);
      expect(isInternalOperationalTag('MONETTA-MK-lote-015'), isTrue);
      expect(
        isInternalOperationalTag('Disponibilidad-proveedor-no-verificada'),
        isTrue,
      );
      expect(isInternalOperationalTag('Coach'), isFalse);
      expect(isInternalOperationalTag('Envío inmediato'), isFalse);

      for (final entry in const <String, String>{
        'Armaf': 'armaf',
        'Lattafa': 'lattafa',
        'Orientica': 'orientica',
        'Maison Alhambra': 'maison_alhambra',
        'French Avenue': 'french_avenue',
        'Yves Saint Laurent': 'yves_saint_laurent',
      }.entries) {
        final product = products.first;
        final perfume = Product(
          id: 'gid://shopify/Product/999',
          handle: 'perfume-test',
          title: 'Perfume ${entry.key} Eau de Parfum 100 ml',
          vendor: entry.key,
          productType: 'Perfumes',
          tags: const [
            'Proveedor-Perfume-Palace',
            'MONETTA-lote-001',
            'Disponibilidad-proveedor-no-verificada',
          ],
          variants: product.variants,
          images: product.images,
          createdAt: kSnapshotDate,
          updatedAt: kSnapshotDate,
        );
        final f = norm.normalize(perfume, now: kSnapshotDate);
        expect(f.brand?.value, entry.value);
        expect(f.category?.value, 'perfume');
      }

      final shoulderBag = Product(
        id: 'gid://shopify/Product/1000',
        handle: 'bolsa-hombro',
        title: 'Bolsa Coach Laurel',
        vendor: 'Coach',
        productType: 'Bolsa de hombro',
        tags: const ['Coach', 'Bolsa de hombro'],
        variants: products.first.variants,
        images: products.first.images,
        createdAt: kSnapshotDate,
        updatedAt: kSnapshotDate,
      );
      final shoulderFacets = norm.normalize(shoulderBag, now: kSnapshotDate);
      expect(shoulderFacets.category?.value, 'bolsa');
      expect(shoulderFacets.silhouette?.value, 'shoulder');

      for (final accType in const ['Charm para bolsa', 'Correa para bolso']) {
        final accessory = Product(
          id: 'gid://shopify/Product/1001',
          handle: 'acc',
          title: '$accType Coach',
          vendor: 'Coach',
          productType: accType,
          tags: [accType, 'Coach'],
          variants: products.first.variants,
          images: products.first.images,
          createdAt: kSnapshotDate,
          updatedAt: kSnapshotDate,
        );
        final accFacets = norm.normalize(accessory, now: kSnapshotDate);
        expect(accFacets.category?.value, 'accesorio');
      }
    });
  });
}
