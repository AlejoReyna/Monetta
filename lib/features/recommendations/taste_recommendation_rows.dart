/// «Basado en tus gustos»: two progressive horizontal rows.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../catalog/product_tile.dart';
import '../home/home_v41_catalog.dart';

class TasteRecommendationRows extends StatefulWidget {
  const TasteRecommendationRows({super.key});

  @override
  State<TasteRecommendationRows> createState() =>
      _TasteRecommendationRowsState();
}

class _TasteRecommendationRowsState extends State<TasteRecommendationRows> {
  static const int _pageSize = 20;
  int _visible = _pageSize;
  String? _error;

  List<Product> _load(CatalogStore store) =>
      uniqueTasteProducts(store, limit: kFavoritesTasteProductLimit);

  void _loadMore(int total) {
    setState(() => _visible = (_visible + _pageSize).clamp(0, total));
  }

  void _retry() {
    setState(() {
      _error = null;
      _visible = _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StoreScope.of(context),
      builder: (context, _) {
        final store = StoreScope.of(context);
        if (!store.ready) {
          return const SizedBox.shrink();
        }
        List<Product> products;
        try {
          products = _load(store);
          _error = null;
        } catch (error) {
          products = const [];
          _error = error.toString();
        }
        if (_error != null) {
          return _TasteErrorNotice(onRetry: _retry);
        }
        if (products.isEmpty) return const SizedBox.shrink();

        final editorial = store.profile.isEmpty;
        final visible = products.take(_visible).toList();
        final rowA = <Product>[
          for (var i = 0; i < visible.length; i += 2) visible[i],
        ];
        final rowB = <Product>[
          for (var i = 1; i < visible.length; i += 2) visible[i],
        ];
        final width = MediaQuery.sizeOf(context).width;
        final cardWidth = (width * .42).clamp(140.0, 190.0);
        final cardHeight = productTileExtent(
          tileWidth: cardWidth,
          textScaler: MediaQuery.textScalerOf(context),
          density: ProductTileDensity.compact,
          priceLines: 1,
        );

        return Column(
          key: const ValueKey('favorites-taste-recommendations'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BoutiqueSectionHeader(
              title: 'Basado en tus gustos',
              kicker: editorial ? 'Selección editorial' : null,
            ),
            _TasteRow(
              rowKey: const ValueKey('favorites-taste-row-a'),
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              products: rowA,
            ),
            const SizedBox(height: BoutiqueSpace.md),
            _TasteRow(
              rowKey: const ValueKey('favorites-taste-row-b'),
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              products: rowB,
            ),
            if (_visible < products.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BoutiqueSpace.gutter,
                  BoutiqueSpace.md,
                  BoutiqueSpace.gutter,
                  BoutiqueSpace.xl,
                ),
                child: TextButton(
                  key: const ValueKey('favorites-taste-load-more'),
                  onPressed: () => _loadMore(products.length),
                  child: const Text('Ver más recomendaciones'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TasteRow extends StatelessWidget {
  const _TasteRow({
    required this.rowKey,
    required this.cardWidth,
    required this.cardHeight,
    required this.products,
  });

  final Key rowKey;
  final double cardWidth;
  final double cardHeight;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        key: rowKey,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: BoutiqueSpace.md),
        itemBuilder: (context, index) => SizedBox(
          width: cardWidth,
          child: ProductCard(
            key: ValueKey('taste-card-${products[index].id}'),
            product: products[index],
            density: ProductTileDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _TasteErrorNotice extends StatelessWidget {
  const _TasteErrorNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No pudimos cargar recomendaciones.',
            style: boutiqueText(size: 14),
          ),
          TextButton(
            key: const ValueKey('favorites-taste-retry'),
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
