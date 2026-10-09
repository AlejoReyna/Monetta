/// CHAR-02 (objective state, red until RF-31): a typed destination
/// (`AppDestination`) resolves a tapped notification, and `DestinationNavigator`
/// opens it. A product that is not in the cache is looked up after a catalog
/// refresh instead of silently sending the shopper to the home, and the three
/// ways a lookup can end (found, gone, could not check) are told apart.
///
/// Time: the catalog refresh is a fake the test controls (a `Completer`), so
/// nothing reads a clock or the network. Frames are pumped in bounded steps,
/// never `pumpAndSettle`, because the search screen may show a progress
/// indicator that animates forever.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/composition/app_scopes.dart';
import 'package:monetta_app/app/destinations/app_destination.dart';
import 'package:monetta_app/app/destinations/destination_navigator.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/notifications/notification_models.dart';
import 'package:monetta_app/data/repositories/catalog_repository.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/features/product/product_unavailable.dart';

import '../../support/product_screen_harness.dart';

const _searchingText = 'Buscando el artículo…';
const _unavailableTitle = 'Este artículo ya no está disponible';
const _couldNotCheckTitle = 'No se pudo comprobar este artículo';
const _checkConnection = 'Revisa tu conexión e inténtalo de nuevo.';
const _retryLabel = 'Reintentar';
const _deadLinkTitle = 'Enlace no disponible';
const _deadLinkBody = 'Este enlace ya no lleva a ninguna pieza de Monetta.';
const _goHomeLabel = 'Ir al inicio';

const _homeMarker = 'INICIO';
const _middleMarker = 'INTERMEDIA';

const _gid = 'gid://shopify/Product/9001';

/// Pumps a few bounded frames: enough for a pushed route to mount and its
/// transition to end, without waiting for animations that never settle.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 14; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A refresh whose answer the test decides, and which counts its calls.
class _FakeRefresh {
  _FakeRefresh(this._answer);

  Future<CatalogSyncResult> Function() _answer;
  int calls = 0;

  set answer(Future<CatalogSyncResult> Function() value) => _answer = value;

  Future<CatalogSyncResult> call() {
    calls += 1;
    return _answer();
  }
}

Future<CatalogSyncResult> _result(CatalogSyncOutcome outcome) =>
    Future.value(CatalogSyncResult(outcome: outcome));

class _Env {
  _Env({
    required this.tester,
    required this.store,
    required this.refresh,
    required this.navigatorKey,
    required this.destinations,
  });

  final WidgetTester tester;
  final CatalogStore store;
  final _FakeRefresh refresh;
  final GlobalKey<NavigatorState> navigatorKey;
  final DestinationNavigator destinations;

  NavigatorState get navigator => navigatorKey.currentState!;

  /// Opens [destination] and pumps; the future is deliberately not awaited
  /// (it may only complete when the opened route closes).
  Future<void> open(AppDestination destination) async {
    unawaited(destinations.open(navigator, destination));
    await _frames(tester);
  }
}

/// Mounts a `MaterialApp` with a navigator key whose `home` sees the store, as
/// the real app does. [answer] is the initial behaviour of the refresh fake.
Future<_Env> _mount(
  WidgetTester tester, {
  Future<CatalogSyncResult> Function()? answer,
}) async {
  mockPathProvider();
  setPhoneView(tester);
  final store = await loadedStore();
  addTearDown(store.dispose);
  final refresh = _FakeRefresh(
    answer ?? () => _result(CatalogSyncOutcome.upToDate),
  );
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: StoreScope(
        notifier: store,
        child: const Scaffold(body: Center(child: Text(_homeMarker))),
      ),
    ),
  );
  await tester.pump();
  return _Env(
    tester: tester,
    store: store,
    refresh: refresh,
    navigatorKey: navigatorKey,
    destinations: DestinationNavigator(store: store, refresh: refresh.call),
  );
}

/// Pushes a plain route above the home so `popUntil(isFirst)` has something to
/// pop.
Future<void> _pushMiddle(_Env env) async {
  unawaited(
    env.navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text(_middleMarker)),
      ),
    ),
  );
  await _frames(env.tester);
  expect(find.text(_middleMarker), findsOneWidget);
}

