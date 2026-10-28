/// Visual evidence generator for the catalog / product-detail / purchase change.
///
/// NOT a regression test and not part of `flutter test` (it lives outside
/// `test/`). It renders the real screens with real system fonts and real
/// product photographs and writes PNGs plus a `metrics.json` with the layout
/// numbers the audit quotes.
///
/// Prerequisites (shell, once; `scratch/` is git-ignored):
/// * `scratch/capture-fonts/`: Georgia, Arial, Roboto and MaterialIcons files. The
///   `flutter_tester` cannot read outside the project, hence the copy.
/// * `scratch/capture-images/`: product photographs named after the last
///   segment of their CDN URL (downloaded once with `curl`).
///
/// Run from the project root:
///
/// ```sh
/// flutter test --no-pub --dart-define=CAPTURE_PHASE=antes \
///   tool/captures/ficha_compra_captures_test.dart
/// ```
///
/// Output: `scratch/captures/<phase>/*.png` and `metrics.json`.
///
/// ## How the photographs get in
///
/// `CachedNetworkImage` needs sqflite, which does not exist in widget tests.
/// Instead of faking the plugin, the decoded photographs are placed in the
/// [ImageCache] under the exact keys the app asks for (`MediaUrl.sized` URL
/// wrapped in a [ResizeImage]), so the widgets find them already loaded.
///
/// ## Fonts
///
/// The app asks for `Inter` (not bundled) and then `SF Pro Text`,
/// `Helvetica Neue`, `Helvetica`, `Arial`, `sans-serif`; the serif helpers ask
/// for `Playfair Display`, `New York`, ..., `Georgia`. Because none of the
/// primary families is bundled, a device renders the first fallback it has
/// (Helvetica Neue on iOS, Roboto on Android; a Georgia-class serif). The
/// captures register Arial (sans) and Georgia (serif) under those primary
/// names as stand-ins for the platform face, and Roboto for text that names no
/// family. They show the layout and hierarchy, not Inter itself.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/shopper_copy.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/media/media_url.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/catalog_controls.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/features/product/external_product_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_selection.dart';
import 'package:monetta_app/features/product/quick_view.dart';
import 'package:monetta_app/main.dart';
import 'package:monetta_app/reco/events.dart';

const String _phase =
    String.fromEnvironment('CAPTURE_PHASE', defaultValue: 'despues');
const double _dpr = 2;
const String _outDir = 'scratch/captures/$_phase';
const String _titleOfLongName =
    ' Edición Especial Aniversario Color Café y Dorado con Herrajes Metálicos';

final Map<String, Map<String, Object?>> _metrics = {};

