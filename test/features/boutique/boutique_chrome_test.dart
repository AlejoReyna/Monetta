import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/monetta_tokens.g.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/brand_screen.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/order_confirmation_screen.dart';
import 'package:monetta_app/features/contact/contact_screen.dart';
import 'package:monetta_app/features/favorites/favorites_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/notifications/notification_inbox.dart';
import 'package:monetta_app/features/notifications/notifications_screen.dart';
import 'package:monetta_app/features/orders/order_detail_screen.dart';
import 'package:monetta_app/features/orders/orders_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/rewards/rewards_section.dart';
import 'package:monetta_app/main.dart';

import '../../support/catalog_browse_fixtures.dart';

/// The grey the owner asked for on both bars, light mode.
const Color _barGrey = MonettaTokens.bar;
const Color _white = MonettaTokens.canvas;

/// Chrome (top bar, bottom bar) is read from what is painted,
/// not from palette getters: the colour a shopper sees is the contract.

String _hex(Color? color) => color == null
    ? 'null'
    : '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

void _phone(WidgetTester tester) {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
}

/// A fixed number of frames: several screens run timers or looping
/// animations, so `pumpAndSettle` is not an option for all of them.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<CatalogStore> _loadedStore() async {
  final store = CatalogStore(database: openTestDatabase());
  await store.loadFromAsset();
  addTearDown(store.dispose);
  return store;
}

Widget _app(ThemeData theme, Widget home) => MaterialApp(
      // A fresh element per brightness so the theme never animates between
      // two cases that share a test body.
      key: ValueKey<Brightness>(theme.brightness),
      theme: theme,
      home: home,
    );

Widget _storeApp(ThemeData theme, CatalogStore store, Widget child) =>
    _app(theme, StoreScope(notifier: store, child: child));

/// The colour the top bar paints: the `Material` the `AppBar` builds. This
/// resolves explicit `backgroundColor`, `AppBarTheme` and the transparent
/// state of the collection's `SliverAppBar` alike.
Color? _topBarColor(WidgetTester tester) {
  final bar = find.byType(AppBar);
  expect(bar, findsOneWidget, reason: 'exactly one AppBar on this screen');
  final material = find.descendant(of: bar, matching: find.byType(Material));
  return tester.widget<Material>(material.first).color;
}

Color? _scaffoldColor(WidgetTester tester) {
  final scaffold = find
      .ancestor(of: find.byType(AppBar), matching: find.byType(Scaffold))
      .first;
  return tester.widget<Scaffold>(scaffold).backgroundColor;
}

Color? _bottomBarColor(WidgetTester tester) {
  final surface = find.byKey(const Key('bottom-nav-surface'));
  expect(surface, findsOneWidget);
  return tester.widget<Material>(surface).color;
}

BrowseEntry _monettaItem(int i, String category) =>
    browseEntry(i, category: category);

OrderSummary _order() => OrderSummary(
      id: 'gid://shopify/Order/1',
      accountId: 'acct-1',
      displayNumber: '#1001',
      fulfillmentStatus: 'fulfilled',
      shopifyOrderId: 'gid://shopify/Order/1',
      source: 'shopify_checkout',
      attributionCode: null,
      status: 'paid',
      totalAmount: 11480,
      currencyCode: 'MXN',
      placedAt: DateTime.utc(2026, 5, 12),
    );

AccountController _accountController(AppDatabase db) => AccountController(
      accountStore: AccountStore(db),
      deviceStore: DeviceStore(db),
      orderHistoryRepository: OrderHistoryRepository(
        store: OrderSummaryStore(db),
        config: AccountsOrdersConfig.disabled,
      ),
      deviceId: 'dev-1',
    );

/// One mountable boutique screen. [mount] pumps it under [theme] on a phone
/// viewport and leaves it settled.
class _Screen {
  const _Screen(this.name, this.mount);

  final String name;
  final Future<void> Function(WidgetTester tester, ThemeData theme) mount;
}

Future<void> _mountHome(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final store = await _loadedStore();
  await tester.pumpWidget(_storeApp(theme, store, const HomeScreen()));
  await _settle(tester);
}

