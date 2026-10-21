/// Reads home layout and collection artwork from the same Shopify store used
/// by the catalog.
library;

import 'dart:convert';

import '../../domain/collection.dart';
import '../../domain/admin_control.dart';
import '../../domain/home_content.dart';
import 'mappers.dart';
import 'queries.dart';
import 'storefront_client.dart';

class HomeContentRepository {
  const HomeContentRepository({required this.client});

  final StorefrontClient client;

  Future<HomeContent> fetch({
    HomeContent fallback = HomeContent.fallback,
  }) async {
    final data = await client.query(kHomeContentQuery);
    final shop = data['shop'] is Map
        ? data['shop'] as Map<Object?, Object?>
        : const <Object?, Object?>{};
    final collections = edgeNodes(data['collections'])
        .map(collectionFromJson)
        .toList(growable: false);
    final allByHandle = <String, Collection>{
      for (final item in collections) item.handle.toLowerCase(): item,
    };
    final byHandle = <String, Collection>{
      for (final item in collections)
        if (!item.isEmpty) item.handle.toLowerCase(): item,
    };

    return fallback.copyWith(
      sectionOrder: _sectionOrder(
        metafieldValue(shop['homeSections']),
        fallback.sectionOrder,
      ),
      collections: _cards(
        metafieldValue(shop['homeCollections']),
        fallback.collections,
        byHandle,
      ),
      bagTypes: _cards(
        metafieldValue(shop['homeBagTypes']),
        fallback.bagTypes,
        byHandle,
      ),
      // Brand logos remain useful navigation and merchandising artwork even
      // when their Shopify collection is temporarily empty.
      brands: _brands(fallback.brands, allByHandle),
      socialLinks: _socialLinks(
        metafieldValue(shop['socialLinks']),
        fallback.socialLinks,
      ),
      aboutImageUrl:
          _url(metafieldValue(shop['aboutImageUrl'])) ?? fallback.aboutImageUrl,
      storefront: _storefront(data['storefrontConfig'], fallback.storefront),
    );
  }

  List<HomeBrandCard> _brands(
    List<HomeBrandCard> fallback,
    Map<String, Collection> byHandle,
  ) {
    return List.unmodifiable([
      for (final seed in fallback)
        seed.copyWith(
          imageUrl: _url(byHandle[seed.handle.toLowerCase()]?.imageUrl),
        ),
    ]);
  }

  List<HomeSectionId> _sectionOrder(
    String? raw,
    List<HomeSectionId> fallback,
  ) {
    final values = _stringList(raw);
    if (values == null) return fallback;
    final result = <HomeSectionId>[];
    for (final value in values) {
      final section = HomeSectionId.fromWire(value);
      if (section != null && !result.contains(section)) result.add(section);
    }
    return result.isEmpty ? fallback : List.unmodifiable(result);
  }

  List<HomeCollectionCard> _cards(
    String? raw,
    List<HomeCollectionCard> fallback,
    Map<String, Collection> byHandle,
  ) {
    final configured = _stringList(raw);
    final seeds = configured == null
        ? fallback
        : <HomeCollectionCard>[
            for (final handle in configured)
              _seedForHandle(handle, fallback) ??
                  HomeCollectionCard(
                    title: _titleFromHandle(handle),
                    handle: handle,
                    fallbackAsset: fallback.first.fallbackAsset,
                  ),
          ];

    final result = <HomeCollectionCard>[];
    for (final seed in seeds) {
      final collection = byHandle[seed.handle.toLowerCase()];
      if (configured != null && collection == null) continue;
      result.add(
        seed.copyWith(
          title: collection?.title,
          imageUrl: _url(collection?.imageUrl),
        ),
      );
    }
    return result.isEmpty ? fallback : List.unmodifiable(result);
  }

  HomeCollectionCard? _seedForHandle(
    String handle,
    List<HomeCollectionCard> fallback,
  ) {
    for (final item in fallback) {
      if (item.handle.toLowerCase() == handle.toLowerCase()) return item;
    }
    return null;
  }

  List<HomeSocialLink> _socialLinks(
    String? raw,
    List<HomeSocialLink> fallback,
  ) {
    if (raw == null) return fallback;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return fallback;
      final result = <HomeSocialLink>[];
      for (final seed in fallback) {
        final url = _url('${decoded[seed.id] ?? ''}');
        result.add(
          HomeSocialLink(
            id: seed.id,
            label: seed.label,
            url: url ?? seed.url,
          ),
        );
      }
      return List.unmodifiable(result);
    } on FormatException {
      return fallback;
    }
  }

  List<String>? _stringList(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final values = decoded
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
        return values.isEmpty ? null : values;
      }
    } on FormatException {
      // Text-list metafields are sometimes returned one item per line.
    }
    final values = raw
        .split(RegExp(r'[,\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? null : values;
  }

  String? _url(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    return uri.toString();
  }

  String _titleFromHandle(String handle) {
    return handle
        .split(RegExp('[-_]'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  AdminStorefrontSettings _storefront(
    Object? raw,
    AdminStorefrontSettings fallback,
  ) {
    if (raw is! Map) return fallback;
    final fields = <String, String>{};
    final values = raw['fields'];
    if (values is List) {
      for (final field in values.whereType<Map<Object?, Object?>>()) {
        final key = field['key'];
        final value = field['value'];
        if (key is String && value is String) fields[key] = value;
      }
    }
    bool value(String key, bool fallbackValue) =>
        fields[key] == null ? fallbackValue : fields[key] != 'false';
    return AdminStorefrontSettings(
      announcement: fields['announcement'] ?? fallback.announcement,
      showHero: value('show_hero', fallback.showHero),
      showNewest: value('show_newest', fallback.showNewest),
      showTodaysPicks: value('show_todays_picks', fallback.showTodaysPicks),
      showExternalPicks:
          value('show_external_picks', fallback.showExternalPicks),
    );
  }
}
