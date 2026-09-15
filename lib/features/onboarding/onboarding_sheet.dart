/// Screen 02 — optional personalisation.
///
/// Opened from the first-visit welcome (`features/welcome/welcome_gate.dart`),
/// never automatically over the home. Optional by design: continuing with
/// nothing selected, or skipping outright, leaves the feed on trending rather
/// than on an empty screen — see `lib/reco/README.md` § 5.
///
/// It still arrives through `showModalBottomSheet` (`isScrollControlled: true`,
/// and `bottomSheetTheme` squares the sheet corners — see `app/theme.dart`),
/// requesting the full viewport height so the shopper sees one continuous
/// panel rather than a card peeking over the home.
///
/// Brands and categories are read from the live catalog, so the panel can never
/// offer something the store does not stock. No gender split — the catalog is
/// effectively single-audience.
///
/// This panel asks for nothing from the operating system. Notification
/// permission stays where it was, on the home's own first-run path, so a
/// personalisation tap never becomes a system prompt.
library;

import 'package:flutter/material.dart';

import '../../app/catalog_store.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';

/// Bundled artwork, keyed by the catalog's canonical brand slug. A brand with
/// no logo still gets a card — the name simply carries it.
const Map<String, String> _kBrandLogoAssets = <String, String>{
  'anne_klein': 'assets/images/brands/anne_klein.webp',
  'coach': 'assets/images/brands/coach.webp',
  'christian_dior': 'assets/images/brands/dior.webp',
  'dior': 'assets/images/brands/dior.webp',
  'guess': 'assets/images/brands/guess.webp',
  'laneige': 'assets/images/brands/laneige.webp',
  'michael_kors': 'assets/images/brands/michael_kors.webp',
  'olaplex': 'assets/images/brands/olaplex.webp',
  'rhode': 'assets/images/brands/rhode.webp',
  'steve_madden': 'assets/images/brands/steve_madden.webp',
  'summer_fridays': 'assets/images/brands/summer_fridays.webp',
  'the_ordinary': 'assets/images/brands/the_ordinary.webp',
  'tommy_hilfiger': 'assets/images/brands/tommy_hilfiger.webp',
};

const Map<String, IconData> _kCategoryIcons = <String, IconData>{
  'bolsa': Icons.shopping_bag_outlined,
  'cartera': Icons.account_balance_wallet_outlined,
  'monedero': Icons.payments_outlined,
  'tarjetero': Icons.credit_card_outlined,
  'reloj': Icons.watch_outlined,
  'cosmetiquera': Icons.brush_outlined,
  'set': Icons.inventory_2_outlined,
  'accesorio': Icons.auto_awesome_outlined,
};

/// Cap the panel so it stays one comfortable scroll rather than a directory.
const int _kMaxBrands = 12;

