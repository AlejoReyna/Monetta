/// Owner-controlled first-fold advertising. Not inferred from the ranked feed.
library;

class CampaignMedia {
  const CampaignMedia({
    required this.videoUrl,
    required this.posterAsset,
    this.ctaLabel = 'Ver catálogos',
  });

  final String videoUrl;
  final String posterAsset;
  final String ctaLabel;

  /// The film currently playing on monetta.mx. Swap via a future Remote
  /// Config override — do not scrape the homepage at runtime.
  static const monettaHome = CampaignMedia(
    videoUrl:
        'https://monetta.mx/cdn/shop/videos/c/vp/68aca88f2bd949eaaf823bd135f341af/68aca88f2bd949eaaf823bd135f341af.HD-720p-4.5Mbps-86006614.mp4?v=0',
    posterAsset: 'assets/images/hero_poster.jpg',
  );
}
