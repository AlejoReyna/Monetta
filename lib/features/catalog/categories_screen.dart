/// Dedicated category directory (client guide page 18), reusing catalog routes.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/catalog_store.dart';
import '../../data/normalize/text.dart';
import '../../domain/home_content.dart';
import '../../main.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import '../boutique/guide_art.dart';
import '../boutique/guide_brand_tile.dart';
import '../navigation/duo_workspace.dart';
import 'brand_screen.dart';
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
  return value.replaceAll(RegExp(r'[\s-]+'), '_');
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({this.content, super.key});
  final HomeContent? content;
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _allBrands = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.maybeOf(context);
    final content = widget.content ??
        HomeContentScope.maybeOf(context)?.content ??
        HomeContent.fallback;
    final brands = content.brands;
    // Three rows on compact layouts, with a working disclosure for the rest.
    final shownBrands = _allBrands
        ? brands
        : brands.take(MonettaTokens.categoryColumnsCompact * 3);
    return ClientGuideScaffold(
      current: ClientGuideDestination.categories,
      body: ListView(
        key: const ValueKey('categories-scroll'),
        padding: EdgeInsets.all(
          MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
        ),
        children: [
          Text(
            'Categorías',
            style: clientGuideStyle(context, MonettaTokens.screenTitle),
          ),
          SizedBox(height: MonettaTokens.space[1]),
          Text(
            'Descubre todas nuestras colecciones de tus marcas favoritas.',
            style: clientGuideStyle(
              context,
              MonettaTokens.body,
              color: palette.inkMuted,
            ),
          ),
          SizedBox(height: MonettaTokens.space[3]),
          Text(
            'Colecciones',
            style: clientGuideStyle(context, MonettaTokens.sectionTitle),
          ),
          SizedBox(height: MonettaTokens.space[2]),
          _DirectoryGrid(
            columns: MonettaTokens.categoryColumnsCompact,
            children: [
              for (final category in guideDirectoryCategories)
                _CollectionTile(
                  key: ValueKey('categories-category-${category.id}'),
                  label: category.title,
                  iconAsset: kGuideCategoryIcons[category.id]!,
                  onTap: store == null
                      ? null
                      : () => openCollection(
                            context,
                            CollectionScreen(
                              title: category.title,
                              filter: category.filter,
                            ),
                          ),
                ),
            ],
          ),
          SizedBox(height: MonettaTokens.space[3]),
          Divider(color: palette.hairline),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Marcas',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.sectionTitle,
                  ),
                ),
              ),
              if (brands.length > MonettaTokens.categoryColumnsCompact * 3)
                TextButton(
                  key: const ValueKey('categories-all-brands'),
                  onPressed: () => setState(() => _allBrands = !_allBrands),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _allBrands ? 'Ver menos' : 'Ver todo',
                        style: clientGuideStyle(
                          context,
                          MonettaTokens.cardLabel,
                        ),
                      ),
                      Icon(
                        _allBrands ? Icons.expand_less : Icons.chevron_right,
                        size: 18,
                        color: palette.ink,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: MonettaTokens.space[2]),
          if (brands.isEmpty)
            Text(
              'Marcas: contenido pendiente.',
              style: clientGuideStyle(context, MonettaTokens.body),
            ),
          _DirectoryGrid(
            columns: MonettaTokens.categoryColumnsCompact,
            children: [
              for (final brand in shownBrands)
                GuideBrandTile(
                  key: ValueKey(
                    'categories-brand-${guideBrandSlug(brand, store)}',
                  ),
                  asset: brand.fallbackAsset,
                  label: brand.title,
                  onTap: store == null
                      ? null
                      : () => unawaited(
                            openBrand(
                              context,
                              brandSlug: guideBrandSlug(brand, store),
                              title: brand.title,
                            ),
                          ),
                ),
            ],
          ),
          SizedBox(height: MonettaTokens.space[4]),
        ],
      ),
    );
  }
}

class _DirectoryGrid extends StatelessWidget {
  const _DirectoryGrid({required this.children, this.columns});
  final List<Widget> children;

  /// Fixed column count; null follows the breakpoints.
  final int? columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = MediaQuery.sizeOf(context).width;
          final columns = this.columns ??
              (MediaQuery.textScalerOf(context).scale(1) > 1.3
                  ? MonettaTokens.productColumnsNarrow
                  : width >= MonettaTokens.breakpointExpanded
                      ? MonettaTokens.categoryColumnsExpanded
                      : width >= MonettaTokens.breakpointMedium
                          ? MonettaTokens.categoryColumnsMedium
                          : MonettaTokens.categoryColumnsCompact);
          final gap = MonettaTokens.space[1];
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children)
                SizedBox(
                  width: (constraints.maxWidth - gap * (columns - 1)) / columns,
                  child: child,
                ),
            ],
          );
        },
      );
}

/// Tile of a collection: gold line icon on the tinted tile, label below.
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.label,
    required this.iconAsset,
    required this.onTap,
    super.key,
  });

  final String label;
  final String iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: palette.surfaceDeep,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(MonettaTokens.radiusTile),
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 1.12,
            child: Padding(
              padding: EdgeInsets.all(MonettaTokens.space[1]),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: MonettaTokens.space[1]),
                      child: Image.asset(
                        iconAsset,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.shopping_bag_outlined,
                          size: MonettaTokens.space[5],
                          color: palette.goldText,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MonettaTokens.space[0]),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: guideSerifStyle(
                      context,
                      size: 14,
                      color: palette.ink,
                      weight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
