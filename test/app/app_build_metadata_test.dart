import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/app_build_metadata.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('uses native package version and build number', () async {
    final metadata = await AppBuildMetadata.load(
      packageInfoLoader: () async => PackageInfo(
        appName: 'Monetta',
        packageName: 'mx.monetta.monettaApp',
        version: '2.4.1',
        buildNumber: '91',
      ),
    );

    expect(metadata.version, '2.4.1');
    expect(metadata.buildNumber, '91');
    expect(metadata.displayVersion, '2.4.1+91');
  });

  test('falls back without a registered platform plugin', () async {
    final metadata = await AppBuildMetadata.load(
      packageInfoLoader: () async => throw StateError('plugin unavailable'),
    );

    expect(metadata.displayVersion, '0.1.0+1');
  });
}
