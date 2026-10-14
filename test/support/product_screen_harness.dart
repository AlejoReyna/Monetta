import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/main.dart';

/// Shared scaffolding for the ficha tests (FICHA-T2): keys of the contract
/// (BRIEF 2.4 / 2.5), a fixed phone view, synthetic products, the lazy-list
/// scrolling helpers and the platform-channel mocks.
///
/// Nothing here reads a clock or the network. The catalog is the bundled
/// asset; sold-out and long-name scenarios are synthetic [Product]s because
/// the asset has no fully sold-out piece.

// ---------------------------------------------------------------------------
// Keys of the contract
// ---------------------------------------------------------------------------

const Key kHeaderTitleKey = Key('product-header-title');
const Key kHeaderBackKey = Key('product-header-back');
const Key kHeaderFavoriteKey = Key('product-gallery-favorite');
const Key kDockKey = Key('purchase-dock');
const Key kDockPrimaryKey = Key('purchase-dock-primary');
const Key kRestockKey = ValueKey<String>('create-restock-alert');
const Key kPurchaseSectionKey = Key('purchase-section');
const Key kBuyNowKey = Key('purchase-buy-now');
const Key kApartarKey = Key('purchase-apartar');

/// Name used by the long-title scenarios: well past the 90 characters the
/// brief asks for, with no consecutive repeated word (the presentation
/// collapses those).
const String kLongProductName =
    'Bolsa satchel estructurada de piel con asa superior desmontable correa '
    'ajustable herrajes dorados y forro interior de microfibra edición especial';

/// Phone viewport used everywhere unless a test overrides it.
const double kPhoneHeight = 844;

// ---------------------------------------------------------------------------
// Platform mocks
// ---------------------------------------------------------------------------

/// `CachedNetworkImage` (through `MonettaImage`) asks `path_provider` for a
/// directory; without a plugin the first test of a process fails at random.
void mockPathProvider() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '/tmp',
  );
}

/// Records every `url_launcher` call and answers with [result]. Restored on
/// teardown.
List<MethodCall> mockUrlLauncher({bool result = true}) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  messenger.setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    return result;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return calls;
}

// ---------------------------------------------------------------------------
// Stores and products
// ---------------------------------------------------------------------------

Future<S> loadStore<S extends CatalogStore>(S store) async {
  await store.loadFromAsset();
  return store;
}

Future<CatalogStore> loadedStore() =>
    loadStore(CatalogStore(database: openTestDatabase()));

ProductVariant syntheticVariant({
  required String id,
  String title = 'Default Title',
  double price = 1299,
  bool available = true,
}) =>
    ProductVariant(id: id, title: title, price: price, available: available);

/// A product that exists only in the test. [variants] defaults to a single
/// `Default Title` variant with [available] stock.
Product syntheticProduct({
  String id = 'gid://shopify/Product/9001',
  String title = 'Bolsa sintética',
  List<ProductVariant>? variants,
  bool available = true,
}) {
  final tail = id.split('/').last;
  return Product(
    id: id,
    handle: 'sintetico-$tail',
    title: title,
    vendor: '',
    productType: '',
    tags: const [],
    variants: variants ??
        [syntheticVariant(id: 'gid://shopify/ProductVariant/$tail')],
    images: const [],
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

/// Three text-chip variants (no reliable colour word, so the selector renders
/// upper-cased chips) in the given availability order.
List<ProductVariant> chipVariants({
  List<bool> available = const [true, true, true],
}) {
  const titles = ['Talla chica', 'Talla mediana', 'Talla grande'];
  const ids = ['v-chica', 'v-mediana', 'v-grande'];
  return [
    for (var i = 0; i < 3; i++)
      syntheticVariant(
        id: ids[i],
        title: titles[i],
        price: 1000.0 + i * 100,
        available: available[i],
      ),
  ];
}

void addProducts(CatalogStore store, List<Product> extra) {
  store.products = [...store.products, ...extra];
}

/// An in-stock asset product whose brand has at least one other piece, so the
/// `Más de <marca>` rail renders. The other piece (with a different shopper
/// name) is returned too.
({Product product, Product other}) productWithBrandRail(CatalogStore store) {
  for (final product in store.products) {
    if (!product.isInStock) continue;
    final brand = store.facetsFor(product.id)?.brand?.value;
    if (brand == null) continue;
    for (final other in store.moreFromBrand(brand, excluding: product.id)) {
      if (other.title != product.title) {
        return (product: product, other: other);
      }
    }
  }
  throw StateError('no asset product has a brand with a second piece');
}

Product singleVariantAssetProduct(CatalogStore store) => store.products
    .firstWhere((p) => p.isInStock && selectableVariants(p).isEmpty);

// ---------------------------------------------------------------------------
// View and mounting
// ---------------------------------------------------------------------------

/// Fixed phone view: dpr 1.0, [width]x[height], and the same bottom inset in
/// `padding` and `viewPadding` (as a notched phone reports it).
void setPhoneView(
  WidgetTester tester, {
  double width = 390,
  double height = kPhoneHeight,
  double inset = 0,
}) {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = FakeViewPadding(bottom: inset);
  tester.view.viewPadding = FakeViewPadding(bottom: inset);
}

Widget _scaled(BuildContext context, Widget? child, double scale) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    );

/// The store sits above the navigator so every pushed route (a second ficha,
/// the bag, the mini cart) sees it, as in the real app.
Widget fichaApp(CatalogStore store, Widget home, {double scale = 1.0}) =>
    StoreScope(
      notifier: store,
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => _scaled(context, child, scale),
        home: home,
      ),
    );

