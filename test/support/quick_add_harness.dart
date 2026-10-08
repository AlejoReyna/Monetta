import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/normalize/facets.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/features/product/quick_view.dart';

import 'product_screen_harness.dart';
import 'scripted_catalog_store.dart';

/// Shared scaffolding for the quick-add ("+") and quick-view tests
/// (FICHA-T3): keys of the contract (BRIEF 2.6), card and grid hosts wired the
/// way the real surfaces wire them, and the semantics helpers.
///
/// Nothing here reads a clock or the network. Sold-out and multi-variant
/// scenarios are synthetic [Product]s because the bundled catalog has no fully
/// sold-out piece (BRIEF 6).

// ---------------------------------------------------------------------------
// Keys and copy of the contract
// ---------------------------------------------------------------------------

Key quickAddKey(String productId) => Key('quick-add-$productId');
const Key kQuickViewActionsKey = Key('quick-view-actions');
const Key kQuickViewPrimaryKey = Key('quick-view-primary');
const Key kQuickViewViewProductKey = Key('quick-view-view-product');
const Key kQuickViewErrorKey = Key('quick-view-error');

const String kAddLabel = 'Agregar al carrito';
const String kPendingLabel = 'Agregando…';
const String kChooseLabel = 'Elige una opción';
const String kRestockLabel = 'Avísame cuando vuelva';
const String kViewProductLabel = 'Ver producto';
const String kAddFailureMessage =
    'No pudimos agregar la pieza. Intenta de nuevo.';
const String kQuickViewTooltip = 'Vista rápida';
const String kCloseQuickViewTooltip = 'Cerrar vista rápida';

// ---------------------------------------------------------------------------
// Stores and products
// ---------------------------------------------------------------------------

Future<ScriptedCatalogStore> scriptedStore() =>
    loadStore(ScriptedCatalogStore(database: openTestDatabase()));

/// Three colour variants that all map to a reliable swatch (`Negro`, `Rojo`,
/// `Azul`), so the selector renders swatches. Prices differ per variant.
Product swatchProduct({
  String id = 'gid://shopify/Product/9101',
  String title = 'Bolsa de colores',
  List<bool> available = const [true, true, true],
}) {
  const titles = ['Negro', 'Rojo', 'Azul'];
  final tail = id.split('/').last;
  return syntheticProduct(
    id: id,
    title: title,
    variants: [
      for (var i = 0; i < 3; i++)
        syntheticVariant(
          id: 'v-$tail-${titles[i].toLowerCase()}',
          title: titles[i],
          price: 1500.0 + i * 100,
          available: available[i],
        ),
    ],
  );
}

/// Three text-chip variants (no reliable colour word).
Product chipProduct({
  String id = 'gid://shopify/Product/9102',
  String title = 'Bolsa de tallas',
  List<bool> available = const [true, true, true],
}) =>
    syntheticProduct(
      id: id,
      title: title,
      variants: chipVariants(available: available),
    );

/// A piece with exactly one selectable (non-default) variant.
Product singleNamedVariantProduct({
  String id = 'gid://shopify/Product/9103',
  String title = 'Bolsa negra',
}) =>
    syntheticProduct(
      id: id,
      title: title,
      variants: [
        syntheticVariant(
          id: 'v-negro-unica',
          title: 'Negro',
          price: 1850,
        ),
      ],
    );

Product soldOutProduct({
  String id = 'gid://shopify/Product/9104',
  String title = 'Bolsa agotada',
}) =>
    syntheticProduct(
      id: id,
      title: title,
      variants: [
        syntheticVariant(
          id: 'v-agotada-${id.split('/').last}',
          available: false,
        ),
      ],
    );

/// The shopper-facing title the card prints for [product] (and the one the
/// accessible label of the "+" must carry).
String cardTitle(CatalogStore store, Product product) =>
    ProductTileData.fromProduct(
      product,
      facets: store.facetsFor(product.id),
    ).title;

String addLabelFor(CatalogStore store, Product product) =>
    'Agregar ${cardTitle(store, product)} al carrito';

/// First bundled piece with several swatch-friendly variants, all available.
Product reliableAssetProduct(CatalogStore store) => store.products.firstWhere(
      (p) =>
          hasReliableColorOptions(p) &&
          selectableVariants(p).length > 1 &&
          p.variants.every((v) => v.available),
    );

/// First bundled piece with several text-chip variants, all available.
Product chipAssetProduct(CatalogStore store) => store.products.firstWhere(
      (p) =>
          selectableVariants(p).length > 1 &&
          !hasReliableColorOptions(p) &&
          p.variants.every((v) => v.available),
    );

