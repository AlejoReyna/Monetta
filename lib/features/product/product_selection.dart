/// Shared product selection and guarded purchase actions.
/// Named options come only from selectedOptions; legacy variant titles remain
/// neutral labels. Missing combinations resolve to -1, never another variant.
library;

import 'package:flutter/material.dart';

import '../../data/normalize/text.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../boutique/boutique_tokens.dart';
import '../checkout/checkout_screen.dart' show openBag;
import '../checkout/mini_cart.dart' show showMiniCart;
import 'variant_selection.dart';

export 'variant_selection.dart';

// ---------------------------------------------------------------------------
// Selection
// ---------------------------------------------------------------------------

/// Variants the shopper can choose from. Single-variant `Default Title`
/// products have no meaningful choice and return empty.
List<ProductVariant> selectableVariants(Product product) {
  return productChoices(product);
}

ProductVariant? selectedVariant(Product product, int index) {
  if (index < 0) return null;
  final selectable = selectableVariants(product);
  if (selectable.isEmpty) {
    return product.variants.isEmpty ? null : product.variants.first;
  }
  if (index < 0 || index >= selectable.length) return selectable.first;
  return selectable[index];
}

double selectionPrice(Product product, int index) {
  return selectedVariant(product, index)?.price ?? product.price;
}

double? selectionCompareAt(Product product, int index) {
  return selectedVariant(product, index)?.compareAtPrice;
}

/// True only when the data carries a real `compare_at` above price.
/// Never shown otherwise — no fabricated discount.
bool selectionOnSale(Product product, int index) {
  final compare = selectionCompareAt(product, index);
  if (compare == null) return false;
  return compare > selectionPrice(product, index);
}

/// Whole percent off, 0 when not on sale.
int selectionDiscountPercent(Product product, int index) {
  final price = selectionPrice(product, index);
  final compare = selectionCompareAt(product, index);
  if (compare == null || compare <= 0 || compare <= price) return 0;
  return ((compare - price) / compare * 100).round();
}

bool selectionInStock(Product product, int index) {
  return selectedVariant(product, index)?.available ?? false;
}

// ---------------------------------------------------------------------------
// Reliable colour mapping
// ---------------------------------------------------------------------------

/// Canonical colour slug → swatch fill. Only slugs with a stable, neutral
/// fill live here. `multicolor` is drawn split, never as a single invention.
const Map<String, Color> kProductSwatchFills = <String, Color>{
  'negro': Color(0xFF1B1B1B),
  'blanco': Color(0xFFFFFFFF),
  'cafe': Color(0xFF6F4E37),
  'beige': Color(0xFFD9CBB8),
  'gris': Color(0xFF9AA0A6),
  'rosa': Color(0xFFE3A7B8),
  'azul': Color(0xFF2F4A7A),
  'rojo': Color(0xFFB3261E),
  'dorado': Color(0xFFC5A052),
  'verde': Color(0xFF3B7B4A),
  'morado': Color(0xFF7A5C9E),
  'amarillo': Color(0xFFE0B400),
};

/// Alias → canonical slug, folded the same way the normalizer folds.
/// Mirrors `assets/rules/normalization_rules.json` colours so the swatch
/// agrees with the facet vocabulary instead of inventing a second one.
const Map<String, String> _colorAliasToSlug = <String, String>{
  'negro': 'negro',
  'negra': 'negro',
  'black': 'negro',
  'jet': 'negro',
  'blanco': 'blanco',
  'blanca': 'blanco',
  'white': 'blanco',
  'vanilla': 'blanco',
  'crema': 'blanco',
  'cream': 'blanco',
  'cafe': 'cafe',
  'chocolate': 'cafe',
  'brown': 'cafe',
  'camel': 'cafe',
  'taupe': 'cafe',
  'natural': 'cafe',
  'conac': 'cafe',
  'yute': 'cafe',
  'saddle': 'cafe',
  'miel': 'cafe',
  'tan': 'cafe',
  'beige': 'beige',
  'nude': 'beige',
  'arena': 'beige',
  'hueso': 'beige',
  'gris': 'gris',
  'grey': 'gris',
  'gray': 'gris',
  'plata': 'gris',
  'silver': 'gris',
  'plateado': 'gris',
  'rosa': 'rosa',
  'rosado': 'rosa',
  'pink': 'rosa',
  'rosa claro': 'rosa',
  'rose': 'rosa',
  'fiusha': 'rosa',
  'fucsia': 'rosa',
  'fuchsia': 'rosa',
  'palo de rosa': 'rosa',
  'blush': 'rosa',
  'azul': 'azul',
  'blue': 'azul',
  'azul marino': 'azul',
  'marino': 'azul',
  'navy': 'azul',
  'denim': 'azul',
  'mezclilla': 'azul',
  'celeste': 'azul',
  'rojo': 'rojo',
  'roja': 'rojo',
  'red': 'rojo',
  'vino': 'rojo',
  'burgundy': 'rojo',
  'wine': 'rojo',
  'dorado': 'dorado',
  'dorada': 'dorado',
  'gold': 'dorado',
  'oro': 'dorado',
  'rose gold': 'dorado',
  'verde': 'verde',
  'green': 'verde',
  'olivo': 'verde',
  'militar': 'verde',
  'morado': 'morado',
  'lila': 'morado',
  'purple': 'morado',
  'iris': 'morado',
  'amarillo': 'amarillo',
  'yellow': 'amarillo',
  'mostaza': 'amarillo',
  'multicolor': 'multicolor',
  'multi': 'multicolor',
};

