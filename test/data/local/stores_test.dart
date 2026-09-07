import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/catalog_cache_store.dart';
import 'package:monetta_app/data/local/database.dart' hide InteractionEvent;
import 'package:monetta_app/data/local/interaction_event_store.dart';
import 'package:monetta_app/data/local/sync_cursor_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/shopify/catalog_sync.dart' as shopify;
import 'package:monetta_app/domain/collection.dart';
import 'package:monetta_app/domain/product.dart';
import 'package:monetta_app/reco/events.dart';

Product _product({
  String id = 'p1',
  List<String> tags = const ['tag "with" quotes', 'crossbody'],
  List<ProductVariant> variants = const [],
}) {
  return Product(
    id: id,
    handle: 'h-$id',
    title: 'Título con acentos y é',
    vendor: 'Monetta',
    productType: 'Bolsa',
    tags: tags,
    variants: variants,
    images: const ['https://example.com/a.jpg'],
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
    collectionHandles: const ['nuevo'],
    brandOverride: 'guess',
  );
}

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  group('CatalogCacheStore', () {
    test('round-trips products including special characters in JSON columns',
        () async {
      final store = CatalogCacheStore(db);
      expect(await store.isEmpty(), isTrue);

      final product = _product(
        variants: const [
          ProductVariant(
              id: 'v1', title: 'Default Title', price: 1999, available: true),
        ],
      );
      await store.upsertProducts([product]);

      expect(await store.isEmpty(), isFalse);
      final loaded = await store.allProducts();
      expect(loaded, hasLength(1));
      expect(loaded.single.tags, product.tags);
      expect(loaded.single.title, product.title);
      expect(loaded.single.variants.single.price, 1999);
      expect(loaded.single.brandOverride, 'guess');
    });

    test('re-upserting a product replaces its variant set instead of appending',
        () async {
      final store = CatalogCacheStore(db);
      await store.upsertProducts([
        _product(
          variants: const [
            ProductVariant(id: 'v1', title: 'A', price: 10, available: true),
            ProductVariant(id: 'v2', title: 'B', price: 20, available: true),
          ],
        ),
      ]);
      await store.upsertProducts([
        _product(
          variants: const [
            ProductVariant(id: 'v1', title: 'A', price: 15, available: false),
          ],
        ),
      ]);

      final loaded = await store.allProducts();
      expect(loaded.single.variants, hasLength(1));
      expect(loaded.single.variants.single.price, 15);
      expect(loaded.single.variants.single.available, isFalse);
    });

    test('collections round-trip', () async {
      final store = CatalogCacheStore(db);
      await store.upsertCollections(const [
        Collection(id: 'c1', handle: 'nuevo', title: 'Nuevo', productCount: 3),
      ]);
      final loaded = await store.allCollections();
      expect(loaded.single.title, 'Nuevo');
      expect(loaded.single.productCount, 3);
    });
  });

  group('SyncCursorStore', () {
    test('load() before any save returns the first-run cursor', () async {
      final store = SyncCursorStore(db);
      final cursor = await store.load();
      expect(cursor.isFirstRun, isTrue);
    });

    test('save() then load() round-trips as UTC and survives a second save',
        () async {
      final store = SyncCursorStore(db);
      await store
          .save(shopify.SyncCursor(lastUpdatedAt: DateTime.utc(2026, 3, 1)));
      await store.save(
        shopify.SyncCursor(
          lastUpdatedAt: DateTime.utc(2026, 3, 1),
          lastFullSyncAt: DateTime.utc(2026, 3, 1),
        ),
      );

      final cursor = await store.load();
      expect(cursor.lastUpdatedAt!.isUtc, isTrue);
      expect(cursor.lastUpdatedAt, DateTime.utc(2026, 3, 1));
      expect(cursor.lastFullSyncAt, DateTime.utc(2026, 3, 1));
    });
  });

  group('WishlistStore', () {
    test('add/remove and device-to-account merge', () async {
      final store = WishlistStore(db);
      await store.add('p1');
      await store.add('p2');
      expect(await store.allProductIds(), {'p1', 'p2'});

      await store.remove('p1');
      expect(await store.allProductIds(), {'p2'});

      await store.add('p3', accountId: 'other-account');
      await store.mergeDeviceItemsIntoAccount('acct-1');

      expect(await store.allProductIds(accountId: 'acct-1'), {'p2'});
      expect(await store.allProductIds(accountId: 'other-account'), {'p3'});
      expect(await store.allProductIds(), isEmpty);
    });

    test('account scopes never leak across reads', () async {
      final store = WishlistStore(db);
      await store.add('p1', accountId: 'acct-a');
      await store.add('p2', accountId: 'acct-b');
      expect(await store.allProductIds(accountId: 'acct-a'), {'p1'});
      expect(await store.allProductIds(accountId: 'acct-b'), {'p2'});
    });
  });

  group('BagStore', () {
    test('upsert, remove, clear and merge', () async {
      final store = BagStore(db);
      await store.upsert(productId: 'p1', variantId: 'v1', quantity: 2);
      await store.upsert(productId: 'p1', variantId: 'v1', quantity: 3);

      final all = await store.all();
      expect(all, hasLength(1));
      expect(all.single.variantId, 'v1');
      expect(all.single.quantity, 3);

      await store.mergeDeviceItemsIntoAccount('acct-1');
      final scoped = await store.all(accountId: 'acct-1');
      expect(scoped.single.variantId, 'v1');
      expect(scoped.single.quantity, 3);

      await store.remove('v1', accountId: 'acct-1');
      expect(await store.all(accountId: 'acct-1'), isEmpty);

      await store.upsert(productId: 'p2', variantId: 'v2', quantity: 1);
      await store.clear();
      expect(await store.all(), isEmpty);
    });

    test('two variants of the same product coexist', () async {
      final store = BagStore(db);
      await store.upsert(productId: 'p1', variantId: 'v-a', quantity: 1);
      await store.upsert(productId: 'p1', variantId: 'v-b', quantity: 2);
      final all = await store.all();
      expect(all.map((e) => e.variantId).toSet(), {'v-a', 'v-b'});
    });

    test('account scopes never leak across bag reads', () async {
      final store = BagStore(db);
      await store.upsert(
        productId: 'p1',
        variantId: 'v1',
        quantity: 1,
        accountId: 'acct-a',
      );
      await store.upsert(
        productId: 'p1',
        variantId: 'v1',
        quantity: 9,
        accountId: 'acct-b',
      );
      expect((await store.all(accountId: 'acct-a')).single.quantity, 1);
      expect((await store.all(accountId: 'acct-b')).single.quantity, 9);
    });
  });

  group('InteractionEventStore', () {
    test('records events and returns them oldest-first', () async {
      final store = InteractionEventStore(db);
      await store.record(
        InteractionEvent(
          type: EventType.productView,
          timestamp: DateTime.utc(2026, 1, 2),
          productId: 'p1',
          dwellMs: 4000,
        ),
      );
      await store.record(
        InteractionEvent(
          type: EventType.addToCart,
          timestamp: DateTime.utc(2026, 1, 1),
          productId: 'p1',
        ),
      );

      final events = await store.all();
      expect(events, hasLength(2));
      expect(events.first.type, EventType.addToCart);
      expect(events.last.type, EventType.productView);
      expect(events.last.dwellMs, 4000);
    });
  });

  group('AccountStore / DeviceStore / SessionStore', () {
    test(
        'account upsert, lookup by shopify id, device attach, session lifecycle',
        () async {
      final accounts = AccountStore(db);
      final devices = DeviceStore(db);
      final sessions = SessionStore(db);

      await accounts.upsert(
        localAccountId: 'acct-1',
        shopifyCustomerId: 'gid://shopify/Customer/1',
        email: 'shopper@example.com',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final byShopifyId =
          await accounts.byShopifyCustomerId('gid://shopify/Customer/1');
      expect(byShopifyId?.localAccountId, 'acct-1');

      await devices.upsert(
          deviceId: 'dev-1', platform: 'ios', appVersion: '1.0.0');
      await devices.attachAccount('dev-1', 'acct-1');
      final device = await devices.byId('dev-1');
      expect(device?.accountId, 'acct-1');

      await sessions.save(
        accountId: 'acct-1',
        secureStorageKeyRef: 'session/acct-1',
        accessTokenExpiresAt: DateTime.utc(2026, 1, 2),
      );

      var latest = await sessions.latestFor('acct-1');
      expect(latest?.secureStorageKeyRef, 'session/acct-1');

      // A second save (a silent refresh, most commonly) updates the same
      // row in place rather than accumulating a new one.
      await sessions.save(
        accountId: 'acct-1',
        secureStorageKeyRef: 'session/acct-1',
        accessTokenExpiresAt: DateTime.utc(2026, 1, 3),
      );
      final allSessions = await db.select(db.sessions).get();
      expect(allSessions, hasLength(1));
      latest = await sessions.latestFor('acct-1');
      // See `database_test.dart`'s note on Drift's UTC/local DateTime
      // round-trip — compare by instant, not by `==`.
      expect(
        latest!.accessTokenExpiresAt.isAtSameMomentAs(DateTime.utc(2026, 1, 3)),
        isTrue,
      );

      await sessions.deleteFor('acct-1');
      expect(await sessions.latestFor('acct-1'), isNull);
    });

    test('deleting an account cascades to its sessions', () async {
      final accounts = AccountStore(db);
      final sessions = SessionStore(db);
      await accounts.upsert(
          localAccountId: 'acct-1', createdAt: DateTime.utc(2026, 1, 1));
      await sessions.save(
        accountId: 'acct-1',
        secureStorageKeyRef: 'ref',
        accessTokenExpiresAt: DateTime.utc(2026, 1, 2),
      );

      await (db.delete(db.accounts)
            ..where((t) => t.localAccountId.equals('acct-1')))
          .go();

      expect(await sessions.latestFor('acct-1'), isNull);
    });
  });
}
