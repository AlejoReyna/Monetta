import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/data/customer_auth/customer_profile.dart';

const CustomerAccountConfig _config = CustomerAccountConfig(
  shopDomain: 'shop.example.com',
  shopId: '90228850722',
  clientId: 'client-id',
  redirectUri: 'shop.90228850722.oauth://callback',
  apiVersion: '2026-07',
);

const String _token = 'shcat_secret_token_123';
const String _customerId = 'gid://shopify/Customer/7';

class _Api {
  _Api(this.handler);

  final http.Response Function(http.Request request) handler;
  final List<http.Request> posts = [];

  HttpCustomerProfileService build() => HttpCustomerProfileService(
        config: _config,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            expect(request.url, _config.customerApiDiscoveryEndpoint);
            return http.Response(
              jsonEncode({
                'graphql_api':
                    'https://clientes.example.com/customer/api/2026-07/graphql',
              }),
              200,
            );
          }
          posts.add(request);
          return handler(request);
        }),
      );

  Map<String, dynamic> get lastBody =>
      jsonDecode(posts.last.body) as Map<String, dynamic>;
}

// UTF-8 bytes, like Shopify's answer: a plain `http.Response(String)` would
// be Latin-1 and turn «Lucía» into an undecodable body.
http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status);

Future<CustomerAuthException> _failure(Future<Object?> Function() call) async {
  try {
    await call();
  } on CustomerAuthException catch (error) {
    return error;
  }
  fail('expected a CustomerAuthException');
}

