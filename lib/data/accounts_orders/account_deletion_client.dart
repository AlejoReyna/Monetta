/// Client for in-app account deletion on `services/accounts_orders`.
///
/// The Shopify Admin token never travels here. This client only presents the
/// shopper's own Customer Account credential.
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class FreshCustomerLogin {
  const FreshCustomerLogin({
    required this.accessToken,
    required this.idToken,
  });

  final String accessToken;
  final String idToken;
}

class AccountDeletionOrderRef {
  const AccountDeletionOrderRef({
    required this.id,
    this.shopifyOrderId,
  });

  final String id;
  final String? shopifyOrderId;
}

sealed class AccountDeletionOutcome {
  const AccountDeletionOutcome();
}

class AccountDeletionClear extends AccountDeletionOutcome {
  const AccountDeletionClear();
}

class AccountDeletionBlocked extends AccountDeletionOutcome {
  const AccountDeletionBlocked(this.order);

  final AccountDeletionOrderRef order;
}

class AccountDeletionDeleted extends AccountDeletionOutcome {
  const AccountDeletionDeleted();
}

class AccountDeletionStale extends AccountDeletionOutcome {
  const AccountDeletionStale();
}

class AccountDeletionOffline extends AccountDeletionOutcome {
  const AccountDeletionOffline();
}

class AccountDeletionFailed extends AccountDeletionOutcome {
  const AccountDeletionFailed();
}

abstract class AccountDeletionClient {
  Future<AccountDeletionOutcome> precheck(String accessToken);

  Future<AccountDeletionOutcome> delete({
    required String accessToken,
    required String idToken,
  });

  void close() {}
}

class HttpAccountDeletionClient implements AccountDeletionClient {
  HttpAccountDeletionClient({
    required this.baseUrl,
    http.Client? httpClient,
  })  : _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final String? baseUrl;
  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<AccountDeletionOutcome> precheck(String accessToken) {
    return _post('/customers/me/account-deletion/precheck', accessToken);
  }

  @override
  Future<AccountDeletionOutcome> delete({
    required String accessToken,
    required String idToken,
  }) {
    return _post(
      '/customers/me/account-deletion',
      accessToken,
      extraHeaders: {'X-Monetta-Id-Token': idToken},
    );
  }

  @override
  void close() {
    if (_ownsClient) _client.close();
  }

  Future<AccountDeletionOutcome> _post(
    String path,
    String accessToken, {
    Map<String, String> extraHeaders = const {},
  }) async {
    final root = baseUrl?.trim();
    if (root == null || root.isEmpty || accessToken.trim().isEmpty) {
      return const AccountDeletionFailed();
    }
    final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$root$path'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
          ...extraHeaders,
        },
      );
    } catch (error) {
      if (_isOffline(error)) return const AccountDeletionOffline();
      return const AccountDeletionFailed();
    }
    return _decode(response);
  }

  AccountDeletionOutcome _decode(http.Response response) {
    Map<String, dynamic> json = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } on FormatException {
      json = const {};
    }
    final error = json['error'];
    if (response.statusCode == 401 && error == 'stale_reauthentication') {
      return const AccountDeletionStale();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const AccountDeletionFailed();
    }
    if (response.statusCode >= 500 || response.statusCode == 429) {
      return const AccountDeletionFailed();
    }
    if (response.statusCode != 200) return const AccountDeletionFailed();
    switch (json['result']) {
      case 'clear':
        return const AccountDeletionClear();
      case 'deleted':
        return const AccountDeletionDeleted();
      case 'blocked_open_order':
        final order = json['order'];
        if (order is! Map<String, dynamic>) {
          return const AccountDeletionFailed();
        }
        final id = order['id'];
        if (id is! String && id is! num) return const AccountDeletionFailed();
        final shopifyOrderId = order['shopifyOrderId'];
        return AccountDeletionBlocked(
          AccountDeletionOrderRef(
            id: '$id',
            shopifyOrderId: shopifyOrderId is String ? shopifyOrderId : null,
          ),
        );
      default:
        return const AccountDeletionFailed();
    }
  }

  bool _isOffline(Object error) {
    if (error is SocketException) return true;
    if (error is http.ClientException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('socketexception');
  }
}
