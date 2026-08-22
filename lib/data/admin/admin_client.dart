/// Authenticated HTTP seam for the Monetta owner control plane.
///
/// Shopify Admin credentials stay on the server. The app sends the signed-in
/// owner's short-lived Shopify Customer access token; the service validates
/// it, checks the owner role, writes Shopify/configuration, and records audit.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/admin_control.dart';

abstract interface class AdminClient {
  Future<AdminSnapshot> fetchSnapshot();

  Future<void> updateProduct(AdminProductRecord product);

  Future<void> updateStorefront(AdminStorefrontSettings settings);

  Future<void> updateSource(AdminSourcePolicy source);

  Future<void> syncAll();
}

class AdminClientException implements Exception {
  const AdminClientException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'AdminClientException($statusCode, $message)';
}

class HttpAdminClient implements AdminClient {
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

  @override
  Future<AdminSnapshot> fetchSnapshot() async {
    final response = await _send('GET', '/admin/control-plane');
    final root = _jsonObject(response.bodyBytes);
    final productRows = root['products'] as List<dynamic>? ?? const [];
    final sourceRows = root['sources'] as List<dynamic>? ?? const [];
    final storefront = root['storefront'];

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
    );
  }

  @override
  Future<void> updateProduct(AdminProductRecord product) async {
    await _send(
      'PATCH',
      '/admin/products/${Uri.encodeComponent(product.id)}',
      body: {
        'title': product.title,
        'price': product.price,
        'visible': product.visible,
      },
    );
  }

  @override
  Future<void> updateStorefront(AdminStorefrontSettings settings) async {
    await _send(
      'PUT',
      '/admin/shop-config',
      body: {
        'announcement': settings.announcement,
        'showHero': settings.showHero,
        'showNewest': settings.showNewest,
        'showExternalPicks': settings.showExternalPicks,
      },
    );
  }

  @override
  Future<void> updateSource(AdminSourcePolicy source) async {
    await _send(
      'PUT',
      '/admin/external-policy/${Uri.encodeComponent(source.id)}',
      body: {
        'enabled': source.enabled,
        'itemLimit': source.itemLimit,
        'baseCommissionRate': source.baseCommissionRate,
        'highValueCommissionRate': source.highValueCommissionRate,
        'highValueThreshold': source.highValueThreshold,
      },
    );
  }

  @override
  Future<void> syncAll() async => _send('POST', '/admin/sync');

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const AdminClientException('owner session unavailable');
    }
    final uri = baseUrl.resolve(path);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
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
      throw AdminClientException(
        'control-plane request failed',
        statusCode: response.statusCode,
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
    return AdminProductRecord(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      imageUrl: json['imageUrl'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      inStock: json['inStock'] as bool? ?? false,
      visible: json['visible'] as bool? ?? true,
      variantCount: (json['variantCount'] as num?)?.toInt() ?? 0,
    );
  }

  static AdminStorefrontSettings _storefrontFromJson(
    Map<String, dynamic> json,
  ) {
    return AdminStorefrontSettings(
      announcement: '${json['announcement'] ?? ''}',
      showHero: json['showHero'] as bool? ?? true,
      showNewest: json['showNewest'] as bool? ?? true,
      showExternalPicks: json['showExternalPicks'] as bool? ?? true,
    );
  }

  static AdminSourcePolicy _sourceFromJson(Map<String, dynamic> json) {
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
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
