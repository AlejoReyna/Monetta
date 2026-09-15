/// Favoritos (paquete E): listado con la tarjeta compartida.
///
/// Usa [ProductCard]/[ProductCardGrid] (contrato del paquete B) y el wishlist
/// real de [CatalogStore] (aislado por cuenta). Sin mocks: lo que se muestra
/// es lo guardado en este dispositivo para la cuenta activa.
library;

import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../domain/product.dart';
import '../../main.dart' show StoreScope;
import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';

Future<void> openFavorites(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const FavoritesScreen()),
  );
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.canvas,
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
    final missing = store.wishlist.length - saved.length;
    if (store.wishlist.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AccountPageHeader(
              kicker: 'Guardados',
              title: 'Favoritos',
              subtitle: 'Toca el corazón de una pieza para guardarla aquí.',
            ),
            EEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Aún no tienes favoritos',
              body: 'Explora el catálogo y guarda las piezas que te '
                  'enamoren. Se conservan por cuenta en este dispositivo.',
              actionLabel: 'Explorar el catálogo',
              onAction: () => Navigator.of(context).pop(),
            ),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          sliver: SliverGrid(
            gridDelegate: productGridDelegate(
              context,
              availableWidth:
                  MediaQuery.sizeOf(context).width - BoutiqueSpace.gutter * 2,
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
      ],
    );
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
