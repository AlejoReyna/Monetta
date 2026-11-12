/// Published merchant policies from the existing Storefront shop source.
/// Missing merchant content stays unavailable; no bundled policy is invented.
library;

import '../customer_auth/customer_graphql_client.dart' show CapabilityRead;
import 'storefront_client.dart';

enum ShopPolicyKind { shipping, refund, privacy, terms }

class ShopPolicyContent {
  const ShopPolicyContent({
    required this.id,
    required this.kind,
    required this.title,
    required this.bodyHtml,
    required this.url,
  });
  final String id, title, bodyHtml;
  final ShopPolicyKind kind;
  final Uri url;
}

class ShopPolicyRepository {
  const ShopPolicyRepository(this.client);
  final StorefrontClient client;
  static const query = '''
    query MonettaPublishedPolicies {
      shop {
        shipping: shippingPolicy { id title body url }
        refund: refundPolicy { id title body url }
        privacy: privacyPolicy { id title body url }
        terms: termsOfService { id title body url }
      }
    }
  ''';

  Future<Map<ShopPolicyKind, CapabilityRead<ShopPolicyContent>>> fetch() async {
    // Exceptions deliberately propagate: an outage is not unpublished content.
    final data = await client.query(query);
    final shop = data['shop'];
    if (shop is! Map) throw const StorefrontException('Invalid policy source');
    return Map.unmodifiable({
      for (final kind in ShopPolicyKind.values)
        kind: _parse(kind, shop[kind.name]),
    });
  }

  static CapabilityRead<ShopPolicyContent> _parse(
    ShopPolicyKind kind,
    Object? raw,
  ) {
    if (raw == null) {
      return const CapabilityRead.unavailable('policy_not_published');
    }
    if (raw is! Map) throw const StorefrontException('Invalid policy content');
    final id = raw['id'],
        title = raw['title'],
        body = raw['body'],
        url = raw['url'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (id is! String ||
        title is! String ||
        body is! String ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const StorefrontException('Invalid policy content');
    }
    if (id.trim().isEmpty ||
        title.trim().isEmpty ||
        body
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('&nbsp;', '')
            .trim()
            .isEmpty) {
      return const CapabilityRead.unavailable('policy_not_published');
    }
    return CapabilityRead.supported(
      ShopPolicyContent(
        id: id,
        kind: kind,
        title: title,
        bodyHtml: body,
        url: uri,
      ),
    );
  }
}
