/// Shopify Customer Account address CRUD (2026-07). No first-party account
/// token, entered email or local address list substitutes for Shopify identity.
library;

import 'customer_graphql_client.dart';

const customerAddressFields = '''
  id firstName lastName company address1 address2 city province zoneCode
  territoryCode zip phoneNumber formatted(withName: true)
''';

class CustomerAddress {
  const CustomerAddress({
    required this.id,
    required this.fields,
    required this.formatted,
  });
  final String id;

  /// Provider fields; nullable fields stay absent, never filled from a profile.
  final Map<String, String> fields;
  final List<String> formatted;
  factory CustomerAddress.fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || (raw['id'] as String).isEmpty) {
      throw const CustomerDataException('malformed_address');
    }
    final fields = <String, String>{};
    for (final key in CustomerAddressInput.allowedFields) {
      if (raw[key] is String) fields[key] = raw[key] as String;
    }
    if (raw['province'] is String) {
      fields['province'] = raw['province'] as String;
    }
    final formatted = raw['formatted'];
    if (formatted is! List || formatted.any((v) => v is! String)) {
      throw const CustomerDataException('malformed_address');
    }
    return CustomerAddress(
      id: raw['id'] as String,
      fields: Map.unmodifiable(fields),
      formatted: List<String>.unmodifiable(formatted),
    );
  }
}

class CustomerAddressInput {
  CustomerAddressInput(Map<String, String> fields)
      : fields = Map.unmodifiable(fields) {
    if (fields.isEmpty || fields.keys.any((k) => !allowedFields.contains(k))) {
      throw ArgumentError('Unsupported address fields');
    }
  }
  final Map<String, String> fields;
  static const allowedFields = {
    'firstName',
    'lastName',
    'company',
    'address1',
    'address2',
    'city',
    'zoneCode',
    'territoryCode',
    'zip',
    'phoneNumber',
  };
}

class CustomerAddressBook {
  const CustomerAddressBook({
    required this.addresses,
    required this.defaultAddressId,
  });
  final List<CustomerAddress> addresses;
  final String? defaultAddressId;
}

abstract interface class CustomerAddressService {
  Future<CustomerAddressBook> fetchAddresses(String accessToken);
  Future<CustomerAddress> create(
    String accessToken,
    CustomerAddressInput address, {
    bool defaultAddress = false,
  });
  Future<CustomerAddress> update(
    String accessToken,
    String addressId,
    CustomerAddressInput address, {
    bool? defaultAddress,
  });
  Future<void> delete(String accessToken, String addressId);
}

class ShopifyCustomerAddressService implements CustomerAddressService {
  const ShopifyCustomerAddressService(this.client);
  final CustomerGraphqlClient client;
  static const query = '''
    query MonettaAddresses(\$after: String) {
      customer {
        defaultAddress { id }
        addresses(first: 100, after: \$after) {
          nodes { $customerAddressFields }
          pageInfo { hasNextPage endCursor }
        }
      }
    }
  ''';
  @override
  Future<CustomerAddressBook> fetchAddresses(String accessToken) async {
    final addresses = <String, CustomerAddress>{};
    final cursors = <String>{};
    String? after;
    String? defaultId;
    do {
      final data =
          await client.execute(accessToken, query, variables: {'after': after});
      final customer = data['customer'];
      if (customer is! Map) {
        throw const CustomerDataException('customer_unavailable');
      }
      final defaultAddress = customer['defaultAddress'];
      defaultId =
          defaultAddress is Map ? defaultAddress['id'] as String? : null;
      final connection = customer['addresses'];
      for (final raw in customerConnectionNodes(connection)) {
        final address = CustomerAddress.fromJson(raw);
        addresses[address.id] = address;
      }
      after = customerNextCursor(connection, cursors);
    } while (after != null);
    return CustomerAddressBook(
      addresses: List.unmodifiable(addresses.values),
      defaultAddressId: defaultId,
    );
  }

