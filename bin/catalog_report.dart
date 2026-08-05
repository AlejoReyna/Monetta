/// Catalog health report — the owner-facing deliverable.
///
/// Pure Dart (no Flutter), so it runs standalone:
///
/// ```
/// dart run bin/catalog_report.dart
/// ```
///
/// Prints how well the catalog classifies and, more usefully, the exact list of
/// products Monetta should fix in Shopify — in Spanish, with the action to take.
/// Products that land in this report are close to invisible to the recommender,
/// so this list is where the owner's effort pays best.
library;

import 'dart:convert';
import 'dart:io';

import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/data/normalize/normalizer.dart';
import 'package:monetta_app/data/normalize/rules.dart';
import 'package:monetta_app/domain/product.dart';

const String _fixture = 'test/fixtures/catalog_2026_08_05.json';
const String _rulesPath = 'assets/rules/normalization_rules.json';

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : _fixture;

  final rules = NormalizationRules.fromJson(
    jsonDecode(File(_rulesPath).readAsStringSync()) as Map<String, dynamic>,
  );
  final products = _load(path);
  final normalizer = Normalizer(rules);
  final now = DateTime.now();
  final facets = products.map((p) => normalizer.normalize(p, now: now)).toList();

  _printCoverage(products, facets, rules);
  _printDistribution(facets);
  _printHealth(products, facets);
}

void _printCoverage(
  List<Product> products,
  List<CanonicalFacets> facets,
  NormalizationRules rules,
) {
  final total = products.length;
  String pct(int n) => '${(n / total * 100).toStringAsFixed(1)}%';

  final brand = facets.where((f) => f.brand != null).length;
  final category = facets.where((f) => f.category != null).length;
  final colors = facets.where((f) => f.colors.isNotEmpty).length;
  final bags = facets.where((f) => f.category?.value == 'bolsa').toList();
  final silhouette = bags.where((f) => f.silhouette != null).length;

  final vendorOnly = products.where((p) {
    final vendor = p.vendor.trim().toLowerCase();
    return vendor.isNotEmpty && !rules.storeVendorAliases.contains(vendor);
  }).length;

  stdout.writeln('COBERTURA  ($total productos)');
  stdout.writeln('  marca         $brand/$total  ${pct(brand)}'
      '   (solo vendor: ${pct(vendorOnly)})');
  stdout.writeln('  categoría     $category/$total  ${pct(category)}');
  stdout.writeln('  silueta       $silhouette/${bags.length}  '
      '${(silhouette / bags.length * 100).toStringAsFixed(1)}%  (solo bolsas)');
  stdout.writeln('  color         $colors/$total  ${pct(colors)}');
  stdout.writeln('');
}

void _printDistribution(List<CanonicalFacets> facets) {
  void tally(String label, Iterable<String?> values) {
    final counts = <String, int>{};
    for (final value in values) {
      if (value == null) continue;
      counts.update(value, (v) => v + 1, ifAbsent: () => 1);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln('  ${label.padRight(12)}'
        '${sorted.map((e) => '${e.key} ${e.value}').join(' · ')}');
  }

  stdout.writeln('DISTRIBUCIÓN');
  tally('marcas', facets.map((f) => f.brand?.value));
  tally('categorías', facets.map((f) => f.category?.value));
  tally('siluetas', facets.map((f) => f.silhouette?.value));
  tally('colores', facets.expand((f) => f.colors.map((c) => c.value)));
  stdout.writeln('');
}

void _printHealth(List<Product> products, List<CanonicalFacets> facets) {
  final issues = buildHealthReport(products, facets);

  stdout.writeln('PRODUCTOS POR CORREGIR EN SHOPIFY  (${issues.length})');
  if (issues.isEmpty) {
    stdout.writeln('  Nada por corregir. 🎉');
    return;
  }
  for (final issue in issues) {
    stdout.writeln('  • ${issue.title}');
    stdout.writeln('    ${issue.handle}  '
        '(confianza ${(issue.confidence * 100).toStringAsFixed(0)}%)');
    stdout.writeln('    → ${issue.advice}');
  }
}

List<Product> _load(String path) {
  final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (json['products'] as List<dynamic>).map((entry) {
    final p = entry as Map<String, dynamic>;
    return Product(
      id: p['id'].toString(),
      handle: p['handle'] as String,
      title: p['title'] as String,
      vendor: p['vendor'] as String,
      productType: p['product_type'] as String,
      tags: (p['tags'] as List<dynamic>).cast<String>(),
      images: (p['images'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(p['created_at'] as String),
      updatedAt: DateTime.parse(p['updated_at'] as String),
      variants: (p['variants'] as List<dynamic>).map((v) {
        final variant = v as Map<String, dynamic>;
        return ProductVariant(
          id: variant['id'].toString(),
          title: variant['title'] as String,
          price: double.parse(variant['price'] as String),
          available: variant['available'] as bool,
          compareAtPrice: variant['compare_at_price'] == null
              ? null
              : double.parse(variant['compare_at_price'] as String),
        );
      }).toList(),
    );
  }).toList();
}