class OnboardingSheet extends StatefulWidget {
  const OnboardingSheet({super.key});

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final Set<String> _brands = <String>{};
  final Set<String> _categories = <String>{};

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (!target.remove(value)) target.add(value);
    });
  }

  void _continue(CatalogStore store) {
    // An empty selection is a valid answer: seeding an empty profile would be
    // identical to not seeding at all, so skip the write and let the feed stay
    // on trending. Everything remains browsable either way.
    if (_brands.isNotEmpty || _categories.isNotEmpty) {
      store.seedFrom(
        brands: _brands.toList(),
        categories: _categories.toList(),
      );
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final palette = context.boutique;
    // `showModalBottomSheet` strips `MediaQuery.padding.top` from the ambient
    // MediaQuery it hands its builder — a sheet is expected to leave the status
    // bar exposed, not to need a top inset. This panel asks for the *full*
    // screen height, so with that value zeroed `SafeArea` has nothing to pad by
    // and the header draws under the status bar. Read the real view inset.
    final viewPadding = MediaQueryData.fromView(View.of(context)).padding;

    final brands = <String>[
      for (final slug in store.availableBrands) slug,
    ].take(_kMaxBrands).toList();
    final categories = _catalogCategories(store);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: Material(
        color: palette.canvas,
        child: Padding(
          padding: EdgeInsets.only(
            top: viewPadding.top,
            bottom: viewPadding.bottom,
          ),
          child: Column(
            children: [
              _Header(onClose: () => Navigator.of(context).pop(false)),
              Divider(height: .5, color: palette.hairline),
              Expanded(
                child: ListView(
                  key: const ValueKey('onboarding-scroll'),
                  padding: const EdgeInsets.fromLTRB(
                    BoutiqueSpace.gutter,
                    BoutiqueSpace.xl,
                    BoutiqueSpace.gutter,
                    BoutiqueSpace.xxl,
                  ),
                  children: [
                    Text(
                      'Personaliza tu experiencia',
                      style: boutiqueTitle(size: 24, color: palette.ink),
                    ),
                    const SizedBox(height: BoutiqueSpace.sm),
                    Text(
                      'Selecciona tus marcas y categorías favoritas para '
                      'recibir recomendaciones. Puedes continuar sin elegir '
                      'nada y cambiarlo cuando quieras.',
                      style: boutiqueText(size: 14, color: palette.inkMuted),
                    ),
                    if (brands.isNotEmpty) ...[
                      const SizedBox(height: BoutiqueSpace.xxl),
                      _GroupLabel(
                        label: 'Marcas favoritas',
                        selectedCount: _brands.length,
                      ),
                      const SizedBox(height: BoutiqueSpace.lg),
                      _SelectionGrid(
                        key: const ValueKey('onboarding-brands-grid'),
                        columnsWide: 3,
                        children: <Widget>[
                          for (final slug in brands)
                            _BrandCard(
                              key: ValueKey('onboarding-brand-$slug'),
                              slug: slug,
                              label: brandLabel(slug),
                              selected: _brands.contains(slug),
                              onTap: () => _toggle(_brands, slug),
                            ),
                        ],
                      ),
                    ],
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: BoutiqueSpace.xxl),
                      _GroupLabel(
                        label: 'Categorías de interés',
                        selectedCount: _categories.length,
                      ),
                      const SizedBox(height: BoutiqueSpace.lg),
                      _SelectionGrid(
                        key: const ValueKey('onboarding-categories-grid'),
                        columnsWide: 4,
                        children: <Widget>[
                          for (final slug in categories)
                            _CategoryCard(
                              key: ValueKey('onboarding-category-$slug'),
                              label: _categoryTitle(slug),
                              icon: _kCategoryIcons[slug] ??
                                  Icons.local_mall_outlined,
                              selected: _categories.contains(slug),
                              onTap: () => _toggle(_categories, slug),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              _Footer(
                onContinue: () => _continue(store),
                onSkip: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Categories the catalog actually carries, most stocked first.
List<String> _catalogCategories(CatalogStore store) {
  final counts = <String, int>{};
  for (final facets in store.facetsById.values) {
    final category = facets.category?.value;
    if (category == null || category.isEmpty) continue;
    counts.update(category, (value) => value + 1, ifAbsent: () => 1);
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return <String>[for (final entry in sorted) entry.key];
}

String _categoryTitle(String slug) {
  final plural = categoryPlural(slug);
  if (plural.isEmpty) return humanizeCatalogValue(slug);
  return '${plural[0].toUpperCase()}${plural.substring(1)}';
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(BoutiqueSpace.gutter, 12, 8, 12),
      child: Row(
        children: [
          const Expanded(child: MonettaWordmark(height: 20)),
          IconButton(
            key: const ValueKey('onboarding-close'),
            tooltip: 'Omitir',
            onPressed: onClose,
            constraints: const BoxConstraints.tightFor(
              width: BoutiqueSpace.tapTarget,
              height: BoutiqueSpace.tapTarget,
            ),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label, required this.selectedCount});

  final String label;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            label,
            style: boutiqueTitle(size: 16, color: palette.ink),
          ),
        ),
        if (selectedCount > 0)
          Text(
            '$selectedCount seleccionadas',
            style: boutiqueText(size: 12, color: palette.inkMuted),
          ),
      ],
    );
  }
}

/// A wrap rather than a `GridView`: cell height stays intrinsic, so a shopper
/// running large text gets taller cards instead of clipped ones.
class _SelectionGrid extends StatelessWidget {
  const _SelectionGrid({
    required this.children,
    required this.columnsWide,
    super.key,
  });

  final List<Widget> children;

  /// Columns on a normal phone: three for the brand cards, four for the
  /// category tiles, as on figure 02. One fewer on a small screen.
  final int columnsWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = BoutiqueSpace.md;
        final width = constraints.maxWidth;
        final columns = width >= 520
            ? columnsWide + 1
            : width >= 330
                ? columnsWide
                : columnsWide - 1;
        final cellWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final child in children)
              SizedBox(width: cellWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Selection is carried three ways at once — fill, border and a check mark —
/// so it never depends on colour alone.
class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      label: semanticLabel,
      checked: selected,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.selectedFill : palette.surface,
        borderRadius: BoutiqueRadius.card,
        child: InkWell(
          onTap: onTap,
          borderRadius: BoutiqueRadius.card,
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.sm,
              vertical: BoutiqueSpace.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BoutiqueRadius.card,
              border: Border.all(
                color: selected ? palette.selectedBorder : palette.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Stack(
              // The card is width-tight from the grid, so the content is
              // centred explicitly rather than falling to the stack's
              // top-left default.
              alignment: Alignment.topCenter,
              children: [
                child,
                Positioned(
                  top: 0,
                  right: 0,
                  child: _SelectionMark(selected: selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.ink : Colors.transparent,
        border: Border.all(
          color: selected ? palette.ink : palette.hairline,
          width: 1,
        ),
      ),
      child:
          selected ? Icon(Icons.check, size: 12, color: palette.canvas) : null,
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.slug,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String slug;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final asset = _kBrandLogoAssets[slug];
    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 38,
            child: asset == null
                ? const SizedBox.shrink()
                : Image.asset(
                    asset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
          const SizedBox(height: BoutiqueSpace.sm),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: boutiqueText(
              size: 13,
              height: 1.25,
              color: palette.ink,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return _SelectableCard(
      selected: selected,
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: palette.ink),
          const SizedBox(height: BoutiqueSpace.sm),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: boutiqueText(
              size: 13,
              height: 1.25,
              color: palette.ink,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onContinue, required this.onSkip});

  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(top: BorderSide(color: palette.hairline, width: .5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BoutiqueSpace.gutter,
          BoutiqueSpace.lg,
          BoutiqueSpace.gutter,
          BoutiqueSpace.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BoutiqueButton(
              key: const ValueKey('onboarding-continue'),
              label: 'Continuar',
              onPressed: onContinue,
            ),
            const SizedBox(height: BoutiqueSpace.xs),
            SizedBox(
              height: BoutiqueSpace.tapTarget,
              child: TextButton(
                key: const ValueKey('onboarding-skip'),
                onPressed: onSkip,
                child: Text(
                  'Omitir por ahora',
                  style: boutiqueText(
                    size: 13,
                    color: palette.inkMuted,
                    weight: FontWeight.w500,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
