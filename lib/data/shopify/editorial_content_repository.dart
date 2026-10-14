/// Reads optional Monetta editorial content from Shopify Metaobjects.
library;

import 'dart:convert';

import '../../domain/editorial_content.dart';
import '../../domain/seasonal_campaign.dart';
import 'queries.dart';
import 'storefront_client.dart';

class EditorialContentRepository {
  const EditorialContentRepository({required this.client});

  final StorefrontClient client;

  Future<MonettaEditorialContent> fetch() async {
    final data = await client.query(kEditorialContentQuery);
    final fallback = MonettaEditorialContent.fallback;
    return MonettaEditorialContent(
      about: _about(data['about'], fallback.about),
      partner: _partner(data, fallback.partner),
      seasonalBanners: await _seasonalBanners(),
    );
  }

  /// A missing definition or a bad payload hides the banner. It must not
  /// fail the About / partner read that already succeeded.
  Future<List<SeasonalCampaign>> _seasonalBanners() async {
    try {
      final data = await client.query(kSeasonalBannerQuery);
      return _parseSeasonalBanners(data['seasonalBanners']);
    } on Object {
      return const <SeasonalCampaign>[];
    }
  }

  AboutMonettaContent _about(
    Object? raw,
    AboutMonettaContent fallback,
  ) {
    final fields = _fields(raw);
    return fallback.copyWith(
      eyebrow: _nonEmpty(fields['eyebrow']) ?? fallback.eyebrow,
      headline: _nonEmpty(fields['headline']) ?? fallback.headline,
      body: _nonEmpty(fields['body']) ?? fallback.body,
      milestones: _milestones(fields['timeline_json']) ?? fallback.milestones,
      trustFacts:
          _stringList(fields['trust_facts_json']) ?? fallback.trustFacts,
    );
  }

  PartnerProgramContent _partner(
    Map<String, dynamic> data,
    PartnerProgramContent fallback,
  ) {
    final fields = _fields(data['partner']);
    final catalogs = _catalogs(data['catalogs']);
    return fallback.copyWith(
      eyebrow: _nonEmpty(fields['eyebrow']) ?? fallback.eyebrow,
      headline: _nonEmpty(fields['headline']) ?? fallback.headline,
      body: _nonEmpty(fields['body']) ?? fallback.body,
      steps: _steps(fields['steps_json']) ?? fallback.steps,
      terms: _terms(fields['terms_json']) ?? fallback.terms,
      faqs: _faqs(fields['faqs_json']) ?? fallback.faqs,
      catalogs: catalogs.isEmpty ? fallback.catalogs : catalogs,
    );
  }

  Map<String, String> _fields(Object? raw) {
    if (raw is! Map) return const {};
    final list = raw['fields'];
    if (list is! List) return const {};
    final result = <String, String>{};
    for (final item in list) {
      if (item is! Map) continue;
      final key = '${item['key'] ?? ''}'.trim();
      final value = '${item['value'] ?? ''}'.trim();
      if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
    }
    return result;
  }

  List<PartnerCatalog> _catalogs(Object? raw) {
    if (raw is! Map || raw['edges'] is! List) return const [];
    final result = <PartnerCatalog>[];
    for (final edge in raw['edges'] as List) {
      if (edge is! Map || edge['node'] is! Map) continue;
      final node = edge['node'] as Map;
      final fields = _fields(node);
      if (_bool(fields['active'], fallback: true) == false) continue;
      final mode = PartnerCatalogMode.fromWire(fields['mode'] ?? '');
      final url = _nonEmpty(fields['url']);
      final uri = url == null ? null : Uri.tryParse(url);
      if (mode == null ||
          url == null ||
          uri == null ||
          !isTrustedPartnerUri(uri)) {
        continue;
      }
      final id = _nonEmpty('${node['handle'] ?? ''}');
      final category = _nonEmpty(fields['category']);
      final categoryLabel = _nonEmpty(fields['category_label']);
      if (id == null || category == null || categoryLabel == null) continue;
      result.add(
        PartnerCatalog(
          id: id,
          category: category,
          categoryLabel: categoryLabel,
          mode: mode,
          url: url,
          description: _nonEmpty(fields['description']) ??
              _defaultCatalogDescription(mode),
          sortOrder: int.tryParse(fields['sort_order'] ?? '') ?? result.length,
          updatedLabel: _nonEmpty(fields['updated_label']),
        ),
      );
    }
    result.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(result);
  }