  @override
  Future<CustomerAddress> create(
    String accessToken,
    CustomerAddressInput address, {
    bool defaultAddress = false,
  }) async {
    final data = await client.execute(
      accessToken,
      '''
      mutation MonettaAddressCreate(\$address: CustomerAddressInput!, \$defaultAddress: Boolean) {
        customerAddressCreate(address: \$address, defaultAddress: \$defaultAddress) {
          customerAddress { $customerAddressFields }
          userErrors { code }
        }
      }
    ''',
      variables: {
        'address': address.fields,
        'defaultAddress': defaultAddress,
      },
      mutation: true,
    );
    return _confirmedAddress(_payload(data, 'customerAddressCreate'));
  }

  @override
  Future<CustomerAddress> update(
    String accessToken,
    String addressId,
    CustomerAddressInput address, {
    bool? defaultAddress,
  }) async {
    _validateId(addressId);
    final data = await client.execute(
      accessToken,
      '''
      mutation MonettaAddressUpdate(\$addressId: ID!, \$address: CustomerAddressInput, \$defaultAddress: Boolean) {
        customerAddressUpdate(addressId: \$addressId, address: \$address, defaultAddress: \$defaultAddress) {
          customerAddress { $customerAddressFields }
          userErrors { code }
        }
      }
    ''',
      variables: {
        'addressId': addressId,
        'address': address.fields,
        if (defaultAddress != null) 'defaultAddress': defaultAddress,
      },
      mutation: true,
    );
    final result = _confirmedAddress(_payload(data, 'customerAddressUpdate'));
    if (result.id != addressId) {
      throw const CustomerDataException(
        'address_mismatch',
        mutationMayHaveSucceeded: true,
      );
    }
    return result;
  }

  @override
  Future<void> delete(String accessToken, String addressId) async {
    _validateId(addressId);
    final data = await client.execute(
      accessToken,
      r'''
      mutation MonettaAddressDelete($addressId: ID!) {
        customerAddressDelete(addressId: $addressId) { deletedAddressId userErrors { code } }
      }
    ''',
      variables: {'addressId': addressId},
      mutation: true,
    );
    if (_payload(data, 'customerAddressDelete')['deletedAddressId'] !=
        addressId) {
      throw const CustomerDataException(
        'deletion_unconfirmed',
        mutationMayHaveSucceeded: true,
      );
    }
  }

  static CustomerAddress _confirmedAddress(Map<dynamic, dynamic> payload) {
    try {
      return CustomerAddress.fromJson(payload['customerAddress']);
    } on CustomerDataException {
      throw const CustomerDataException(
        'address_unconfirmed',
        mutationMayHaveSucceeded: true,
      );
    }
  }

  static void _validateId(String id) {
    if (!id.startsWith('gid://shopify/CustomerAddress/')) {
      throw ArgumentError('Invalid address ID');
    }
  }

  static Map<dynamic, dynamic> _payload(Map<String, dynamic> data, String key) {
    final payload = data[key];
    final errors = payload is Map ? payload['userErrors'] : null;
    if (errors is! List) {
      throw const CustomerDataException(
        'malformed_mutation',
        mutationMayHaveSucceeded: true,
      );
    }
    if (errors.isNotEmpty) {
      // Machine code only: messages/fields may include customer input.
      throw const CustomerDataException('address_rejected');
    }
    return payload as Map;
  }
}

List<dynamic> customerConnectionNodes(Object? connection) {
  if (connection is! Map || connection['nodes'] is! List) {
    throw const CustomerDataException('malformed_connection');
  }
  return connection['nodes'] as List;
}

String? customerNextCursor(Object? connection, Set<String> seen) {
  final info = connection is Map ? connection['pageInfo'] : null;
  if (info is! Map || info['hasNextPage'] is! bool) {
    throw const CustomerDataException('malformed_pagination');
  }
  if (info['hasNextPage'] == false) return null;
  final next = info['endCursor'];
  if (next is! String ||
      next.isEmpty ||
      !seen.add(next) ||
      seen.length > 1000) {
    throw const CustomerDataException('incomplete_pagination');
  }
  return next;
}
