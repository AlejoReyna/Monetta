// Host-side driver for the DEV-03 typography reference captures
// (integration_test/dev03_typography_captures_test.dart).
//
// `flutter drive` runs this file on the Mac. Every screenshot the test takes
// with `binding.takeScreenshot(name)` arrives here as PNG bytes and is written
// to `build/dev03_captures/<name>.png` (relative to the project root, which is
// where `flutter drive` runs; `build/` is ignored by git).
//
// The device label, when given with `--dart-define=DEV03_DEVICE=<name>`, is
// already part of <name>: the test prefixes it, so this driver stays generic.
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

const String _outputDirectory = 'build/dev03_captures';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String name,
      List<int> image, [
      Map<String, Object?>? args,
    ]) async {
      // Keep file names portable: letters, digits, dot, dash and underscore.
      final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final directory = Directory(_outputDirectory);
      await directory.create(recursive: true);
      final file = File('${directory.path}/$safeName.png');
      await file.writeAsBytes(image, flush: true);
      stdout.writeln('DEV-03 capture saved: ${file.path}');
      return true;
    },
  );
}