Future<void> _mountCatalog(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  await tester.pumpWidget(
    _app(
      theme,
      browseScreen([
        _monettaItem(1, 'cartera'),
        _monettaItem(2, 'reloj'),
        _monettaItem(3, 'perfume'),
      ]),
    ),
  );
  await _settle(tester);
}

Future<void> _mountCollection(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final store = await _loadedStore();
  await tester.pumpWidget(
    _storeApp(
      theme,
      store,
      const CollectionScreen(
        title: 'Bolsas',
        filter: CollectionFilter(category: 'bolsa'),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _mountBrand(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final store = await _loadedStore();
  await tester.pumpWidget(
    _storeApp(
      theme,
      store,
      BrandScreen(brandSlug: store.availableBrands.first),
    ),
  );
  await _settle(tester);
}

Future<void> _mountFavorites(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final store = await _loadedStore();
  await tester.pumpWidget(_storeApp(theme, store, const FavoritesScreen()));
  await _settle(tester);
}

Future<void> _mountProduct(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final store = await _loadedStore();
  final product = store.products.firstWhere((item) => item.isInStock);
  await tester.pumpWidget(
    _storeApp(theme, store, ProductScreen(productId: product.id)),
  );
  await _settle(tester);
}

Future<void> _mountBag(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final store = await _loadedStore();
  await store.addToBag(store.products.firstWhere((item) => item.isInStock));
  await tester.pumpWidget(_storeApp(theme, store, const BagScreen()));
  await _settle(tester);
}

Future<void> _mountCheckout(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final store = await _loadedStore();
  await store.addToBag(store.products.firstWhere((item) => item.isInStock));
  await tester.pumpWidget(_storeApp(theme, store, const CheckoutFlowScreen()));
  await _settle(tester);
}

Future<void> _mountConfirmation(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  await tester.pumpWidget(
    _app(theme, const OrderConfirmationScreen(orderLabel: '#1001')),
  );
  await _settle(tester);
}

Future<void> _mountOrders(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final db = openTestDatabase();
  addTearDown(db.close);
  final controller = _accountController(db)
    ..orders = [_order()]
    ..ordersStatus = OrderHistoryStatus.populated;
  await tester.pumpWidget(
    _app(
      theme,
      OrdersScreen(controller: controller, rewardsReader: FakeRewardsReader()),
    ),
  );
  await _settle(tester);
}

Future<void> _mountOrderDetail(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  await tester.pumpWidget(_app(theme, OrderDetailScreen(order: _order())));
  await _settle(tester);
}

Future<void> _mountAccount(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  final db = openTestDatabase();
  addTearDown(db.close);
  await tester.pumpWidget(
    _app(theme, AccountScreen(controller: _accountController(db))),
  );
  await _settle(tester);
}

Future<void> _mountNotifications(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  await tester.pumpWidget(
    _app(
      theme,
      NotificationsScreen(inbox: NotificationInbox(), ownerId: 'acct-1'),
    ),
  );
  await _settle(tester);
}

Future<void> _mountContact(WidgetTester tester, ThemeData theme) async {
  _phone(tester);
  await tester.pumpWidget(
    _app(theme, ContactScreen(openUri: (uri) async => true)),
  );
  await _settle(tester);
}

/// Scrolls the home past its hero — the home equivalent of scrolling a
/// collection banner away.
Future<void> _scrollHomePastHero(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const ValueKey('home-discovery-header')),
    const Offset(0, -700),
  );
  await _settle(tester);
}

final _screens = <_Screen>[
  // Home is not in this loop: it has no page title header. Dedicated Home
  // cases below pin its bar at rest and after the hero scrolls away.
  const _Screen('Catálogo', _mountCatalog),
  const _Screen('Colección (sólido)', _mountCollection),
  const _Screen('Marca', _mountBrand),
  const _Screen('Favoritos', _mountFavorites),
  const _Screen('Producto', _mountProduct),
  const _Screen('Bolsa', _mountBag),
  const _Screen('Checkout', _mountCheckout),
  const _Screen('Confirmación de pedido', _mountConfirmation),
  const _Screen('Pedidos', _mountOrders),
  const _Screen('Detalle de pedido', _mountOrderDetail),
  const _Screen('Cuenta', _mountAccount),
  const _Screen('Notificaciones', _mountNotifications),
  const _Screen('Contacto', _mountContact),
];

/// Contrast ratio per WCAG 2.x, on opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + .05) / (darker + .05);
}

void main() {
  final light = buildTheme();
  final dark = buildDarkTheme();

  group('UI-THEME-04 light: page ground and screen header', () {
    for (final screen in _screens) {
      final topBarColor = _white;
      testWidgets(
        'UI-THEME-04 (objetivo) ${screen.name}: top bar ${_hex(topBarColor)}, '
        'scaffold ${_hex(_white)}',
        (tester) async {
          await screen.mount(tester, light);

          final problems = <String>[
            if (_topBarColor(tester) != topBarColor)
              'top bar painted ${_hex(_topBarColor(tester))}, '
                  'expected ${_hex(topBarColor)}',
            if (_scaffoldColor(tester) != _white)
              'scaffold painted ${_hex(_scaffoldColor(tester))}, '
                  'expected ${_hex(_white)}',
          ];
          expect(problems, isEmpty);
          if (screen.name != 'Producto') {
            final title = find.byKey(const ValueKey('monetta-page-title'));
            final back = find.byKey(const ValueKey('monetta-page-back'));
            expect(
              tester.widget<Text>(title).style!.fontFamily,
              kBoutiqueSerifFamily,
            );
            expect(tester.widget<Text>(title).textAlign, TextAlign.start);
            expect(
              tester.getRect(title).left,
              closeTo(tester.getRect(back).right, .01),
            );
          }
        },
      );
    }

    testWidgets(
      'UI-THEME-04 (objetivo) Colección con foto: the white bar stays fixed '
      '${_hex(_white)} once the banner has scrolled away',
      (tester) async {
        _phone(tester);
        final store = await _loadedStore();
        await tester.pumpWidget(
          _storeApp(
            light,
            store,
            const CollectionScreen(
              title: 'Bolsas',
              filter: CollectionFilter(category: 'bolsa'),
              heroImageAsset: 'assets/images/home_collection_bags.webp',
            ),
          ),
        );
        await _settle(tester);

        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -700),
        );
        await _settle(tester);

        // The title only moves into the bar past 120px of scroll, so this
        // proves the bar is in its solid state and not still over the photo.
        final scrollable = find
            .descendant(
              of: find.byType(CustomScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first;
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          greaterThan(120),
          reason: 'precondition: the banner has scrolled away',
        );
        final problems = <String>[
          if (_topBarColor(tester) != _white)
            'solid bar painted ${_hex(_topBarColor(tester))}, '
                'expected ${_hex(_white)}',
        ];
        expect(problems, isEmpty);
      },
    );

    testWidgets(
      'UI-THEME-04 (caracterización) Colección con foto: the bar stays white '
      'above the photograph',
      (tester) async {
        _phone(tester);
        final store = await _loadedStore();
        await tester.pumpWidget(
          _storeApp(
            light,
            store,
            const CollectionScreen(
              title: 'Bolsas',
              filter: CollectionFilter(category: 'bolsa'),
              heroImageAsset: 'assets/images/home_collection_bags.webp',
            ),
          ),
        );
        await _settle(tester);

        expect(_topBarColor(tester), _white);
      },
    );

    testWidgets(
      'UI-THEME-04 (caracterización) Home: the bar is ${_hex(_white)} above '
      'the hero',
      (tester) async {
        await _mountHome(tester, light);

        final problems = <String>[
          if (_topBarColor(tester) != _white)
            'top bar painted ${_hex(_topBarColor(tester))}, '
                'expected ${_hex(_white)} above the hero',
          if (_scaffoldColor(tester) != _white)
            'scaffold painted ${_hex(_scaffoldColor(tester))}, '
                'expected ${_hex(_white)}',
        ];
        expect(problems, isEmpty);
      },
    );

    testWidgets(
      'UI-THEME-04 (objetivo) Home: the bar stays ${_hex(_white)} once the '
      'hero has scrolled away',
      (tester) async {
        await _mountHome(tester, light);
        await _scrollHomePastHero(tester);

        final problems = <String>[
          if (_topBarColor(tester) != _white)
            'solid bar painted ${_hex(_topBarColor(tester))}, '
                'expected ${_hex(_white)}',
        ];
        expect(problems, isEmpty);
      },
    );
  });

  group('UI-THEME-05 light: flat full-width navigation', () {
    for (final screen in <_Screen>[
      const _Screen('Catálogo', _mountCatalog),
      const _Screen('Colección', _mountCollection),
    ]) {
      testWidgets('${screen.name}: flat light bar under the page-ground header',
          (tester) async {
        await screen.mount(tester, light);
        expect(_bottomBarColor(tester), _barGrey);
        expect(_topBarColor(tester), _white);
      });
    }
    testWidgets('Home: flat bar stays light while the hero scrolls away',
        (tester) async {
      await _mountHome(tester, light);
      expect(_bottomBarColor(tester), _barGrey);
      expect(_topBarColor(tester), _white);
      await _scrollHomePastHero(tester);
      expect(_bottomBarColor(tester), _barGrey);
      expect(_topBarColor(tester), _white);
    });
  });

  group('UI-THEME-06 dark: unchanged', () {
    final subset = <_Screen>[
      // Home is covered by its own case below, at rest and after scroll.
      const _Screen('Catálogo', _mountCatalog),
      const _Screen('Producto', _mountProduct),
      const _Screen('Cuenta', _mountAccount),
    ];
    for (final screen in subset) {
      testWidgets(
        'UI-THEME-06 (caracterización) ${screen.name}: scaffold and top bar '
        'are the dark canvas',
        (tester) async {
          await screen.mount(tester, dark);

          expect(_topBarColor(tester), MonettaColors.dark.canvas);
          expect(_scaffoldColor(tester), MonettaColors.dark.canvas);
        },
      );
    }

    testWidgets(
      'UI-THEME-06 (caracterización) Home: the bar is the dark canvas above '
      'the hero and once it scrolls away',
      (tester) async {
        await _mountHome(tester, dark);

        expect(_topBarColor(tester), MonettaColors.dark.canvas);
        expect(_scaffoldColor(tester), MonettaColors.dark.canvas);

        await _scrollHomePastHero(tester);

        expect(_topBarColor(tester), MonettaColors.dark.canvas);
      },
    );

    for (final screen in <_Screen>[
      const _Screen('Home', _mountHome),
      const _Screen('Catálogo', _mountCatalog),
      const _Screen('Colección', _mountCollection),
    ]) {
      testWidgets(
        'UI-THEME-06 (caracterización) ${screen.name}: bottom bar is the dark '
        'navigation surface',
        (tester) async {
          await screen.mount(tester, dark);

          expect(
            _bottomBarColor(tester),
            const Color(0xFF191A18),
          );
        },
      );
    }
  });

  group('UI-THEME-07 light: text keeps WCAG AA on the new grounds', () {
    testWidgets(
      'UI-THEME-07 (guarda) ink and inkMuted reach 4.5:1 on canvas, surface '
      'and the real top bar; goldText on canvas and the bar',
      (tester) async {
        await _mountCatalog(tester, light);

        final catalogContext = tester.element(find.byType(CatalogBrowseScreen));
        final palette = BoutiquePalette.of(catalogContext);
        final bar = _topBarColor(tester)!;

        final grounds = <String, Color>{
          'canvas': palette.canvas,
          'surface': palette.surface,
          'top bar': bar,
        };
        final problems = <String>[];
        for (final ground in grounds.entries) {
          for (final text in <String, Color>{
            'ink': palette.ink,
            'inkMuted': palette.inkMuted,
          }.entries) {
            final ratio = _contrast(text.value, ground.value);
            if (ratio < 4.5) {
              problems.add(
                '${text.key} on ${ground.key} ${_hex(ground.value)} is '
                '${ratio.toStringAsFixed(2)}:1',
              );
            }
          }
        }
        for (final ground in <String, Color>{
          'canvas': palette.canvas,
          'top bar': bar,
        }.entries) {
          final ratio = _contrast(palette.goldText, ground.value);
          if (ratio < 4.5) {
            problems.add(
              'goldText on ${ground.key} ${_hex(ground.value)} is '
              '${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
        expect(problems, isEmpty);
      },
    );
  });
}
