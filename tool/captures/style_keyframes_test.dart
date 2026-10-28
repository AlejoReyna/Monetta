/// Visual evidence for the style-guideline migration (milestone 1): the native
/// Inicio, Colección, Producto and Cuenta screens plus a component board, at a
/// phone (390) and a tablet (834) width.
///
/// NOT a regression test and NOT part of `flutter test` (it lives outside
/// `test/`). It renders the real screens with the bundled Inter and Playfair
/// Display and real product photographs, and writes PNGs plus `metrics.json`.
///
/// Prerequisite: `scratch/capture-images/` holds the product photographs named
/// after the last segment of their CDN URL (`scratch/` is git-ignored). The
/// `flutter_tester` cannot read outside the project, hence the copy.
///
/// ```sh
/// flutter test --no-pub --dart-define=CAPTURE_OUT=scratch/captures/m1 \
///   tool/captures/style_keyframes_test.dart
/// ```
///
/// `CachedNetworkImage` needs sqflite, which widget tests lack, so decoded
/// photographs are placed in the [ImageCache] under the exact keys the app
/// asks for.
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
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/media/media_url.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/navigation/monetta_navigation_bar.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart'
    show MonettaBottomDestination;
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/rewards/rewards_models.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/main.dart';

import '../../test/support/bundled_fonts.dart';
import '../../test/support/product_screen_harness.dart' show mockPathProvider;

const String _out =
    String.fromEnvironment('CAPTURE_OUT', defaultValue: 'scratch/captures/m1');

const Key _captureKey = ValueKey('style-capture');
const Map<String, (Size, double)> _views = {
  '390': (Size(390, 1250), 2),
  '834': (Size(834, 1250), 1.5),
};

final Map<String, Object?> _metrics = {};

/// flutter_cache_manager opens a sqflite database the first time a photo that
/// is not in the seeded set is requested; widget tests have no plugin for it.
/// Those images stay placeholders, so that one error is not a failure here.
void _ignoreCacheManagerPluginErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('databaseFactory') || text.contains('path_provider')) {
      _metrics['ignoredCacheManagerErrors'] =
          (_metrics['ignoredCacheManagerErrors'] as int? ?? 0) + 1;
      return;
    }
    previous?.call(details);
  };
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

Future<int> _seedImages(WidgetTester tester, Iterable<String> urls) async {
  var seeded = 0;
  await tester.runAsync(() async {
    final cache = PaintingBinding.instance.imageCache
      ..maximumSizeBytes = 2 << 30
      ..maximumSize = 5000;
    for (final url in urls.toSet()) {
      final image = await _decode(url);
      if (image == null) continue;
      seeded += 1;
      for (final width in <int>[
        MediaUrl.thumbWidth,
        MediaUrl.cardWidth,
        MediaUrl.heroWidth,
      ]) {
        final provider =
            CachedNetworkImageProvider(MediaUrl.sized(url, width: width));
        final key = await ResizeImage.resizeIfNeeded(width, null, provider)
            .obtainKey(ImageConfiguration.empty);
        cache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(
            Future<ImageInfo>.value(ImageInfo(image: image.clone())),
          ),
        );
      }
    }
  });
  return seeded;
}

/// Images that are not in the photo set (banners, remote artwork) try the real
/// network cache, which needs a plugin widget tests lack: they stay as
/// placeholders, so the harness drops those errors and says so in metrics.
Future<void> _settle(WidgetTester tester, String name) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  var dropped = 0;
  while (tester.takeException() != null) {
    dropped += 1;
  }
  _metrics['unloadedImageErrors-$name'] = dropped;
}

Future<void> _write(WidgetTester tester, String name, double dpr) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_captureKey),
    );
    final image = await boundary.toImage(pixelRatio: dpr);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_out/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Widget _frame(Widget home, CatalogStore store) => RepaintBoundary(
      key: _captureKey,
      child: StoreScope(
        notifier: store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: home,
        ),
      ),
    );

