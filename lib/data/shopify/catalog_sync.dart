/// Delta catalog sync — the mechanism behind "the owner adds products in
/// Shopify and the app just has them".
///
/// Pure Dart, deterministic, no clock access. There is deliberately **no sync
/// job**: the app reads Shopify live and remembers a high-water mark, so the
/// steady state is a request that returns nothing.
library;

import '../../domain/product.dart';
import 'mappers.dart';
import 'queries.dart';
import 'storefront_client.dart';

/// Where the last successful sync got to.
class SyncCursor {
  const SyncCursor({this.lastUpdatedAt, this.lastFullSyncAt});

  /// Highest `updatedAt` we have already stored. Null means "never synced".
  final DateTime? lastUpdatedAt;

  final DateTime? lastFullSyncAt;

  bool get isFirstRun => lastUpdatedAt == null;

  /// The Shopify search filter for the next delta request.
  ///
  /// Returns null on first run, which means "fetch everything".
  ///
  /// The `>` is deliberately exclusive *and* we re-request the boundary second
  /// by subtracting one second: Shopify's `updated_at` has second granularity,
  /// so an exclusive filter on an exact match can silently skip a product saved
  /// in the same second as the previous sync's last record. Re-fetching a
  /// handful of products is free; missing one is invisible and permanent.
  String? get deltaFilter {
    final since = lastUpdatedAt;
    if (since == null) return null;
    final safe = since.subtract(const Duration(seconds: 1)).toUtc();
    return 'updated_at:>${_iso(safe)}';
  }

  static String _iso(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}T'
        '${utc.hour.toString().padLeft(2, '0')}:'
        '${utc.minute.toString().padLeft(2, '0')}:'
        '${utc.second.toString().padLeft(2, '0')}Z';
  }

  SyncCursor advancedTo(DateTime? highest, {DateTime? fullSyncAt}) {
    final current = lastUpdatedAt;
    final next = highest == null
        ? current
        : (current == null || highest.isAfter(current) ? highest : current);
    return SyncCursor(
      lastUpdatedAt: next,
      lastFullSyncAt: fullSyncAt ?? lastFullSyncAt,
    );
  }
}

class SyncResult {
  const SyncResult({
    required this.products,
    required this.cursor,
    required this.wasFullSync,
    required this.pagesFetched,
  });

  /// Products created or changed since the last sync. Usually empty.
  final List<Product> products;

  final SyncCursor cursor;
  final bool wasFullSync;
  final int pagesFetched;

  bool get hasChanges => products.isNotEmpty;
}

class CatalogSync {
  const CatalogSync({
    required this.client,
    this.pageSize = 250,
    this.maxPages = 20,
    this.fullResyncInterval = const Duration(days: 7),
  });

  final StorefrontClient client;

  /// Shopify's ceiling for this connection is 250.
  final int pageSize;

  /// Hard stop on pagination. 271 products fit in two pages today; 20 pages
  /// allows ~10× catalog growth while still guaranteeing the loop terminates
  /// if a cursor ever misbehaves.
  final int maxPages;

  /// Even with a healthy cursor, do a full resync occasionally. Deletions and
  /// unpublishes do not move `updated_at` on anything we can see, so a delta-only
  /// client would keep showing a product that was removed from the store.
  final Duration fullResyncInterval;

  bool needsFullSync(SyncCursor cursor, DateTime now) {
    if (cursor.isFirstRun) return true;
    final last = cursor.lastFullSyncAt;
    if (last == null) return true;
    return now.difference(last) >= fullResyncInterval;
  }

  /// Fetch everything that changed since [cursor].
  ///
  /// On a typical app open this makes one request that returns zero products.
  Future<SyncResult> run({
    required SyncCursor cursor,
    required DateTime now,
  }) async {
    final full = needsFullSync(cursor, now);
    final filter = full ? null : cursor.deltaFilter;

    final products = <Product>[];
    String? after;
    var pages = 0;
    DateTime? highest;

    while (pages < maxPages) {
      final data = await client.query(
        kProductsDeltaQuery,
        variables: <String, dynamic>{
          'first': pageSize,
          if (after != null) 'after': after,
          if (filter != null) 'query': filter,
        },
      );

      final connection = data['products'];
      final nodes = edgeNodes(connection);
      pages++;

      for (final node in nodes) {
        final product = productFromJson(node);
        products.add(product);
        if (highest == null || product.updatedAt.isAfter(highest)) {
          highest = product.updatedAt;
        }
      }

      final pageInfo = connection is Map ? connection['pageInfo'] : null;
      final hasNext = pageInfo is Map && pageInfo['hasNextPage'] == true;
      if (!hasNext) break;

      final endCursor = pageInfo is Map ? pageInfo['endCursor'] as String? : null;
      // Defensive: hasNextPage true with no cursor would spin forever.
      if (endCursor == null) break;
      after = endCursor;
    }

    return SyncResult(
      products: products,
      cursor: cursor.advancedTo(highest, fullSyncAt: full ? now : null),
      wasFullSync: full,
      pagesFetched: pages,
    );
  }
}
