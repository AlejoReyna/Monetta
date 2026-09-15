/// Quick-view Fig.06 — vista rápida sobre la tarjeta.
///
/// Sheet arrastrable con cerrar X; imagen contenida + miniaturas;
/// marca–nombre–precio (con anterior y `-%` solo con dato real); colores con
/// la misma [ProductOptionSelector] de la ficha; **sin** línea de
/// `Últimas piezas` — el catálogo no trae cantidades, solo `available`, y la
/// urgencia nunca se fabrica; Agregar bolsa + Ver producto con la misma
/// selección y el mismo add-to-bag de la ficha ([addSelectionToBag]).
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

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/product.dart';
import '../../main.dart';
import '../../reco/events.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../checkout/mini_cart.dart';
import 'product_selection.dart';

/// Opens the quick-view for [product] without leaving the current surface.
Future<void> showProductQuickView(
  BuildContext context,
  Product product, {
  int initialVariantIndex = 0,
}) {
  final store = StoreScope.of(context);
  store.record(EventType.galleryInteraction, productId: product.id);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StoreScope(
      notifier: store,
      child: _QuickViewSheet(
        product: product,
        initialVariantIndex: initialVariantIndex,
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
  });

  final Product product;
  final BuildContext parentContext;
  final int initialVariantIndex;

  @override
  State<_QuickViewSheet> createState() => _QuickViewSheetState();
}

