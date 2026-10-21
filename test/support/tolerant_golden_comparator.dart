import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [LocalFileComparator] that accepts a golden whose pixel difference is at
/// or below [tolerance], expressed as a fraction (0.005 is 0.5 %).
///
/// CoreText can vary slightly between macOS releases, so text edges may move
/// by a pixel without the screen having changed. Anything above the tolerance
/// fails with the standard difference report written next to the golden.
class TolerantGoldenComparator extends LocalFileComparator {
  /// [testFile] is the URI of the test file; goldens resolve relative to it.
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.005});

  /// Largest accepted `diffPercent`, as a fraction.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