/// Returns the canonical colour slug when [variantTitle] names exactly one
/// colour, else null.
///
/// Unreliable (null) when:
/// * the title carries `/` (`Cafe/Dorado`) — a bicolor has no single swatch;
/// * zero or two+ canonical colours match (`Arena/Beige Dorado Signature`);
/// * the word is unknown (`Marrón` has no alias — not invented).
String? reliableColorSlug(String variantTitle) {
  final folded = fold(variantTitle);
  if (folded.isEmpty) return null;
  if (folded.contains('/')) return null;
  final matched = <String>{};
  // Longest aliases first so `azul marino` wins over bare `azul`, and
  // `rosa claro` over bare `rosa`.
  final aliases = _colorAliasToSlug.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final alias in aliases) {
    if (containsWord(folded, alias)) {
      matched.add(_colorAliasToSlug[alias]!);
      if (matched.length > 1) return null;
    }
  }
  if (matched.length != 1) return null;
  return matched.single;
}

/// True when every selectable variant maps to exactly one swatch colour.
/// The ficha and the sheet show swatches only in this case; otherwise they
/// fall back to neutral text chips (never a guessed colour).
bool hasReliableColorOptions(Product product) {
  final selectable = selectableVariants(product);
  if (selectable.isEmpty) return false;
  for (final variant in selectable) {
    final color = variant.selectedOptions.entries.where(
      (e) => const ['color', 'colour', 'colores'].contains(fold(e.key)),
    );
    if (color.length != 1) return false;
    final slug = _colorAliasToSlug[fold(color.single.value)];
    if (slug == null) return false;
    if (slug == 'multicolor') return false;
    if (!kProductSwatchFills.containsKey(slug)) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Shared purchase actions
// ---------------------------------------------------------------------------

/// Outcome of [tryAddSelectionToBag].
enum BagAddStatus {
  /// One unit of the chosen variant is now in the bag.
  added,

  /// The chosen variant exists but is sold out; the bag was not touched.
  soldOut,

  /// There is no variant to buy; the bag was not touched.
  unavailable,

  /// The store threw while adding; [BagAddResult.error] carries the cause.
  failed,
}

/// Typed result of [tryAddSelectionToBag] so every purchase surface reports
/// the same outcomes instead of guessing from a nullable id.
class BagAddResult {
  const BagAddResult(this.status, {this.variantId, this.error});

  final BagAddStatus status;

  /// The variant that was added; only set when [status] is
  /// [BagAddStatus.added].
  final String? variantId;

  /// The failure that stopped the add; only set when [status] is
  /// [BagAddStatus.failed].
  final Object? error;
}

/// The single path that puts the current selection into the bag.
///
/// Guards stock here because `CatalogStore.addToBag` resolves the exact
/// variant even when it is sold out. The variant is never substituted: the
/// one at [variantIndex] is added or nothing is.
Future<BagAddResult> tryAddSelectionToBag(
  BuildContext context,
  Product product,
  int variantIndex,
) async {
  final store = StoreScope.of(context);
  final variant = selectedVariant(product, variantIndex);
  if (variant == null) {
    return const BagAddResult(BagAddStatus.unavailable);
  }
  if (!variant.available) {
    return const BagAddResult(BagAddStatus.soldOut);
  }
  try {
    await store.addToBag(product, variantId: variant.id);
  } catch (error) {
    return BagAddResult(BagAddStatus.failed, error: error);
  }
  return BagAddResult(BagAddStatus.added, variantId: variant.id);
}

/// Adds the current selection to the bag. Returns the added variant id, or
/// null when nothing was added (no variant, sold out, or a failed write).
Future<String?> addSelectionToBag(
  BuildContext context,
  Product product,
  int variantIndex,
) async {
  final result = await tryAddSelectionToBag(context, product, variantIndex);
  return result.status == BagAddStatus.added ? result.variantId : null;
}

/// Primary add: add + confirm with the shared mini-cart sheet. Nothing is
/// confirmed unless the unit really went into the bag.
Future<void> addToBagAndShowMiniCart(
  BuildContext context,
  Product product,
  int variantIndex,
) async {
  final result = await tryAddSelectionToBag(context, product, variantIndex);
  if (result.status != BagAddStatus.added || !context.mounted) return;
  // Keeps the existing confirmation surface — a sheet, never a toast.
  await showMiniCart(context);
}

/// Opens the bag on a context that outlives a preview sheet.
Future<void> openShoppingBag(BuildContext context) => openBag(context);

/// "Comprar ahora": add + open the bag. The bag opens only after a real add.
Future<void> buyNowOpenBag(
  BuildContext context,
  Product product,
  int variantIndex,
) async {
  final result = await tryAddSelectionToBag(context, product, variantIndex);
  if (result.status != BagAddStatus.added || !context.mounted) return;
  await openBag(context);
}

/// Exposed for widget tests that assert the shared helper is the only writer.
@visibleForTesting
Future<void> testOnlyAdd(
  BuildContext context,
  Product product,
  int variantIndex,
) =>
    addSelectionToBag(context, product, variantIndex);

// ---------------------------------------------------------------------------
// Shared colour selector UI (one widget, both surfaces)
// ---------------------------------------------------------------------------

/// Variant picker shared by the ficha and the quick-view.
///
/// * Reliable single-colour options → swatches: 30pt circles in 48pt targets,
///   the chosen one wrapped in a thin ink ring (a shape cue, never colour
///   alone).
/// * Anything else → neutral text chips.
/// * Single-variant products → nothing (no fake choice).
class ProductOptionSelector extends StatefulWidget {
  const ProductOptionSelector({
    required this.product,
    required this.selectedIndex,
    required this.onSelect,
    this.colorHeading = 'Color',
    this.showSelectedName = true,
    super.key,
  });

  final Product product;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final String colorHeading;
  final bool showSelectedName;

  @override
  State<ProductOptionSelector> createState() => _ProductOptionSelectorState();
}

class _ProductOptionSelectorState extends State<ProductOptionSelector> {
  Map<String, String> _values = {};

  void _readSelection() {
    _values = Map.of(
      widget.selectedIndex == null
          ? const <String, String>{}
          : selectedVariant(widget.product, widget.selectedIndex!)
                  ?.selectedOptions ??
              const <String, String>{},
    );
  }

  @override
  void initState() {
    super.initState();
    _readSelection();
  }

  @override
  void didUpdateWidget(covariant ProductOptionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        (oldWidget.selectedIndex != widget.selectedIndex &&
            widget.selectedIndex != -1)) {
      _readSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final choices = selectableVariants(widget.product);
    if (choices.isEmpty) return const SizedBox.shrink();
    final groups = productOptionValues(widget.product);
    // Old snapshots with no selectedOptions retain honest, complete labels.
    // Never turn the variant title into a fabricated colour or size.
    if (groups.isEmpty) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < choices.length; i++)
            _OptionChip(
              label: choices[i].title,
              selected: widget.selectedIndex == i,
              available: choices[i].available,
              onTap: () => widget.onSelect(i),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups.entries) ...[
          Text(
            _values[group.key] == null || !widget.showSelectedName
                ? group.key
                : '${group.key}: ${_values[group.key]}',
            style: boutiqueText(size: 14, color: palette.ink, height: 1.3),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final value in group.value)
                Builder(
                  builder: (context) {
                    final next = {..._values, group.key: value};
                    final index = indexForOptions(widget.product, next);
                    final available = index >= 0 && choices[index].available;
                    final isColor = const ['color', 'colour', 'colores']
                        .contains(fold(group.key));
                    final slug =
                        isColor ? _colorAliasToSlug[fold(value)] : null;
                    void select() {
                      setState(() => _values = next);
                      widget.onSelect(index);
                    }

                    if (slug != null && kProductSwatchFills.containsKey(slug)) {
                      return _Swatch(
                        fill: kProductSwatchFills[slug]!,
                        selected: _values[group.key] == value,
                        available: available,
                        label: value,
                        onTap: select,
                      );
                    }
                    return _OptionChip(
                      label: value,
                      selected: _values[group.key] == value,
                      available: available,
                      onTap: select,
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (widget.selectedIndex == -1)
          Text(
            'Esta combinación no está disponible.',
            key: const Key('product-combination-unavailable'),
            style: boutiqueText(size: 13, color: palette.inkMuted),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.fill,
    required this.selected,
    required this.available,
    required this.label,
    required this.onTap,
  });

  final Color fill;
  final bool selected;
  final bool available;
  final String label;
  final VoidCallback onTap;

  /// Diameter of the colour disc.
  static const double _disc = 30;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color $label${available ? '' : ', no disponible'}',
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: SizedBox(
          width: BoutiqueSpace.tapTarget,
          height: BoutiqueSpace.tapTarget,
          child: Center(
            child: Opacity(
              opacity: available ? 1 : 0.35,
              // The ring is always laid out so choosing a colour never moves
              // its neighbours; only its paint changes.
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? palette.ink : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Container(
                  width: _disc,
                  height: _disc,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fill,
                    border: Border.all(color: palette.hairline),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Opción $label${available ? '' : ', no disponible'}',
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Opacity(
          opacity: available ? 1 : 0.45,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 48,
              maxWidth: 220,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.lg,
              vertical: BoutiqueSpace.sm,
            ),
            decoration: BoxDecoration(
              color: selected ? palette.selectedFill : Colors.transparent,
              borderRadius: BoutiqueRadius.control,
              border: Border.all(
                color: selected ? palette.selectedBorder : palette.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 14, color: palette.ink),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: boutiqueEyebrow(size: 10, color: palette.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