/// A board of the shared foundations drawn from the real widgets and tokens.
class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final width = MediaQuery.sizeOf(context).width;
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 12),
          child: Text(t, style: boutiqueSectionHeading(context: context)),
        );
    final swatches = <(String, Color)>[
      ('canvas', MonettaTokens.canvas),
      ('bar', MonettaTokens.bar),
      ('surface', MonettaTokens.surface),
      ('surfaceWarm', MonettaTokens.surfaceWarm),
      ('surfaceTile', MonettaTokens.surfaceTile),
      ('ink', MonettaTokens.ink),
      ('inkMuted', MonettaTokens.inkMuted),
      ('actionPrimary', MonettaTokens.actionPrimary),
      ('actionDark', MonettaTokens.actionDark),
      ('accentText', MonettaTokens.accentText),
      ('gold', MonettaTokens.gold),
      ('divider', MonettaTokens.divider),
      ('borderControl', MonettaTokens.borderControl),
      ('sale', MonettaTokens.sale),
      ('saleSurface', MonettaTokens.saleSurface),
    ];
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final roles = <(String, MonettaTypeRole, String)>[
      ('campaign', MonettaTokens.campaign, 'Nueva colección'),
      ('screenTitle', MonettaTokens.screenTitle, 'Categorías'),
      ('sectionTitle', MonettaTokens.sectionTitle, 'Compra por estilo'),
      ('productName', MonettaTokens.productName, 'Tabby Shoulder Bag 26'),
      ('accountRow', MonettaTokens.accountRow, 'Mis pedidos'),
    ];
    return Scaffold(
      backgroundColor: p.canvas,
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MonettaTokens.gutterFor(width),
          vertical: 24,
        ),
        children: [
          Text(
            'Tablero de componentes',
            style: boutiqueScreenTitle(context: context),
          ),
          title('Color semántico'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (name, color) in swatches)
                SizedBox(
                  width: 112,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BoutiqueRadius.tile,
                          border: Border.all(color: p.hairline),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(name, style: boutiqueText(size: 12, color: p.ink)),
                      Text(
                        hex(color),
                        style: boutiqueText(size: 11, color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          title('Tipografía'),
          for (final (name, role, sample) in roles) ...[
            Text(
              '$name · ${role.sizeFor(width).round()} px',
              style: boutiqueText(size: 12, color: p.inkMuted),
            ),
            Text(
              sample,
              style: TextStyle(
                fontFamily: kBoutiqueSerifFamily,
                fontFamilyFallback: kBoutiqueSerifFallback,
                fontSize: role.sizeFor(width),
                height: role.lineHeight,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 10),
          ],
          title('Botones y chips'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child:
                    BoutiqueButton(label: 'Agregar a bolsa', onPressed: () {}),
              ),
              SizedBox(
                width: 220,
                child: BoutiqueButton(
                  label: 'Comprar ahora',
                  filled: false,
                  onPressed: () {},
                ),
              ),
              const SizedBox(
                width: 220,
                child: BoutiqueButton(label: 'No disponible', onPressed: null),
              ),
              ChoiceChip(
                label: const Text('Bolsas'),
                selected: true,
                onSelected: (_) {},
              ),
              ChoiceChip(
                label: const Text('Carteras'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
          title('Navegación inferior'),
          ClipRRect(
            borderRadius: BoutiqueRadius.control,
            child: MonettaNavigationBar(
              current: MonettaBottomDestination.home,
              bagCount: 2,
              onSelected: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    mockPathProvider();
    await loadBundledFonts();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  tearDownAll(() {
    File('$_out/metrics.json')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(_metrics)}\n',
      );
  });

  // The first network image of the process opens flutter_cache_manager's
  // database, which needs a plugin widget tests lack. Trigger and absorb that
  // one error here so it does not land in a capture.
  testWidgets('warm-up (absorbs the cache-manager plugin error)', (
    tester,
  ) async {
    _ignoreCacheManagerPluginErrors();
    await tester.runAsync(() async {
      final done = Completer<void>();
      unawaited(
        runZonedGuarded(
          () async {
            CachedNetworkImageProvider('https://example.invalid/x.png')
                .resolve(ImageConfiguration.empty)
                .addListener(
                  ImageStreamListener((_, __) {}, onError: (_, __) {}),
                );
            await Future<void>.delayed(const Duration(milliseconds: 400));
            done.complete();
          },
          (error, stack) {},
        ),
      );
      await done.future;
    });
    while (tester.takeException() != null) {}
  });

  for (final entry in _views.entries) {
    final label = entry.key;
    final (size, dpr) = entry.value;

    Future<CatalogStore> prepare(WidgetTester tester) async {
      _ignoreCacheManagerPluginErrors();
      tester.view.physicalSize = size * dpr;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      final db = openTestDatabase();
      final store = CatalogStore(database: db);
      await tester.runAsync(store.loadFromAsset);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      final seeded = await _seedImages(tester, [
        for (final p in store.products) ...p.images,
      ]);
      _metrics['photos-$label'] = seeded;
      return store;
    }

    testWidgets('inicio $label', (tester) async {
      final store = await prepare(tester);
      await tester.pumpWidget(_frame(const HomeScreen(), store));
      await _settle(tester, 'inicio-$label');
      await _write(tester, 'inicio__$label', dpr);
    });

    testWidgets('coleccion $label', (tester) async {
      final store = await prepare(tester);
      await tester.pumpWidget(
        _frame(
          const CollectionScreen(
            title: 'Bolsas',
            filter: CollectionFilter(category: 'bolsa'),
          ),
          store,
        ),
      );
      await _settle(tester, 'coleccion-$label');
      await _write(tester, 'coleccion__$label', dpr);
    });

    testWidgets('producto $label', (tester) async {
      final store = await prepare(tester);
      final product = store.products.firstWhere(
        (p) => p.handle == 'bolso-coach-shoulder-negro-rectangular',
        orElse: () => store.products.first,
      );
      await tester.pumpWidget(
        _frame(ProductScreen(productId: product.id), store),
      );
      await _settle(tester, 'producto-$label');
      await _write(tester, 'producto__$label', dpr);
    });

    testWidgets('cuenta $label', (tester) async {
      final store = await prepare(tester);
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = AccountController(
        accountStore: AccountStore(db),
        deviceStore: DeviceStore(db),
        orderHistoryRepository: OrderHistoryRepository(
          store: OrderSummaryStore(db),
          config: AccountsOrdersConfig.disabled,
        ),
        deviceId: 'capture-device',
      )
        ..account = Account(
          localAccountId: 'capture-account',
          shopifyCustomerId: 'gid://shopify/Customer/10',
          email: 'ana@example.com',
          displayName: 'Ana Fernández',
          authProvider: 'shopify',
          createdAt: DateTime.utc(2026),
          lastSeenAt: DateTime.utc(2026),
        )
        ..ordersStatus = OrderHistoryStatus.populated;
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _frame(
          AccountScreen(
            controller: controller,
            rewardsReader: FakeRewardsReader(
              summary: RewardsSummary(
                redemptionEnabled: true,
                firstPurchaseEnabled: false,
                reviewEnabled: false,
                referralEnabled: false,
                availableCents: 32000,
                pendingCents: 0,
                reservedCents: 0,
                nextExpiry: null,
                asOf: DateTime.utc(2026, 10, 20),
              ),
            ),
          ),
          store,
        ),
      );
      await _settle(tester, 'cuenta-$label');
      await _write(tester, 'cuenta__$label', dpr);
    });

    testWidgets('board $label', (tester) async {
      final store = await prepare(tester);
      await tester.pumpWidget(_frame(const _Board(), store));
      await _settle(tester, 'board-$label');
      await _write(tester, 'board__$label', dpr);
    });
  }
}
