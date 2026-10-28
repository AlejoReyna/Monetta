import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:monetta_app/main.dart' as app;
import 'package:monetta_app/platform/system_layout_context.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Duo host delivers coherent view-relative geometry',
      (tester) async {
    await app.main();
    SystemLayoutContext geometry = const SystemLayoutContext();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
      final scopes = find.byType(SystemLayoutScope);
      if (scopes.evaluate().isNotEmpty) {
        geometry = tester.widget<SystemLayoutScope>(scopes.first).geometry;
        if (geometry.supported) break;
      }
    }
    expect(geometry.supported, isTrue);
    expect(geometry.viewSize.width, greaterThan(0));
    expect(geometry.viewSize.height, greaterThan(0));
    expect(geometry.sequence, greaterThan(0));
    // Public geometry only: no account, query, cart, or checkout values.
    // Emitted to the local test log for the native spike evidence.
    debugPrint(
      jsonEncode({
        'size': [geometry.viewSize.width, geometry.viewSize.height],
        'safeInsets': [
          geometry.safeInsets.left,
          geometry.safeInsets.top,
          geometry.safeInsets.right,
          geometry.safeInsets.bottom,
        ],
        'barEdge': geometry.barEdge.name,
        'divisions': [
          for (final r in geometry.divisions)
            {
              'frame': [
                r.bounds.left,
                r.bounds.top,
                r.bounds.width,
                r.bounds.height,
              ],
              'active': r.active,
            },
        ],
        'occlusions': [
          for (final r in geometry.occlusions)
            {
              'frame': [
                r.bounds.left,
                r.bounds.top,
                r.bounds.width,
                r.bounds.height,
              ],
              'active': r.active,
            },
        ],
      }),
    );
  });
}
