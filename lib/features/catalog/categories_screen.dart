/// Dedicated category directory (client guide page 18), reusing catalog routes.
library;

import 'package:flutter/material.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/catalog_store.dart';
import '../../data/normalize/text.dart';
import '../../domain/home_content.dart';
import '../../main.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import '../navigation/duo_workspace.dart';
import '../boutique/guide_art.dart';
import 'category_tree.dart';
import 'brands_screen.dart';
import 'collection_screen.dart';

Future<void> openCategories(BuildContext context) async {
  if (ModalRoute.of(context)?.settings.name == DuoWorkspace.categoriesRoute) {
    return;
  }
  final store = StoreScope.maybeOf(context);
  final account = AccountScope.maybeOf(context);
  final content =
      HomeContentScope.maybeOf(context)?.content ?? HomeContent.fallback;
  await DuoWorkspace.navigatorFor(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: DuoWorkspace.categoriesRoute),
      builder: (_) {
        Widget screen = CategoriesScreen(content: content);
        if (store != null) screen = StoreScope(notifier: store, child: screen);
        if (account != null) {
          screen = AccountScope(notifier: account, child: screen);
        }
        return screen;
      },
    ),
  );
}

class GuideCategory {
  const GuideCategory(
    this.id,
    this.title,
    this.filter,
    this.icon, [
    this.asset,
  ]);
  final String id;
  final String title;
  final CollectionFilter filter;
  final IconData icon;
  final String? asset;
}

const clientGuideCategories = [
  GuideCategory(
    'crossbody',
    'Crossbody',
    CollectionFilter(category: 'bolsa', silhouette: 'crossbody'),
    Icons.shopping_bag_outlined,
    'assets/images/home_bag_crossbody.webp',
  ),
  GuideCategory(
    'tote',
    'Tote',
    CollectionFilter(category: 'bolsa', silhouette: 'tote'),
    Icons.shopping_bag_outlined,
    'assets/images/home_bag_tote.webp',
  ),
  GuideCategory(
    'shoulder',
    'Shoulder',
    CollectionFilter(category: 'bolsa', silhouette: 'shoulder'),
    Icons.shopping_bag_outlined,
    'assets/images/home_bag_shoulder.webp',
  ),
  GuideCategory(
    'handbags',
    'Handbags',
    CollectionFilter(
      category: 'bolsa',
      queryTerms: ['handbag', 'top handle', 'bolsa de mano'],
    ),
    Icons.shopping_bag_outlined,
    'assets/images/home_collection_bags.webp',
  ),
  GuideCategory(
    'wallets',
    'Carteras',
    CollectionFilter(category: 'cartera'),
    Icons.account_balance_wallet_outlined,
    'assets/images/home_collection_wallets.webp',
  ),
  GuideCategory(
    'perfumes',
    'Perfumes',
    CollectionFilter(category: 'perfume'),
    Icons.water_drop_outlined,
  ),
  GuideCategory(
    'accessories',
    'Accesorios',
    CollectionFilter(category: 'accesorio'),
    Icons.watch_outlined,
  ),
  GuideCategory(
    'watches',
    'Relojes',
    CollectionFilter(category: 'reloj'),
    Icons.watch_outlined,
    'assets/images/home_collection_watches.webp',
  ),
];

/// Gold line icon of a collection tile in Categorías. Relojes has none: the
/// guide folds watches into «Accesorios» (its icon is a watch).
const Map<String, String> kGuideCategoryIcons = <String, String>{
  'crossbody': kGuideIconCategoryCrossbody,
  'tote': kGuideIconCategoryTote,
  'shoulder': kGuideIconCategoryShoulder,
  'handbags': kGuideIconCategoryHandbags,
  'wallets': kGuideIconCategoryWallets,
  'perfumes': kGuideIconCategoryPerfumes,
  'accessories': kGuideIconCategoryAccessories,
};

/// The seven collections of the guide's Categorías, in its order.
List<GuideCategory> get guideDirectoryCategories => [
      for (final category in clientGuideCategories)
        if (kGuideCategoryIcons.containsKey(category.id)) category,
    ];

/// Editorial cards may carry a display name; navigation needs a canonical facet.
String guideBrandSlug(HomeBrandCard brand, CatalogStore? store) {
  final value = fold(brand.brand);
  if (store?.ready ?? false) {
    for (final entry in store!.rules.brands.entries) {
      if (entry.key == value || entry.value.contains(value)) return entry.key;
    }
  }
  return ''; // No configured canonical binding: do not manufacture a slug.
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({this.content, this.bindings = const {}, super.key});
  final HomeContent? content;
  final Map<String, CollectionFilter> bindings;
  @override
  Widget build(BuildContext context) => ClientGuideScaffold(
        current: ClientGuideDestination.categories,
        body: Center(
          child: SizedBox(
            width: 800,
            child: ListView(
              key: const ValueKey('categories-scroll'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Categorías',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.screenTitle,
                  ),
                ),
                const SizedBox(height: 16),
                CategoryTree(
                  bindings: {
                    ...configuredCategoryBindings(
                      content ??
                          HomeContentScope.maybeOf(context)?.content ??
                          HomeContent.fallback,
                      StoreScope.maybeOf(context),
                    ),
                    ...bindings,
                  },
                  onOpen: (node, filter) => openCollection(
                    context,
                    CollectionScreen(
                      title: node.label,
                      filter: filter,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Marcas',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.sectionTitle,
                  ),
                ),
                BrandDirectory(content: content),
              ],
            ),
          ),
        ),
      );
}
