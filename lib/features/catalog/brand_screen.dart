/// One brand, presented editorially — for any brand the catalog carries.
///
/// The app could already *filter* by brand; what it lacked was a destination
/// that looks like the brand. This screen is that destination, built on the
/// same canonical brand facet the filters use, so there is nothing
/// Coach-specific in it: pass any slug the catalog resolves and it works.
///
/// Nothing here is invented. The wordmark is the bundled official artwork when
/// one exists for that slug, the tagline and the story are owner-supplied and
/// simply absent otherwise, the category tabs are the categories that have
/// products behind them, and there is no "Más vendidas" tab because the app
/// has no sales ranking to sort by.
library;

import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/text_scale_policy.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';
import '../product/quick_view.dart';
import 'catalog_controls.dart';
import 'collection_screen.dart';
import 'product_card.dart';

/// Bundled wordmark for a canonical brand slug, e.g. `michael_kors`.
///
/// Returns a path whether or not the file ships; the widget's own
/// `errorBuilder` falls back to type, which keeps this honest for brands that
/// have no artwork yet.
String brandLogoAsset(String slug) => 'assets/images/brands/$slug.webp';

Future<void> openBrand(
  BuildContext context, {
  required String brandSlug,
  String? title,
  String? tagline,
  String? story,
  String? heroImageUrl,
  String? heroImageAsset,
}) async {
  final store = StoreScope.of(context);
  await Navigator.of(context).push<void>(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: BrandScreen(
          brandSlug: brandSlug,
          title: title,
          tagline: tagline,
          story: story,
          heroImageUrl: heroImageUrl,
          heroImageAsset: heroImageAsset,
        ),
      ),
    ),
  );
}

class BrandScreen extends StatefulWidget {
  const BrandScreen({
    required this.brandSlug,
    this.title,
    this.tagline,
    this.story,
    this.heroImageUrl,
    this.heroImageAsset,
    super.key,
  });

  /// Canonical facet value — `coach`, `michael_kors`, `guess`. Never a raw
  /// Shopify `vendor`, which is the shop name on most of this catalog.
  final String brandSlug;

  /// Defaults to the shopper-facing label for [brandSlug].
  final String? title;

  /// One short owner-authored line under the wordmark. Hidden when null.
  final String? tagline;

  /// "Sobre la marca". The whole block disappears when there is no text —
  /// no placeholder paragraph, no invented authenticity claims.
  final String? story;

  /// Brand photography. Only pass artwork that is verifiably this brand's;
  /// with none, the header is the wordmark on a neutral ground.
  final String? heroImageUrl;
  final String? heroImageAsset;

  @override
  State<BrandScreen> createState() => _BrandScreenState();
}

class _BrandScreenState extends State<BrandScreen> {
  /// Null means "Todo". Selecting a tab narrows the category and never drops
  /// the brand scope.
  String? _category;

  String get _title => widget.title ?? brandLabel(widget.brandSlug);

  List<Product> _brandProducts(CatalogStore store) => store.products
      .where(
        (product) =>
            store.facetsFor(product.id)?.brand?.value == widget.brandSlug,
      )
      .toList(growable: false);

  /// Only categories that actually have pieces — a tab that leads nowhere is
  /// worse than no tab.
  List<String> _categories(CatalogStore store, List<Product> products) {
    final slugs = <String>{
      for (final product in products)
        if (store.facetsFor(product.id)?.category?.value case final value?)
          value,
    }.toList()
      ..sort(
        (a, b) => categoryPlural(a).toLowerCase().compareTo(
              categoryPlural(b).toLowerCase(),
            ),
      );
    return slugs;
  }

  List<Product> _visible(CatalogStore store, List<Product> products) {
    final category = _category;
    final visible = category == null
        ? [...products]
        : products
            .where(
              (product) =>
                  store.facetsFor(product.id)?.category?.value == category,
            )
            .toList();
    visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return visible;
  }