  List<StoryMilestone>? _milestones(String? raw) {
    final list = _jsonList(raw);
    if (list == null) return null;
    final result = <StoryMilestone>[];
    for (final item in list) {
      if (item is! Map) continue;
      final year = _nonEmpty('${item['year'] ?? ''}');
      final title = _nonEmpty('${item['title'] ?? ''}');
      final body = _nonEmpty('${item['body'] ?? ''}');
      if (year != null && title != null && body != null) {
        result.add(StoryMilestone(year: year, title: title, body: body));
      }
    }
    return result.isEmpty ? null : List.unmodifiable(result);
  }

  List<PartnerStep>? _steps(String? raw) {
    final list = _jsonList(raw);
    if (list == null) return null;
    final result = <PartnerStep>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map) continue;
      final title = _nonEmpty('${item['title'] ?? ''}');
      final body = _nonEmpty('${item['body'] ?? ''}');
      if (title != null && body != null) {
        result.add(
          PartnerStep(
            number: _nonEmpty('${item['number'] ?? ''}') ??
                '${i + 1}'.padLeft(2, '0'),
            title: title,
            body: body,
          ),
        );
      }
    }
    return result.isEmpty ? null : List.unmodifiable(result);
  }

  List<PartnerTerm>? _terms(String? raw) {
    final list = _jsonList(raw);
    if (list == null) return null;
    final result = <PartnerTerm>[];
    for (final item in list) {
      if (item is! Map) continue;
      final value = _nonEmpty('${item['value'] ?? ''}');
      final label = _nonEmpty('${item['label'] ?? ''}');
      if (value != null && label != null) {
        result.add(PartnerTerm(value: value, label: label));
      }
    }
    return result.isEmpty ? null : List.unmodifiable(result);
  }

  List<PartnerFaq>? _faqs(String? raw) {
    final list = _jsonList(raw);
    if (list == null) return null;
    final result = <PartnerFaq>[];
    for (final item in list) {
      if (item is! Map) continue;
      final question = _nonEmpty('${item['question'] ?? ''}');
      final answer = _nonEmpty('${item['answer'] ?? ''}');
      if (question != null && answer != null) {
        result.add(PartnerFaq(question: question, answer: answer));
      }
    }
    return result.isEmpty ? null : List.unmodifiable(result);
  }

  List<String>? _stringList(String? raw) {
    final list = _jsonList(raw);
    if (list == null) return null;
    final result = list
        .map((item) => _nonEmpty('$item'))
        .whereType<String>()
        .toList(growable: false);
    return result.isEmpty ? null : result;
  }

  List<Object?>? _jsonList(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  bool _bool(String? value, {required bool fallback}) => switch (value) {
        'true' || '1' => true,
        'false' || '0' => false,
        _ => fallback,
      };

  List<SeasonalCampaign> _parseSeasonalBanners(Object? raw) {
    if (raw is! Map || raw['edges'] is! List) return const <SeasonalCampaign>[];
    final result = <SeasonalCampaign>[];
    for (final edge in raw['edges'] as List) {
      if (edge is! Map || edge['node'] is! Map) continue;
      final node = Map<dynamic, dynamic>.from(edge['node'] as Map);
      final campaign = _campaign(node, _richFields(node));
      if (campaign != null) result.add(campaign);
    }
    return List<SeasonalCampaign>.unmodifiable(result);
  }

  List<_RichField> _richFields(Map<dynamic, dynamic> node) {
    final list = node['fields'];
    if (list is! List) return const <_RichField>[];
    final result = <_RichField>[];
    for (final item in list) {
      if (item is! Map) continue;
      final key = '${item['key'] ?? ''}'.trim();
      if (key.isEmpty) continue;
      final reference = item['reference'];
      result.add(
        _RichField(
          key: key,
          value: '${item['value'] ?? ''}'.trim(),
          reference:
              reference is Map ? Map<dynamic, dynamic>.from(reference) : null,
        ),
      );
    }
    return result;
  }

  SeasonalCampaign? _campaign(
    Map<dynamic, dynamic> node,
    List<_RichField> fields,
  ) {
    final link = _collectionLink(fields);
    final campaign = SeasonalCampaign(
      id: _nonEmpty('${node['handle'] ?? ''}'),
      title: _nonEmpty(_field(fields, const ['title'])?.value) ?? '',
      imageUrl: _imageUrl(_field(fields, const ['image'])),
      ipadImageUrl: _imageUrl(
        _field(fields, const ['ipadImage', 'ipad_image']),
      ),
      tag: _nonEmpty(_field(fields, const ['tag'])?.value),
      subtitle: _nonEmpty(_field(fields, const ['subtitle'])?.value),
      ctaText: _nonEmpty(
        _field(fields, const ['ctaText', 'cta_text'])?.value,
      ),
      collectionId: link.id,
      collectionHandle: link.handle,
      startsAt: _date(_field(fields, const ['startsAt', 'starts_at'])?.value),
      endsAt: _date(_field(fields, const ['endsAt', 'ends_at'])?.value),
    );
    if (!campaign.hasVisibleContent) return null;
    return campaign;
  }

  _RichField? _field(List<_RichField> fields, List<String> keys) {
    for (final field in fields) {
      if (keys.contains(field.key)) return field;
    }
    return null;
  }

  String? _imageUrl(_RichField? field) {
    if (field == null) return null;
    final reference = field.reference;
    if (reference != null) {
      final image = reference['image'];
      if (image is Map) {
        final url = _https('${image['url'] ?? ''}');
        if (url != null) return url;
      }
      final direct = _https('${reference['url'] ?? ''}');
      if (direct != null) return direct;
    }
    return _https(field.value);
  }

  _CollectionLink _collectionLink(List<_RichField> fields) {
    final field = _field(fields, const ['collectionId', 'collection_id']);
    if (field == null) return const _CollectionLink();
    final reference = field.reference;
    if (reference != null) {
      final handle = _nonEmpty('${reference['handle'] ?? ''}');
      final id = _nonEmpty('${reference['id'] ?? ''}');
      if (handle != null || id != null) {
        return _CollectionLink(
          id: id ?? _nonEmpty(field.value),
          handle: handle,
        );
      }
    }
    final value = _nonEmpty(field.value);
    if (value == null) return const _CollectionLink();
    if (value.startsWith('gid://')) {
      return _CollectionLink(id: value);
    }
    return _CollectionLink(id: value, handle: value);
  }

  DateTime? _date(String? raw) {
    final value = _nonEmpty(raw);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  String? _https(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return trimmed;
  }

  String _defaultCatalogDescription(PartnerCatalogMode mode) => switch (mode) {
        PartnerCatalogMode.wholesale =>
          'Precios para preparar y cotizar tu pedido.',
        PartnerCatalogMode.suggestedPrices =>
          'Listo para compartir con precios sugeridos de venta.',
        PartnerCatalogMode.noPrices =>
          'Comparte los modelos y decide tu precio final.',
      };
}

class _RichField {
  const _RichField({required this.key, required this.value, this.reference});

  final String key;
  final String value;
  final Map<dynamic, dynamic>? reference;
}

class _CollectionLink {
  const _CollectionLink({this.id, this.handle});

  final String? id;
  final String? handle;
}
