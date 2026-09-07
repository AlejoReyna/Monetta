import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/data/admin/admin_client.dart';

void main() {
  test('syncAll does not call external-status (F22)', () async {
    final channels = <String>[];
    final client = HttpAdminClient(
      baseUrl: Uri.parse('https://admin.monetta.test'),
      accessTokenProvider: () async => 'owner-token',
      client: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/admin/sync') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          channels.add('${body['channel']}');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'job': {
                  'id': 'job-${body['channel']}',
                  'status': 'completed',
                },
              }),
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('unexpected', 500);
      }),
    );

    await client.syncAll();
    client.close();

    expect(channels, ['shopify-products', 'storefront-content']);
    expect(channels, isNot(contains('external-status')));
  });
}
