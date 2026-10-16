import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/features/home/banner_contrast.dart';

void main() {
  test('the scrim stays at least 55% and clears 4.5:1 for title and subtitle',
      () {
    final alpha = resolveBannerScrimAlpha();
    const white = Color(0xFFFFFFFF);
    final base = Color.alphaBlend(
      const Color(0xFF000000).withValues(alpha: alpha),
      white,
    );
    final subtitle = Color.alphaBlend(
      white.withValues(alpha: 0.85),
      base,
    );

    expect(alpha, greaterThanOrEqualTo(kBannerScrimFloor));
    expect(alpha, lessThanOrEqualTo(kBannerScrimCeiling));
    expect(contrastRatio(white, base), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(subtitle, base), greaterThanOrEqualTo(4.5));
    expect(
      contrastRatio(readableGold(on: base), base),
      greaterThanOrEqualTo(4.5),
    );
  });
}
