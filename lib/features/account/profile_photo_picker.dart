/// The only place the app touches the `image_picker` plugin, so widgets and
/// tests depend on a plain function type instead.
library;

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Returns the chosen image's bytes, or null when the shopper backed out.
/// May throw (denied photo access, no picker available); callers show a
/// friendly message rather than the exception.
typedef ProfilePhotoPicker = Future<Uint8List?> Function();

/// Longest side of the stored profile photo, in pixels.
const double kProfilePhotoMaxSide = 384;

/// Opens the system photo picker. iOS and Android resize to
/// [kProfilePhotoMaxSide] and JPEG-compress natively, which keeps the result
/// well under the 60 000-character metafield guard. No camera, and no
/// Android permission (the system picker grants one-off access).
Future<Uint8List?> pickProfilePhotoFromGallery() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: kProfilePhotoMaxSide,
    maxHeight: kProfilePhotoMaxSide,
    imageQuality: 70,
  );
  if (file == null) return null;
  return file.readAsBytes();
}