/// First bundled piece with several variants, some sold out, still in stock.
Product partialAssetProduct(CatalogStore store) => store.products.firstWhere(
      (p) =>
          selectableVariants(p).length > 1 &&
          p.variants.any((v) => !v.available) &&
          p.isInStock,
    );

// ---------------------------------------------------------------------------
// Opening the quick view
// ---------------------------------------------------------------------------

/// `showProductQuickView`, optionally asking the shopper to choose an option
/// (the way the "+" of a card with several variants opens it).
Future<void> openQuickView(
  BuildContext context,
  Product product, {
  bool requireChoice = false,
}) =>
    showProductQuickView(context, product, requireChoice: requireChoice);

// ---------------------------------------------------------------------------
// Hosts
// ---------------------------------------------------------------------------

Key cardKey(Product product) => ValueKey('product-card-${product.id}');

/// One [ProductCard] wired like the real surfaces: [onQuickView] defaults to
/// opening the quick view; pass [wireQuickView] false for a surface without it.
Widget cardApp(
  CatalogStore store,
  Product product, {
  double width = 200,
  double scale = 1.0,
  VoidCallback? onQuickView,
  bool wireQuickView = true,
}) =>
    fichaApp(
      store,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: Builder(
              builder: (context) => ProductCard(
                key: cardKey(product),
                product: product,
                onQuickView: onQuickView ??
                    (wireQuickView
                        ? () => openQuickView(context, product)
                        : null),
              ),
            ),
          ),
        ),
      ),
      scale: scale,
    );

/// A [ProductCardGrid] with the quick view wired, as search and the brand
/// page wire it.
Widget gridApp(
  CatalogStore store,
  List<Product> products, {
  double scale = 1.0,
}) =>
    fichaApp(
      store,
      Scaffold(
        body: Builder(
          builder: (context) => ProductCardGrid(
            products: products,
            padding: const EdgeInsets.all(16),
            onQuickView: (product) => openQuickView(context, product),
          ),
        ),
      ),
      scale: scale,
    );

/// [CatalogBrowseScreen] with the store above it, or without when [store] is
/// null (the browse screen must degrade gracefully). Facets default to the
/// store's own.
Widget catalogApp(
  CatalogStore? store,
  List<Product> products, {
  Map<String, CanonicalFacets>? facetsById,
  double scale = 1.0,
}) {
  final screen = CatalogBrowseScreen(
    products: products,
    facetsById: facetsById ?? store?.facetsById ?? const {},
  );
  return store == null
      ? externalApp(screen, scale: scale)
      : fichaApp(store, screen, scale: scale);
}

/// A host with one button that opens the quick view of [product].
Widget quickViewApp(
  CatalogStore store,
  Product product, {
  double scale = 1.0,
  bool requireChoice = false,
}) =>
    fichaApp(
      store,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => openQuickView(
                context,
                product,
                requireChoice: requireChoice,
              ),
              child: const Text('ABRIR'),
            ),
          ),
        ),
      ),
      scale: scale,
    );

