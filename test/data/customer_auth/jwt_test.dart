import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/customer_auth/jwt.dart';

String _segment(Map<String, dynamic> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

void main() {
  group('decodeIdTokenClaims', () {
    test('reads claims from the payload segment, padding stripped', () {
      final token = '${_segment({
            'alg': 'none',
          })}.${_segment({
            'sub': 'gid://shopify/Customer/1',
            'email': 'shopper@example.com',
          })}.sig';

      final claims = decodeIdTokenClaims(token);

      expect(claims['sub'], 'gid://shopify/Customer/1');
      expect(claims['email'], 'shopper@example.com');
    });

    test('throws FormatException on a token missing segments', () {
      expect(() => decodeIdTokenClaims('not-a-jwt'), throwsFormatException);
      expect(() => decodeIdTokenClaims('a.b'), throwsFormatException);
    });
  });
}
