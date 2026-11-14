/// Centered quick view: exact variant options, photography, price and stock;
/// independent favorite, X/Escape, in-place add confirmation and PDP entry.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter/services.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../platform/system_layout_context.dart';
import '../../reco/events.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../catalog/product_tile.dart' show PackshotBlend;
import '../catalog/product_controls.dart';
import '../navigation/duo_workspace.dart';
import 'product_selection.dart';
import 'purchase_dock.dart';

const String _kChooseLabel = 'Elige una opción';

/// Share of the screen width the card takes, before the 440 cap.
const double _kCardWidthFactor = 0.79;
const double _kCardMaxWidth = 440;

/// Least air between the card and each screen edge.
const double _kCardSideMargin = 28;
const double _kCardRadius = 22;

/// Opens the quick-view for [product] without leaving the current surface.
Future<void> showProductQuickView(
  BuildContext context,
  Product product, {
  int initialVariantIndex = 0,
  bool requireChoice = false,
  String? initialVariantId,
  ValueChanged<String?>? onVariantChanged,
  ProductRestockAction? onRestock,
}) {
  final store = StoreScope.of(context);
  final originFocus = FocusManager.instance.primaryFocus;
  initialVariantIndex = variantIndexForId(
    product,
    initialVariantId,
    fallback: initialVariantIndex,
  );
  store.record(EventType.galleryInteraction, productId: product.id);
  // A two-sided window shows the card on its right side, beside the catalog,
  // with no veil: touching another piece replaces it.
  final shownBeside = DuoWorkspace.showPane(
    context,
    DuoPanePage(
      kind: DuoPaneKind.preview,
      productId: product.id,
      builder: (paneContext) => StoreScope(
        notifier: store,
        child: _QuickViewSheet(
          product: product,
          initialVariantIndex: initialVariantIndex,
          requireChoice: requireChoice,
          onVariantChanged: onVariantChanged,
          onRestock: onRestock,
          parentContext: paneContext,
          embedded: true,
        ),
      ),
    ),
  );
  if (shownBeside) return Future<void>.value();
  return showGeneralDialog<void>(
    context: context,
    anchorPoint: presentationAnchor(context),
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Cerrar vista previa',
    barrierColor: context.monettaColors.scrim,
    transitionDuration: reduceMotion(context) ? Duration.zero : kSnap,
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: kMotionCurve),
      child: child,
    ),
    pageBuilder: (dialogContext, _, __) => StoreScope(
      notifier: store,
      child: _QuickViewSheet(
        product: product,
        initialVariantIndex: initialVariantIndex,
        requireChoice: requireChoice,
        onVariantChanged: onVariantChanged,
        onRestock: onRestock,
        parentContext: context,
      ),
    ),
  ).whenComplete(() {
    if (originFocus?.context != null) originFocus!.requestFocus();
  });
}

class _QuickViewSheet extends StatefulWidget {
  const _QuickViewSheet({
    required this.product,
    required this.parentContext,
    this.initialVariantIndex = 0,
    this.requireChoice = false,
    this.embedded = false,
    this.onVariantChanged,
    this.onRestock,
  });

  final Product product;
  final BuildContext parentContext;
  final int initialVariantIndex;
  final ValueChanged<String?>? onVariantChanged;
  final ProductRestockAction? onRestock;

  /// The card as a page of a two-sided window's right side rather than a
  /// dialog: it stays after an add, and «×» returns that side to the bag.
  final bool embedded;

  /// Open with no option chosen so the shopper picks one explicitly (the "+"
  /// of a card with several variants).
  final bool requireChoice;

  @override
  State<_QuickViewSheet> createState() => _QuickViewSheetState();
}

class _QuickViewSheetState extends State<_QuickViewSheet> {
  late final PageController _gallery;

  /// The chosen option; null while the shopper still has to pick one.
  int? _variantIndex;
  int _page = 0;
  bool _adding = false;
  bool _added = false;
  String? _selectedId;
  bool _missingCombination = false;
  String? _error;

