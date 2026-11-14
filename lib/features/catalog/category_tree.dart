/// Owner taxonomy. Destinations are supplied explicitly; labels never become IDs.
library;

import 'package:flutter/material.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/guide_art.dart';
import '../boutique/client_guide_components.dart';
import 'collection_screen.dart';
import '../../domain/home_content.dart';
import '../../app/catalog_store.dart';
import '../../data/normalize/text.dart';
import '../../app/motion.dart';

class CategoryNode {
  const CategoryNode(
    this.id,
    this.label,
    this.icon, [
    this.children = const [],
  ]);
  final String id, label;
  final IconData icon;
  final List<CategoryNode> children;
}

const categoryTree = [
  CategoryNode('bags', 'Bolsos', Icons.shopping_bag_outlined, [
    CategoryNode('bags-women', 'Bolsos de Mujer', Icons.shopping_bag_outlined, [
      CategoryNode('crossbody', 'Crossbody', Icons.shopping_bag_outlined),
      CategoryNode('tote', 'Tote', Icons.shopping_bag_outlined),
      CategoryNode('hand', 'De mano', Icons.shopping_bag_outlined),
      CategoryNode('shoulder', 'De hombro', Icons.shopping_bag_outlined),
    ]),
    CategoryNode('bags-men', 'Bolsos de Hombre', Icons.work_outline),
  ]),
  CategoryNode('wallets', 'Carteras', Icons.account_balance_wallet_outlined, [
    CategoryNode('wallets-women', 'Carteras de Mujer',
        Icons.account_balance_wallet_outlined, [
      CategoryNode(
        'wristlets',
        'Muñequeras',
        Icons.account_balance_wallet_outlined,
      ),
      CategoryNode(
        'classic-wallets',
        'Carteras',
        Icons.account_balance_wallet_outlined,
      ),
      CategoryNode('cardholders', 'Tarjeteros', Icons.credit_card),
    ]),
    CategoryNode(
      'wallets-men',
      'Carteras de Hombre',
      Icons.account_balance_wallet_outlined,
    ),
  ]),
  CategoryNode('perfumes', 'Perfumes', Icons.water_drop_outlined, [
    CategoryNode(
      'perfumes-women',
      'Perfumes de Mujer',
      Icons.water_drop_outlined,
    ),
    CategoryNode(
      'perfumes-men',
      'Perfumes de Hombre',
      Icons.water_drop_outlined,
    ),
  ]),
  CategoryNode('shoes', 'Calzado', Icons.hiking_outlined, [
    CategoryNode('shoes-women', 'Calzado de Mujer', Icons.hiking_outlined, [
      CategoryNode('sport', 'Deportivo', Icons.hiking_outlined),
      CategoryNode('casual', 'Casual', Icons.hiking_outlined),
    ]),
    CategoryNode('shoes-men', 'Calzado de Hombre', Icons.hiking_outlined),
  ]),
  CategoryNode('accessories', 'Accesorios', Icons.watch_outlined, [
    CategoryNode('glasses', 'Lentes', Icons.visibility_outlined),
    CategoryNode('watches', 'Relojes', Icons.watch_outlined),
    CategoryNode('charms', 'Charms', Icons.diamond_outlined),
    CategoryNode('other-accessories', 'Otros accesorios', Icons.watch_outlined),
  ]),
];

