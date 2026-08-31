/// Runtime build metadata used by device registration and cart attribution.
library;

import 'package:package_info_plus/package_info_plus.dart';

class AppBuildMetadata {
  const AppBuildMetadata({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  String get displayVersion =>
      buildNumber.isEmpty ? version : '$version+$buildNumber';

  static Future<AppBuildMetadata> load({
    Future<PackageInfo> Function()? packageInfoLoader,
  }) async {
    try {
      final info = await (packageInfoLoader ?? PackageInfo.fromPlatform)();
      final version = info.version.trim();
      return AppBuildMetadata(
        version: version.isEmpty ? '0.1.0' : version,
        buildNumber: info.buildNumber.trim(),
      );
    } on Object {
      // Unit tests and unsupported hosts do not register the platform plugin.
      // Keep startup available while using the pubspec version as a fallback.
      return const AppBuildMetadata(version: '0.1.0', buildNumber: '1');
    }
  }
}
