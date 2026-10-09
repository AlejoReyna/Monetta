/// UI-03 (objective state): Inicio, Colección, Búsqueda and Ficha mount and
/// scroll to their end without any `FlutterError` at 375x812 and 440x956, with
/// the text scale at 1.0, 1.3 and 1.5 under the E-T1 / D-12 policy and the real
/// Inter and Playfair Display faces. See `text_scale_matrix.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/search_history.dart';
import 'package:monetta_app/features/catalog/search_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';

import '../../support/text_scale_matrix.dart';

/// The in-stock asset product with the longest title.
Product _longestInStock(Iterable<Product> products) {
  final inStock = products.where((p) => p.isInStock).toList()
    ..sort((a, b) => b.title.length.compareTo(a.title.length));
  return inStock.first;
}

/// At least one product card: proves the grid really holds products.
Finder _productCards() => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith('product-card-');
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  useBundledFonts();

  registerTextScaleMatrix(
    'Inicio',
    (tester, store) async => const HomeScreen(),
    anchor: (store) => find.byKey(const ValueKey('home-search-bar')),
  );

  registerTextScaleMatrix(
    'Coleccion',
    (tester, store) async => const CollectionScreen(
      title: 'Bolsas',
      filter: CollectionFilter(category: 'bolsa'),
    ),
    anchor: (store) => _productCards(),
  );

  registerTextScaleMatrix(
    'Busqueda con resultados',
    (tester, store) async => SearchScreen(
      initialQuery: 'Michael Kors',
      prompt: 'Encuentra algo muy tú',
      history: SearchHistory(),
    ),
    anchor: (store) => _productCards(),
  );

  registerTextScaleMatrix(
    'Ficha',
    (tester, store) async =>
        ProductScreen(productId: _longestInStock(store.products).id),
    // The dock button keeps its key in the sold-out state too, so the in-stock
    // label is what proves the piece can be bought.
    anchor: (store) => find.descendant(
      of: find.byKey(const Key('purchase-dock-primary')),
      matching: find.text('Agregar al carrito'),
    ),
  );
}
