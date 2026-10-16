/// Owner-scheduled home banner. Shopify can replace it without an app release.
///
/// The bundled app does not invent a campaign. When no Storefront source is
/// configured the home shows a placeholder; when a source is configured and
/// nothing is inside its window the section is removed.
library;

/// How the home should paint the seasonal slot.
enum SeasonalBannerPhase {
  /// No Storefront source. Paint the shipped placeholder.
  placeholder,

  /// A source is configured and the first read has not finished.
  loading,

  /// A source is configured and no campaign is inside its window.
  hidden,

  /// An in-window campaign is ready to paint.
  ready,
}

/// One `app_seasonal_banner` metaobject entry.
class SeasonalCampaign {
  const SeasonalCampaign({
    required this.title,
    this.id,
    this.imageUrl,
    this.ipadImageUrl,
    this.tag,
    this.subtitle,
    this.ctaText,
    this.collectionId,
    this.collectionHandle,
    this.startsAt,
    this.endsAt,
  });

  /// Metaobject handle, when Shopify sent one.
  final String? id;
  final String title;
  final String? imageUrl;
  final String? ipadImageUrl;
  final String? tag;
  final String? subtitle;
  final String? ctaText;

  /// Shopify collection GID, when the field was a reference or a gid string.
  final String? collectionId;

  /// Catalog handle the collection screen can filter on.
  final String? collectionHandle;
  final DateTime? startsAt;

  /// Exclusive. A campaign whose [endsAt] equals [now] is already over.
  final DateTime? endsAt;

  bool get hasVisibleContent {
    return title.trim().isNotEmpty ||
        _filled(imageUrl) ||
        _filled(ipadImageUrl);
  }

  /// [startsAt] is inclusive. A missing bound does not limit that side.
  bool isActiveAt(DateTime now) {
    if (!hasVisibleContent) return false;
    final instant = now.toUtc();
    final start = startsAt?.toUtc();
    final end = endsAt?.toUtc();
    if (start != null && instant.isBefore(start)) return false;
    if (end != null && !instant.isBefore(end)) return false;
    return true;
  }

  /// Phone art is [imageUrl]. iPad 13" prefers [ipadImageUrl] and falls back.
  String? imageFor({required bool ipad}) {
    final phone = _nullIfEmpty(imageUrl);
    final tablet = _nullIfEmpty(ipadImageUrl);
    if (ipad) return tablet ?? phone;
    return phone ?? tablet;
  }
}

/// The campaign with the latest [SeasonalCampaign.startsAt] still in window.
///
/// An undated campaign loses to a dated one. Two undated campaigns keep the
/// first in [campaigns].
SeasonalCampaign? pickActiveSeasonalCampaign(
  List<SeasonalCampaign> campaigns,
  DateTime now,
) {
  SeasonalCampaign? best;
  for (final campaign in campaigns) {
    if (!campaign.isActiveAt(now)) continue;
    if (best == null || _startsLater(campaign, best)) best = campaign;
  }
  return best;
}

bool _startsLater(SeasonalCampaign candidate, SeasonalCampaign current) {
  final start = candidate.startsAt;
  final currentStart = current.startsAt;
  if (start == null) return false;
  if (currentStart == null) return true;
  return start.isAfter(currentStart);
}

bool _filled(String? value) => _nullIfEmpty(value) != null;

String? _nullIfEmpty(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
