/// Favoritos (paquete E): listado con la tarjeta compartida, más el carrusel
/// «Basado en tus gustos».
///
/// Usa [ProductCard] (contrato del paquete B) y el wishlist real de
/// [CatalogStore] (aislado por cuenta). Sin mocks: lo guardado es lo de esta
/// cuenta en este dispositivo. El carrusel reutiliza la misma tarjeta y, si
/// hay historial, el feed que [CatalogStore.feed] ya ordena; sin historial
/// conserva el orden del catálogo cargado y no afirma un gusto inferido.
library;

import '../navigation/adaptive_storefront_scaffold.dart';
import '../navigation/duo_workspace.dart';
import '../navigation/storefront_destination_navigation.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../data/shopify/catalog_item_mapper.dart';
import '../../domain/catalog_item.dart';
import '../../domain/product.dart';
import '../../main.dart' show StoreScope;
import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/browse_detail_layout.dart';
import '../catalog/catalog_browse_screen.dart';
import '../catalog/product_card.dart';

/// Tope de este carrusel. Otros rieles del catálogo conservan el suyo.
const int kFavoritesRailCap = 60;

/// Origen de las piezas del carrusel de favoritos.
enum FavoritesRailSource {
  /// Orden del catálogo ya cargado. No hay historial que personalizar.
  editorial,

  /// Orden del feed existente, cuando el perfil ya tiene historial.
  history,
}

/// Selección del carrusel: piezas únicas, sin las ya guardadas, sin repetir
/// para llegar al tope.
class FavoritesRailSelection {
  const FavoritesRailSelection({
    required this.products,
    required this.source,
  });

  final List<Product> products;
  final FavoritesRailSource source;

  bool get editorial => source == FavoritesRailSource.editorial;
}

/// Arma el carrusel desde lo que la pantalla ya tiene en memoria.
///
/// [loaded] es el catálogo cargado, en su orden. [ranked] es el feed de
/// recomendación cuando [hasHistory] es verdadero; si no hay historial, se
/// ignora y el orden queda el editorial. Nunca duplica un id, nunca incluye
/// un favorito y nunca pasa de [cap] ni de las piezas distintas ya cargadas.
FavoritesRailSelection favoritesRailProducts({
  required List<Product> loaded,
  required Set<String> favoriteIds,
  List<Product>? ranked,
  required bool hasHistory,
  int cap = kFavoritesRailCap,
}) {
  final limit = cap < 0 ? 0 : cap;

  List<Product> takeUnique(Iterable<Product> source) {
    final seen = <String>{};
    final out = <Product>[];
    for (final product in source) {
      if (favoriteIds.contains(product.id)) continue;
      if (!seen.add(product.id)) continue;
      out.add(product);
      if (out.length >= limit) break;
    }
    return out;
  }

  if (hasHistory) {
    final personalized = takeUnique(ranked ?? const <Product>[]);
    if (personalized.isNotEmpty) {
      return FavoritesRailSelection(
        products: personalized,
        source: FavoritesRailSource.history,
      );
    }
  }
  return FavoritesRailSelection(
    products: takeUnique(loaded),
    source: FavoritesRailSource.editorial,
  );
}

Future<void> openFavorites(BuildContext context) {
  // Saved pieces are browsed on the browsing side, beside the account.
  return DuoWorkspace.navigatorFor(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const BrowseDetailLayout(child: FavoritesScreen()),
    ),
  );
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return AdaptiveStorefrontScaffold(
      avoidReservedRegions: true,
      backgroundColor: palette.canvas,
      bottomNavigationBar: storefrontNavigation(
        context,
        current: MonettaBottomDestination.account,
      ),
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Favoritos',
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Container(height: .5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: StoreScope.of(context),
          builder: (context, _) => _FavoritesBody(
            store: StoreScope.of(context),
          ),
        ),
      ),
    );
  }
}

class _FavoritesBody extends StatelessWidget {
  const _FavoritesBody({required this.store});

  final CatalogStore store;

