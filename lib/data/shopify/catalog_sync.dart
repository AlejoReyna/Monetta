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
  const SyncCursor({
    this.lastUpdatedAt,
    this.lastFullSyncAt,
    this.shopDomain,
  });

  /// Highest `updatedAt` we have already stored. Null means "never synced".
  final DateTime? lastUpdatedAt;

  final DateTime? lastFullSyncAt;

  /// Storefront shop host that produced this cursor. Null on legacy rows.
  final String? shopDomain;

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

  SyncCursor advancedTo(
    DateTime? highest, {
    DateTime? fullSyncAt,
    String? shopDomain,
  }) {
    final current = lastUpdatedAt;
    final next = highest == null
        ? current
        : (current == null || highest.isAfter(current) ? highest : current);
    return SyncCursor(
      lastUpdatedAt: next,
      lastFullSyncAt: fullSyncAt ?? lastFullSyncAt,
      shopDomain: shopDomain ?? this.shopDomain,
    );
  }

  SyncCursor withShop(String shopDomain) => SyncCursor(
        lastUpdatedAt: lastUpdatedAt,
        lastFullSyncAt: lastFullSyncAt,
        shopDomain: shopDomain,
      );
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

/// Raised when pagination or nested connections cannot be proven complete.
///
/// Callers must **not** advance successful-sync metadata (cursor / fullSyncAt /
/// healthy provenance) when this is thrown — a truncated page set must never
/// look like a successful sync, especially before a destructive full replace.
class CatalogSyncIncompleteException implements Exception {
  const CatalogSyncIncompleteException(this.message);
  final String message;

  @override
  String toString() => 'CatalogSyncIncompleteException: $message';
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

  /// Hard stop on pagination. Hitting this with `hasNextPage` still true is an
  /// incomplete sync, not success — see [CatalogSyncIncompleteException].
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
  /// Throws [CatalogSyncIncompleteException] when the page set cannot be proven
  /// complete — callers must preserve last-known-good cache and cursor.
  Future<SyncResult> run({
    required SyncCursor cursor,
    required DateTime now,
  }) async {
    final full = needsFullSync(cursor, now);
    final filter = full ? null : cursor.deltaFilter;
    final shopDomain = client.config.shopDomain;

    final products = <Product>[];
    String? after;
    var pages = 0;
    DateTime? highest;

    while (true) {
      if (pages >= maxPages) {
        throw const CatalogSyncIncompleteException(
          'Product pagination exceeded maxPages while hasNextPage was still true',
        );
      }

      final data = await client.query(
        kProductsDeltaQuery,
        variables: <String, dynamic>{
          'first': pageSize,
          if (after != null) 'after': after,
          if (filter != null) 'query': filter,
          'country': client.config.country,
          'language': client.config.language,
        },
      );

      final connection = data['products'];
      final nodes = _validatedNodes(connection);
      pages++;

      for (final node in nodes) {
        final product = await completeProduct(node);
        products.add(product);
        if (highest == null || product.updatedAt.isAfter(highest)) {
          highest = product.updatedAt;
        }
      }

      final pageInfo = connection is Map ? connection['pageInfo'] : null;
      if (pageInfo is! Map || pageInfo['hasNextPage'] != true) {
        break;
      }

      final endCursor = pageInfo['endCursor'];
      if (endCursor is! String || endCursor.isEmpty) {
        throw const CatalogSyncIncompleteException(
          'hasNextPage true but endCursor missing — refusing incomplete sync',
        );
      }
      if (after != null && endCursor == after) {
        throw const CatalogSyncIncompleteException(
          'Repeated pagination cursor without advancing — refusing incomplete sync',
        );
      }
      after = endCursor;
    }

    return SyncResult(
      products: products,
      cursor: cursor.advancedTo(
        highest,
        fullSyncAt: full ? now : null,
        shopDomain: shopDomain,
      ),
      wasFullSync: full,
      pagesFetched: pages,
    );
  }

  /// All cache writers, including focused featured reads, must use this
  /// before replacing a product's authoritative variants/membership.
  Future<Product> completeProduct(Map<String, dynamic> node) async {
    await _completeRequiredConnections(node);
    return productFromJson(node);
  }

  // Images are an intentional six-image display preview. Variants and
  // collection membership are authoritative and must be fully fetched.
  Future<void> _completeRequiredConnections(Map<String, dynamic> node) async {
    for (final field in const ['variants', 'collections']) {
      var connection = node[field];
      final nodes = _validatedNodes(connection);
      final seen = <String>{};
      var pages = 1;
      while (((connection as Map)['pageInfo'] as Map)['hasNextPage'] == true) {
        final after = (connection['pageInfo'] as Map)['endCursor'] as String;
        if (!seen.add(after) || pages++ >= maxPages) {
          throw const CatalogSyncIncompleteException(
            'Nested pagination did not complete',
          );
        }
        final data = await client.query(
          productConnectionQuery(field),
          variables: {
            'id': node['id'],
            'after': after,
            'country': client.config.country,
            'language': client.config.language,
          },
        );
        final product = data['product'];
        connection = product is Map ? product[field] : null;
        nodes.addAll(_validatedNodes(connection));
      }
      node[field] = {
        'edges': [
          for (final n in nodes) {'node': n},
        ],
        'pageInfo': {'hasNextPage': false, 'endCursor': null},
      };
    }
  }

  static List<Map<String, dynamic>> _validatedNodes(dynamic connection) {
    const invalid = CatalogSyncIncompleteException(
      'Invalid connection or pagination metadata',
    );
    if (connection is! Map) throw invalid;
    final info = connection['pageInfo'];
    if (info is! Map ||
        !info.containsKey('endCursor') ||
        info['hasNextPage'] is! bool ||
        (info['endCursor'] != null && info['endCursor'] is! String) ||
        (info['hasNextPage'] == true &&
            (info['endCursor'] is! String ||
                (info['endCursor'] as String).isEmpty))) {
      throw invalid;
    }
    final List<Map<String, dynamic>> nodes;
    if (connection.containsKey('nodes')) {
      final raw = connection['nodes'];
      if (raw is! List ||
          raw.any((n) => n is! Map || n.keys.any((k) => k is! String))) {
        throw invalid;
      }
      nodes = [for (final n in raw) Map<String, dynamic>.from(n as Map)];
    } else {
      final raw = connection['edges'];
      if (raw is! List ||
          raw.any((e) => e is! Map || e['node'] is! Map<String, dynamic>)) {
        throw invalid;
      }
      nodes = [
        for (final edge in raw)
          Map<String, dynamic>.from((edge as Map)['node'] as Map),
      ];
    }
    return nodes;
  }
}