Product _missingProduct() => syntheticProduct(id: _gid, title: 'Pieza nueva');

NotificationRouteData _route(
  String type, {
  String? productKey,
  String? handle,
}) =>
    NotificationRouteData(
      type: type,
      productKey: productKey,
      collectionHandle: handle,
    );

void _expectSearching(WidgetTester tester) {
  expect(find.text(_searchingText), findsOneWidget);
  expect(find.byType(ProductScreen), findsNothing);
  expect(find.text(_unavailableTitle), findsNothing);
  expect(find.text(_couldNotCheckTitle), findsNothing);
}

void _expectProductOpen(WidgetTester tester, String productId) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ProductScreen), findsOneWidget);
  expect(
    tester.widget<ProductScreen>(find.byType(ProductScreen)).productId,
    productId,
  );
  expect(find.text(_searchingText), findsNothing);
  expect(find.text(_unavailableTitle), findsNothing);
  expect(find.text(_couldNotCheckTitle), findsNothing);
}

void _expectGone(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.byType(ProductUnavailable), findsOneWidget);
  expect(find.text(_unavailableTitle), findsOneWidget);
  expect(find.text(_searchingText), findsNothing);
  expect(find.text(_couldNotCheckTitle), findsNothing);
}

void _expectCouldNotCheck(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.text(_couldNotCheckTitle), findsOneWidget);
  expect(find.text(_checkConnection), findsOneWidget);
  expect(find.text(_retryLabel), findsOneWidget);
  expect(find.text(_searchingText), findsNothing);
  expect(
    find.text(_unavailableTitle),
    findsNothing,
    reason: 'a lookup that could not run must not claim the piece is gone',
  );
  expect(find.byType(ProductScreen), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CHAR-02 AppDestination.fromNotification', () {
    test('CHAR-02 a shopify: product key resolves to a product', () {
      final destination = AppDestination.fromNotification(
        _route('product', productKey: 'shopify:$_gid'),
      );

      expect(
        destination,
        isA<ProductDestination>()
            .having((d) => d.productId, 'productId', _gid)
            .having((d) => d.initialVariantIndex, 'initialVariantIndex', 0),
      );
      expect(destination.origin, NavigationOrigin.notification);
    });

    test('CHAR-02 a product key without prefix resolves to the same product',
        () {
      final destination = AppDestination.fromNotification(
        _route('product', productKey: _gid),
      );

      expect(
        destination,
        isA<ProductDestination>().having((d) => d.productId, 'productId', _gid),
      );
      expect(destination.origin, NavigationOrigin.notification);
    });

    test('CHAR-02 an external: product key resolves to an unavailable link',
        () {
      final destination = AppDestination.fromNotification(
        _route('product', productKey: 'external:abc-123'),
      );

      expect(destination, isA<UnavailableLinkDestination>());
      expect(destination.origin, NavigationOrigin.notification);
    });

    test('CHAR-02 a collection with a handle resolves to a collection', () {
      final destination = AppDestination.fromNotification(
        _route('collection', handle: 'anillos'),
      );

      expect(
        destination,
        isA<CollectionDestination>()
            .having((d) => d.handle, 'handle', 'anillos')
            .having((d) => d.title, 'title', isNull),
      );
      expect(destination.origin, NavigationOrigin.notification);
    });

    test('CHAR-02 a collection without a handle resolves to the home', () {
      final destination = AppDestination.fromNotification(
        _route('collection'),
      );

      expect(destination, isA<HomeDestination>());
      expect(destination.origin, NavigationOrigin.notification);
    });

    test('CHAR-02 a product without a key resolves to the home', () {
      final destination = AppDestination.fromNotification(_route('product'));

      expect(destination, isA<HomeDestination>());
      expect(destination.origin, NavigationOrigin.notification);
    });

    test('CHAR-02 an unknown type resolves to the home', () {
      final destination = AppDestination.fromNotification(
        _route('surprise', productKey: 'shopify:$_gid', handle: 'anillos'),
      );

      expect(destination, isA<HomeDestination>());
      expect(destination.origin, NavigationOrigin.notification);
    });

    test('CHAR-02 the home type resolves to the home', () {
      final destination = AppDestination.fromNotification(_route('home'));

      expect(destination, isA<HomeDestination>());
      expect(destination.origin, NavigationOrigin.notification);
    });
  });

  group('CHAR-02 DestinationNavigator.open', () {
    testWidgets(
      'CHAR-02 a product already in the cache opens its page with the chosen '
      'variant and does not refresh',
      (tester) async {
        final env = await _mount(tester);
        addProducts(
          env.store,
          [syntheticProduct(id: _gid, variants: chipVariants())],
        );

        await env.open(const ProductDestination(_gid, initialVariantIndex: 2));

        _expectProductOpen(tester, _gid);
        expect(
          tester
              .widget<ProductScreen>(find.byType(ProductScreen))
              .initialVariantIndex,
          2,
        );
        expect(env.refresh.calls, 0);
      },
    );

    testWidgets(
      'CHAR-02 a product outside the cache shows "Buscando el artículo…" '
      'while the catalog refreshes, then replaces that screen with the page',
      (tester) async {
        final pending = Completer<CatalogSyncResult>();
        final env = await _mount(tester, answer: () => pending.future);
        expect(env.store.products.any((p) => p.id == _gid), isFalse);

        await env.open(const ProductDestination(_gid));

        expect(env.refresh.calls, 1);
        _expectSearching(tester);

        addProducts(env.store, [_missingProduct()]);
        pending.complete(
          const CatalogSyncResult(outcome: CatalogSyncOutcome.updated),
        );
        await _frames(tester);

        _expectProductOpen(tester, _gid);
        expect(env.refresh.calls, 1);

        // The search screen was replaced, not stacked underneath.
        env.navigator.pop();
        await _frames(tester);
        expect(find.byType(ProductScreen), findsNothing);
        expect(find.text(_searchingText), findsNothing);
        expect(find.text(_homeMarker), findsOneWidget);
        expect(env.navigator.canPop(), isFalse);
      },
    );

    for (final outcome in [
      CatalogSyncOutcome.upToDate,
      CatalogSyncOutcome.updated,
    ]) {
      testWidgets(
        'CHAR-02 a product still missing after a refresh that ended '
        '${outcome.name} shows that it is no longer available',
        (tester) async {
          final env = await _mount(tester, answer: () => _result(outcome));

          await env.open(const ProductDestination(_gid));

          expect(env.refresh.calls, 1);
          _expectGone(tester);
          expect(find.text(_retryLabel), findsNothing);
        },
      );
    }

    for (final outcome in [
      CatalogSyncOutcome.failed,
      CatalogSyncOutcome.skippedNotConfigured,
      CatalogSyncOutcome.skippedRealtimeAuthoritative,
    ]) {
      testWidgets(
        'CHAR-02 a product outside the cache with a refresh that ended '
        '${outcome.name} offers to retry instead of claiming it is gone',
        (tester) async {
          final env = await _mount(tester, answer: () => _result(outcome));

          await env.open(const ProductDestination(_gid));

          expect(env.refresh.calls, 1);
          _expectCouldNotCheck(tester);
        },
      );
    }

    testWidgets(
      'CHAR-02 a product outside the cache with a refresh that throws offers '
      'to retry instead of claiming it is gone',
      (tester) async {
        final env = await _mount(
          tester,
          answer: () => Future<CatalogSyncResult>.error(
            StateError('transport down'),
          ),
        );

        await env.open(const ProductDestination(_gid));

        expect(env.refresh.calls, 1);
        _expectCouldNotCheck(tester);
      },
    );

    testWidgets(
      'CHAR-02 "Reintentar" repeats the lookup and opens the page once the '
      'product appears',
      (tester) async {
        final env = await _mount(
          tester,
          answer: () => _result(CatalogSyncOutcome.failed),
        );
        await env.open(const ProductDestination(_gid));
        _expectCouldNotCheck(tester);
        expect(env.refresh.calls, 1);

        env.refresh.answer = () async {
          addProducts(env.store, [_missingProduct()]);
          return const CatalogSyncResult(outcome: CatalogSyncOutcome.updated);
        };
        await tester.tap(find.text(_retryLabel));
        await _frames(tester);

        expect(env.refresh.calls, 2);
        _expectProductOpen(tester, _gid);

        env.navigator.pop();
        await _frames(tester);
        expect(find.byType(ProductScreen), findsNothing);
        expect(find.text(_couldNotCheckTitle), findsNothing);
        expect(find.text(_homeMarker), findsOneWidget);
        expect(env.navigator.canPop(), isFalse);
      },
    );

    testWidgets(
      'CHAR-02 "Reintentar" with the product still gone shows that it is no '
      'longer available',
      (tester) async {
        final env = await _mount(
          tester,
          answer: () => _result(CatalogSyncOutcome.failed),
        );
        await env.open(const ProductDestination(_gid));
        _expectCouldNotCheck(tester);

        env.refresh.answer = () => _result(CatalogSyncOutcome.upToDate);
        await tester.tap(find.text(_retryLabel));
        await _frames(tester);

        expect(env.refresh.calls, 2);
        _expectGone(tester);
      },
    );

    testWidgets(
      'CHAR-02 "Reintentar" that fails again keeps offering to retry',
      (tester) async {
        final env = await _mount(
          tester,
          answer: () => _result(CatalogSyncOutcome.failed),
        );
        await env.open(const ProductDestination(_gid));

        await tester.tap(find.text(_retryLabel));
        await _frames(tester);

        expect(env.refresh.calls, 2);
        _expectCouldNotCheck(tester);
      },
    );

    testWidgets(
      'CHAR-02 a collection destination opens the collection by handle, '
      'titled with the handle when there is no title',
      (tester) async {
        final env = await _mount(tester);

        await env.open(const CollectionDestination('anillos'));

        expect(tester.takeException(), isNull);
        final screen = tester.widget<CollectionScreen>(
          find.byType(CollectionScreen),
        );
        expect(screen.title, 'anillos');
        expect(screen.filter.collectionHandle, 'anillos');
        expect(env.refresh.calls, 0);
      },
    );

    testWidgets(
      'CHAR-02 a collection destination with a title opens the collection '
      'with that title',
      (tester) async {
        final env = await _mount(tester);

        await env
            .open(const CollectionDestination('anillos', title: 'Anillos'));

        expect(tester.takeException(), isNull);
        final screen = tester.widget<CollectionScreen>(
          find.byType(CollectionScreen),
        );
        expect(screen.title, 'Anillos');
        expect(screen.filter.collectionHandle, 'anillos');
      },
    );

    testWidgets(
      'CHAR-02 an unavailable-link destination explains it and "Ir al inicio" '
      'returns to the first route',
      (tester) async {
        final env = await _mount(tester);
        await _pushMiddle(env);

        await env.open(const UnavailableLinkDestination());

        expect(tester.takeException(), isNull);
        expect(find.text(_deadLinkTitle), findsOneWidget);
        expect(find.text(_deadLinkBody), findsOneWidget);
        expect(find.text(_goHomeLabel), findsOneWidget);
        expect(env.refresh.calls, 0);

        await tester.tap(find.text(_goHomeLabel));
        await _frames(tester);

        expect(find.text(_deadLinkTitle), findsNothing);
        expect(find.text(_middleMarker, skipOffstage: false), findsNothing);
        expect(find.text(_homeMarker), findsOneWidget);
        expect(env.navigator.canPop(), isFalse);
      },
    );

    testWidgets(
      'CHAR-02 a home destination pops back to the first route',
      (tester) async {
        final env = await _mount(tester);
        await _pushMiddle(env);

        await env.open(const HomeDestination());

        expect(tester.takeException(), isNull);
        expect(find.text(_middleMarker, skipOffstage: false), findsNothing);
        expect(find.text(_homeMarker), findsOneWidget);
        expect(env.navigator.canPop(), isFalse);
        expect(env.refresh.calls, 0);
      },
    );
  });
}
