/// First-party Monetta account registration over `services/accounts_orders`.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class SystemAccountException implements Exception {
  SystemAccountException(this.message);
  final String message;

  @override
  String toString() => 'SystemAccountException: $message';
}

class SystemAccountRegistration {
  const SystemAccountRegistration({
    required this.accountId,
    required this.email,
    required this.displayName,
    required this.sessionToken,
    required this.expiresAt,
  });

  final String accountId;
  final String email;
  final String? displayName;
  final String sessionToken;
  final DateTime expiresAt;
}

abstract class SystemAccountClient {
  Future<SystemAccountRegistration> register({
    required String email,
    required String password,
    required String? displayName,
    required String deviceId,
  });

  Future<SystemAccountRegistration> login({
    required String email,
    required String password,
    required String deviceId,
  });

  Future<void> logout(String sessionToken);
}

class HttpSystemAccountClient implements SystemAccountClient {
  HttpSystemAccountClient({required this.baseUrl, http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  @override
  Future<SystemAccountRegistration> register({
    required String email,
    required String password,
    required String? displayName,
    required String deviceId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/accounts/register'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
        'deviceId': deviceId,
      }),
    );
    if (response.statusCode != 201) {
      throw SystemAccountException(
        'POST /accounts/register returned ${response.statusCode}',
      );
    }

    return _parseSession(response.body);
  }

  @override
  Future<SystemAccountRegistration> login({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/accounts/login'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'deviceId': deviceId,
      }),
    );
    if (response.statusCode != 200) {
      throw SystemAccountException(
        'POST /accounts/login returned ${response.statusCode}',
      );
    }
    return _parseSession(response.body);
  }

  @override
  Future<void> logout(String sessionToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/accounts/logout'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $sessionToken',
      },
    );
    if (response.statusCode != 200 && response.statusCode != 401) {
      throw SystemAccountException(
        'POST /accounts/logout returned ${response.statusCode}',
      );
    }
  }

  SystemAccountRegistration _parseSession(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final account = json['account'] as Map<String, dynamic>;
      final session = json['session'] as Map<String, dynamic>;
      return SystemAccountRegistration(
        accountId: account['id'] as String,
        email: account['email'] as String,
        displayName: account['displayName'] as String?,
        sessionToken: session['token'] as String,
        expiresAt: DateTime.parse(session['expiresAt'] as String),
      );
    } catch (error) {
      throw SystemAccountException('Malformed account response: $error');
    }
  }
}
