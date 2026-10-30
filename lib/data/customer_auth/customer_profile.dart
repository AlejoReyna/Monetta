/// The shopper's editable profile — first name and photo — stored in Shopify.
///
/// The name is the customer's own `firstName`, written through the Customer
/// Account API `customerUpdate` mutation. The photo has no native Shopify
/// field, so it lives in a merchant-owned customer metafield
/// (`monetta.profile_photo`, `multi_line_text_field`) as a small
/// `data:image/jpeg;base64,…` URL: the same value the web account page reads
/// and writes. Neither is ever written to SQLite (no schema change); the app
/// keeps them in memory per account.
///
/// Transport rules are the ones `customer_identity.dart` documents (endpoint
/// discovery, raw `Authorization` header, 401/403 meaning the token, GraphQL
/// `errors` on HTTP 200). Tokens and photo bytes never reach an exception or
/// a log line: every `debugDetail` here names a count, a status or an error
/// code, nothing else.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'customer_account_config.dart';
import 'customer_auth_error.dart';
import 'customer_identity.dart' show kMaxCustomerApiResponseBytes;

/// Shopify caps a metafield value at 64 KB. A data URL longer than this is
/// rejected before any request is built, leaving headroom under the cap.
const int kMaxProfilePhotoDataUrlLength = 60000;

const String kProfilePhotoMetafieldNamespace = 'monetta';
const String kProfilePhotoMetafieldKey = 'profile_photo';

class CustomerProfile {
  const CustomerProfile({
    required this.shopifyCustomerId,
    this.firstName,
    this.lastName,
    this.displayName,
    this.photoDataUrl,
  });

  /// `gid://shopify/Customer/...`.
  final String shopifyCustomerId;
  final String? firstName;
  final String? lastName;
  final String? displayName;

  /// The `data:image/...;base64,…` value of the photo metafield, or null when
  /// the shopper has none.
  final String? photoDataUrl;

  CustomerProfile copyWith({
    String? firstName,
    String? displayName,
    String? photoDataUrl,
    bool clearPhoto = false,
  }) {
    return CustomerProfile(
      shopifyCustomerId: shopifyCustomerId,
      firstName: firstName ?? this.firstName,
      lastName: lastName,
      displayName: displayName ?? this.displayName,
      photoDataUrl: clearPhoto ? null : photoDataUrl ?? this.photoDataUrl,
    );
  }
}

/// Thrown by [CustomerProfileService.setPhoto] when the data URL is longer
/// than [kMaxProfilePhotoDataUrlLength]. Nothing was sent. Carries only the
/// length, never the content.
class ProfilePhotoTooLargeException implements Exception {
  const ProfilePhotoTooLargeException(this.length);

  final int length;

  @override
  String toString() => 'ProfilePhotoTooLargeException($length characters)';
}

/// Injected into `AccountController` the way `CustomerIdentityService` is
/// injected into the session repository, so the profile stays testable
/// without a socket.
abstract class CustomerProfileService {
  /// Throws [CustomerAuthException] — never an HTTP or socket error.
  Future<CustomerProfile> fetch(String accessToken);

  /// Returns the display name Shopify reports after the change, or null when
  /// the answer carried none.
  Future<String?> updateFirstName(String accessToken, String firstName);

  /// Throws [ProfilePhotoTooLargeException] before sending anything when
  /// [dataUrl] is over [kMaxProfilePhotoDataUrlLength] characters.
  Future<void> setPhoto(
    String accessToken,
    String customerId,
    String dataUrl,
  );

  Future<void> removePhoto(String accessToken, String customerId);
}

const String _jpegPrefix = 'data:image/jpeg;base64,';
const String _pngPrefix = 'data:image/png;base64,';

bool _looksLikePng(List<int> bytes) =>
    bytes.length > 8 &&
    bytes[0] == 0x89 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x4E &&
    bytes[3] == 0x47;

/// Wraps the picker's image bytes as a data URL. The picker re-encodes to
/// JPEG; a PNG that slips through is labelled as such so the web page can
/// still render it.
String profilePhotoDataUrl(Uint8List bytes) =>
    '${_looksLikePng(bytes) ? _pngPrefix : _jpegPrefix}${base64Encode(bytes)}';

/// Decodes a stored photo value back to bytes. Anything that is not a base64
/// `data:image/jpeg` or `data:image/png` URL — including malformed base64 —
/// returns null: a metafield is merchant-editable text, so it is untrusted.
Uint8List? decodeProfilePhotoDataUrl(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  final String payload;
  if (trimmed.startsWith(_jpegPrefix)) {
    payload = trimmed.substring(_jpegPrefix.length);
  } else if (trimmed.startsWith(_pngPrefix)) {
    payload = trimmed.substring(_pngPrefix.length);
  } else {
    return null;
  }
  if (payload.isEmpty) return null;
  try {
    final bytes = base64Decode(payload);
    return bytes.isEmpty ? null : bytes;
  } on FormatException {
    return null;
  }
}

