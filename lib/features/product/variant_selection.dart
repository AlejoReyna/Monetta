import '../../domain/product.dart';

List<ProductVariant> productChoices(Product product) =>
    product.variants.where((v) => !v.isDefault).toList();

int variantIndexForId(Product product, String? id, {int fallback = 0}) {
  if (id == null) return fallback;
  final choices = productChoices(product);
  if (choices.isEmpty) {
    return product.variants.any((v) => v.id == id) ? 0 : -1;
  }
  return choices.indexWhere((v) => v.id == id);
}

Map<String, List<String>> productOptionValues(Product product) {
  final options = <String, List<String>>{};
  for (final variant in productChoices(product)) {
    for (final entry in variant.selectedOptions.entries) {
      final values = options.putIfAbsent(entry.key, () => []);
      if (!values.contains(entry.value)) values.add(entry.value);
    }
  }
  return options;
}

/// Resolves the exact combination, including exhausted variants. Missing
/// combinations stay missing; another size/colour is never substituted.
int indexForOptions(Product product, Map<String, String> options) =>
    productChoices(product).indexWhere(
      (v) =>
          v.selectedOptions.length == options.length &&
          options.entries.every((e) => v.selectedOptions[e.key] == e.value),
    );

typedef ProductRestockAction = void Function(
  Product product,
  ProductVariant variant,
);
