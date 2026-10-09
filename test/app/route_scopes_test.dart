import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/onboarding_controller.dart';
import 'package:monetta_app/app/product_telemetry.dart';
import 'package:monetta_app/app/theme_controller.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

import '../support/monetta_app_harness.dart';

/// One app scope, probed by exact type from any [BuildContext].
class _ScopeProbe {
  const _ScopeProbe(this.name, this.isVisibleFrom);

  final String name;
  final bool Function(BuildContext context) isVisibleFrom;
}

/// Every scope of the app: the nine declared in `main.dart` plus the three in
/// `lib/app/`. `WelcomeScope` belongs to the welcome feature and
/// `AppRouteScopes` is a composition widget, not a scope: neither is listed.
final List<_ScopeProbe> _appScopes = <_ScopeProbe>[
  _ScopeProbe(
    'StoreScope',
    (c) => c.getElementForInheritedWidgetOfExactType<StoreScope>() != null,
  ),
  _ScopeProbe(
    'EditorialContentScope',
    (c) =>
        c.getElementForInheritedWidgetOfExactType<EditorialContentScope>() !=
        null,
  ),
  _ScopeProbe(
    'HomeContentScope',
    (c) =>
        c.getElementForInheritedWidgetOfExactType<HomeContentScope>() != null,
  ),
  _ScopeProbe(
    'FeaturedCatalogScope',
    (c) =>
        c.getElementForInheritedWidgetOfExactType<FeaturedCatalogScope>() !=
        null,
  ),
  _ScopeProbe(
    'AccountScope',
    (c) => c.getElementForInheritedWidgetOfExactType<AccountScope>() != null,
  ),
  _ScopeProbe(
    'CartScope',
    (c) => c.getElementForInheritedWidgetOfExactType<CartScope>() != null,
  ),
  _ScopeProbe(
    'AdminScope',
    (c) => c.getElementForInheritedWidgetOfExactType<AdminScope>() != null,
  ),
  _ScopeProbe(
    'NotificationScope',
    (c) =>
        c.getElementForInheritedWidgetOfExactType<NotificationScope>() != null,
  ),
  _ScopeProbe(
    'AdminNotificationScope',
    (c) =>
        c.getElementForInheritedWidgetOfExactType<AdminNotificationScope>() !=
        null,
  ),
  _ScopeProbe(
    'ThemeScope',
    (c) => c.getElementForInheritedWidgetOfExactType<ThemeScope>() != null,
  ),
  _ScopeProbe(
    'OnboardingScope',
    (c) => c.getElementForInheritedWidgetOfExactType<OnboardingScope>() != null,
  ),
  _ScopeProbe(
    'ProductTelemetryScope',
    (c) =>
        c.getElementForInheritedWidgetOfExactType<ProductTelemetryScope>() !=
        null,
  ),
];

void main() {
  testWidgets(
    'CHAR-15 (objetivo, roja hasta RF-30) a pushed route sees every app scope '
    'the home sees',
    (tester) async {
      await withMonettaApp(tester, () async {
        final homeContext = tester.element(find.byType(HomeScreen));

        BuildContext? pushedContext;
        final navigator = Navigator.of(homeContext, rootNavigator: true);
        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (context) {
                pushedContext = context;
                return const Scaffold(body: SizedBox.expand());
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          pushedContext,
          isNotNull,
          reason: 'the pushed route was never built',
        );

        final seenByHome = <String>[];
        final notSeenByHome = <String>[];
        final missingInRoute = <String>[];
        for (final scope in _appScopes) {
          if (!scope.isVisibleFrom(homeContext)) {
            notSeenByHome.add(scope.name);
            continue;
          }
          seenByHome.add(scope.name);
          if (!scope.isVisibleFrom(pushedContext!)) {
            missingInRoute.add(scope.name);
          }
        }

        // The comparison below is only meaningful if the home really sees the
        // core scopes; otherwise the harness, not the app, is at fault.
        expect(
          seenByHome,
          containsAll(<String>[
            'StoreScope',
            'AccountScope',
            'ThemeScope',
            'ProductTelemetryScope',
            'NotificationScope',
            'AdminScope',
          ]),
          reason: 'the home does not see the core scopes; scopes the home '
              'does not see: $notSeenByHome',
        );

        expect(
          missingInRoute,
          isEmpty,
          reason: 'A route pushed on the root Navigator must see every app '
              'scope the home sees. Missing in the pushed route: '
              '$missingInRoute. Seen by the home: $seenByHome. Not seen by '
              'the home either (not counted): $notSeenByHome.',
        );
      });
    },
  );
}