/// Mounts [quickViewApp] and opens the sheet.
Future<void> pumpQuickView(
  WidgetTester tester,
  CatalogStore store,
  Product product, {
  double scale = 1.0,
  bool requireChoice = false,
}) async {
  await tester.pumpWidget(
    quickViewApp(store, product, scale: scale, requireChoice: requireChoice),
  );
  await tester.pump();
  await tester.tap(find.text('ABRIR'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Finders and measurements
// ---------------------------------------------------------------------------

Finder quickAddOf(Product product) => find.byKey(quickAddKey(product.id));

/// Taps the "+" of [product], failing with a readable reason when the card
/// has none.
Future<void> tapQuickAdd(WidgetTester tester, Product product) async {
  expect(
    quickAddOf(product),
    findsOneWidget,
    reason: 'the card of "${product.title}" has a "+"',
  );
  await tester.tap(quickAddOf(product));
}

/// The caption name of the card of [product] (the photo fallback prints the
/// title too, so the caption is the last match inside the card).
Finder cardName(CatalogStore store, Product product) => find
    .descendant(
      of: find.byKey(cardKey(product)),
      matching: find.text(cardTitle(store, product)),
    )
    .last;

Finder primaryButton() => find.byKey(kQuickViewPrimaryKey);

Finder actionsBar() => find.byKey(kQuickViewActionsKey);

Finder inPrimary(Finder matching) =>
    find.descendant(of: primaryButton(), matching: matching);

Finder quickViewSheet() => find.byType(DraggableScrollableSheet);

Finder inSheet(Finder matching) =>
    find.descendant(of: quickViewSheet(), matching: matching);

/// Check marks the option selector draws on the selected option.
Finder selectionMarks() => find.descendant(
      of: find.byType(ProductOptionSelector),
      matching: find.byIcon(Icons.check),
    );

Finder _swatch(String variantTitle) => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.startsWith('Color $variantTitle') ?? false),
    );

/// The tappable option of [variant]: its swatch or its text chip.
Finder optionOf(Product product, ProductVariant variant) =>
    hasReliableColorOptions(product)
        ? _swatch(variant.title).first
        : optionChip(variant.title);

/// Brings [target] into view inside the quick view's scrolling list. The list
/// is lazy, so a far child may not exist yet: scroll until it is built.
Future<void> revealInSheet(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .descendant(of: quickViewSheet(), matching: find.byType(Scrollable))
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pump();
}

/// Scrolls the sheet to [variant] and taps it.
Future<void> pickVariant(
  WidgetTester tester,
  Product product,
  ProductVariant variant,
) async {
  final target = optionOf(product, variant);
  await revealInSheet(tester, target);
  await tester.tap(target);
  await tester.pump();
}

/// Rect of the photograph of the tile that contains [inside].
Rect photoRectOf(WidgetTester tester, Finder inside) {
  final tile = find.ancestor(
    of: inside,
    matching: find.byType(MonettaProductTile),
  );
  expect(tile, findsOneWidget, reason: 'the control sits inside one tile');
  return tester.getRect(
    find.descendant(of: tile, matching: find.byType(AspectRatio)).first,
  );
}

/// The heart ("Guardar") of the tile that contains [inside]; null on a
/// surface that draws none (the full catalog).
Rect? heartRectOf(WidgetTester tester, Finder inside) {
  final tile = find.ancestor(
    of: inside,
    matching: find.byType(MonettaProductTile),
  );
  final heart = find.descendant(of: tile, matching: find.byTooltip('Guardar'));
  return heart.evaluate().isEmpty ? null : tester.getRect(heart.first);
}

/// A "+" zone of at least 48x48 that lies entirely inside the photograph.
void expectQuickAddFitsPhoto(WidgetTester tester, Finder control) {
  expect(control, findsOneWidget);
  final zone = tester.getRect(control);
  final photo = photoRectOf(tester, control);
  expect(zone.width, greaterThanOrEqualTo(48 - 0.01), reason: 'width');
  expect(zone.height, greaterThanOrEqualTo(48 - 0.01), reason: 'height');
  expect(
    photo.inflate(0.01).contains(zone.topLeft) &&
        photo.inflate(0.01).contains(zone.bottomRight),
    isTrue,
    reason: 'zone $zone inside the photo $photo',
  );
}

/// Asserts the contract of the "+" geometry: a tappable zone of at least
/// 48x48, fully inside the photograph, pinned to its lower right corner and
/// clear of the heart.
void expectQuickAddGeometry(WidgetTester tester, Finder control) {
  expectQuickAddFitsPhoto(tester, control);
  final zone = tester.getRect(control);
  final photo = photoRectOf(tester, control);
  expect(
    zone.center.dx,
    greaterThan(photo.left + photo.width * 0.75),
    reason: 'right quarter of the photo',
  );
  expect(
    zone.center.dy,
    greaterThan(photo.top + photo.height * 0.75),
    reason: 'bottom quarter of the photo',
  );
  final heart = heartRectOf(tester, control);
  if (heart != null) {
    expect(zone.overlaps(heart), isFalse, reason: 'clear of the heart $heart');
  }
}

// ---------------------------------------------------------------------------
// Semantics
// ---------------------------------------------------------------------------

Tristate enabledStateOf(WidgetTester tester, Finder control) =>
    tester.getSemantics(control).getSemanticsData().flagsCollection.isEnabled;

bool isButtonNode(WidgetTester tester, Finder control) =>
    tester.getSemantics(control).getSemanticsData().flagsCollection.isButton;

/// True unless the control announces itself as disabled.
bool isEnabledControl(WidgetTester tester, Finder control) =>
    enabledStateOf(tester, control) != Tristate.isFalse;

// ---------------------------------------------------------------------------
// Flow helpers
// ---------------------------------------------------------------------------

/// Settles the tree and lets any short confirmation timer elapse, so no timer
/// is left pending when the test body ends.
Future<void> flush(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
}

/// Closes the mini cart by tapping the barrier above the sheet.
Future<void> dismissMiniCart(WidgetTester tester) async {
  await tester.tapAt(const Offset(8, 40));
  await tester.pumpAndSettle();
}
