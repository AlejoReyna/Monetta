/// The only place the app touches the `image_picker` plugin, so widgets and
/// tests depend on a plain function type instead.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:image_picker/image_picker.dart';

import '../../data/customer_auth/customer_profile.dart';

/// Returns the chosen image's bytes, or null when the shopper backed out.
/// May throw (denied photo access, no picker available); callers show a
/// friendly message rather than the exception.
typedef ProfilePhotoPicker = Future<Uint8List?> Function();

/// Longest side of the stored profile photo, in pixels.
const double kProfilePhotoMaxSide = 384;
const _profilePhotoChannel = MethodChannel('monetta/profile_photo');

/// Normalizes picked photo bytes when iOS delivers an HEIC container.
///
/// iOS converts to a compact JPEG so the avatar renders across platforms.
/// Other platforms can use their image decoder or keep the original bytes.
@visibleForTesting
Future<Uint8List> normalizeProfilePhotoBytes(Uint8List bytes) async {
  if (bytes.isEmpty || !isHeicProfilePhoto(bytes)) return bytes;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final jpeg = await _profilePhotoChannel.invokeMethod<Uint8List>(
      'convertHeic',
      bytes,
    );
    if (jpeg != null) return jpeg;
  }
  final originalFits =
      profilePhotoDataUrl(bytes).length <= kMaxProfilePhotoDataUrlLength;
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: kProfilePhotoMaxSide.toInt(),
    );
    final frame = await codec.getNextFrame();
    try {
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (png != null) {
        final pngBytes = png.buffer.asUint8List();
        final pngFits = profilePhotoDataUrl(pngBytes).length <=
            kMaxProfilePhotoDataUrlLength;
        if (pngFits && (!originalFits || pngBytes.length <= bytes.length)) {
          return pngBytes;
        }
      }
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  } on Object {
    // Fall back to the original HEIC bytes when the platform codec rejects or
    // skips transcoding (e.g. synthetic fixtures or non-ImageIO platforms).
  }
  return bytes;
}

/// Opens the system photo picker. iOS and Android resize to
/// [kProfilePhotoMaxSide] and JPEG-compress natively, which keeps the result
/// well under the 60 000-character metafield guard. No camera, and no
/// Android permission (the system picker grants one-off access). When raw HEIC
/// bytes slip through on iPhone, [normalizeProfilePhotoBytes] handles them
/// without failing.
Future<Uint8List?> pickProfilePhotoFromGallery() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: kProfilePhotoMaxSide,
    maxHeight: kProfilePhotoMaxSide,
    imageQuality: 70,
  );
  if (file == null) return null;
  return normalizeProfilePhotoBytes(await file.readAsBytes());
}
