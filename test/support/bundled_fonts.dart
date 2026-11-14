import 'dart:io';

import 'package:flutter/services.dart';

/// Registers the real DM Sans, Cormorant Garamond and Mrs
/// Saint Delafield files from `assets/fonts/`
/// with the engine, so a widget test measures text with the faces the app
/// ships instead of the square-glyph test font (which is wider and ignores
/// `fontFamilyFallback`).
///
/// The registration goes through `FontLoader` and reads the files with
/// `dart:io`, so it needs the real event loop: call it from `setUpAll` (or from
/// inside `tester.runAsync`), never from the fake-async body of a
/// `testWidgets`. The families are single-face TTF files; `.ttc` collections
/// hang the loader. The path is relative to the project root, which is the
/// working directory of `flutter test`.
///
/// Registration is memoized per isolate: each test file runs in its own
/// isolate, so every file that needs the real faces calls this once.
Future<void> loadBundledFonts() => _loaded ??= _load();

Future<void>? _loaded;

/// The families and files the app is expected to ship (RF-17, E-T2).
const Map<String, List<String>> kBundledFontFiles = <String, List<String>>{
  'DM Sans': <String>[
    'assets/fonts/dm_sans/DMSans-Regular.ttf',
    'assets/fonts/dm_sans/DMSans-SemiBold.ttf',
    'assets/fonts/dm_sans/DMSans-Bold.ttf',
  ],
  // The guide's serif and script (open stand-ins for Reglarik and Above the
  // Beyond Script), so the captures show the real faces.
  'Cormorant Garamond': <String>[
    'assets/fonts/cormorant_garamond/CormorantGaramond-Light.ttf',
    'assets/fonts/cormorant_garamond/CormorantGaramond-LightItalic.ttf',
    'assets/fonts/cormorant_garamond/CormorantGaramond-Regular.ttf',
    'assets/fonts/cormorant_garamond/CormorantGaramond-Italic.ttf',
    'assets/fonts/cormorant_garamond/CormorantGaramond-Medium.ttf',
    'assets/fonts/cormorant_garamond/CormorantGaramond-Bold.ttf',
  ],
  'Mrs Saint Delafield': <String>[
    'assets/fonts/mrs_saint_delafield/MrsSaintDelafield-Regular.ttf',
  ],
};

Future<void> _load() async {
  for (final entry in kBundledFontFiles.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final bytes = await File(path).readAsBytes();
      final data = ByteData.sublistView(Uint8List.fromList(bytes));
      loader.addFont(Future<ByteData>.value(data));
    }
    await loader.load();
  }
}