// ---------------------------------------------------------------------------
// Fonts and photographs
// ---------------------------------------------------------------------------

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final name in files) {
      final bytes = await File('scratch/capture-fonts/$name').readAsBytes();
      loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  // The flutter_tester resolves ANY family that is not registered to Ahem,
  // and it does so for the primary family before looking at the fallback
  // list. The unbundled families the app asks for first (Inter, Playfair
  // Display, Helvetica Neue) therefore have to exist under their own names:
  // they carry the face a device falls back to (Helvetica/Arial-class sans,
  // Georgia-class serif).
  const sans = ['Arial.ttf', 'Arial Bold.ttf'];
  const serif = ['Georgia.ttf', 'Georgia Bold.ttf'];
  for (final family in ['Inter', 'Helvetica Neue', 'Helvetica', 'Arial']) {
    await load(family, sans);
  }
  for (final family in ['Playfair Display', 'Georgia']) {
    await load(family, serif);
  }
  await load(
    'Roboto',
    ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf'],
  );
  // Widget tests draw Material icons as boxes unless the icon font is loaded.
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

final Map<String, ui.Image> _decoded = {};

File? _localFileFor(String url) {
  final segments = Uri.tryParse(url)?.pathSegments;
  if (segments == null || segments.isEmpty) return null;
  final file = File('scratch/capture-images/${segments.last}');
  return file.existsSync() ? file : null;
}

Future<ui.Image?> _decode(String url) async {
  final cached = _decoded[url];
  if (cached != null) return cached;
  final file = _localFileFor(url);
  if (file == null) return null;
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return _decoded[url] = frame.image;
}

/// Places the photographs of [products] in the image cache under the keys the
/// widgets will ask for.
Future<void> _seedImages(
  WidgetTester tester,
  Iterable<String> urls,
) async {
  await tester.runAsync(() async {
    final cache = PaintingBinding.instance.imageCache
      ..maximumSizeBytes = 2 << 30
      ..maximumSize = 5000;
    ImageStreamCompleter completerFor(ui.Image image) =>
        OneFrameImageStreamCompleter(
          Future<ImageInfo>.value(ImageInfo(image: image.clone())),
        );
    for (final url in urls.toSet()) {
      final image = await _decode(url);
      if (image == null) continue;
      for (final width in <int>[
        MediaUrl.thumbWidth,
        MediaUrl.cardWidth,
        MediaUrl.heroWidth,
      ]) {
        final provider =
            CachedNetworkImageProvider(MediaUrl.sized(url, width: width));
        final key = await ResizeImage.resizeIfNeeded(width, null, provider)
            .obtainKey(ImageConfiguration.empty);
        cache.putIfAbsent(key, () => completerFor(image));
      }
      // Unsized provider: the external detail screen asks for the raw URL.
      final raw = CachedNetworkImageProvider(url);
      cache.putIfAbsent(
        await raw.obtainKey(ImageConfiguration.empty),
        () => completerFor(image),
      );
    }
  });
}

// ---------------------------------------------------------------------------
// Store and fixtures
// ---------------------------------------------------------------------------

/// A store whose add-to-bag can be held (to see the pending state) or made to
/// fail (to see the error state). Behaves like [CatalogStore] otherwise.
class _ScriptedStore extends CatalogStore {
  _ScriptedStore({required super.database});

  Completer<void>? hold;
  Object? failWith;
  int addCalls = 0;

  @override
  Future<void> addToBag(Product product, {String? variantId}) async {
    addCalls += 1;
    final gate = hold;
    if (gate != null) await gate.future;
    final failure = failWith;
    if (failure != null) throw failure;
    await super.addToBag(product, variantId: variantId);
  }
}

Product _trimImages(Product product) => Product(
      id: product.id,
      handle: product.handle,
      title: product.title,
      vendor: product.vendor,
      productType: product.productType,
      tags: product.tags,
      variants: product.variants,
      images: product.images.take(3).toList(growable: false),
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      descriptionHtml: product.descriptionHtml,
      collectionHandles: product.collectionHandles,
      brandOverride: product.brandOverride,
      categoryOverride: product.categoryOverride,
    );

Product _variantOf(
  Product base, {
  required String id,
  String? title,
  bool? available,
}) =>
    Product(
      id: id,
      handle: id.split('/').last,
      title: title ?? base.title,
      vendor: base.vendor,
      productType: base.productType,
      tags: base.tags,
      variants: [
        for (final v in base.variants)
          ProductVariant(
            id: '${v.id}-$id',
            title: v.title,
            price: v.price,
            available: available ?? v.available,
            compareAtPrice: v.compareAtPrice,
          ),
      ],
      images: base.images,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      descriptionHtml: base.descriptionHtml,
      collectionHandles: base.collectionHandles,
    );

class _Fixtures {
  _Fixtures(this.store);

  final CatalogStore store;

  /// Resolves every lazily-built fixture so synthetic products are registered
  /// before the widget tree (and the photograph seeding) needs them.
  void warmUp() {
    single;
    discounted;
    multi;
    soldOut;
    longName;
  }

  late final Product single = store.products.firstWhere(
    (p) =>
        p.isInStock &&
        selectableVariants(p).isEmpty &&
        p.images.length >= 2 &&
        !p.isOnSale,
  );
  late final Product discounted = store.products.firstWhere(
    (p) =>
        p.isInStock &&
        p.isOnSale &&
        p.images.length >= 2 &&
        selectableVariants(p).isEmpty,
  );
  late final Product multi = store.products.firstWhere(
    (p) =>
        p.variants.every((v) => v.available) &&
        selectableVariants(p).length > 1 &&
        p.images.length >= 2 &&
        hasReliableColorOptions(p),
    orElse: () => store.products.firstWhere(
      (p) =>
          p.variants.every((v) => v.available) &&
          selectableVariants(p).length > 1 &&
          p.images.length >= 2,
    ),
  );
  late final Product soldOut = _register(
    _variantOf(
      single,
      id: 'gid://shopify/Product/9990001',
      available: false,
    ),
    like: single,
  );
  late final Product longName = _register(
    _variantOf(
      multi,
      id: 'gid://shopify/Product/9990002',
      title: '${multi.title}$_titleOfLongName',
    ),
    like: multi,
  );

  Product _register(Product product, {required Product like}) {
    store.products = [...store.products, product];
    final facets = store.facetsById[like.id];
    if (facets != null) {
      store.facetsById = {...store.facetsById, product.id: facets};
    }
    return product;
  }

  CatalogItem externalItem({String? title}) => CatalogItem(
        sourceScopedId: 'coach_us:capture-1',
        source: CatalogSourceType.coachUs,
        merchant: 'Coach',
        title: title ?? 'Willow Tote 24 In Signature Canvas',
        brand: 'Coach',
        category: 'Handbags',
        imageUrl: single.images.first,
        price: const Money(amount: 395, currency: Currency.usd),
        availability: CatalogAvailability.inStock,
        detailUrl: 'https://www.coach.com/products/willow/C1.html',
        marketRestriction: MarketRestriction.unitedStates,
        lastObservedAt: DateTime.utc(2026, 8, 10),
        purchaseMode: PurchaseMode.externalResearch,
      );

  /// Items of the full catalog grid: Monetta pieces plus two external ones.
  List<CatalogItem> browseItems() => [
        externalItem(),
        ...store.catalogItems.where((i) => i.shopifyProductId != null).take(26),
        externalItem(title: 'Hamilton Legacy Shoulder Bag'),
      ];
}

// ---------------------------------------------------------------------------
// Rig
// ---------------------------------------------------------------------------

class _Rig {
  _Rig(this.tester, this.store, this.fixtures, this.name, this.boundaryKey);

  final WidgetTester tester;
  final _ScriptedStore store;
  final _Fixtures fixtures;
  final String name;
  final GlobalKey boundaryKey;

  bool has(Finder finder) => finder.evaluate().isNotEmpty;

  Future<void> wait([int ms = 500]) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
    await tester.pump(Duration(milliseconds: ms));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> tap(Finder finder, {int ms = 600}) async {
    if (!has(finder)) return;
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(finder.first, warnIfMissed: false);
    await wait(ms);
  }

  Future<void> scrollTo(double offset) async {
    final scrollables = find.byType(Scrollable);
    if (!has(scrollables)) return;
    final state = tester.state<ScrollableState>(scrollables.first);
    state.position.jumpTo(
      offset.clamp(
        state.position.minScrollExtent,
        state.position.maxScrollExtent,
      ),
    );
    await wait(300);
  }

  Future<void> scrollToEnd() async {
    final scrollables = find.byType(Scrollable);
    if (!has(scrollables)) return;
    final state = tester.state<ScrollableState>(scrollables.first);
    state.position.jumpTo(state.position.maxScrollExtent);
    await wait(300);
  }

  Future<void> scrollIntoView(Finder finder) async {
    if (!has(finder)) return;
    await tester.ensureVisible(finder.first);
    await wait(300);
  }

  void metric(String key, Object? value) {
    (_metrics[name] ??= {})[key] = value;
    debugPrint('METRIC $name $key=$value');
  }

  Rect? rectOf(Finder finder) =>
      has(finder) ? tester.getRect(finder.first) : null;

  void measureChrome() {
    final nav = rectOf(find.byKey(const Key('bottom-nav-surface')));
    if (nav != null) {
      metric('navHeight', nav.height);
      metric('navBottom', nav.bottom);
      final item = rectOf(find.byKey(const Key('bottom-nav-catalog')));
      if (item != null) {
        metric(
          'navItemSize',
          '${item.width.toStringAsFixed(1)}x${item.height}',
        );
      }
      final icon = rectOf(find.byKey(const Key('bottom-nav-catalog-icon')));
      final label = rectOf(find.byKey(const Key('bottom-nav-catalog-label')));
      if (icon != null && label != null) {
        metric('navIconSize', icon.size.toString());
        metric('navIconLabelGap', label.top - icon.bottom);
      }
      final labelWidget = find.byKey(const Key('bottom-nav-catalog-label'));
      if (has(labelWidget)) {
        metric(
          'navLabelFontSize',
          tester.widget<Text>(labelWidget).style?.fontSize,
        );
      }
    }
    final legacyBar = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_PurchaseBar',
    );
    if (has(legacyBar)) {
      metric('legacyPurchaseBarHeight', tester.getSize(legacyBar.first).height);
    }
    final dock = rectOf(find.byKey(const Key('purchase-dock')));
    if (dock != null) {
      metric('dockHeight', dock.height);
      metric('dockBottom', dock.bottom);
      final primary = rectOf(find.byKey(const Key('purchase-dock-primary')));
      if (primary != null) metric('dockPrimaryHeight', primary.height);
    }
    final headerTitle = rectOf(find.byKey(const Key('product-header-title')));
    if (headerTitle != null) {
      final viewWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      metric('headerTitleCenterOffset', headerTitle.center.dx - viewWidth / 2);
      metric('headerTitleSize', headerTitle.size.toString());
    }
    final appBar = rectOf(find.byType(AppBar));
    if (appBar != null) metric('appBarHeight', appBar.height);
    final firstTile = rectOf(find.byType(MonettaProductTile));
    if (appBar != null &&
        firstTile != null &&
        !has(find.byType(SliverAppBar))) {
      metric('gapHeaderToGrid', firstTile.top - appBar.bottom);
    }
  }

  Map<String, Object?> styleOf(Finder finder) {
    if (!has(finder)) return const {};
    final style = tester.widget<Text>(finder.first).style;
    return {
      'family': style?.fontFamily,
      'fallback': style?.fontFamilyFallback?.join(' > '),
      'size': style?.fontSize,
      'weight': style?.fontWeight?.toString(),
      'height': style?.height,
    };
  }

  Future<void> shoot(String suffix) async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final bytes = await tester.runAsync<Uint8List>(() async {
      final image = await boundary.toImage(pixelRatio: _dpr);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    await tester.runAsync(() async {
      final dir = Directory(_outDir)..createSync(recursive: true);
      await File('${dir.path}/$name$suffix.png').writeAsBytes(bytes!);
    });
    debugPrint('SHOT $name$suffix');
  }
}

/// The themed buttons and the snack bar replace the ambient text style with
/// one that names no family; the test engine draws such text with a box font,
/// a device with its platform default. Roboto stands in for that default.
ThemeData _withDefaultFamily(ThemeData base) {
  ButtonStyle? patch(ButtonStyle? style) {
    final text = style?.textStyle?.resolve(const <WidgetState>{});
    if (style == null || text == null) return style;
    return style.copyWith(
      textStyle: WidgetStatePropertyAll(text.copyWith(fontFamily: 'Roboto')),
    );
  }

  final snackText = base.snackBarTheme.contentTextStyle ??
      base.textTheme.bodyMedium
          ?.copyWith(color: base.colorScheme.onInverseSurface);

  return base.copyWith(
    snackBarTheme: base.snackBarTheme.copyWith(
      contentTextStyle: snackText?.copyWith(fontFamily: 'Roboto'),
    ),
    filledButtonTheme:
        FilledButtonThemeData(style: patch(base.filledButtonTheme.style)),
    outlinedButtonTheme:
        OutlinedButtonThemeData(style: patch(base.outlinedButtonTheme.style)),
    textButtonTheme:
        TextButtonThemeData(style: patch(base.textButtonTheme.style)),
    elevatedButtonTheme:
        ElevatedButtonThemeData(style: patch(base.elevatedButtonTheme.style)),
  );
}

typedef _Body = Future<void> Function(_Rig rig);

void _scenario(
  String name, {
  required Widget Function(_Fixtures fixtures) home,
  required _Body body,
  Size size = const Size(390, 844),
  double topInset = 47,
  double bottomInset = 34,
  double textScale = 1,
  bool dark = false,
}) {
  testWidgets(name, (tester) async {
    tester.view
      ..devicePixelRatio = _dpr
      ..physicalSize = size * _dpr
      ..padding =
          FakeViewPadding(top: topInset * _dpr, bottom: bottomInset * _dpr)
      ..viewPadding =
          FakeViewPadding(top: topInset * _dpr, bottom: bottomInset * _dpr);
    addTearDown(tester.view.reset);

    final db = openTestDatabase();
    final store = _ScriptedStore(database: db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    await store.loadFromAsset();
    store.products = [for (final p in store.products) _trimImages(p)];
    final fixtures = _Fixtures(store);

    fixtures.warmUp();
    await _seedImages(tester, [
      for (final p in store.products) ...p.images,
    ]);
    for (final p in store.products.take(5)) {
      store.record(EventType.productView, productId: p.id);
    }

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: Stack(
          fit: StackFit.expand,
          textDirection: TextDirection.ltr,
          children: [
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _withDefaultFamily(buildTheme()),
              darkTheme: _withDefaultFamily(buildDarkTheme()),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: StoreScope(notifier: store, child: child!),
              ),
              home: home(fixtures),
            ),
            if (bottomInset > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: Container(
                    key: const Key('capture-home-indicator'),
                    width: 134,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final rig = _Rig(tester, store, fixtures, name, boundaryKey);
    await rig.wait(900);
    await body(rig);
    // An exception is evidence, not a harness failure: it is recorded.
    final error = tester.takeException();
    if (error != null) rig.metric('unhandledException', error.toString());
  });
}

// ---------------------------------------------------------------------------
// Hosts
// ---------------------------------------------------------------------------

Widget _navHost() => Builder(
      builder: (context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: Text('Contenido de la pantalla')),
        bottomNavigationBar: MonettaBottomNavigation(
          current: MonettaBottomDestination.catalog,
          bagCount: 3,
          onSelected: (_) {},
        ),
      ),
    );

Widget _cardsHost(_Fixtures f) => Scaffold(
      body: SafeArea(
        child: ProductCardGrid(
          products: [f.single, f.multi, f.discounted, f.soldOut],
          padding: const EdgeInsets.all(20),
          onQuickView: (product) {},
        ),
      ),
    );

Widget _quickViewHost(_Fixtures f, Product product) => Builder(
      builder: (context) => Scaffold(
        body: ProductCardGrid(
          products: [product],
          padding: const EdgeInsets.all(20),
          onQuickView: (p) => showProductQuickView(context, p),
        ),
      ),
    );

/// The second option of the variant selector (swatch or chip).
Finder _secondOption() => find
    .descendant(
      of: find.byType(ProductOptionSelector),
      matching: find.byType(GestureDetector),
    )
    .at(1);

String? _firstCategory(CatalogStore store) {
  final counts = <String, int>{};
  for (final facets in store.facetsById.values) {
    final category = facets.category?.value;
    if (category != null) counts[category] = (counts[category] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
      .first
      .key;
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await _loadFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        final dir = Directory('scratch/capture-cache')
          ..createSync(recursive: true);
        return dir.absolute.path;
      },
    );
  });

  tearDownAll(() {
    final dir = Directory(_outDir)..createSync(recursive: true);
    File('${dir.path}/metrics.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(_metrics),
    );
  });

  // -- Bottom navigation ----------------------------------------------------
  _scenario(
    '01-nav-390-inset34',
    home: (f) => _navHost(),
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '02-nav-390-inset0',
    home: (f) => _navHost(),
    bottomInset: 0,
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '03-nav-390-scale2-inset34',
    home: (f) => _navHost(),
    textScale: 2,
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '04-nav-320-scale2-inset34',
    home: (f) => _navHost(),
    size: const Size(320, 640),
    textScale: 2,
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '05-nav-390-dark',
    home: (f) => _navHost(),
    dark: true,
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );

  // -- Catalog ("Productos") --------------------------------------------------
  Widget browse(_Fixtures f) =>
      CatalogBrowseScreen(items: f.browseItems(), bagCount: 2);

  _scenario(
    '10-browse-390-top',
    home: browse,
    body: (rig) async {
      rig.measureChrome();
      rig.metric(
        'productosTitle',
        rig.styleOf(find.text('Productos')),
      );
      final reference = rig.fixtures.browseItems()[1];
      final title = ProductTileData.fromCatalogItem(reference).title;
      rig.metric('tileNameStyle', rig.styleOf(find.text(title)));
      rig.metric('referenceTileName', title);
      rig.metric(
        'quickFilterPillsPresent',
        rig.has(find.byKey(const Key('catalog-quick-brand'))),
      );
      rig.metric(
        'quickAddControls',
        find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('quick-add-'),
            )
            .evaluate()
            .length,
      );
      await rig.shoot('');
    },
  );
  _scenario(
    '11-browse-390-end',
    home: browse,
    body: (rig) async {
      await rig.scrollToEnd();
      rig.measureChrome();
      final lastTile = rig.tester.getRect(find.byType(MonettaProductTile).last);
      final nav = rig.rectOf(find.byKey(const Key('bottom-nav-surface')));
      rig.metric('lastTileBottom', lastTile.bottom);
      rig.metric('navTop', nav?.top);
      rig.metric(
        'lastTileClearOfBar',
        nav == null ? null : lastTile.bottom <= nav.top + 0.5,
      );
      await rig.shoot('');
    },
  );
  _scenario(
    '12-browse-390-panel',
    home: browse,
    body: (rig) async {
      await rig.tap(find.byKey(const Key('catalog-filter-button')));
      await rig.shoot('');
    },
  );
  _scenario(
    '13-browse-390-filtered',
    home: browse,
    body: (rig) async {
      await rig.tap(find.byKey(const Key('catalog-filter-button')));
      await rig.tap(find.byKey(const Key('catalog-filter-availability')));
      await rig.tap(find.text('En existencia'));
      await rig.tap(find.byKey(const Key('catalog-filter-apply')), ms: 900);
      rig.metric(
        'filterBadge',
        rig.has(find.byKey(const Key('catalog-filter-count')))
            ? rig.tester
                .widget<Text>(
                  find.descendant(
                    of: find.byKey(const Key('catalog-filter-count')),
                    matching: find.byType(Text),
                  ),
                )
                .data
            : null,
      );
      await rig.shoot('');
    },
  );
  _scenario(
    '14-browse-390-empty',
    home: (f) => CatalogBrowseScreen(
      items: [
        for (final item in f.store.catalogItems.take(4))
          CatalogItem(
            sourceScopedId: item.sourceScopedId,
            source: item.source,
            merchant: item.merchant,
            title: item.title,
            brand: item.brand,
            category: item.category,
            imageUrl: item.imageUrl,
            price: item.price,
            availability: CatalogAvailability.outOfStock,
            detailUrl: item.detailUrl,
            marketRestriction: item.marketRestriction,
            lastObservedAt: item.lastObservedAt,
            purchaseMode: item.purchaseMode,
            shopifyProductId: item.shopifyProductId,
          ),
      ],
      bagCount: 2,
    ),
    body: (rig) async {
      await rig.tap(find.byKey(const Key('catalog-filter-button')));
      await rig.tap(find.byKey(const Key('catalog-filter-availability')));
      await rig.tap(find.text('En existencia'));
      await rig.tap(find.byKey(const Key('catalog-filter-apply')), ms: 900);
      await rig.shoot('');
    },
  );
  for (final width in <double>[320, 430, 768]) {
    _scenario(
      '1${width == 320 ? 5 : width == 430 ? 6 : 7}-browse-${width.toInt()}-top',
      home: browse,
      size: Size(width, width > 500 ? 1024 : 844),
      body: (rig) async {
        rig.measureChrome();
        await rig.shoot('');
      },
    );
  }
  _scenario(
    '18-browse-390-scale2',
    home: browse,
    textScale: 2,
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '19-browse-390-dark',
    home: browse,
    dark: true,
    body: (rig) async {
      await rig.shoot('');
    },
  );

  // -- Home: the clearance under its last section ---------------------------
  _scenario(
    '60-home-390-end',
    home: (f) => const HomeScreen(),
    body: (rig) async {
      await rig.scrollToEnd();
      await rig.wait(1500);
      await rig.scrollToEnd();
      rig.measureChrome();
      final bleed = rig.rectOf(
        find.byKey(const ValueKey('home-account-invitation-bottom-bleed')),
      );
      if (bleed != null) rig.metric('homeBleedHeight', bleed.height);
      await rig.shoot('');
    },
  );

  // Compact cards, as Home draws its rails (about 160 px wide, square photo).
  _scenario(
    '61-cards-compact-rail',
    home: (f) => Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 300,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(20),
              children: [
                for (final product in [f.single, f.multi, f.discounted])
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 160,
                      child: Builder(
                        builder: (context) => ProductCard(
                          product: product,
                          density: ProductTileDensity.compact,
                          onQuickView: () => showProductQuickView(
                            context,
                            product,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    body: (rig) async {
      await rig.shoot('');
    },
  );

  // -- Collections ----------------------------------------------------------
  Widget collection(_Fixtures f, {bool hero = false}) => CollectionScreen(
        title: 'Bolsas',
        description:
            hero ? 'Piezas originales importadas de Estados Unidos.' : null,
        heroImageAsset: hero ? 'assets/images/home_collection_bags.webp' : null,
        filter: CollectionFilter(category: _firstCategory(f.store)),
      );

  _scenario(
    '20-collection-390-top',
    home: collection,
    body: (rig) async {
      rig.measureChrome();
      final banner = rig.rectOf(find.byType(CatalogEditorialBanner));
      final firstCard = rig.rectOf(find.byType(ProductCard));
      if (banner != null && firstCard != null) {
        rig.metric('gapBannerToGrid', firstCard.top - banner.bottom);
      }
      rig.metric('bannerTitle', rig.styleOf(find.text('Bolsas')));
      rig.metric(
        'silhouettePillsPresent',
        find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>)
                      .value
                      .startsWith('collection-silhouette-'),
            )
            .evaluate()
            .isNotEmpty,
      );
      rig.metric(
        'sortChipPresent',
        rig.has(find.byKey(const Key('collection-sort-chip'))),
      );
      await rig.shoot('');
    },
  );
  _scenario(
    '21-collection-390-scrolled',
    home: collection,
    body: (rig) async {
      await rig.scrollTo(520);
      rig.metric('collapsedTitle', rig.styleOf(find.text('Bolsas')));
      await rig.shoot('');
    },
  );
  _scenario(
    '22-collection-390-hero',
    home: (f) => collection(f, hero: true),
    body: (rig) async {
      await rig.shoot('');
    },
  );
  _scenario(
    '23-collection-390-panel',
    home: collection,
    body: (rig) async {
      await rig.tap(find.byKey(const Key('collection-filter-button')));
      await rig.tap(find.byKey(const Key('collection-filter-type')));
      await rig.shoot('');
    },
  );

  // -- Product detail -------------------------------------------------------
  Widget productScreen(Product p) => ProductScreen(productId: p.id);

  _scenario(
    '30-product-390-top',
    home: (f) => productScreen(f.discounted),
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '31-product-390-purchase-section',
    home: (f) => productScreen(f.discounted),
    body: (rig) async {
      await rig.scrollIntoView(find.byKey(const Key('purchase-section')));
      if (!rig.has(find.byKey(const Key('purchase-section')))) {
        await rig.scrollTo(1500);
      }
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '32-product-390-end',
    home: (f) => productScreen(f.discounted),
    body: (rig) async {
      await rig.scrollToEnd();
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '33-product-390-multi-variant',
    home: (f) => productScreen(f.multi),
    body: (rig) async {
      await rig.scrollTo(560);
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '34-product-390-long-name',
    home: (f) => productScreen(f.longName),
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '35-product-320-long-name',
    home: (f) => productScreen(f.longName),
    size: const Size(320, 640),
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '36-product-390-scale2',
    home: (f) => productScreen(f.single),
    textScale: 2,
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '37-product-390-sold-out',
    home: (f) => productScreen(f.soldOut),
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '38-product-390-dark',
    home: (f) => productScreen(f.discounted),
    dark: true,
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '39-product-390-added-minicart',
    home: (f) => productScreen(f.single),
    body: (rig) async {
      final primary = find.byKey(const Key('purchase-dock-primary'));
      await rig.tap(
        rig.has(primary) ? primary : find.text('AGREGAR A LA BOLSA'),
        ms: 900,
      );
      rig.metric('bagQuantityAfterAdd', rig.store.bagQuantity);
      await rig.shoot('');
    },
  );
  _scenario(
    '3a-product-390-name-and-headings',
    home: (f) => productScreen(f.discounted),
    body: (rig) async {
      final name = shopperProductName(rig.fixtures.discounted.title);
      rig.metric(
        'headerTitle',
        rig.styleOf(
          find.descendant(of: find.byType(AppBar), matching: find.text(name)),
        ),
      );
      rig.metric(
        'mainProductName',
        rig.styleOf(
          find.descendant(of: find.byType(ListView), matching: find.text(name)),
        ),
      );
      rig.metric(
        'sectionHeadingMore',
        rig.styleOf(find.textContaining('Más de')),
      );
      rig.metric(
        'sectionHeadingRecent',
        rig.styleOf(find.text('Vistas hace un momento')),
      );
      await rig.shoot('');
    },
  );

  // -- External product -----------------------------------------------------
  _scenario(
    '40-external-390-top',
    home: (f) => ExternalProductScreen(item: f.externalItem()),
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );
  _scenario(
    '41-external-390-long-name-scale2',
    home: (f) => ExternalProductScreen(
      item: f.externalItem(
        title:
            'Willow Tote 24 In Signature Canvas With Leather Trim And Turnlock Closure Limited Edition',
      ),
    ),
    textScale: 2,
    body: (rig) async {
      rig.measureChrome();
      await rig.shoot('');
    },
  );

  // -- Cards: quick add -----------------------------------------------------
  _scenario(
    '50-cards-390-grid',
    home: _cardsHost,
    body: (rig) async {
      for (final product in [
        rig.fixtures.single,
        rig.fixtures.multi,
        rig.fixtures.soldOut,
      ]) {
        final add = rig.rectOf(find.byKey(Key('quick-add-${product.id}')));
        rig.metric(
          'quickAdd:${product.id}',
          add == null ? 'absent' : add.size.toString(),
        );
      }
      await rig.shoot('');
    },
  );
  _scenario(
    '51-cards-390-pending',
    home: _cardsHost,
    body: (rig) async {
      final add = find.byKey(Key('quick-add-${rig.fixtures.single.id}'));
      if (!rig.has(add)) return;
      rig.store.hold = Completer<void>();
      await rig.tap(add, ms: 300);
      await rig.tap(add, ms: 300);
      rig.metric('addCallsWhilePending', rig.store.addCalls);
      await rig.shoot('');
      rig.store.hold?.complete();
      await rig.wait(900);
    },
  );
  _scenario(
    '52-cards-390-added',
    home: _cardsHost,
    body: (rig) async {
      final add = find.byKey(Key('quick-add-${rig.fixtures.single.id}'));
      if (!rig.has(add)) return;
      await rig.tap(add, ms: 900);
      rig.metric('bagQuantityAfterQuickAdd', rig.store.bagQuantity);
      await rig.shoot('');
    },
  );
  _scenario(
    '53-cards-390-failure',
    home: _cardsHost,
    body: (rig) async {
      final add = find.byKey(Key('quick-add-${rig.fixtures.single.id}'));
      if (!rig.has(add)) return;
      rig.store.failWith = StateError('simulated failure');
      await rig.tap(add, ms: 900);
      rig.metric('bagQuantityAfterFailure', rig.store.bagQuantity);
      await rig.shoot('');
    },
  );

  // -- Quick view -----------------------------------------------------------
  Future<void> openQuickView(_Rig rig, Product product) async {
    final add = find.byKey(Key('quick-add-${product.id}'));
    if (rig.has(add)) {
      await rig.tap(add, ms: 900);
    } else {
      await rig.tap(find.byTooltip('Vista rápida'), ms: 900);
    }
  }

  _scenario(
    '54-quickview-390-multi',
    home: (f) => _quickViewHost(f, f.multi),
    body: (rig) async {
      await openQuickView(rig, rig.fixtures.multi);
      final legacyAdd = find.text('AGREGAR A LA BOLSA');
      if (rig.has(legacyAdd)) {
        rig.metric(
          'legacyQuickViewAddRect',
          rig.tester.getRect(legacyAdd.first).toString(),
        );
      }
      final primary = rig.rectOf(find.byKey(const Key('quick-view-primary')));
      if (primary != null) {
        rig.metric('quickViewPrimaryRect', primary.toString());
      }
      rig.metric(
        'quickViewActionsPresent',
        rig.has(find.byKey(const Key('quick-view-actions'))),
      );
      final actions = rig.rectOf(find.byKey(const Key('quick-view-actions')));
      if (actions != null) rig.metric('quickViewActionsBottom', actions.bottom);
      await rig.shoot('');
    },
  );
  _scenario(
    '55-quickview-390-chosen',
    home: (f) => _quickViewHost(f, f.multi),
    body: (rig) async {
      await openQuickView(rig, rig.fixtures.multi);
      await rig.tap(_secondOption(), ms: 700);
      await rig.shoot('');
    },
  );
  _scenario(
    '56-quickview-390-error',
    home: (f) => _quickViewHost(f, f.multi),
    body: (rig) async {
      await openQuickView(rig, rig.fixtures.multi);
      await rig.tap(_secondOption(), ms: 700);
      rig.store.failWith = StateError('simulated failure');
      final primary = find.byKey(const Key('quick-view-primary'));
      await rig.tap(
        rig.has(primary) ? primary : find.text('AGREGAR A LA BOLSA'),
        ms: 900,
      );
      rig.metric('bagQuantityAfterFailure', rig.store.bagQuantity);
      await rig.shoot('');
    },
  );
  _scenario(
    '57-quickview-390-sold-out',
    home: (f) => _quickViewHost(f, f.soldOut),
    body: (rig) async {
      await openQuickView(rig, rig.fixtures.soldOut);
      await rig.shoot('');
    },
  );
  _scenario(
    '58-quickview-320-scale2',
    home: (f) => _quickViewHost(f, f.multi),
    size: const Size(320, 640),
    textScale: 2,
    body: (rig) async {
      await openQuickView(rig, rig.fixtures.multi);
      await rig.shoot('');
    },
  );
  _scenario(
    '59-quickview-390-dark',
    home: (f) => _quickViewHost(f, f.multi),
    dark: true,
    body: (rig) async {
      await openQuickView(rig, rig.fixtures.multi);
      await rig.shoot('');
    },
  );
}
