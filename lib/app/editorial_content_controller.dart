/// Cache-safe owner content for the About and reseller experiences, plus
/// the seasonal home banner.
library;

import 'package:flutter/foundation.dart';

import '../data/shopify/editorial_content_repository.dart';
import '../domain/editorial_content.dart';
import '../domain/seasonal_campaign.dart';

class EditorialContentController extends ChangeNotifier {
  EditorialContentController({
    EditorialContentRepository? repository,
    DateTime Function()? now,
  })  : _repository = repository,
        _now = now ?? DateTime.now,
        _configured = repository != null,
        _loading = repository != null;

  final EditorialContentRepository? _repository;
  final DateTime Function() _now;
  final bool _configured;
  bool _loading;
  MonettaEditorialContent _content = MonettaEditorialContent.fallback;

  MonettaEditorialContent get content => _content;

  /// Placeholder when this build has no Storefront source. Loading until the
  /// first read finishes. Hidden when that read has no campaign in window.
  SeasonalBannerPhase get seasonalBannerPhase {
    if (!_configured) return SeasonalBannerPhase.placeholder;
    if (_loading) return SeasonalBannerPhase.loading;
    if (activeSeasonalCampaign == null) return SeasonalBannerPhase.hidden;
    return SeasonalBannerPhase.ready;
  }

  SeasonalCampaign? get activeSeasonalCampaign {
    if (!_configured || _loading) return null;
    return pickActiveSeasonalCampaign(_content.seasonalBanners, _now());
  }

  /// Best effort by design: the bundled fallback is already complete, and an
  /// unavailable or partially configured Metaobject must not block the app.
  /// A failed banner read leaves the section hidden rather than inventing one.
  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null) return;
    final wasLoading = _loading;
    try {
      _content = await repository.fetch();
      _loading = false;
      notifyListeners();
    } on Object {
      if (!wasLoading) return;
      _loading = false;
      notifyListeners();
    }
  }
}
