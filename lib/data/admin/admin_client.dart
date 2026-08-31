/// Authenticated HTTP seam for the Monetta owner control plane.
///
/// Shopify Admin credentials stay on the server. The app sends the signed-in
/// owner's short-lived Shopify Customer access token; the service validates
/// it, checks the owner role, writes Shopify/configuration, and records audit.
library;

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../domain/admin_control.dart';

abstract interface class AdminClient {
  Future<AdminSnapshot> fetchSnapshot();

  Future<void> updateProduct(AdminProductRecord product);

  Future<void> updateStorefront(AdminStorefrontSettings settings);

  Future<void> updateSource(AdminSourcePolicy source);

  Future<void> syncAll();
}

abstract interface class FeaturedAdminClient {
  Future<AdminFeaturedCatalog> fetchFeaturedCatalog();

  Future<AdminFeaturedCatalog> setProductFeatured({
    required String productId,
    required bool featured,
    required DateTime expectedCollectionUpdatedAt,
  });

  Future<AdminFeaturedMutationResult> replaceFeaturedCatalog({
    required List<String> productIds,
    required DateTime expectedCollectionUpdatedAt,
  });
}

abstract interface class StorefrontAdminClient {
  Future<AdminStorefrontSettings> updateStorefrontCanonical(
    AdminStorefrontSettings settings,
  );
}

abstract interface class ProductAdminClient {
  Future<AdminProductRecord> updateProductCanonical({
    required AdminProductRecord before,
    required AdminProductRecord next,
  });
}

abstract interface class ExternalSourceAdminClient {
  Future<AdminSourcePolicy> updateSourceCanonical(AdminSourcePolicy source);
}

class AdminAuditPage {
  const AdminAuditPage({required this.events, this.nextCursor});

  final List<AdminAuditEvent> events;
  final String? nextCursor;
}

abstract interface class AuditAdminClient {
  Future<AdminAuditPage> fetchAudit({String? cursor});
}

