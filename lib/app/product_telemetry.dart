/// Privacy-bounded product analytics and crash reporting.
library;

import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';

enum ProductEvent {
  appOpen('app_open'),
  onboardingCompleted('onboarding_completed'),
  onboardingSkipped('onboarding_skipped'),
  searchSubmitted('search_submitted'),
  viewItem('view_item'),
  wishlistChanged('wishlist_changed'),
  addToCart('add_to_cart'),
  beginCheckout('begin_checkout'),
  checkoutHandoff('checkout_handoff'),
  checkoutCompleted('checkout_completed'),
  checkoutCancelled('checkout_cancelled'),
  checkoutFailed('checkout_failed'),
  loginCompleted('login_completed'),
  loginFailed('login_failed'),
  orderRefresh('order_refresh'),
  adminMutation('admin_mutation');

  const ProductEvent(this.analyticsName);
  final String analyticsName;
}

class TelemetryConfig {
  const TelemetryConfig({required this.enabled});

  factory TelemetryConfig.fromEnvironment() => const TelemetryConfig(
        enabled: bool.fromEnvironment('TELEMETRY_ENABLED'),
      );

  final bool enabled;
}

abstract interface class ProductTelemetry {
  bool get enabled;

  Future<void> log(
    ProductEvent event, {
    Map<String, Object?> parameters = const {},
  });

  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  });
}

class DisabledProductTelemetry implements ProductTelemetry {
  const DisabledProductTelemetry();

  @override
  bool get enabled => false;

  @override
  Future<void> log(
    ProductEvent event, {
    Map<String, Object?> parameters = const {},
  }) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) async {}
}

class FirebaseProductTelemetry implements ProductTelemetry {
  FirebaseProductTelemetry._(this._analytics, this._crashlytics);

  final FirebaseAnalytics _analytics;
  final FirebaseCrashlytics _crashlytics;

  static Future<FirebaseProductTelemetry> start() async {
    final analytics = FirebaseAnalytics.instance;
    final crashlytics = FirebaseCrashlytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    await crashlytics.setCrashlyticsCollectionEnabled(true);
    return FirebaseProductTelemetry._(analytics, crashlytics);
  }

  @override
  bool get enabled => true;

  @override
  Future<void> log(
    ProductEvent event, {
    Map<String, Object?> parameters = const {},
  }) {
    return _analytics.logEvent(
      name: event.analyticsName,
      parameters: sanitizeTelemetryParameters(parameters),
    );
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
    String? reason,
  }) {
    return _crashlytics.recordError(
      error,
      stackTrace,
      fatal: fatal,
      reason: reason,
    );
  }
}

/// Keeps event payloads low-cardinality and rejects identifiers/PII at the
/// boundary. Product and variant IDs are deliberately not analytics fields.
Map<String, Object> sanitizeTelemetryParameters(
  Map<String, Object?> input,
) {
  const allowed = {
    'environment',
    'source',
    'category',
    'brand',
    'currency',
    'result_count',
    'query_length',
    'item_count',
    'in_stock',
    'enabled',
    'success',
    'status',
  };
  final output = <String, Object>{};
  for (final entry in input.entries) {
    if (!allowed.contains(entry.key)) continue;
    final value = entry.value;
    if (value is num || value is bool) {
      output[entry.key] = value as Object;
    } else if (value is String && value.length <= 80) {
      output[entry.key] = value;
    }
  }
  return output;
}

class ProductTelemetryScope extends InheritedWidget {
  const ProductTelemetryScope({
    required this.telemetry,
    required super.child,
    super.key,
  });

  final ProductTelemetry telemetry;

  static ProductTelemetry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ProductTelemetryScope>()
      ?.telemetry;

  @override
  bool updateShouldNotify(ProductTelemetryScope oldWidget) =>
      !identical(telemetry, oldWidget.telemetry);
}

void logProductEvent(
  BuildContext context,
  ProductEvent event, {
  Map<String, Object?> parameters = const {},
}) {
  final telemetry = ProductTelemetryScope.maybeOf(context);
  if (telemetry == null) return;
  unawaited(telemetry.log(event, parameters: parameters));
}