Widget externalApp(Widget home, {double scale = 1.0}) => MaterialApp(
      theme: buildTheme(),
      builder: (context, child) => _scaled(context, child, scale),
      home: home,
    );

/// Mounts [ProductScreen]. With [settle] false nothing is pumped after the
/// first frame, which is what the "first frame" assertions need.
Future<void> pumpFicha(
  WidgetTester tester,
  CatalogStore store,
  String productId, {
  double scale = 1.0,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    fichaApp(store, ProductScreen(productId: productId), scale: scale),
  );
  if (settle) await tester.pump();
}

// ---------------------------------------------------------------------------
// Finders
// ---------------------------------------------------------------------------

Finder appBarFinder() => find.byType(AppBar);

Finder inAppBar(Finder matching) =>
    find.descendant(of: appBarFinder(), matching: matching);

Finder headerTitle() => inAppBar(find.byKey(kHeaderTitleKey));

/// The main name `Text` of the content: same string as the header title but
/// not the header itself.
Finder contentNameText(String name) => find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data == name &&
          widget.key != kHeaderTitleKey,
    );

/// Text-chip option `title` of the variant selector.
Finder optionChip(String variantTitle) => find.descendant(
      of: find.byType(ProductOptionSelector),
      matching: find.text(variantTitle.toUpperCase()),
    );

Finder mainList() => find.byType(ListView).first;

Finder mainScrollable() =>
    find.descendant(of: mainList(), matching: find.byType(Scrollable)).first;

// ---------------------------------------------------------------------------
// Scrolling (the ficha is a lazy ListView: far widgets do not exist yet)
// ---------------------------------------------------------------------------

ScrollPosition _position(WidgetTester tester) =>
    tester.state<ScrollableState>(mainScrollable()).position;

/// Scrolls the main list until [target] is built, then makes it visible.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  final position = _position(tester);
  if (target.evaluate().isEmpty) {
    position.jumpTo(position.minScrollExtent);
    await tester.pump();
    while (target.evaluate().isEmpty) {
      if (position.pixels >= position.maxScrollExtent - 0.5) {
        final what = target.describeMatch(Plurality.one);
        fail('$what never appeared in the main list');
      }
      position
          .jumpTo(math.min(position.pixels + 200, position.maxScrollExtent));
      await tester.pump();
    }
  }
  await tester.ensureVisible(target.first);
  await tester.pump();
}

/// Scrolls the main list to its real end (the extent is an estimate until the
/// tail is built).
Future<void> scrollToEnd(WidgetTester tester) async {
  final position = _position(tester);
  for (var i = 0; i < 200; i++) {
    final before = position.maxScrollExtent;
    position.jumpTo(before);
    await tester.pump();
    if (position.maxScrollExtent == before &&
        position.pixels >= position.maxScrollExtent - 0.5) {
      return;
    }
  }
  fail('the main list never reached a stable end');
}

/// Distance of the top of [target] from the top of the list's content,
/// independent of the current scroll offset.
Future<double> contentOffsetOf(WidgetTester tester, Finder target) async {
  await scrollTo(tester, target);
  final listTop = tester.getTopLeft(mainList()).dy;
  return _position(tester).pixels +
      tester.getTopLeft(target.first).dy -
      listTop;
}

/// Bottom edge of the last child the main list has built.
double lastBuiltChildBottom(WidgetTester tester) {
  final sliver = tester.element(find.byType(SliverList).first);
  final children = <Element>[];
  sliver.visitChildren(children.add);
  final box = children.last.renderObject! as RenderBox;
  return box.localToGlobal(Offset(0, box.size.height)).dy;
}

// ---------------------------------------------------------------------------
// Text measurements
// ---------------------------------------------------------------------------

RenderParagraph paragraphOf(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)).first,
    );

/// Number of laid-out lines of [text]: the distinct tops of the boxes the
/// paragraph reports for its whole content.
int lineCount(WidgetTester tester, Finder text) {
  final paragraph = paragraphOf(tester, text);
  final length = paragraph.text.toPlainText().length;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  );
  return {for (final box in boxes) box.top.round()}.length;
}

TextStyle styleOf(WidgetTester tester, Finder text) {
  expect(text, findsOneWidget);
  final style = tester.widget<Text>(text).style;
  expect(style, isNotNull, reason: 'the text carries an explicit style');
  return style!;
}

/// Runs [body] with the semantics tree enabled and releases it afterwards
/// (the handle must be disposed before the end of the test body, so a
/// teardown is too late).
Future<void> withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

/// What a screen reader announces for [node]: its label, or the tooltip of an
/// icon button that has no label.
String accessibleName(SemanticsNode node) =>
    node.label.isNotEmpty ? node.label : node.tooltip;

/// Scrolls to the text chip of [variantTitle] and taps it.
Future<void> selectOption(WidgetTester tester, String variantTitle) async {
  await scrollTo(tester, optionChip(variantTitle));
  await tester.tap(optionChip(variantTitle));
  await tester.pump();
}