class AdminClientException implements Exception {
  const AdminClientException(
    this.message, {
    this.statusCode,
    this.code,
    this.requestId,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final String? requestId;

  @override
  String toString() => 'AdminClientException($statusCode, $message)';
}

class HttpAdminClient
    implements
        AdminClient,
        FeaturedAdminClient,
        StorefrontAdminClient,
        ProductAdminClient,
        ExternalSourceAdminClient,
        AuditAdminClient {
  HttpAdminClient({
    required this.baseUrl,
    required this.accessTokenProvider,
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final Uri baseUrl;
  final Future<String?> Function() accessTokenProvider;
  final http.Client _client;
  final bool _ownsClient;
  final Random _random = Random.secure();

  @override
  Future<AdminSnapshot> fetchSnapshot() async {
    final response = await _send('GET', '/admin/control-plane');
    final root = _jsonObject(response.bodyBytes);
    final productRows = root['products'] as List<dynamic>? ?? const [];
    final sourceRows = root['sources'] as List<dynamic>? ?? const [];
    final storefront = root['storefront'];
    final health = root['health'];
    final healthMap = health is Map<String, dynamic> ? health : null;
    final shopifyHealth = healthMap?['shopify'];
    final sourcesHealth = healthMap?['sources'];

    return AdminSnapshot(
      products: productRows
          .whereType<Map<String, dynamic>>()
          .map(_productFromJson)
          .toList(),
      storefront: storefront is Map<String, dynamic>
          ? _storefrontFromJson(storefront)
          : AdminStorefrontSettings.defaults,
      sources: sourceRows
          .whereType<Map<String, dynamic>>()
          .map(_sourceFromJson)
          .toList(),
      featured: root['featuredCatalog'] is Map<String, dynamic>
          ? _featuredFromJson(
              root['featuredCatalog'] as Map<String, dynamic>,
              root['health'],
            )
          : null,
      shopifyHealthStatus: shopifyHealth is Map<String, dynamic>
          ? shopifyHealth['status'] as String?
          : null,
      sourcesHealthStatus: sourcesHealth is Map<String, dynamic>
          ? sourcesHealth['status'] as String?
          : null,
    );
  }

  @override
  Future<AdminAuditPage> fetchAudit({String? cursor}) async {
    final query =
        cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    final response = await _send('GET', '/admin/audit$query');
    final root = _jsonObject(response.bodyBytes);
    final rows = root['events'];
    if (rows is! List) {
      throw const AdminClientException('invalid audit response');
    }
    return AdminAuditPage(
      events: rows
          .whereType<Map<String, dynamic>>()
          .map(_auditFromJson)
          .toList(growable: false),
      nextCursor: root['nextCursor'] as String?,
    );
  }

  @override
  Future<AdminFeaturedCatalog> fetchFeaturedCatalog() async {
    final response = await _send('GET', '/admin/featured-catalog');
    final root = _jsonObject(response.bodyBytes);
    final featured = root['featuredCatalog'];
    if (featured is! Map<String, dynamic>) {
      throw const AdminClientException('invalid featured catalog response');
    }
    return _featuredFromJson(featured, root['health']);
  }

  @override
  Future<AdminFeaturedCatalog> setProductFeatured({
    required String productId,
    required bool featured,
    required DateTime expectedCollectionUpdatedAt,
  }) async {
    final response = await _send(
      'PUT',
      '/admin/featured-catalog/products/${Uri.encodeComponent(productId)}',
      idempotencyKey: _newIdempotencyKey(),
      body: {
        'featured': featured,
        'expectedCollectionUpdatedAt':
            expectedCollectionUpdatedAt.toUtc().toIso8601String(),
      },
    );
    final root = _jsonObject(response.bodyBytes);
    final value = root['featuredCatalog'];
    if (value is! Map<String, dynamic>) {
      throw const AdminClientException('featured catalog ordering is pending');
    }
    return _featuredFromJson(value, root['health']);
  }

  @override
  Future<AdminFeaturedMutationResult> replaceFeaturedCatalog({
    required List<String> productIds,
    required DateTime expectedCollectionUpdatedAt,
  }) async {
    final response = await _send(
      'PUT',
      '/admin/featured-catalog',
      idempotencyKey: _newIdempotencyKey(),
      body: {
        'productIds': productIds,
        'expectedCollectionUpdatedAt':
            expectedCollectionUpdatedAt.toUtc().toIso8601String(),
      },
    );
    final root = _jsonObject(response.bodyBytes);
    final value = root['featuredCatalog'];
    return AdminFeaturedMutationResult(
      catalog: value is Map<String, dynamic>
          ? _featuredFromJson(value, root['health'])
          : null,
      jobId: root['jobId'] as String?,
    );
  }

  @override
  Future<void> updateProduct(AdminProductRecord product) async {
    await updateProductCanonical(before: product, next: product);
  }

  @override
  Future<AdminProductRecord> updateProductCanonical({
    required AdminProductRecord before,
    required AdminProductRecord next,
  }) async {
    var canonical = before;
    final expectedUpdatedAt = canonical.updatedAt;
    if (expectedUpdatedAt == null) {
      throw const AdminClientException('producto sin versión de Shopify');
    }

    if (before.title != next.title) {
      canonical = await _updateProductTitle(
        productId: next.id,
        title: next.title,
        expectedUpdatedAt: canonical.updatedAt ?? expectedUpdatedAt,
      );
    }

    if (before.variants.length == 1 && next.variants.length == 1) {
      final oldVariant = before.variants.first;
      final nextVariant = next.variants.first;
      if (oldVariant.id == nextVariant.id &&
          oldVariant.price != nextVariant.price) {
        canonical = await _updateVariantPrice(
          productId: next.id,
          variantId: nextVariant.id,
          price: nextVariant.price,
          expectedProductUpdatedAt: canonical.updatedAt ?? expectedUpdatedAt,
        );
      }
    }

    if (before.publishedToMonetta != next.publishedToMonetta) {
      canonical = await _updatePublication(
        productId: next.id,
        published: next.publishedToMonetta,
        expectedUpdatedAt: canonical.updatedAt ?? expectedUpdatedAt,
      );
    }
    return canonical;
  }

  Future<AdminProductRecord> _updateProductTitle({
    required String productId,
    required String title,
    required DateTime expectedUpdatedAt,
  }) async {
    final response = await _send(
      'PATCH',
      '/admin/products/${Uri.encodeComponent(productId)}',
      idempotencyKey: _newIdempotencyKey(),
      body: {
        'title': title,
        'expectedUpdatedAt': expectedUpdatedAt.toUtc().toIso8601String(),
      },
    );
    return _productFromResponse(response);
  }

  Future<AdminProductRecord> _updateVariantPrice({
    required String productId,
    required String variantId,
    required double price,
    required DateTime expectedProductUpdatedAt,
  }) async {
    final response = await _send(
      'PATCH',
      '/admin/products/${Uri.encodeComponent(productId)}/variants/${Uri.encodeComponent(variantId)}',
      idempotencyKey: _newIdempotencyKey(),
      body: {
        'price': price.toStringAsFixed(2),
        'expectedProductUpdatedAt':
            expectedProductUpdatedAt.toUtc().toIso8601String(),
      },
    );
    return _productFromResponse(response);
  }

  Future<AdminProductRecord> _updatePublication({
    required String productId,
    required bool published,
    required DateTime expectedUpdatedAt,
  }) async {
    final response = await _send(
      'PUT',
      '/admin/products/${Uri.encodeComponent(productId)}/publication',
      idempotencyKey: _newIdempotencyKey(),
      body: {
        'published': published,
        'expectedUpdatedAt': expectedUpdatedAt.toUtc().toIso8601String(),
      },
    );
    return _productFromResponse(response);
  }

  @override
  Future<void> updateStorefront(AdminStorefrontSettings settings) async {
    await updateStorefrontCanonical(settings);
  }

  @override
  Future<AdminStorefrontSettings> updateStorefrontCanonical(
    AdminStorefrontSettings settings,
  ) async {
    final response = await _send(
      'PUT',
      '/admin/storefront-config',
      idempotencyKey: _newIdempotencyKey(),
      body: {
        'announcement': settings.announcement,
        'showHero': settings.showHero,
        'showNewest': settings.showNewest,
        'showTodaysPicks': settings.showTodaysPicks,
        'showExternalPicks': settings.showExternalPicks,
        'expectedVersion': settings.version,
      },
    );
    final root = _jsonObject(response.bodyBytes);
    final value = root['storefront'];
    if (value is! Map<String, dynamic>) {
      throw const AdminClientException('invalid storefront response');
    }
    return _storefrontFromJson(value);
  }

  @override
  Future<void> updateSource(AdminSourcePolicy source) async {
    await updateSourceCanonical(source);
  }

  @override
  Future<AdminSourcePolicy> updateSourceCanonical(
    AdminSourcePolicy source,
  ) async {
    final response = await _send(
      'PUT',
      '/admin/external-policy/${Uri.encodeComponent(source.id)}',
      idempotencyKey: _newIdempotencyKey(),
      body: {
        'enabled': source.enabled,
        'itemLimit': source.itemLimit,
        'baseCommissionRate': source.baseCommissionRate,
        'highValueCommissionRate': source.highValueCommissionRate,
        'highValueThreshold': source.highValueThreshold,
      },
    );
    final root = _jsonObject(response.bodyBytes);
    final value = root['source'];
    if (value is! Map<String, dynamic>) {
      throw const AdminClientException('invalid external source response');
    }
    return _sourceFromJson(value);
  }

  @override
  Future<void> syncAll() async {
    AdminClientException? firstFailure;
    for (final channel in const [
      'shopify-products',
      'storefront-content',
      'external-status',
    ]) {
      try {
        await _runSyncChannel(channel);
      } on AdminClientException catch (error) {
        firstFailure ??= error;
      }
    }
    if (firstFailure != null) throw firstFailure;
  }

  Future<void> _runSyncChannel(String channel) async {
    final response = await _send(
      'POST',
      '/admin/sync',
      idempotencyKey: _newIdempotencyKey(),
      body: {'channel': channel},
    );
    var root = _jsonObject(response.bodyBytes);
    final rawJob = root['job'];
    if (rawJob is! Map) {
      throw const AdminClientException('invalid sync response');
    }
    var job = Map<String, Object?>.from(rawJob);
    for (var attempt = 0; attempt < 20; attempt += 1) {
      final status = '${job['status'] ?? ''}';
      if (status == 'completed') return;
      if (status == 'failed') {
        throw AdminClientException(
          'sync failed',
          code: job['errorCode'] is String ? job['errorCode'] as String : null,
          requestId:
              root['requestId'] is String ? root['requestId'] as String : null,
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final jobId = job['id'];
      if (jobId is! String || jobId.isEmpty) {
        throw const AdminClientException('invalid sync job response');
      }
      final statusResponse = await _send(
        'GET',
        '/admin/sync/jobs/${Uri.encodeComponent(jobId)}',
      );
      root = _jsonObject(statusResponse.bodyBytes);
      final nextRawJob = root['job'];
      if (nextRawJob is! Map) {
        throw const AdminClientException('invalid sync job response');
      }
      job = Map<String, Object?>.from(nextRawJob);
    }
    throw const AdminClientException('sync did not finish in time');
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const AdminClientException('owner session unavailable');
    }
    final uri = baseUrl.resolve(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      'PUT' => await _client.put(uri, headers: headers, body: encoded),
      'PATCH' => await _client.patch(uri, headers: headers, body: encoded),
      _ => throw AdminClientException('unsupported method $method'),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? code;
      String? requestId;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['error'] is Map) {
          final error = decoded['error'] as Map;
          code = error['code'] as String?;
          requestId = error['requestId'] as String?;
        }
      } on Object {
        // Preserve the bounded generic error for malformed upstream bodies.
      }
      throw AdminClientException(
        'control-plane request failed',
        statusCode: response.statusCode,
        code: code,
        requestId: requestId,
      );
    }
    return response;
  }

  static Map<String, dynamic> _jsonObject(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) {
      throw const AdminClientException('invalid control-plane response');
    }
    return decoded;
  }

  static AdminProductRecord _productFromJson(Map<String, dynamic> json) {
    final variants = (json['variants'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_variantFromJson)
        .toList(growable: false);
    return AdminProductRecord(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      imageUrl: json['imageUrl'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      inStock: json['inStock'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      variantCount: (json['variantCount'] as num?)?.toInt() ?? 0,
      descriptionHtml: '${json['descriptionHtml'] ?? ''}',
      status: '${json['status'] ?? 'ACTIVE'}',
      publishedToMonetta: json['publishedToMonetta'] as bool? ??
          json['visible'] as bool? ??
          true,
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
      variants: variants,
    );
  }

  static AdminProductRecord _productFromResponse(http.Response response) {
    final root = _jsonObject(response.bodyBytes);
    final product = root['product'];
    if (product is! Map<String, dynamic>) {
      throw const AdminClientException('invalid product response');
    }
    return _productFromJson(product);
  }

  static AdminProductVariant _variantFromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    final rawCompare = json['compareAtPrice'];
    return AdminProductVariant(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse('$rawPrice') ?? 0,
      compareAtPrice: rawCompare is num
          ? rawCompare.toDouble()
          : double.tryParse('$rawCompare'),
      availableForSale: json['availableForSale'] as bool? ?? false,
      currencyCode: '${json['currencyCode'] ?? 'MXN'}',
    );
  }

  static AdminFeaturedCatalog _featuredFromJson(
    Map<String, dynamic> json,
    Object? healthJson,
  ) {
    final collection = json['collection'];
    final eligible = (json['eligibleProducts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(_productFromJson)
        .toList(growable: false);
    final health = healthJson is Map ? healthJson : const <Object?, Object?>{};
    return AdminFeaturedCatalog(
      eligibleProducts: eligible,
      selectedProductIds:
          (json['selectedProductIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      collectionId: collection is Map ? collection['id'] as String? : null,
      collectionHandle: collection is Map
          ? '${collection['handle'] ?? 'monetta-todays-picks'}'
          : 'monetta-todays-picks',
      collectionTitle: collection is Map
          ? '${collection['title'] ?? "Today's Picks"}'
          : "Today's Picks",
      collectionUpdatedAt: collection is Map
          ? DateTime.tryParse('${collection['updatedAt'] ?? ''}')
          : null,
      healthStatus: health['status'] as String? ?? 'ready',
      healthErrorCode: health['errorCode'] as String?,
    );
  }

  String _newIdempotencyKey() {
    final entropy = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'flutter-${DateTime.now().toUtc().microsecondsSinceEpoch}-$entropy';
  }

  static AdminStorefrontSettings _storefrontFromJson(
    Map<String, dynamic> json,
  ) {
    return AdminStorefrontSettings(
      announcement: '${json['announcement'] ?? ''}',
      showHero: json['showHero'] as bool? ?? true,
      showNewest: json['showNewest'] as bool? ?? true,
      showTodaysPicks: json['showTodaysPicks'] as bool? ?? true,
      showExternalPicks: json['showExternalPicks'] as bool? ?? true,
      version: (json['version'] as num?)?.toInt() ?? 0,
    );
  }

  static AdminSourcePolicy _sourceFromJson(Map<String, dynamic> json) {
    final health = json['health'];
    final healthMap = health is Map<String, dynamic> ? health : null;
    return AdminSourcePolicy(
      id: '${json['id'] ?? ''}',
      merchant: '${json['merchant'] ?? ''}',
      enabled: json['enabled'] as bool? ?? true,
      itemLimit: (json['itemLimit'] as num?)?.toInt() ?? 12,
      baseCommissionRate:
          (json['baseCommissionRate'] as num?)?.toDouble() ?? .18,
      highValueCommissionRate:
          (json['highValueCommissionRate'] as num?)?.toDouble() ?? .12,
      highValueThreshold:
          (json['highValueThreshold'] as num?)?.toDouble() ?? 4000,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      lastSuccessfulRunAt: DateTime.tryParse(
        '${json['lastSuccessfulRunAt'] ?? ''}',
      ),
      healthStatus: '${healthMap?['status'] ?? 'unavailable'}',
      healthErrorCode: healthMap?['errorCode'] as String?,
    );
  }

  static AdminAuditEvent _auditFromJson(Map<String, dynamic> json) {
    final channels = <AdminChannel>{};
    switch ('${json['targetType'] ?? ''}') {
      case 'shopify_product':
      case 'shopify_collection':
      case 'shopify_metaobject':
        channels.add(AdminChannel.shopify);
      case 'external_source':
        channels.add(AdminChannel.externalCatalog);
      default:
        channels.add(AdminChannel.app);
    }
    return AdminAuditEvent(
      description: '${json['action'] ?? 'Cambio administrativo'}',
      channels: channels,
      createdAt:
          DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      previewOnly: false,
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