  @override
  Widget build(BuildContext context) {
    final saved = _savedProducts(store);
    final rail = _railSelection(store);
    final missing = store.wishlist.length - saved.length;
    final taste = rail.products.isEmpty
        ? null
        : _FavoritesTasteRail(
            products: rail.products,
            editorial: rail.editorial,
            onOpen: () => _openRail(context, rail.products),
          );
    if (store.wishlist.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: AccountPageHeader(
                kicker: 'Guardados',
                title: 'Favoritos',
                subtitle: 'Toca el corazón de una pieza para guardarla aquí.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Aún no tienes favoritos',
                body: 'Explora el catálogo y guarda las piezas que te '
                    'enamoren. Se conservan por cuenta en este dispositivo.',
                actionLabel: 'Explorar el catálogo',
                onAction: () => Navigator.of(context).pop(),
              ),
            ),
            if (taste != null) ...[
              const SizedBox(height: BoutiqueSpace.sectionGapTight),
              taste,
            ],
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
            child: AccountPageHeader(
              kicker: 'Guardados',
              title: 'Favoritos',
              subtitle: saved.length == 1
                  ? '1 pieza guardada en esta cuenta.'
                  : '${saved.length} piezas guardadas en esta cuenta.',
            ),
          ),
        ),
        if (missing > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ENotice(
                message: missing == 1
                    ? '1 pieza guardada ya no está disponible en el catálogo.'
                    : '$missing piezas guardadas ya no están disponibles en '
                        'el catálogo.',
                actionLabel: 'Quitar no disponibles',
                onAction: () => _removeMissing(context, store),
                icon: Icons.visibility_off_outlined,
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, taste == null ? 32 : 0),
          sliver: SliverGrid(
            gridDelegate: productGridDelegate(
              context,
              availableWidth:
                  MediaQuery.sizeOf(context).width - BoutiqueSpace.gutter * 2,
              priceLines: tilePriceLinesFor(saved),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => ProductCard(
                key: ValueKey('favorite-card-${saved[index].id}'),
                product: saved[index],
              ),
              childCount: saved.length,
            ),
          ),
        ),
        if (taste != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: BoutiqueSpace.sectionGapTight,
                bottom: 32,
              ),
              child: taste,
            ),
          ),
      ],
    );
  }

  /// Feed existente si el perfil tiene historial; si no, el catálogo cargado.
  ///
  /// El listado de favoritos no pagina: muestra lo ya cargado. Este carrusel
  /// hace lo mismo y se detiene en [kFavoritesRailCap], sin inventar piezas.
  FavoritesRailSelection _railSelection(CatalogStore store) {
    if (store.products.isEmpty) {
      return const FavoritesRailSelection(
        products: [],
        source: FavoritesRailSource.editorial,
      );
    }
    final hasHistory = !store.profile.isEmpty;
    final ranked = hasHistory
        ? [
            for (final item in store.feed(limit: store.products.length))
              item.product,
          ]
        : null;
    return favoritesRailProducts(
      loaded: store.products,
      favoriteIds: store.wishlist,
      ranked: ranked,
      hasHistory: hasHistory,
    );
  }

  void _openRail(BuildContext context, List<Product> products) {
    final byId = {
      for (final item in store.catalogItems)
        if (item.shopifyProductId != null) item.shopifyProductId!: item,
    };
    final items = <CatalogItem>[
      for (final product in products)
        byId[product.id] ??
            catalogItemFromShopifyProduct(
              product,
              facets: store.facetsFor(product.id),
            ),
    ];
    openCatalogBrowse(context, items: items);
  }

  List<Product> _savedProducts(CatalogStore store) {
    final byId = {for (final p in store.products) p.id: p};
    return [
      for (final id in store.wishlist)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> _removeMissing(
    BuildContext context,
    CatalogStore store,
  ) async {
    final byId = {for (final p in store.products) p.id: p};
    final missing = [
      for (final id in store.wishlist)
        if (byId[id] == null) id,
    ];
    for (final id in missing) {
      await store.toggleWishlist(id);
    }
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Se quitaron las piezas no disponibles.'),
        ),
      );
    }
  }
}

/// Carrusel horizontal de dos filas. Cada celda es la [ProductCard] común,
/// así vista rápida, variante y favorito siguen siendo los de la tarjeta.
///
/// El listado de favoritos no trae páginas: construye con un builder lo que
/// ya está cargado. Este carrusel hace igual y solo materializa las columnas
/// que entran en pantalla.
class _FavoritesTasteRail extends StatelessWidget {
  const _FavoritesTasteRail({
    required this.products,
    required this.editorial,
    required this.onOpen,
  });

  final List<Product> products;
  final bool editorial;
  final VoidCallback onOpen;

  static const ProductTileDensity _density = ProductTileDensity.compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final cardWidth = (MediaQuery.sizeOf(context).width * .36).clamp(
      132.0,
      190.0,
    );
    final tileHeight = productTileExtent(
      tileWidth: cardWidth,
      textScaler: MediaQuery.textScalerOf(context),
      density: _density,
      priceLines: tilePriceLinesFor(products),
    );
    const gap = BoutiqueSpace.sm;
    final columns = (products.length / 2).ceil();

    return Column(
      key: const ValueKey('favorites-reco-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Basado en tus gustos',
          actionLabel: 'Ver',
          onAction: onOpen,
        ),
        // Sin historial el orden es el del catálogo. El título de la sección
        // es el del contrato; esta línea evita presentarlo como gusto inferido.
        if (editorial)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BoutiqueSpace.gutter,
              0,
              BoutiqueSpace.gutter,
              BoutiqueSpace.md,
            ),
            child: Text(
              'Selección editorial',
              style: boutiqueText(size: 13, color: palette.inkMuted),
            ),
          ),
        SizedBox(
          height: tileHeight * 2 + gap,
          child: ListView.builder(
            key: const ValueKey('favorites-reco-rail'),
            scrollDirection: Axis.horizontal,
            primary: false,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.gutter,
            ),
            itemCount: columns,
            itemBuilder: (context, column) {
              final top = products[column * 2];
              final bottomIndex = column * 2 + 1;
              final bottom =
                  bottomIndex < products.length ? products[bottomIndex] : null;
              return Padding(
                padding: EdgeInsets.only(
                  right: column == columns - 1 ? 0 : BoutiqueSpace.md,
                ),
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: tileHeight,
                        child: ProductCard(
                          key: ValueKey('favorite-reco-${top.id}'),
                          product: top,
                          density: _density,
                        ),
                      ),
                      const SizedBox(height: gap),
                      if (bottom != null)
                        SizedBox(
                          height: tileHeight,
                          child: ProductCard(
                            key: ValueKey('favorite-reco-${bottom.id}'),
                            product: bottom,
                            density: _density,
                          ),
                        )
                      else
                        SizedBox(height: tileHeight),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
