/// Quick-view Fig.06 — vista previa centrada sobre la pantalla atenuada.
///
/// Una tarjeta centrada (≈ 79 % del ancho, máximo 440) con «‹» y «×» sobre la
/// foto, fila de miniaturas, marca–nombre–precio (con anterior y `-%` solo con
/// dato real), colores con la misma [ProductOptionSelector] de la ficha,
/// «Stock» (Disponible o Agotado) — **sin** línea de `Últimas piezas`: el
/// catálogo no trae cantidades, solo `available`, y la urgencia nunca se
/// fabrica —, y «AGREGAR A BOLSA» + «VER PRODUCTO» con la misma selección y el
/// mismo add-to-bag de la ficha ([tryAddSelectionToBag]). Si no cabe (texto
/// grande, pantallas bajas) el contenido de la tarjeta se desplaza por dentro.
///
/// No toca `product_card.dart` (dueño B): esa tarjeta ya expone `onQuickView`
/// como callback opcional. Cualquier tarjeta la abre con:
///
/// ```dart
/// ProductCard(
///   product: product,
///   onQuickView: () => showProductQuickView(context, product),
/// )
/// ```
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

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
import '../checkout/mini_cart.dart';
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
}) {
  final store = StoreScope.of(context);
  store.record(EventType.galleryInteraction, productId: product.id);
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
        parentContext: context,
      ),
    ),
  );
}

class _QuickViewSheet extends StatefulWidget {
  const _QuickViewSheet({
    required this.product,
    required this.parentContext,
    this.initialVariantIndex = 0,
    this.requireChoice = false,
  });

  final Product product;
  final BuildContext parentContext;
  final int initialVariantIndex;

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
  String? _error;

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
          : 0;
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
    final parent = widget.parentContext;
    setState(() {
      _adding = true;
      _error = null;
    });
    final result = await tryAddSelectionToBag(context, widget.product, index);
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
    Navigator.of(context).pop();
    // Same confirmation as the ficha — one modal at a time.
    if (parent.mounted) {
      await showMiniCart(parent);
    }
  }

  void _viewFullProduct() {
    final product = widget.product;
    final parent = widget.parentContext;
    final variantIndex = _variantIndex ?? 0;
    Navigator.of(context).pop();
    if (parent.mounted) {
      openProduct(parent, product, initialVariantIndex: variantIndex);
    }
  }

  Future<void> _requestRestock(Product product) async {
    final notifications = NotificationScope.maybeOf(context);
    if (notifications == null || !notifications.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los avisos todavía no están disponibles en esta versión.',
          ),
        ),
      );
      return;
    }
    final ok = await notifications.createRestockAlert(product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Te avisaremos cuando esta pieza vuelva.'
              : notifications.lastError ?? 'No pudimos crear el aviso.',
        ),
      ),
    );
  }

  /// The two page buttons, under the stock line. «AGREGAR A BOLSA» keeps its
  /// key and every state of the old bar (choose, restock, pending).
  Widget _buildActions(BoutiquePalette palette, {required bool inStock}) {
    final chosen = _variantIndex;
    final String label;
    final VoidCallback? onPressed;
    if (chosen == null) {
      label = _kChooseLabel;
      onPressed = null;
    } else if (!inStock) {
      label = 'Avísame cuando vuelva';
      onPressed = () => _requestRestock(widget.product);
    } else {
      label = _adding ? 'AGREGANDO…' : 'AGREGAR A BOLSA';
      onPressed = _addToBag;
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
        PurchaseDockButton(
          key: const Key('quick-view-primary'),
          label: label,
          pending: _adding,
          large: true,
          onPressed: onPressed,
        ),
        const SizedBox(height: BoutiqueSpace.sm),
        PurchaseOutlineButton(
          key: const Key('quick-view-view-product'),
          label: 'VER PRODUCTO',
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
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final glyph = Icon(icon, size: size, color: palette.ink);
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: () => Navigator.of(context).pop(),
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
            PageView.builder(
              controller: _gallery,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => PackshotBlend(
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
            if (!inStock)
              IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BoutiqueSpace.lg,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.canvas,
                      borderRadius: BoutiqueRadius.capsule,
                      border: Border.all(color: palette.ink, width: 1),
                    ),
                    child: Text(
                      'AGOTADO',
                      style: boutiqueEyebrow(size: 11, color: palette.ink),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: BoutiqueSpace.xs,
              left: BoutiqueSpace.xs,
              child: _photoControl(
                key: const Key('quick-view-back'),
                tooltip: 'Regresar',
                icon: Icons.chevron_left,
                size: 30,
                palette: palette,
              ),
            ),
            Positioned(
              top: BoutiqueSpace.xs,
              right: BoutiqueSpace.xs,
              child: _photoControl(
                key: const Key('quick-view-close'),
                tooltip: 'Cerrar vista previa',
                icon: Icons.close,
                size: 24,
                palette: palette,
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
                  child: GestureDetector(
                    onTap: () => _goToPage(i),
                    behavior: HitTestBehavior.opaque,
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
    final product = widget.product;
    final store = StoreScope.of(context);
    final facets = store.facetsFor(product.id);
    final chosen = _variantIndex;
    // Until an option is chosen the card shows the piece's own price and no
    // sale or availability claim: those belong to one variant.
    final price =
        chosen == null ? product.price : selectionPrice(product, chosen);
    final compare = chosen == null ? null : selectionCompareAt(product, chosen);
    final onSale = chosen != null && selectionOnSale(product, chosen);
    final discount =
        chosen == null ? 0 : selectionDiscountPercent(product, chosen);
    final inStock = chosen == null || selectionInStock(product, chosen);
    final images = product.images.isEmpty ? <String?>[null] : product.images;

    final media = MediaQuery.of(context);
    final screen = media.size;
    final cardWidth = math.max(
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

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        media.padding.top + BoutiqueSpace.lg,
        0,
        bottomEdge + BoutiqueSpace.lg,
      ),
      child: Center(
        child: SizedBox(
          width: cardWidth,
          child: Material(
            key: const Key('quick-view-card'),
            color: palette.canvas,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(_kCardRadius)),
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
                        if (facets?.brand != null)
                          Text(
                            brandLabel(facets!.brand!.value),
                            key: const Key('quick-view-brand'),
                            style: boutiqueDisplay(
                              22,
                              weight: FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                        const SizedBox(height: BoutiqueSpace.xs),
                        Text(
                          shopperProductName(product.title),
                          key: const Key('quick-view-name'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                            showSelectedName: false,
                            onSelect: (i) => setState(() {
                              _variantIndex = i;
                              _error = null;
                            }),
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
  }
}