  Product? get _currentProduct => StoreScope.of(context)
      .products
      .where((p) => p.id == widget.product.id)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    _gallery = PageController();
    final selectable = selectableVariants(widget.product);
    if (widget.requireChoice && selectable.length > 1) {
      _variantIndex = null;
    } else {
      _variantIndex = (widget.initialVariantIndex >= 0 &&
              widget.initialVariantIndex < selectable.length)
          ? widget.initialVariantIndex
          : widget.initialVariantIndex < 0
              ? -1
              : 0;
      _selectedId = selectedVariant(widget.product, _variantIndex!)?.id;
    }
  }

  @override
  void dispose() {
    _gallery.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    setState(() => _page = index);
    if (reduceMotion(context)) {
      _gallery.jumpToPage(index);
    } else {
      _gallery.animateToPage(index, duration: kSwap, curve: kMotionCurve);
    }
  }

  Future<void> _addToBag() async {
    final index = _variantIndex;
    if (index == null || _adding) return;
    setState(() {
      _adding = true;
      _error = null;
      _added = false;
    });
    final product = _currentProduct;
    final currentIndex = product == null
        ? -1
        : variantIndexForId(product, _selectedId, fallback: -1);
    final result = product == null
        ? const BagAddResult(BagAddStatus.unavailable)
        : await tryAddSelectionToBag(context, product, currentIndex);
    if (!mounted) return;
    if (result.status != BagAddStatus.added) {
      // The sheet stays open and the choice is kept so the shopper can retry.
      setState(() {
        _adding = false;
        _error = switch (result.status) {
          BagAddStatus.soldOut => 'Esta opción está agotada.',
          BagAddStatus.unavailable =>
            'Esta pieza no está disponible por ahora.',
          _ => 'No pudimos agregar la pieza. Intenta de nuevo.',
        };
      });
      return;
    }
    NotificationScope.maybeOf(context)?.recordPushOutcome('add_to_cart');
    setState(() {
      _adding = false;
      _added = true;
    });
  }

  void _viewFullProduct() {
    final product = _currentProduct;
    if (product == null) return;
    final parent = widget.parentContext;
    final variantIndex = _variantIndex ?? 0;
    if (widget.embedded) {
      // The product replaces this card on the same side.
      openProduct(
        context,
        product,
        initialVariantIndex: variantIndex,
        initialVariantId: _selectedId,
      );
      return;
    }
    Navigator.of(context).pop();
    if (parent.mounted) {
      openProduct(
        parent,
        product,
        initialVariantIndex: variantIndex,
        initialVariantId: _selectedId,
      );
    }
  }

  /// The two page buttons, under the stock line. «Agregar al carrito» keeps its
  /// key and every state of the old bar (choose, restock, pending).
  Widget _buildActions(BoutiquePalette palette, {required bool inStock}) {
    final chosen = _variantIndex;
    final String label;
    final VoidCallback? onPressed;
    if (chosen == null) {
      label = _kChooseLabel;
      onPressed = null;
    } else if (!inStock) {
      label = 'Agotado';
      onPressed = null;
    } else {
      label = _adding ? 'Agregando…' : 'Agregar al carrito';
      onPressed = _currentProduct == null ? null : _addToBag;
    }
    return Column(
      key: const Key('quick-view-actions'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error case final message?) ...[
          Semantics(
            key: const Key('quick-view-error'),
            liveRegion: true,
            child: Text(
              message,
              style: boutiqueText(size: 13, color: palette.sale),
            ),
          ),
          const SizedBox(height: BoutiqueSpace.sm),
        ],
        if (inStock || chosen == null || chosen == -1)
          PurchaseDockButton(
            key: const Key('quick-view-primary'),
            label: label,
            pending: _adding,
            large: true,
            onPressed: onPressed,
          ),
        if (!inStock &&
            chosen != null &&
            chosen >= 0 &&
            widget.onRestock != null &&
            _currentProduct != null)
          TextButton(
            onPressed: () {
              final product = _currentProduct;
              final variant = product == null
                  ? null
                  : selectedVariant(
                      product,
                      variantIndexForId(product, _selectedId, fallback: -1),
                    );
              if (product != null && variant != null && !variant.available) {
                widget.onRestock!(product, variant);
              }
            },
            child: Text(
              'Avísame cuando vuelva',
              style: boutiqueText(color: palette.ink),
            ),
          ),
        if (_added)
          Semantics(liveRegion: true, child: const Text('Agregado al carrito')),
        if (_currentProduct == null)
          const Text('Este producto ya no está disponible.'),
        const SizedBox(height: BoutiqueSpace.sm),
        if (_currentProduct != null)
          PurchaseOutlineButton(
            key: const Key('quick-view-view-product'),
            label: 'Ver producto',
            textColor: palette.action,
            onPressed: _viewFullProduct,
          ),
      ],
    );
  }

  /// A back or close control over the photograph: no disc in the light theme
  /// (the photo is its ground); a surface disc in the dark theme, where the
  /// photograph keeps its white ground and a light glyph would vanish.
  Widget _photoControl({
    required Key key,
    required String tooltip,
    required IconData icon,
    required double size,
    required BoutiquePalette palette,
    VoidCallback? onPressed,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glyph = Icon(icon, size: size, color: palette.ink);
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      constraints: const BoxConstraints.tightFor(
        width: BoutiqueSpace.tapTarget,
        height: BoutiqueSpace.tapTarget,
      ),
      padding: EdgeInsets.zero,
      icon: dark
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surfaceDeep.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: Padding(padding: const EdgeInsets.all(6), child: glyph),
            )
          : glyph,
    );
  }

  Widget _buildPhoto(
    BoutiquePalette palette,
    List<String?> images, {
    required bool inStock,
  }) {
    final product = widget.product;
    return AspectRatio(
      aspectRatio: 6 / 5,
      child: ColoredBox(
        color: palette.surfaceDeep,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Read after the close button (UI v4.1 order).
            Semantics(
              container: true,
              sortKey: const OrdinalSortKey(1),
              child: PageView.builder(
                controller: _gallery,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Semantics(
                  // Read in place of the photograph; tapping it opens the PDP.
                  label: 'Foto ${i + 1} de ${images.length}',
                  hint: 'Abre el producto',
                  child: InkWell(
                    onTap: _viewFullProduct,
                    child: PackshotBlend(
                      ground: palette.surfaceDeep,
                      child: MonettaImage(
                        url: images[i],
                        fit: BoxFit.contain,
                        cacheWidth: MediaUrl.cardWidth,
                        fallbackLabel:
                            '${shopperProductName(product.title)} · Monetta',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!inStock)
              const Positioned(
                left: 8,
                bottom: 4,
                child: ProductSoldOutBadge(),
              ),
            Positioned(
              top: BoutiqueSpace.xs,
              right: BoutiqueSpace.xs,
              child: Semantics(
                // The close button is read first (UI v4.1 order).
                container: true,
                sortKey: const OrdinalSortKey(0),
                child: _photoControl(
                  key: const Key('quick-view-close'),
                  tooltip: 'Cerrar vista previa',
                  icon: Icons.close,
                  size: 24,
                  palette: palette,
                  onPressed: widget.embedded
                      ? () => DuoWorkspace.showBag(context)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Up to four equal square thumbnails; none for a single photograph.
  Widget _buildThumbnails(BoutiquePalette palette, List<String?> images) {
    const gap = BoutiqueSpace.sm;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.maxWidth - gap * 3) / 4;
        final shown = math.min(images.length, 4);
        return Row(
          children: [
            for (var i = 0; i < shown; i++)
              Padding(
                padding: EdgeInsets.only(right: i == shown - 1 ? 0 : gap),
                child: Semantics(
                  button: true,
                  selected: i == _page,
                  label: 'Foto ${i + 1} de ${images.length}',
                  child: InkWell(
                    onTap: () => _goToPage(i),
                    child: Container(
                      key: ValueKey('thumb-$i'),
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        color: palette.surfaceDeep,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: i == _page
                              ? palette.borderControl
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4.5),
                        child: PackshotBlend(
                          ground: palette.surfaceDeep,
                          child: MonettaImage(
                            url: images[i],
                            fit: BoxFit.contain,
                            cacheWidth: MediaUrl.thumbWidth,
                            fallbackLabel: widget.product.title,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPrice(
    BoutiquePalette palette, {
    required double price,
    required double? compare,
    required bool onSale,
    required int discount,
    required bool inStock,
  }) {
    return Wrap(
      spacing: BoutiqueSpace.sm,
      runSpacing: BoutiqueSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          formatShopperPrice(price),
          key: const Key('quick-view-price'),
          style: boutiqueText(
            size: 21,
            weight: FontWeight.w600,
            color: inStock ? palette.ink : palette.inkMuted,
            height: 1.2,
          ),
        ),
        // Same rule as the ficha: previous price and -% only off real
        // compare_at data.
        if (onSale && compare != null) ...[
          Text(
            formatShopperPrice(compare),
            style: boutiqueText(
              size: 14,
              color: palette.inkMuted,
              height: 1.2,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          if (discount > 0)
            Container(
              key: const ValueKey('discount-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: palette.saleSurface,
                borderRadius: BoutiqueRadius.capsule,
              ),
              child: Text(
                '-$discount%',
                style: boutiqueText(
                  size: 13,
                  weight: FontWeight.w500,
                  color: palette.sale,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// «Stock» and its pill. Availability is factual (`available` bool);
  /// low-stock urgency («Últimas piezas») needs a quantity the catalog does
  /// not carry, so it is deliberately never rendered here.
  Widget _buildStock(BoutiquePalette palette, {required bool inStock}) {
    return Wrap(
      spacing: BoutiqueSpace.md,
      runSpacing: BoutiqueSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Stock',
          style: boutiqueText(size: 15, color: palette.ink, height: 1.3),
        ),
        Container(
          key: const Key('quick-view-stock'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: inStock ? palette.surfaceDeep : palette.saleSurface,
            borderRadius: BoutiqueRadius.capsule,
          ),
          child: Text(
            inStock ? 'Disponible' : 'Agotado',
            style: boutiqueText(
              size: 14,
              color: inStock ? palette.ink : palette.sale,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final currentProduct = _currentProduct;
    final product = currentProduct ?? widget.product;
    final facets = store.facetsFor(product.id);
    if (_selectedId != null && !_missingCombination) {
      _variantIndex = variantIndexForId(product, _selectedId);
    }
    final chosen = _variantIndex;
    // Until an option is chosen the card shows the piece's own price and no
    // sale or availability claim: those belong to one variant.
    final price =
        chosen == null ? product.price : selectionPrice(product, chosen);
    final compare = chosen == null ? null : selectionCompareAt(product, chosen);
    final onSale = chosen != null && selectionOnSale(product, chosen);
    final discount =
        chosen == null ? 0 : selectionDiscountPercent(product, chosen);
    final inStock = currentProduct != null &&
        (chosen == null || selectionInStock(product, chosen));
    final memberImages = chosen == null
        ? const <String>[]
        : imagesForVariant(product, selectedVariant(product, chosen));
    final images = memberImages.isEmpty ? <String?>[null] : memberImages;

    final media = MediaQuery.of(context);
    final screen = media.size;
    // On a two-sided window's right side the card takes that side's width.
    final cardWidth = widget.embedded
        ? math.max(0.0, screen.width - 2 * BoutiqueSpace.lg)
        : math.max(
            0.0,
            math.min(
              math.min(screen.width * _kCardWidthFactor, _kCardMaxWidth),
              screen.width - 2 * _kCardSideMargin,
            ),
          );
    // The card never leaves the safe area nor the keyboard: whatever does not
    // fit scrolls inside it. A phone with the keyboard up reports no bottom
    // padding, so the larger of the two is the bottom edge.
    final bottomEdge = math.max(media.padding.bottom, media.viewInsets.bottom);

    final card = Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        media.padding.top + BoutiqueSpace.lg,
        0,
        bottomEdge + BoutiqueSpace.lg,
      ),
      child: Align(
        alignment: widget.embedded ? Alignment.topCenter : Alignment.center,
        child: SizedBox(
          width: cardWidth,
          child: Material(
            key: const Key('quick-view-card'),
            color: palette.canvas,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius:
                  const BorderRadius.all(Radius.circular(_kCardRadius)),
              // On the canvas of the right side the card needs an edge.
              side: widget.embedded
                  ? BorderSide(color: palette.hairline)
                  : BorderSide.none,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPhoto(palette, images, inStock: inStock),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      BoutiqueSpace.lg,
                      BoutiqueSpace.md,
                      BoutiqueSpace.lg,
                      BoutiqueSpace.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (images.length > 1) ...[
                          _buildThumbnails(palette, images),
                          const SizedBox(height: BoutiqueSpace.md),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: ProductFavoriteButton(
                            selected: store.wishlist.contains(product.id),
                            onPressed: () => store.toggleWishlist(product.id),
                          ),
                        ),
                        if (facets?.brand != null)
                          Text(
                            brandLabel(facets!.brand!.value),
                            key: const Key('quick-view-brand'),
                            style: boutiqueText(
                              size: 18,
                              weight: FontWeight.w600,
                              color: palette.ink,
                            ),
                          ),
                        const SizedBox(height: BoutiqueSpace.xs),
                        Text(
                          shopperProductName(product.title),
                          key: const Key('quick-view-name'),
                          style: boutiqueText(
                            size: 15,
                            color: palette.ink,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: BoutiqueSpace.md),
                        _buildPrice(
                          palette,
                          price: price,
                          compare: compare,
                          onSale: onSale,
                          discount: discount,
                          inStock: inStock,
                        ),
                        if (selectableVariants(product).isNotEmpty) ...[
                          const SizedBox(height: BoutiqueSpace.lg),
                          if (chosen == null) ...[
                            Text(
                              _kChooseLabel,
                              key: const Key('quick-view-choose-hint'),
                              style: boutiqueText(
                                size: 14,
                                weight: FontWeight.w600,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: BoutiqueSpace.sm),
                          ],
                          ProductOptionSelector(
                            product: product,
                            selectedIndex: chosen,
                            colorHeading: 'Colores',
                            showSelectedName: true,
                            onSelect: (i) {
                              if (_adding) return;
                              setState(() {
                                _variantIndex = i;
                                _missingCombination = i < 0;
                                _selectedId = selectedVariant(product, i)?.id;
                                widget.onVariantChanged?.call(_selectedId);
                                _page = 0;
                                if (_gallery.hasClients) _gallery.jumpToPage(0);
                                _added = false;
                                _error = null;
                              });
                            },
                          ),
                        ],
                        if (chosen != null) ...[
                          const SizedBox(height: BoutiqueSpace.sm),
                          _buildStock(palette, inStock: inStock),
                        ],
                        const SizedBox(height: BoutiqueSpace.lg),
                        _buildActions(palette, inStock: inStock),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!widget.embedded) {
      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).pop(),
        },
        child: Focus(autofocus: true, child: card),
      );
    }
    return Scaffold(
      key: const Key('duo-preview'),
      backgroundColor: palette.canvas,
      body: card,
    );
  }
}
