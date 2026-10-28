import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final directory = Directory('artifacts/iphone-duo/runtime-captures');
  await directory.create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [arguments]) async {
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes, flush: true);
      return true;
    },
    responseDataCallback: (data) async {
      await File('artifacts/iphone-duo/runtime-task-result.txt')
          .writeAsString('Report keys: ${data?.keys.join(', ')}');
    },
  );
}
