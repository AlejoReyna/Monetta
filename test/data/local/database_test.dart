import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  group('AppDatabase', () {
    test('opens and reports schema version 1', () {
      expect(db.schemaVersion, 1);
    });

    test('round-trips a cached product and its variants', () async {
      await db.into(db.cachedProducts).insert(
            CachedProductsCompanion.insert(
              id: 'gid://shopify/Product/1',
              handle: 'guess-tote',
              title: 'GUESS Tote',
              vendor: 'Monetta',
              productType: 'Bolsa',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.into(db.cachedVariants).insert(
            CachedVariantsCompanion.insert(
              id: 'gid://shopify/ProductVariant/1',
              productId: 'gid://shopify/Product/1',
              title: 'Default Title',
              price: 1999.0,
              available: true,
            ),
          );

      final products = await db.select(db.cachedProducts).get();
      final variants = await db.select(db.cachedVariants).get();

      expect(products, hasLength(1));
      expect(products.single.title, 'GUESS Tote');
      expect(variants, hasLength(1));
      expect(variants.single.productId, 'gid://shopify/Product/1');
    });

    test('cascades variant deletion when the parent product is deleted', () async {
      await db.into(db.cachedProducts).insert(
            CachedProductsCompanion.insert(
              id: 'p1',
              handle: 'h',
              title: 't',
              vendor: 'v',
              productType: 'pt',
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.into(db.cachedVariants).insert(
            CachedVariantsCompanion.insert(
              id: 'v1',
              productId: 'p1',
              title: 'Default Title',
              price: 10.0,
              available: true,
            ),
          );

      await (db.delete(db.cachedProducts)..where((t) => t.id.equals('p1')))
          .go();

      expect(await db.select(db.cachedVariants).get(), isEmpty);
    });

    test('sync cursor upsert keeps a single row', () async {
      // The `id` primary key must always be passed explicitly: SQLite
      // auto-assigns a fresh rowid for an omitted INTEGER PRIMARY KEY
      // regardless of `withDefault`, which would silently defeat the
      // upsert's ON CONFLICT clause and insert a second row instead.
      await db.into(db.syncCursors).insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              id: const Value(0),
              lastUpdatedAt: Value(DateTime.utc(2026, 1, 1)),
            ),
          );
      await db.into(db.syncCursors).insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              id: const Value(0),
              lastUpdatedAt: Value(DateTime.utc(2026, 2, 1)),
            ),
          );

      final rows = await db.select(db.syncCursors).get();
      expect(rows, hasLength(1));
      // Drift's default (non-text) DateTime storage reads back as local
      // time (`isUtc: false`) even though a UTC value was written — same
      // instant, different flag. Dart's `DateTime.==` is flag-sensitive, so
      // compare by instant rather than by `==`. Repository code must
      // normalize with `.toUtc()` before handing a value to
      // `data/shopify`'s `SyncCursor`, which assumes UTC throughout.
      expect(
        rows.single.lastUpdatedAt!.isAtSameMomentAs(DateTime.utc(2026, 2, 1)),
        isTrue,
      );
    });

    test('wishlist item primary key rejects a duplicate product insert', () async {
      await db.into(db.wishlistItems).insert(
            WishlistItemsCompanion.insert(
              productId: 'p1',
              addedAt: DateTime.utc(2026, 1, 1),
            ),
          );

      expect(
        () => db.into(db.wishlistItems).insert(
              WishlistItemsCompanion.insert(
                productId: 'p1',
                addedAt: DateTime.utc(2026, 1, 2),
              ),
            ),
        throwsA(anything),
      );
    });

    test('a session cascades away when its account is deleted', () async {
      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              localAccountId: 'a1',
              createdAt: DateTime.utc(2026, 1, 1),
              lastSeenAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              accountId: 'a1',
              secureStorageKeyRef: 'session/a1',
              accessTokenExpiresAt: DateTime.utc(2026, 1, 2),
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          );

      await (db.delete(db.accounts)..where((t) => t.localAccountId.equals('a1')))
          .go();

      expect(await db.select(db.sessions).get(), isEmpty);
    });
  });
}
