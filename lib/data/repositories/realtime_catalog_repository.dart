library;

import 'dart:async';

import '../../domain/product.dart';
import '../firestore/catalog_realtime_source.dart';
import '../local/catalog_cache_store.dart';
import '../shopify/shopify_gid.dart';
import 'catalog_write_coordinator.dart';

enum RealtimeCatalogOutcome {
  applied,
  empty,
  invalid,
  error,
  disconnected,
}

class RealtimeCatalogUpdate {
  const RealtimeCatalogUpdate._(
    this.outcome, {
    this.products = const [],
    this.invalidDocumentIds = const [],
    this.error,
  });

  const RealtimeCatalogUpdate.applied(List<Product> products)
      : this._(RealtimeCatalogOutcome.applied, products: products);

  const RealtimeCatalogUpdate.empty() : this._(RealtimeCatalogOutcome.empty);

  const RealtimeCatalogUpdate.invalid(List<String> documentIds)
      : this._(
          RealtimeCatalogOutcome.invalid,
          invalidDocumentIds: documentIds,
        );

  const RealtimeCatalogUpdate.error(Object error)
      : this._(RealtimeCatalogOutcome.error, error: error);

  const RealtimeCatalogUpdate.disconnected()
      : this._(RealtimeCatalogOutcome.disconnected);

  final RealtimeCatalogOutcome outcome;
  final List<Product> products;
  final List<String> invalidDocumentIds;
  final Object? error;
}

typedef RealtimeRetryDelay = Future<void> Function(Duration duration);

/// Validates full Firestore snapshots before atomically replacing the cache.
///
/// Empty or partially-invalid snapshots are deliberately ignored: neither is
/// strong enough evidence that a previously valid local catalog should be
/// erased. A stream error is surfaced and the source is subscribed again with
/// bounded exponential backoff; Firestore also performs its own transport
/// reconnection while an individual subscription remains open.
class RealtimeCatalogRepository {
  RealtimeCatalogRepository({
    required CatalogRealtimeSource source,
    required CatalogCacheStore cache,
    CatalogWriteCoordinator? writeCoordinator,
    RealtimeRetryDelay retryDelay = _defaultRetryDelay,
  })  : _source = source,
        _cache = cache,
        _writeCoordinator =
            writeCoordinator ?? CatalogWriteCoordinator(expectsFirestore: true),
        _retryDelay = retryDelay;

  final CatalogRealtimeSource _source;
  final CatalogCacheStore _cache;
  final CatalogWriteCoordinator _writeCoordinator;
  final RealtimeRetryDelay _retryDelay;

  Stream<RealtimeCatalogUpdate> watch() async* {
    var retryAttempt = 0;
    while (true) {
      try {
        await for (final documents in _source.watchProducts()) {
          retryAttempt = 0;
          yield await applySnapshot(documents);
        }
        yield const RealtimeCatalogUpdate.disconnected();
      } catch (error) {
        yield RealtimeCatalogUpdate.error(error);
      }

      await _retryDelay(_backoff(retryAttempt));
      if (retryAttempt < 5) retryAttempt += 1;
    }
  }

  Future<RealtimeCatalogUpdate> applySnapshot(
    List<CatalogRealtimeDocument> documents,
  ) async {
    if (documents.isEmpty) return const RealtimeCatalogUpdate.empty();

    final products = <Product>[];
    final invalidDocumentIds = <String>[];
    for (final document in documents) {
      try {
        products.add(_productFromDocument(document));
      } catch (_) {
        invalidDocumentIds.add(document.documentId);
      }
    }

    if (invalidDocumentIds.isNotEmpty) {
      return RealtimeCatalogUpdate.invalid(invalidDocumentIds);
    }

    await _writeCoordinator.runFirestoreWrite(
      () => _cache.replaceProducts(products),
    );
    return RealtimeCatalogUpdate.applied(products);
  }

