/// App-only presentation geometry. Shared/generated brand tokens stay intact.
library;

import 'package:flutter/widgets.dart';

abstract final class StorefrontLayout {
  static const double paneGap = 24;
  static const double splitWidth = 700;
  static const double splitHeight = 480;
  static const double browseMinimum = 320;
  static const double detailMinimum = 340;
  static const double railWidth = 72;
  static const double cartSplitWidth = 860;
  static const double minimumTaskHeight = 200;
  static const double regionMinimumWidth = 240;
  static const double minimumGalleryHeight = 180;

  static bool enlargedText(TextScaler scaler) => scaler.scale(16) > 16 * 1.3;

  static bool canSplit(Size size, TextScaler textScaler) =>
      size.width >= splitWidth &&
      size.height >= splitHeight &&
      size.width >= splitWidth * (textScaler.scale(16) / 16);

  static int columns(double width, TextScaler textScaler) {
    var count = width < 340
        ? 1
        : width < 720
            ? 2
            : width < 1060
                ? 3
                : 4;
    final minimum =
        160 + 80 * (textScaler.scale(16) / 16 - 1).clamp(0, double.infinity);
    while (count > 1 && width / count < minimum) {
      count--;
    }
    return count;
  }
}