class _QuickViewSheetState extends State<_QuickViewSheet> {
  late final PageController _gallery;
  late int _variantIndex;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _gallery = PageController();
    final selectable = selectableVariants(widget.product);
    _variantIndex = (widget.initialVariantIndex >= 0 &&
            widget.initialVariantIndex < selectable.length)
        ? widget.initialVariantIndex
        : 0;
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
    final parent = widget.parentContext;
    await addSelectionToBag(context, widget.product, _variantIndex);
    if (!mounted) return;
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
    final variantIndex = _variantIndex;
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
          content:
              Text('Los avisos todavía no están disponibles en esta versión.'),
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

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final product = widget.product;
    final store = StoreScope.of(context);
    final facets = store.facetsFor(product.id);
    final price = selectionPrice(product, _variantIndex);
    final compare = selectionCompareAt(product, _variantIndex);
    final onSale = selectionOnSale(product, _variantIndex);
    final discount = selectionDiscountPercent(product, _variantIndex);
    final inStock = selectionInStock(product, _variantIndex);
    final images = product.images.isEmpty ? <String?>[null] : product.images;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.canvas,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: BoutiqueSpace.sm),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.hairline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Cerrar vista rápida',
                    icon: const Icon(Icons.close, size: 20),
                    color: palette.ink,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      BoutiqueSpace.gutter,
                      0,
                      BoutiqueSpace.gutter,
                      BoutiqueSpace.md,
                    ),
                    children: [
                      ClipRRect(
                        borderRadius: BoutiqueRadius.card,
                        child: ColoredBox(
                          color: palette.surfaceDeep,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                PageView.builder(
                                  controller: _gallery,
                                  itemCount: images.length,
                                  onPageChanged: (i) =>
                                      setState(() => _page = i),
                                  itemBuilder: (_, i) => Padding(
                                    padding:
                                        const EdgeInsets.all(BoutiqueSpace.sm),
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
                                          border: Border.all(
                                            color: palette.ink,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          'AGOTADO',
                                          style: boutiqueEyebrow(
                                            size: 11,
                                            color: palette.ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (images.length > 1)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: BoutiqueSpace.sm,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children:
                                          List.generate(images.length, (i) {
                                        final on = i == _page;
                                        return AnimatedContainer(
                                          duration: reduceMotion(context)
                                              ? Duration.zero
                                              : kSnap,
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                          ),
                                          width: on ? 22 : 12,
                                          height: 2,
                                          decoration: BoxDecoration(
                                            color: on
                                                ? palette.ink
                                                : palette.ink
                                                    .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (images.length > 1) ...[
                        const SizedBox(height: BoutiqueSpace.sm),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < images.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(
                                    right: i == images.length - 1
                                        ? 0
                                        : BoutiqueSpace.sm,
                                  ),
                                  child: GestureDetector(
                                    onTap: () => _goToPage(i),
                                    behavior: HitTestBehavior.opaque,
                                    child: Semantics(
                                      button: true,
                                      selected: i == _page,
                                      label:
                                          'Foto ${i + 1} de ${images.length}',
                                      child: Container(
                                        key: ValueKey('thumb-$i'),
                                        width: 48,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: palette.surface,
                                          borderRadius: BoutiqueRadius.tile,
                                          border: Border.all(
                                            color: i == _page
                                                ? palette.ink
                                                : palette.hairline,
                                            width: i == _page ? 1.5 : 1,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BoutiqueRadius.tile,
                                          child: MonettaImage(
                                            url: images[i],
                                            fit: BoxFit.contain,
                                            cacheWidth: MediaUrl.thumbWidth,
                                            fallbackLabel: product.title,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: BoutiqueSpace.lg),
                      if (facets?.brand != null)
                        Text(
                          brandLabel(facets!.brand!.value).toUpperCase(),
                          style: boutiqueEyebrow(
                            size: 11,
                            color: palette.inkMuted,
                          ),
                        ),
                      if (facets?.brand != null)
                        const SizedBox(height: BoutiqueSpace.xs),
                      Text(
                        shopperProductName(product.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: boutiqueDisplay(20, color: palette.ink),
                      ),
                      const SizedBox(height: BoutiqueSpace.sm),
                      Wrap(
                        spacing: BoutiqueSpace.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            kMoney.format(price),
                            style: boutiqueText(
                              size: 18,
                              weight: FontWeight.w700,
                              color: inStock ? palette.ink : palette.inkMuted,
                            ),
                          ),
                          // Same rule as the ficha: previous price and
                          // -% only off real compare_at data.
                          if (onSale && compare != null) ...[
                            Text(
                              kMoney.format(compare),
                              style: boutiqueText(
                                size: 13,
                                color: palette.inkMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            if (discount > 0)
                              Container(
                                key: const ValueKey('discount-badge'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.sale,
                                  borderRadius: BoutiqueRadius.capsule,
                                ),
                                child: Text(
                                  '-$discount%',
                                  style: boutiqueEyebrow(
                                    size: 11,
                                    color: const Color(0xFFFFFFFF),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: BoutiqueSpace.sm),
                      // Availability is factual (`available` bool).
                      // Low-stock urgency ("Últimas piezas") needs a
                      // quantity the catalog does not carry, so it is
                      // deliberately never rendered here.
                      Text(
                        inStock
                            ? 'Disponible · envío 3 a 5 días'
                            : 'Agotado · te avisamos cuando vuelva',
                        style: boutiqueText(size: 12, color: palette.inkMuted),
                      ),
                      if (selectableVariants(product).isNotEmpty) ...[
                        const SizedBox(height: BoutiqueSpace.lg),
                        ProductOptionSelector(
                          product: product,
                          selectedIndex: _variantIndex,
                          onSelect: (i) => setState(() => _variantIndex = i),
                        ),
                      ],
                      const SizedBox(height: BoutiqueSpace.xl),
                      if (inStock)
                        BoutiqueButton(
                          label: 'AGREGAR A LA BOLSA',
                          onPressed: _addToBag,
                        )
                      else
                        BoutiqueButton(
                          label: 'AVÍSAME CUANDO VUELVA',
                          onPressed: () => _requestRestock(product),
                        ),
                      const SizedBox(height: BoutiqueSpace.sm),
                      BoutiqueButton(
                        label: 'VER PRODUCTO',
                        onPressed: _viewFullProduct,
                        filled: false,
                      ),
                      const SizedBox(height: BoutiqueSpace.sm),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