  static Product _productFromDocument(CatalogRealtimeDocument document) {
    final data = document.data;
    if (_integer(data['schemaVersion'], 'schemaVersion') != 1) {
      throw const FormatException('Unsupported catalog schema');
    }
    if (_string(data['source'], 'source') != 'shopify') {
      throw const FormatException('Unexpected catalog source');
    }
    final legacyId = _string(data['shopifyLegacyId'], 'shopifyLegacyId');
    if (legacyId != document.documentId) {
      throw const FormatException('Document id does not match product');
    }
    if (data['isPublished'] != true) {
      throw const FormatException('Product is not published');
    }

    final variantsRaw = _list(data['variants'], 'variants');
    final variants = <ProductVariant>[];
    for (final value in variantsRaw) {
      if (value is! Map) throw const FormatException('Invalid variant');
      final variant = Map<String, Object?>.from(value);
      variants.add(
        ProductVariant(
          id: _variantGid(variant['id']),
          title: _string(variant['title'], 'variant.title'),
          price: _money(variant['price'], 'variant.price'),
          available: _boolean(variant['available'], 'variant.available'),
          compareAtPrice: _nullableMoney(
            variant['compareAtPrice'],
            'variant.compareAtPrice',
          ),
          sku: _nullableString(variant['sku'], 'variant.sku'),
        ),
      );
    }

    return Product(
      id: _productGid(data['id'], legacyId),
      handle: _string(data['handle'], 'handle'),
      title: _string(data['title'], 'title'),
      vendor: _string(data['vendor'], 'vendor'),
      productType: _string(
        data['productType'],
        'productType',
        allowEmpty: true,
      ),
      tags: _stringList(data['tags'], 'tags'),
      variants: variants,
      images: _stringList(data['images'], 'images'),
      createdAt: _date(data['createdAt'], 'createdAt'),
      updatedAt: _date(data['updatedAt'], 'updatedAt'),
      descriptionHtml: _string(
        data['descriptionHtml'],
        'descriptionHtml',
        allowEmpty: true,
      ),
      collectionHandles: _stringList(
        data['collectionHandles'],
        'collectionHandles',
      ),
      brandOverride: _nullableString(data['brandOverride'], 'brandOverride'),
      categoryOverride: _nullableString(
        data['categoryOverride'],
        'categoryOverride',
      ),
    );
  }

  static String _string(
    Object? value,
    String field, {
    bool allowEmpty = false,
  }) {
    if (value is String && (allowEmpty || value.isNotEmpty)) return value;
    throw FormatException('Invalid $field');
  }

  static String? _nullableString(Object? value, String field) {
    if (value == null) return null;
    return _string(value, field);
  }

  static int _integer(Object? value, String field) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException('Invalid $field');
  }

  static bool _boolean(Object? value, String field) {
    if (value is bool) return value;
    throw FormatException('Invalid $field');
  }

  static List<Object?> _list(Object? value, String field) {
    if (value is List) return List<Object?>.from(value);
    throw FormatException('Invalid $field');
  }

  static List<String> _stringList(Object? value, String field) {
    final values = _list(value, field);
    if (values.any((item) => item is! String)) {
      throw FormatException('Invalid $field');
    }
    return values.cast<String>();
  }

  static double _money(Object? value, String field) {
    if (value is num && value.isFinite && value >= 0) return value.toDouble();
    throw FormatException('Invalid $field');
  }

  static double? _nullableMoney(Object? value, String field) {
    if (value == null) return null;
    return _money(value, field);
  }

  static DateTime _date(Object? value, String field) {
    if (value is! String) throw FormatException('Invalid $field');
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Invalid $field');
    return parsed.toUtc();
  }

  static String _productGid(Object? value, String legacyId) {
    final gid = shopifyProductGid(value);
    if (gid != shopifyProductGid(legacyId)) {
      throw const FormatException('Product GID does not match legacy id');
    }
    return gid;
  }

  static String _variantGid(Object? value) => shopifyVariantGid(value);

  static Duration _backoff(int attempt) => Duration(
        seconds: 1 << attempt.clamp(0, 5),
      );

  static Future<void> _defaultRetryDelay(Duration duration) =>
      Future<void>.delayed(duration);
}
