/// Full-bleed seasonal campaign under Colecciones.
///
/// The box is reserved up front (phone 3:4, iPad 13" 16:9) so a late image
/// cannot change the layout. A missing Storefront source paints the shipped
/// placeholder; a configured source with no live campaign is not mounted by
/// the home at all.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme.dart';
import '../../domain/seasonal_campaign.dart';
import '../boutique/boutique_tokens.dart';
import 'banner_contrast.dart';
import 'monetta_m_mark.dart';

/// Darker step of the storefront ivory, used where a photograph is missing.
const Color kSeasonalPlaceholderCream = Color(0xFFD9CDB6);

const String kSeasonalPlaceholderCaption = 'Anuncio de temporada';

/// iPad Pro 13" (and the 12.9" class) in either orientation.
const double kSeasonalIpad13ShortestSide = 1024;

bool seasonalBannerUsesIpadFrame(Size size) =>
    size.shortestSide >= kSeasonalIpad13ShortestSide;

/// Height of the reserved frame. Phone is 3:4; iPad 13" is 16:9.
///
/// Capped at the viewport so a landscape phone cannot grow past the screen.
/// On a portrait phone, 3:4 of the width is the ~75% fold the design describes.
double seasonalBannerHeightFor(Size size) {
  final aspect = seasonalBannerUsesIpadFrame(size) ? 16 / 9 : 3 / 4;
  return math.min(size.width / aspect, size.height);
}

class SeasonalBanner extends StatelessWidget {
  const SeasonalBanner({
    required this.phase,
    this.campaign,
    this.onOpenCollection,
    this.imageOverride,
    super.key,
  });

  final SeasonalBannerPhase phase;
  final SeasonalCampaign? campaign;
  final ValueChanged<SeasonalCampaign>? onOpenCollection;

  /// Test seam. Production reads [SeasonalCampaign.imageFor].
  final ImageProvider<Object>? imageOverride;

  static const Key bannerKey = ValueKey<String>('home-seasonal-banner');

  @override
  Widget build(BuildContext context) {
    if (phase == SeasonalBannerPhase.hidden) {
      return const SizedBox.shrink(key: bannerKey);
    }

    final size = MediaQuery.sizeOf(context);
    final height = seasonalBannerHeightFor(size);
    final campaign = this.campaign;
    final canOpen = phase == SeasonalBannerPhase.ready &&
        campaign?.collectionHandle != null &&
        onOpenCollection != null;
    final label = _label(phase, campaign);

    return Semantics(
      key: bannerKey,
      button: canOpen,
      label: label,
      onTap: canOpen ? () => onOpenCollection!(campaign!) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canOpen ? () => onOpenCollection!(campaign!) : null,
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                _art(context, size),
                if (phase != SeasonalBannerPhase.loading) ...[
                  const _BannerScrim(),
                  _BannerCopy(
                    phase: phase,
                    campaign: campaign,
                    ipad: seasonalBannerUsesIpadFrame(size),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _art(BuildContext context, Size size) {
    if (phase == SeasonalBannerPhase.loading) {
      return const _SeasonalShimmer();
    }
    final provider = _provider(size);
    if (provider == null) return const _PlaceholderBackdrop();
    return Image(
      image: provider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame == null) return const _SeasonalShimmer();
        return KeyedSubtree(
          key: const ValueKey<String>('home-seasonal-image'),
          child: child,
        );
      },
      errorBuilder: (_, __, ___) => const _PlaceholderBackdrop(),
    );
  }

  ImageProvider<Object>? _provider(Size size) {
    final override = imageOverride;
    if (override != null) return override;
    final url = campaign?.imageFor(ipad: seasonalBannerUsesIpadFrame(size));
    if (url == null) return null;
    return NetworkImage(url);
  }

  static String _label(SeasonalBannerPhase phase, SeasonalCampaign? campaign) {
    if (phase == SeasonalBannerPhase.loading) {
      return 'Cargando anuncio de temporada';
    }
    final title = campaign?.title.trim() ?? '';
    if (title.isNotEmpty) return title;
    return kSeasonalPlaceholderCaption;
  }
}

class _BannerScrim extends StatelessWidget {
  const _BannerScrim();

  @override
  Widget build(BuildContext context) {
    final alpha = resolveBannerScrimAlpha();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const <double>[0, 0.42, 0.58],
            colors: <Color>[
              const Color(0x00000000),
              const Color(0x00000000),
              Colors.black.withValues(alpha: alpha),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCopy extends StatelessWidget {
  const _BannerCopy({
    required this.phase,
    required this.campaign,
    required this.ipad,
  });

  final SeasonalBannerPhase phase;
  final SeasonalCampaign? campaign;
  final bool ipad;

  @override
  Widget build(BuildContext context) {
    final alpha = resolveBannerScrimAlpha();
    final base = Color.alphaBlend(
      Colors.black.withValues(alpha: alpha),
      const Color(0xFFFFFFFF),
    );
    final tagColor = readableGold(on: base, preferred: context.boutique.gold);
    final ready = phase == SeasonalBannerPhase.ready ? campaign : null;
    final title = ready == null || ready.title.trim().isEmpty
        ? kSeasonalPlaceholderCaption
        : ready.title.trim();
    final tag = ready?.tag?.trim();
    final subtitle = ready?.subtitle?.trim();
    final cta = _cta(ready);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ipad ? 560 : double.infinity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tag != null && tag.isNotEmpty) ...[
                Text(
                  tag.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: kBoutiqueSansFamily,
                    fontFamilyFallback: kBoutiqueSansFallback,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                    height: 1.3,
                    color: tagColor,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: editorial(
                  ipad ? 36 : 32,
                  color: Colors.white,
                  height: 1.12,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: boutiqueText(
                    size: 15,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
              if (cta != null) ...[
                const SizedBox(height: 14),
                Text(
                  cta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: boutiqueText(
                    size: 13,
                    weight: FontWeight.w600,
                    height: 1.2,
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                  ).copyWith(decorationColor: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _cta(SeasonalCampaign? campaign) {
    if (campaign?.collectionHandle == null) return null;
    final text = campaign?.ctaText?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.endsWith('→')) return text;
    return '$text →';
  }
}

class _PlaceholderBackdrop extends StatelessWidget {
  const _PlaceholderBackdrop();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      key: const ValueKey<String>('home-seasonal-placeholder'),
      color: dark ? context.boutique.surfaceDeep : kSeasonalPlaceholderCream,
      child: Center(
        child: Opacity(
          opacity: 0.15,
          child: MonettaMMark(
            size: 120,
            color: context.boutique.gold,
          ),
        ),
      ),
    );
  }
}

class _SeasonalShimmer extends StatelessWidget {
  const _SeasonalShimmer();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A2622) : const Color(0xFFE7DCC8);
    final highlight = dark ? const Color(0xFF3A342C) : const Color(0xFFF8F3EA);
    return Shimmer.fromColors(
      key: const ValueKey<String>('home-seasonal-shimmer'),
      baseColor: base,
      highlightColor: highlight,
      child: const ColoredBox(color: Colors.white),
    );
  }
}