/// Existing canonical family/watch facets are real bindings, not label slugs.
/// Gender nodes require an explicit configured collection handle.
Map<String, CollectionFilter> configuredCategoryBindings(
  HomeContent content,
  CatalogStore? store,
) {
  final result = <String, CollectionFilter>{};
  if (store == null || !store.ready) return result;
  const canonical = {
    'bags': 'bolsa',
    'wallets': 'cartera',
    'perfumes': 'perfume',
    'accessories': 'accesorio',
    'watches': 'reloj',
  };
  for (final entry in canonical.entries) {
    if (store.rules.categories.containsKey(entry.value)) {
      result[entry.key] = CollectionFilter(category: entry.value);
    }
  }
  void bind(CategoryNode node, [CollectionFilter? parent]) {
    // Only exact owner-configured semantic labels may bind gender/subtypes.
    // Generic style cards do not establish gender membership.
    if (node.id.contains('-women') || node.id.contains('-men')) {
      for (final card in [...content.collections, ...content.bagTypes]) {
        if (fold(card.title) == fold(node.label) &&
            card.handle.trim().isNotEmpty) {
          result[node.id] =
              CollectionFilter(collectionHandle: card.handle.trim());
        }
      }
    }
    final direct = result[node.id];
    const styles = {
      'crossbody': 'crossbody',
      'tote': 'tote',
      'shoulder': 'shoulder',
      'hand': 'satchel',
      'wristlets': 'wristlet',
    };
    if (parent?.collectionHandle != null &&
        styles.containsKey(node.id) &&
        store.rules.silhouettes.containsKey(styles[node.id])) {
      result[node.id] = CollectionFilter(
        collectionHandle: parent!.collectionHandle,
        silhouette: styles[node.id],
      );
    }
    for (final child in node.children) {
      bind(child, direct);
    }
  }

  for (final node in categoryTree) {
    bind(node);
  }
  return result;
}

class CategoryTree extends StatelessWidget {
  const CategoryTree({this.bindings = const {}, this.onOpen, super.key});
  final Map<String, CollectionFilter> bindings;
  final void Function(CategoryNode, CollectionFilter)? onOpen;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final node in categoryTree) _node(context, node),
        ],
      );
  Widget _node(BuildContext context, CategoryNode node) {
    final binding = bindings[node.id];
    final iconName = const {
          'bags': 'bolsos',
          'bags-women': 'bolsos-mujer',
          'bags-men': 'bolsos-hombre',
          'wallets': 'carteras',
          'wallets-women': 'carteras-mujer',
          'wallets-men': 'carteras-hombre',
          'classic-wallets': 'carteras-clasicas',
          'cardholders': 'tarjeteros',
          'wristlets': 'munequeras',
          'shoes': 'calzado',
          'shoes-women': 'calzado-mujer',
          'shoes-men': 'calzado-hombre',
          'sport': 'deportivo',
          'casual': 'casual',
          'accessories': 'accesorios',
          'glasses': 'lentes',
          'watches': 'relojes',
          'other-accessories': 'otros-accesorios',
          'hand': 'de-mano',
          'shoulder': 'de-hombro',
          'perfumes-women': 'perfumes-mujer',
          'perfumes-men': 'perfumes-hombre',
        }[node.id] ??
        node.id;
    final icon = SizedBox(
      width: 28,
      height: 28,
      child: GuideSemanticImage(id: 'icon:$iconName'),
    );
    final title = Text(node.label);
    if (node.children.isEmpty) {
      // Missing gender/subtype bindings must not silently broaden the set.
      if (binding == null || onOpen == null) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 16),
              Expanded(child: title),
            ],
          ),
        );
      }
      return ListTile(
        key: ValueKey('category-${node.id}'),
        leading: icon,
        title: title,
        onTap: () => onOpen!(node, binding),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GuideGlassSurface(
        child: Material(
          color: context.boutique.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: context.boutique.hairline),
          ),
          child: ExpansionTile(
            key: PageStorageKey('category-${node.id}'),
            expansionAnimationStyle:
                reduceMotion(context) ? AnimationStyle.noAnimation : null,
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: icon,
            title: title,
            childrenPadding: const EdgeInsets.only(left: 12),
            children: [
              if (binding != null && onOpen != null)
                ListTile(
                  key: ValueKey('category-open-${node.id}'),
                  title: Text('Explorar ${node.label}'),
                  onTap: () => onOpen!(node, binding),
                ),
              for (final child in node.children) _node(context, child),
            ],
          ),
        ),
      ),
    );
  }
}