  void _openAll() {
    openCollection(
      context,
      CollectionScreen(
        title: _category == null
            ? _title
            : '$_title · ${categoryPlural(_category!)}',
        // The brand stays part of the destination, so the collection's own
        // "Limpiar" returns to this brand rather than the whole catalog.
        filter: CollectionFilter(
          brand: widget.brandSlug,
          category: _category,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final products = _brandProducts(store);
    final categories = _categories(store, products);
    final visible = _visible(store, products);
    final story = widget.story?.trim() ?? '';
    final width = MediaQuery.sizeOf(context).width - BoutiqueSpace.gutter * 2;

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _title,
          style: boutiqueText(
            size: 15,
            weight: FontWeight.w600,
            color: palette.ink,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _BrandHeader(
              key: const ValueKey('brand-header'),
              title: _title,
              slug: widget.brandSlug,
              tagline: widget.tagline,
              heroImageUrl: widget.heroImageUrl,
              heroImageAsset: widget.heroImageAsset,
            ),
          ),
          if (categories.length > 1)
            SliverToBoxAdapter(
              child: _BrandTabs(
                categories: categories,
                selected: _category,
                onSelected: (slug) => setState(() => _category = slug),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BoutiqueSpace.gutter,
                BoutiqueSpace.lg,
                BoutiqueSpace.gutter,
                0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CatalogResultCount(count: visible.length),
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: CatalogEmptyState(
                key: const ValueKey('brand-empty'),
                title: 'Aún no hay piezas',
                body: 'No encontramos piezas de $_title en esta vista.',
                actionLabel: categories.isEmpty ? null : 'Ver todo de $_title',
                onAction: categories.isEmpty
                    ? null
                    : () => setState(() => _category = null),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                BoutiqueSpace.gutter,
                BoutiqueSpace.lg,
                BoutiqueSpace.gutter,
                BoutiqueSpace.lg,
              ),
              sliver: SliverGrid(
                key: const ValueKey('brand-product-grid'),
                gridDelegate: productGridDelegate(
                  context,
                  availableWidth: width,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = visible[index];
                    return ProductCard(
                      key: ValueKey('product-card-${product.id}'),
                      product: product,
                      onQuickView: () => showProductQuickView(context, product),
                    );
                  },
                  childCount: visible.length,
                ),
              ),
            ),
          if (story.isNotEmpty)
            SliverToBoxAdapter(
              child: _BrandStory(
                key: const ValueKey('brand-story'),
                body: story,
              ),
            ),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BoutiqueSpace.gutter,
                  BoutiqueSpace.xl,
                  BoutiqueSpace.gutter,
                  BoutiqueSpace.xxl,
                ),
                child: BoutiqueButton(
                  key: const ValueKey('brand-see-all'),
                  label: 'Ver todo de $_title',
                  onPressed: visible.isEmpty ? null : _openAll,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wordmark first. With verified brand photography it sits on the image;
/// without, it sits on the secondary ivory surface — never on a photograph
/// borrowed from another brand.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.title,
    required this.slug,
    required this.tagline,
    required this.heroImageUrl,
    required this.heroImageAsset,
    super.key,
  });

  final String title;
  final String slug;
  final String? tagline;
  final String? heroImageUrl;
  final String? heroImageAsset;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = heroImageUrl != null || heroImageAsset != null;
    if (hasPhoto) {
      return CatalogEditorialBanner(
        title: title,
        description: tagline,
        imageUrl: heroImageUrl,
        imageAsset: heroImageAsset,
        centerTitle: true,
      );
    }

    final palette = context.boutique;
    return Container(
      width: double.infinity,
      color: palette.surfaceDeep,
      padding: const EdgeInsets.symmetric(
        horizontal: BoutiqueSpace.gutter,
        vertical: BoutiqueSpace.xxl,
      ),
      child: Column(
        children: [
          // `contain` inside a fixed box: a logo is artwork, never stretched
          // or tinted to fit a background.
          SizedBox(
            height: 44,
            child: Image.asset(
              brandLogoAsset(slug),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: boutiqueScreenTitle(color: palette.ink),
                ),
              ),
            ),
          ),
          if (tagline case final line? when line.trim().isNotEmpty) ...[
            const SizedBox(height: BoutiqueSpace.md),
            Text(
              line,
              textAlign: TextAlign.center,
              style: boutiqueText(size: 14, color: palette.inkMuted),
            ),
          ],
          const SizedBox(height: BoutiqueSpace.lg),
          Container(width: 56, height: 1.4, color: palette.gold),
        ],
      ),
    );
  }
}

/// Underline tabs from the reference. Scrollable, so a brand with many
/// categories never squeezes its labels below the readable floor.
class _BrandTabs extends StatelessWidget {
  const _BrandTabs({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final entries = <(String?, String)>[
      (null, 'Todo'),
      for (final slug in categories) (slug, categoryPlural(slug)),
    ];

    return SizedBox(
      // The tab band holds 14pt labels, so it follows their scale.
      height: 52 * textScaleFactorFor(MediaQuery.textScalerOf(context), 14),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: BoutiqueSpace.xl),
        itemBuilder: (context, index) {
          final (slug, label) = entries[index];
          final on = slug == selected;
          return Semantics(
            button: true,
            selected: on,
            child: InkWell(
              key: Key('brand-tab-${slug ?? 'all'}'),
              onTap: () => onSelected(slug),
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: BoutiqueSpace.tapTarget,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: on ? palette.ink : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: boutiqueText(
                    size: 14,
                    weight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? palette.ink : palette.inkMuted,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BrandStory extends StatelessWidget {
  const _BrandStory({required this.body, super.key});

  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: BoutiqueSpace.xl),
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.xl,
        BoutiqueSpace.gutter,
        BoutiqueSpace.xl,
      ),
      color: palette.surfaceDeep,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sobre la marca',
            style: boutiqueSectionHeading(color: palette.ink),
          ),
          const SizedBox(height: BoutiqueSpace.md),
          Text(
            body,
            style: boutiqueText(
              size: 14,
              color: palette.inkMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
