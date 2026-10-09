import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

/// Mounts the real `MonettaApp` with only its platform edges faked, for the
/// tests that must observe the app root (RF-17 UI-01 and UI-02).
///
/// Faked: `path_provider` (Drift's `monetta.sqlite` lives in a temp directory),
/// `flutter_secure_storage` (in memory), the asset bundle (an empty bundled
/// catalog) and the default `http.Client` (an in-memory server that answers
/// 404). No clock and no network: the Drift background isolate and the file I/O
/// need the real event loop, so the bootstrap yields to it through
/// `tester.runAsync` while the simulated clock stays frozen.
///
/// `CatalogStore` caches assets in statics per isolate, so every test in one
/// file must use the same (empty) catalog: this harness always does.

const Map<String, Object?> _emptyCatalog = <String, Object?>{
  '_source': 'test',
  '_snapshot': '2026-10-06',
  'products': <Object?>[],
};

/// Runs [body] with `MonettaApp` mounted and its home on screen, then unmounts
/// the app and drains the Drift isolate before removing the temp directory.
Future<void> withMonettaApp(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final dir = Directory.systemTemp.createTempSync('monetta_app_harness_');
  _installPlatformFakes(tester, dir);
  final server = MockClient((request) async => http.Response('{}', 404));

  try {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(const MonettaApp());
        await _bootstrapToHome(tester);
        await body();
      },
      () => server,
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    await tester.runAsync(() async {
      // Let the Drift background isolate drain before the temp dir goes away.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Best effort: the OS temp dir is reclaimed anyway.
      }
    });
  }
}

/// Yields to the real event loop, with the simulated clock frozen, until the
/// home is mounted. The iteration cap only guards against a hung bootstrap.
Future<void> _bootstrapToHome(WidgetTester tester) async {
  for (var i = 0; i < 1500; i += 1) {
    if (find.byType(HomeScreen).evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  fail('MonettaApp never mounted HomeScreen.');
}

void _installPlatformFakes(WidgetTester tester, Directory dir) {
  final messenger = tester.binding.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => dir.path,
  );

  final secure = <String, String>{};
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final arguments = (call.arguments as Map?)?.cast<String, Object?>();
      final key = arguments?['key'] as String?;
      switch (call.method) {
        case 'write':
          secure[key!] = arguments!['value']! as String;
          return null;
        case 'read':
          return secure[key];
        case 'delete':
          secure.remove(key);
          return null;
        case 'containsKey':
          return secure.containsKey(key);
        case 'readAll':
          return Map<String, String>.of(secure);
        case 'deleteAll':
          secure.clear();
          return null;
      }
      return null;
    },
  );

  final emptyCatalog = ByteData.sublistView(
    Uint8List.fromList(utf8.encode(jsonEncode(_emptyCatalog))),
  );
  messenger.setMockMessageHandler('flutter/assets', (message) async {
    if (message != null) {
      final key = utf8.decode(
        message.buffer
            .asUint8List(message.offsetInBytes, message.lengthInBytes),
      );
      if (key.endsWith('assets/catalog/catalog.json')) return emptyCatalog;
    }
    return messenger.delegate.send('flutter/assets', message);
  });

  addTearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    messenger.setMockMessageHandler('flutter/assets', null);
  });
}