class HttpCustomerProfileService implements CustomerProfileService {
  HttpCustomerProfileService({
    required this.config,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final CustomerAccountConfig config;
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  Uri? _graphQlEndpoint;
  Future<Uri>? _discoveryInFlight;

  static const String profileQuery = '''
query MonettaCustomerProfile {
  customer {
    id
    firstName
    lastName
    displayName
    metafield(namespace: "monetta", key: "profile_photo") {
      value
    }
  }
}''';

  static const String updateFirstNameMutation = '''
mutation MonettaCustomerUpdateFirstName(\$input: CustomerUpdateInput!) {
  customerUpdate(input: \$input) {
    customer {
      id
      firstName
      displayName
    }
    userErrors {
      code
      field
      message
    }
  }
}''';

  static const String setPhotoMutation = '''
mutation MonettaProfilePhotoSet(\$metafields: [MetafieldsSetInput!]!) {
  metafieldsSet(metafields: \$metafields) {
    metafields {
      key
      namespace
    }
    userErrors {
      code
      field
      message
    }
  }
}''';

  static const String removePhotoMutation = '''
mutation MonettaProfilePhotoRemove(\$metafields: [MetafieldIdentifierInput!]!) {
  metafieldsDelete(metafields: \$metafields) {
    deletedMetafields {
      key
      namespace
      ownerId
    }
    userErrors {
      code
      field
      message
    }
  }
}''';

  @override
  Future<CustomerProfile> fetch(String accessToken) async {
    final data = await _execute(
      accessToken,
      operation: 'profile',
      query: profileQuery,
      // A customer with no readable metafield definition yet makes Shopify
      // answer with partial data plus an access error on the metafield only.
      // The name is still usable then, so partial data is accepted here.
      tolerateErrorsWithData: true,
    );
    return parseProfile(data);
  }

  @override
  Future<String?> updateFirstName(String accessToken, String firstName) async {
    final data = await _execute(
      accessToken,
      operation: 'customerUpdate',
      query: updateFirstNameMutation,
      variables: {
        'input': {'firstName': firstName},
      },
    );
    final payload = _payload(data, 'customerUpdate');
    final customer = payload['customer'];
    final displayName =
        customer is Map<String, dynamic> ? customer['displayName'] : null;
    return displayName is String && displayName.trim().isNotEmpty
        ? displayName.trim()
        : null;
  }

  @override
  Future<void> setPhoto(
    String accessToken,
    String customerId,
    String dataUrl,
  ) async {
    // Checked first: an oversized value must never be sent (nor trigger
    // endpoint discovery).
    if (dataUrl.length > kMaxProfilePhotoDataUrlLength) {
      throw ProfilePhotoTooLargeException(dataUrl.length);
    }
    final data = await _execute(
      accessToken,
      operation: 'metafieldsSet',
      query: setPhotoMutation,
      variables: {
        'metafields': [
          {
            'ownerId': customerId,
            'namespace': kProfilePhotoMetafieldNamespace,
            'key': kProfilePhotoMetafieldKey,
            'type': 'multi_line_text_field',
            'value': dataUrl,
          },
        ],
      },
    );
    _payload(data, 'metafieldsSet');
  }

  @override
  Future<void> removePhoto(String accessToken, String customerId) async {
    final data = await _execute(
      accessToken,
      operation: 'metafieldsDelete',
      query: removePhotoMutation,
      variables: {
        'metafields': [
          {
            'ownerId': customerId,
            'namespace': kProfilePhotoMetafieldNamespace,
            'key': kProfilePhotoMetafieldKey,
          },
        ],
      },
    );
    _payload(data, 'metafieldsDelete');
  }

  /// Sends one operation and returns the response's `data` object. Every
  /// failure is a [CustomerAuthException]; `userErrors` are checked by
  /// [_payload], which knows which mutation field to look in.
  Future<Map<String, dynamic>> _execute(
    String accessToken, {
    required String operation,
    required String query,
    Map<String, Object?>? variables,
    bool tolerateErrorsWithData = false,
  }) async {
    final endpoint = await _resolveGraphQlEndpoint();
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              // Raw, with no `Bearer ` prefix — see `customer_identity.dart`.
              'Authorization': accessToken,
            },
            body: jsonEncode({
              'query': query,
              if (variables != null) 'variables': variables,
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail: 'customer $operation request timed out',
      );
    } catch (error) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail:
            'customer $operation transport failure: ${error.runtimeType}',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.sessionExpired,
        debugDetail: 'customer $operation rejected the access token',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer $operation HTTP ${response.statusCode}',
      );
    }
    if (response.bodyBytes.length > kMaxCustomerApiResponseBytes) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer $operation response exceeded size limit',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer $operation returned a non-JSON body',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer $operation JSON root was not an object',
      );
    }

    final data = decoded['data'];
    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      final customer = data is Map<String, dynamic> ? data['customer'] : null;
      if (!(tolerateErrorsWithData && customer is Map<String, dynamic>)) {
        // Only an unauthenticated answer means the token is the problem. An
        // `ACCESS_DENIED` here is far more likely the metafield definition
        // not granting «Read and write» yet, which a re-login cannot fix.
        final text = errors.join(' ').toUpperCase();
        final unauthenticated =
            text.contains('UNAUTHENTICATED') || text.contains('UNAUTHORIZED');
        throw CustomerAuthException(
          unauthenticated
              ? CustomerAuthErrorKind.sessionExpired
              : CustomerAuthErrorKind.server,
          debugDetail: 'customer $operation returned ${errors.length} '
              'GraphQL error(s)',
        );
      }
    }
    if (data is! Map<String, dynamic>) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer $operation carried no data object',
      );
    }
    return data;
  }

  /// The mutation payload under [field], with `userErrors` turned into an
  /// exception whose detail names only the error codes.
  static Map<String, dynamic> _payload(
    Map<String, dynamic> data,
    String field,
  ) {
    final payload = data[field];
    if (payload is! Map<String, dynamic>) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer $field returned no payload',
      );
    }
    final userErrors = payload['userErrors'];
    if (userErrors is List && userErrors.isNotEmpty) {
      final codes = <String>{};
      for (final error in userErrors) {
        final code = error is Map<String, dynamic> ? error['code'] : null;
        // Codes are enum-like (`TAKEN`, `ACCESS_DENIED`); anything else is
        // free text that could echo submitted content, so it is not copied.
        codes.add(
          code is String && RegExp(r'^[A-Z0-9_]{1,40}$').hasMatch(code)
              ? code
              : 'UNKNOWN',
        );
      }
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer $field userErrors: ${codes.join(',')}',
      );
    }
    return payload;
  }

  /// Separated from the HTTP call so the parsing rules are testable on their
  /// own, like `HttpCustomerIdentityService.parseIdentity`.
  static CustomerProfile parseProfile(Map<String, dynamic> data) {
    final customer = data['customer'];
    if (customer is! Map<String, dynamic>) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer profile response carried no customer object',
      );
    }
    final id = customer['id'];
    if (id is! String || id.isEmpty) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer profile response carried no customer id',
      );
    }
    String? text(Object? value) =>
        value is String && value.trim().isNotEmpty ? value.trim() : null;
    final metafield = customer['metafield'];
    final photo =
        metafield is Map<String, dynamic> ? text(metafield['value']) : null;
    return CustomerProfile(
      shopifyCustomerId: id,
      firstName: text(customer['firstName']),
      lastName: text(customer['lastName']),
      displayName: text(customer['displayName']),
      photoDataUrl: photo,
    );
  }

  /// Discovers and caches Shopify's account API URL from the storefront
  /// domain — same rule and same reasons as `HttpCustomerIdentityService`.
  Future<Uri> _resolveGraphQlEndpoint() {
    final cached = _graphQlEndpoint;
    if (cached != null) return Future.value(cached);

    final inFlight = _discoveryInFlight;
    if (inFlight != null) return inFlight;

    late final Future<Uri> future;
    future = _discoverGraphQlEndpoint().then((endpoint) {
      _graphQlEndpoint = endpoint;
      return endpoint;
    }).whenComplete(() {
      if (identical(_discoveryInFlight, future)) {
        _discoveryInFlight = null;
      }
    });
    _discoveryInFlight = future;
    return future;
  }

  Future<Uri> _discoverGraphQlEndpoint() async {
    final http.Response response;
    try {
      response = await _client.get(
        config.customerApiDiscoveryEndpoint,
        headers: const {'Accept': 'application/json'},
      ).timeout(timeout);
    } on TimeoutException {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail: 'customer API discovery timed out',
      );
    } catch (error) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.offline,
        debugDetail: 'customer API discovery transport failure: '
            '${error.runtimeType}',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery HTTP ${response.statusCode}',
      );
    }
    if (response.bodyBytes.length > kMaxCustomerApiResponseBytes) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery response exceeded size limit',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery returned non-JSON',
      );
    }
    final endpointValue =
        decoded is Map<String, dynamic> ? decoded['graphql_api'] : null;
    final endpoint =
        endpointValue is String ? Uri.tryParse(endpointValue) : null;
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.hasFragment) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'customer API discovery carried no valid graphql_api',
      );
    }
    return endpoint;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
