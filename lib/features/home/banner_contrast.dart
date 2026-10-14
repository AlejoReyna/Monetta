/// Scrim strength for type sitting on the seasonal photograph.
///
/// The photo is treated as white — the brightest pixel a campaign image can
/// hold — so the reserved gradient still clears 4.5:1 if the file is pale.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Floor from the design: black at 55% over the image.
const double kBannerScrimFloor = 0.55;

/// Stop raising the scrim before the photograph disappears.
const double kBannerScrimCeiling = 0.92;

const double kBannerContrastMin = 4.5;

const Color _scrimBlack = Color(0xFF000000);
const Color _scrimWhite = Color(0xFFFFFFFF);

double contrastRatio(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

/// End alpha of the bottom scrim. Starts at [kBannerScrimFloor] and steps up
/// until opaque white and white at 85% both clear [kBannerContrastMin].
double resolveBannerScrimAlpha({
  Color worstCasePhoto = const Color(0xFFFFFFFF),
}) {
  for (var step = 0; step <= 20; step++) {
    final alpha = math.min(
      kBannerScrimCeiling,
      kBannerScrimFloor + step * 0.02,
    );
    if (_scrimClears(alpha, worstCasePhoto)) return alpha;
  }
  return kBannerScrimCeiling;
}

bool _scrimClears(double alpha, Color photo) {
  final base = Color.alphaBlend(
    _scrimBlack.withValues(alpha: alpha),
    photo,
  );
  final titleOk = contrastRatio(_scrimWhite, base) >= kBannerContrastMin;
  final subtitle = Color.alphaBlend(
    _scrimWhite.withValues(alpha: 0.85),
    base,
  );
  final subtitleOk = contrastRatio(subtitle, base) >= kBannerContrastMin;
  return titleOk && subtitleOk;
}

/// Gold for the season tag. Prefer [preferred]; lighten toward ivory until
/// the tag clears [kBannerContrastMin] on [on].
Color readableGold({
  required Color on,
  Color preferred = const Color(0xFFC5A052),
}) {
  if (contrastRatio(preferred, on) >= kBannerContrastMin) return preferred;
  const ivory = Color(0xFFF8F5EE);
  var color = preferred;
  for (var step = 1; step <= 20; step++) {
    color = Color.lerp(preferred, ivory, step / 20) ?? preferred;
    if (contrastRatio(color, on) >= kBannerContrastMin) return color;
  }
  return color;
}
