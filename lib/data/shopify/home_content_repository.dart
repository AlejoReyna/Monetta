/// Reads home layout and collection artwork from the same Shopify store used
/// by the catalog.
library;

import 'dart:convert';

import '../../domain/collection.dart';
import '../../domain/admin_control.dart';
import '../../domain/home_content.dart';
import '../../domain/shopify_sample_filter.dart';
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
        .where((item) => !isShopifySampleCollectionHandle(item.handle))
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
      bannersBySlot: _banners(
        data['banners'],
        data['appBanners'],
        fallback.bannersBySlot,
      ),
    );
  }

  Map<String, GuideBannerOverride> _banners(
    Object? merchantBanners,
    Object? appBanners,
    Map<String, GuideBannerOverride> fallback,
  ) {
    final nodes = <Map<String, dynamic>>[
      ...edgeNodes(appBanners),
      ...edgeNodes(merchantBanners),
    ];
    if (nodes.isEmpty) return fallback;

    final resolved = <String, GuideBannerOverride>{...fallback};
    for (final node in nodes) {
      final fields = <String, String>{};
      String? referenceImageUrl;
      String? referenceAltText;
      final rawFields = node['fields'];
      if (rawFields is List) {
        for (final field in rawFields.whereType<Map<Object?, Object?>>()) {
          final key = field['key'];
          final value = field['value'];
          if (key is String && value is String && value.trim().isNotEmpty) {
            fields[key] = value.trim();
          }
          if (key == 'image' && field['reference'] is Map) {
            final ref = field['reference'] as Map<Object?, Object?>;
            final image = ref['image'];
            if (image is Map) {
              final url = image['url'];
              final alt = image['altText'];
              if (url is String && url.trim().isNotEmpty) {
                referenceImageUrl = url.trim();
              }
              if (alt is String && alt.trim().isNotEmpty) {
                referenceAltText = alt.trim();
              }
            }
          }
        }
      }

      final rawSlot = fields['slot'] ?? '${node['handle'] ?? ''}';
      final slot = _normalizeBannerSlot(rawSlot);
      if (slot == null) continue;

      final activeRaw = fields['active']?.toLowerCase();
      final active = activeRaw == null ||
          (activeRaw != 'false' && activeRaw != '0');
      if (!active) {
        resolved.remove(slot);
        continue;
      }

      final imageUrl = _url(referenceImageUrl ?? fields['image'] ?? fields['image_url']);
      if (imageUrl == null) continue;

      final copy = fields['alt_text'] ?? fields['copy'] ?? referenceAltText;
      final destination = fields['destination_url'] ?? fields['destination'];

      resolved[slot] = GuideBannerOverride(
        slot: slot,
        imageUrl: imageUrl,
        copy: copy != null && copy.trim().isNotEmpty ? copy.trim() : null,
        destinationUrl: destination != null && destination.trim().isNotEmpty
            ? destination.trim()
            : null,
        active: true,
      );
    }
    return Map.unmodifiable(resolved);
  }

  String? _normalizeBannerSlot(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'b04-editorial' ||
        trimmed.toLowerCase() == 'b04_editorial') {
      return 'B04-editorial';
    }
    final match = RegExp(r'^[bB](\d{1,2})(?:[_-].*)?$').firstMatch(trimmed);
    if (match == null) return null;
    final number = int.tryParse(match.group(1)!);
    if (number == null || number < 1 || number > 32) return null;
    return 'B${number.toString().padLeft(2, '0')}';
  }

  List<HomeBrandCard> _brands(
    List<HomeBrandCard> fallback,
    Map<String, Collection> byHandle,
  ) {
    return List.unmodifiable([
      for (final seed in fallback)
        seed.copyWith(
          imageUrl: _url(
            _resolveBrandCollection(seed, byHandle)?.imageUrl,
          ),
        ),
    ]);
  }

  Collection? _resolveBrandCollection(
    HomeBrandCard seed,
    Map<String, Collection> byHandle,
  ) {
    final handle = seed.handle.toLowerCase();
    final direct = byHandle[handle];
    if (direct != null) return direct;
    return switch (handle) {
      'guess-1' => byHandle['guess'],
      'olalplex' => byHandle['olaplex'],
      _ => null,
    };
  }

  Collection? _resolveCardCollection(
    HomeCollectionCard seed,
    Map<String, Collection> byHandle,
  ) {
    final handle = seed.handle.toLowerCase();
    if (seed.category == 'bolsa' && handle == 'guess') {
      final bolsas = byHandle['bolsas'];
      if (bolsas != null) return bolsas;
    }
    final direct = byHandle[handle];
    if (direct != null) return direct;
    return switch (handle) {
      'carteras-1' => byHandle['carteras'],
      'carteras' => byHandle['carteras-1'],
      'relojes' => byHandle['relojes-1'],
      'relojes-1' => byHandle['relojes'],
      'crossbodys' => byHandle['crossbody'],
      'crossbody' => byHandle['crossbodys'],
      'hombro' => byHandle['shoulder'],
      'shoulder' => byHandle['hombro'],
      _ => null,
    };
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
      final collection = _resolveCardCollection(seed, byHandle);
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