void main() {
  group('profile photo data URL helpers', () {
    test('wrap JPEG bytes and decode them back', () {
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
      final url = profilePhotoDataUrl(bytes);
      expect(url, startsWith('data:image/jpeg;base64,'));
      expect(decodeProfilePhotoDataUrl(url), bytes);
    });

    test('label PNG bytes as PNG and decode them', () {
      final bytes = Uint8List.fromList(
        [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1],
      );
      final url = profilePhotoDataUrl(bytes);
      expect(url, startsWith('data:image/png;base64,'));
      expect(decodeProfilePhotoDataUrl(url), bytes);
    });

    test('reject anything that is not a base64 JPEG or PNG data URL', () {
      expect(decodeProfilePhotoDataUrl(null), isNull);
      expect(decodeProfilePhotoDataUrl(''), isNull);
      expect(decodeProfilePhotoDataUrl('https://x.test/a.jpg'), isNull);
      expect(decodeProfilePhotoDataUrl('data:image/gif;base64,AAAA'), isNull);
      expect(
        decodeProfilePhotoDataUrl('data:image/svg+xml;base64,AAAA'),
        isNull,
      );
      expect(decodeProfilePhotoDataUrl('data:image/jpeg;base64,'), isNull);
      expect(
        decodeProfilePhotoDataUrl('data:image/jpeg;base64,***not base64***'),
        isNull,
      );
      expect(decodeProfilePhotoDataUrl('data:image/jpeg,AAAA'), isNull);
    });
  });

  group('HttpCustomerProfileService.fetch', () {
    test('sends the exact query, a raw token, and parses the metafield',
        () async {
      final api = _Api((request) {
        expect(request.headers['Authorization'], _token);
        return _json({
          'data': {
            'customer': {
              'id': _customerId,
              'firstName': 'Ana',
              'lastName': 'Ruiz',
              'displayName': 'Ana Ruiz',
              'metafield': {'value': 'data:image/jpeg;base64,AAAA'},
            },
          },
        });
      });

      final profile = await api.build().fetch(_token);

      expect(api.lastBody['query'], HttpCustomerProfileService.profileQuery);
      expect(api.lastBody.containsKey('variables'), isFalse);
      expect(
        HttpCustomerProfileService.profileQuery,
        contains('metafield(namespace: "monetta", key: "profile_photo")'),
      );
      expect(profile.shopifyCustomerId, _customerId);
      expect(profile.firstName, 'Ana');
      expect(profile.lastName, 'Ruiz');
      expect(profile.displayName, 'Ana Ruiz');
      expect(profile.photoDataUrl, 'data:image/jpeg;base64,AAAA');
    });

    test('parses a customer without the metafield', () async {
      final api = _Api(
        (_) => _json({
          'data': {
            'customer': {
              'id': _customerId,
              'firstName': null,
              'lastName': '  ',
              'displayName': 'ana@example.com',
              'metafield': null,
            },
          },
        }),
      );

      final profile = await api.build().fetch(_token);

      expect(profile.photoDataUrl, isNull);
      expect(profile.firstName, isNull);
      expect(profile.lastName, isNull);
      expect(profile.displayName, 'ana@example.com');
    });

    test('keeps the name when only the metafield read is denied', () async {
      final api = _Api(
        (_) => _json({
          'errors': [
            {
              'message': 'Access denied for metafield field.',
              'path': ['customer', 'metafield'],
              'extensions': {'code': 'ACCESS_DENIED'},
            },
          ],
          'data': {
            'customer': {
              'id': _customerId,
              'firstName': 'Ana',
              'metafield': null,
            },
          },
        }),
      );

      final profile = await api.build().fetch(_token);

      expect(profile.firstName, 'Ana');
      expect(profile.photoDataUrl, isNull);
    });

    test('401 and 403 are sessionExpired and never echo the token', () async {
      for (final status in [401, 403]) {
        final api = _Api((_) => http.Response('nope $_token', status));
        final error = await _failure(() => api.build().fetch(_token));
        expect(error.kind, CustomerAuthErrorKind.sessionExpired);
        expect(error.toString(), isNot(contains(_token)));
        expect(error.debugDetail, isNot(contains(_token)));
      }
    });

    test('an UNAUTHENTICATED GraphQL error is sessionExpired', () async {
      final api = _Api(
        (_) => _json({
          'errors': [
            {
              'message': 'x',
              'extensions': {'code': 'UNAUTHENTICATED'},
            },
          ],
          'data': null,
        }),
      );
      final error = await _failure(() => api.build().fetch(_token));
      expect(error.kind, CustomerAuthErrorKind.sessionExpired);
    });

    test('other GraphQL errors and bad statuses are server errors', () async {
      final graphQl = _Api(
        (_) => _json({
          'errors': [
            {'message': 'boom'},
          ],
        }),
      );
      expect(
        (await _failure(() => graphQl.build().fetch(_token))).kind,
        CustomerAuthErrorKind.server,
      );
      final http500 = _Api((_) => http.Response('', 500));
      expect(
        (await _failure(() => http500.build().fetch(_token))).kind,
        CustomerAuthErrorKind.server,
      );
      final noCustomer = _Api(
        (_) => _json({
          'data': {'customer': null},
        }),
      );
      expect(
        (await _failure(() => noCustomer.build().fetch(_token))).kind,
        CustomerAuthErrorKind.server,
      );
    });

    test('a transport failure is offline and names no token', () async {
      final service = HttpCustomerProfileService(
        config: _config,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'graphql_api': 'https://clientes.example.com/graphql',
              }),
              200,
            );
          }
          throw StateError('socket closed while sending $_token');
        }),
      );
      final error = await _failure(() => service.fetch(_token));
      expect(error.kind, CustomerAuthErrorKind.offline);
      expect(error.toString(), isNot(contains(_token)));
    });
  });

  group('HttpCustomerProfileService.updateFirstName', () {
    test('sends customerUpdate with only firstName and returns displayName',
        () async {
      final api = _Api(
        (_) => _json({
          'data': {
            'customerUpdate': {
              'customer': {
                'id': _customerId,
                'firstName': 'Lucía',
                'displayName': 'Lucía Ruiz',
              },
              'userErrors': <Object>[],
            },
          },
        }),
      );

      final displayName = await api.build().updateFirstName(_token, 'Lucía');

      expect(displayName, 'Lucía Ruiz');
      expect(
        api.lastBody['query'],
        HttpCustomerProfileService.updateFirstNameMutation,
      );
      expect(api.lastBody['variables'], {
        'input': {'firstName': 'Lucía'},
      });
      expect(api.posts.last.headers['Authorization'], _token);
    });

    test('userErrors become a server error naming only the codes', () async {
      final api = _Api(
        (_) => _json({
          'data': {
            'customerUpdate': {
              'customer': null,
              'userErrors': [
                {
                  'code': 'INVALID',
                  'field': ['input', 'firstName'],
                  'message': 'Contains forbidden text Lucía',
                },
                {
                  'code': null,
                  'field': null,
                  'message': 'free text Lucía',
                },
              ],
            },
          },
        }),
      );

      final error = await _failure(
        () => api.build().updateFirstName(_token, 'Lucía'),
      );

      expect(error.kind, CustomerAuthErrorKind.server);
      expect(error.debugDetail, contains('INVALID'));
      expect(error.debugDetail, contains('UNKNOWN'));
      expect(error.debugDetail, isNot(contains('Lucía')));
      expect(error.toString(), isNot(contains(_token)));
    });
  });

  group('HttpCustomerProfileService photo', () {
    test('setPhoto sends metafieldsSet with the exact variables', () async {
      final api = _Api(
        (_) => _json({
          'data': {
            'metafieldsSet': {
              'metafields': [
                {'key': 'profile_photo', 'namespace': 'monetta'},
              ],
              'userErrors': <Object>[],
            },
          },
        }),
      );
      const dataUrl = 'data:image/jpeg;base64,/9j/AAAA';

      await api.build().setPhoto(_token, _customerId, dataUrl);

      expect(
        api.lastBody['query'],
        HttpCustomerProfileService.setPhotoMutation,
      );
      expect(api.lastBody['variables'], {
        'metafields': [
          {
            'ownerId': _customerId,
            'namespace': 'monetta',
            'key': 'profile_photo',
            'type': 'multi_line_text_field',
            'value': dataUrl,
          },
        ],
      });
    });

    test('setPhoto accepts exactly the limit and refuses one more character',
        () async {
      final api = _Api(
        (_) => _json({
          'data': {
            'metafieldsSet': {
              'metafields': <Object>[],
              'userErrors': <Object>[],
            },
          },
        }),
      );
      final service = api.build();
      final atLimit = 'x' * kMaxProfilePhotoDataUrlLength;
      await service.setPhoto(_token, _customerId, atLimit);
      expect(api.posts, hasLength(1));

      final tooLong = 'x' * (kMaxProfilePhotoDataUrlLength + 1);
      await expectLater(
        service.setPhoto(_token, _customerId, tooLong),
        throwsA(isA<ProfilePhotoTooLargeException>()),
      );
      // No second request, and not even a discovery call for it.
      expect(api.posts, hasLength(1));
    });

    test('an oversized photo sends nothing at all', () async {
      var requests = 0;
      final service = HttpCustomerProfileService(
        config: _config,
        client: MockClient((request) async {
          requests += 1;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        service.setPhoto(
          _token,
          _customerId,
          'x' * (kMaxProfilePhotoDataUrlLength + 1),
        ),
        throwsA(
          isA<ProfilePhotoTooLargeException>().having(
            (e) => e.toString(),
            'toString',
            isNot(contains('xxxx')),
          ),
        ),
      );
      expect(requests, 0);
    });

    test('setPhoto userErrors (definition missing) are a server error',
        () async {
      final api = _Api(
        (_) => _json({
          'data': {
            'metafieldsSet': {
              'metafields': <Object>[],
              'userErrors': [
                {
                  'code': 'ACCESS_DENIED',
                  'field': ['metafields', '0'],
                  'message': 'Access to this namespace and key is denied.',
                },
              ],
            },
          },
        }),
      );
      final error = await _failure(
        () => api
            .build()
            .setPhoto(_token, _customerId, 'data:image/jpeg;base64,AA'),
      );
      expect(error.kind, CustomerAuthErrorKind.server);
      expect(error.debugDetail, contains('ACCESS_DENIED'));
      expect(error.debugDetail, isNot(contains('data:image')));
    });

    test('setPhoto 401 is sessionExpired', () async {
      final api = _Api((_) => http.Response('', 401));
      final error = await _failure(
        () => api
            .build()
            .setPhoto(_token, _customerId, 'data:image/jpeg;base64,AA'),
      );
      expect(error.kind, CustomerAuthErrorKind.sessionExpired);
      expect(error.toString(), isNot(contains(_token)));
    });

    test('removePhoto sends metafieldsDelete with the identifiers', () async {
      final api = _Api(
        (_) => _json({
          'data': {
            'metafieldsDelete': {
              'deletedMetafields': [
                {
                  'key': 'profile_photo',
                  'namespace': 'monetta',
                  'ownerId': _customerId,
                },
              ],
              'userErrors': <Object>[],
            },
          },
        }),
      );

      await api.build().removePhoto(_token, _customerId);

      expect(
        api.lastBody['query'],
        HttpCustomerProfileService.removePhotoMutation,
      );
      expect(api.lastBody['variables'], {
        'metafields': [
          {
            'ownerId': _customerId,
            'namespace': 'monetta',
            'key': 'profile_photo',
          },
        ],
      });
    });

    test('removePhoto userErrors are a server error', () async {
      final api = _Api(
        (_) => _json({
          'data': {
            'metafieldsDelete': {
              'deletedMetafields': <Object>[],
              'userErrors': [
                {'code': 'NOT_FOUND', 'field': null, 'message': 'x'},
              ],
            },
          },
        }),
      );
      final error = await _failure(
        () => api.build().removePhoto(_token, _customerId),
      );
      expect(error.kind, CustomerAuthErrorKind.server);
      expect(error.debugDetail, contains('NOT_FOUND'));
    });
  });
}
