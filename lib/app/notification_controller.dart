/// Coordinates consent, FCM token registration and reduced profile sync.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import '../data/customer_auth/secure_token_store.dart';
import '../data/notifications/firebase_notification_gateway.dart';
import '../data/notifications/interest_profile_snapshot.dart';
import '../data/notifications/local_notification_scheduler.dart';
import '../data/notifications/notification_api_client.dart';
import '../data/notifications/notification_config.dart';
import '../data/notifications/notification_models.dart';
import 'catalog_store.dart';

const _credentialKey = 'notification_device_credential_v1';
const _preferencesKey = 'notification_preferences_v1';
const _profileVersionKey = 'notification_profile_version_v1';

class NotificationController extends ChangeNotifier {
  NotificationController({
    required this.config,
    required this.deviceId,
    required this.catalogStore,
    required this.secureStore,
    required this.onOpenRoute,
    NotificationGateway? gateway,
    NotificationApiClient? apiClient,
    LocalNotificationScheduler? localScheduler,
  })  : _gateway = gateway,
        _api = apiClient,
        _local = localScheduler;

  final NotificationConfig config;
  final String deviceId;
  final CatalogStore catalogStore;
  final SecureTokenStore secureStore;
  final void Function(NotificationRouteData route) onOpenRoute;
  final NotificationGateway? _gateway;
  final NotificationApiClient? _api;
  final LocalNotificationScheduler? _local;

  NotificationPreferences preferences = const NotificationPreferences();
  NotificationPermissionState permission =
      NotificationPermissionState.notDetermined;
  bool ready = false;
  bool saving = false;
  String? lastError;
  String? _credential;
  Future<void>? _restoring;
  bool _disposed = false;
  int _profileVersion = 0;
  String? _lastProfileFingerprint;
  String? _activeDeliveryId;
  int? _lastBagQuantity;
  LocalCartReminderConfig _localConfig = LocalCartReminderConfig.disabled;
  Timer? _profileDebounce;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<NotificationEnvelope>? _foregroundSubscription;
  StreamSubscription<NotificationEnvelope>? _openedSubscription;

  bool get available => config.isUsable && _gateway != null && _api != null;

  /// Loads the saved state, syncs with the service and delivers the route of a
  /// notification that launched the app. Never throws: failures are kept in
  /// [lastError] and [ready] always ends up `true`.
  Future<void> restore() {
    final running = _restore();
    _restoring = running;
    return running;
  }

  /// Waits for a [restore] that has already started, so the first-frame
  /// permission prompt and the settings actions never read state that
  /// [restore] has not loaded yet. Without a [restore] it returns at once.
  Future<void> _awaitRestore() async {
    final running = _restoring;
    if (running != null) await running;
  }

  Future<void> _restore() async {
    if (!available) {
      ready = true;
      if (!_disposed) notifyListeners();
      return;
    }
    NotificationRouteData? localInitial;
    try {
      _credential = await secureStore.read(_credentialKey);
      final rawPreferences = await secureStore.read(_preferencesKey);
      if (rawPreferences != null) {
        final value = jsonDecode(rawPreferences);
        if (value is Map<String, dynamic>) {
          preferences = NotificationPreferences.fromJson(value);
        }
      }
      _profileVersion = int.tryParse(
            await secureStore.read(_profileVersionKey) ?? '',
          ) ??
          0;
      permission = await _gateway!.permissionState();
      localInitial = await _local?.initialize(_openRoute);
      if (_disposed) return;
      _listenToProviders();

      if (_credential != null) {
        await _refreshInstallation();
        if (preferences.anyEnabled && permission.canReceive) {
          await _syncEndpoint();
          await _syncPreferences(source: 'settings');
          if (preferences.personalizedOffers) await _syncProfile(force: true);
        }
      }
      _localConfig = await _api!.fetchConfig();
      if (_disposed) return;
      catalogStore.addListener(_onCatalogChanged);
      await _updateCartReminder();
    } catch (error) {
      lastError = _friendlyError(error);
    }

    // A tapped notification must open its route even when the steps above
    // failed (for instance with no connectivity), so it is read on its own.
    try {
      if (_disposed) return;
      final firebaseInitial = await _gateway!.takeInitialMessage();
      final initialRoute = firebaseInitial?.route ?? localInitial;
      if (initialRoute != null && !_disposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) _openRoute(initialRoute);
        });
      }
    } catch (error) {
      lastError ??= _friendlyError(error);
    } finally {
      ready = true;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> savePreferences(
    NotificationPreferences next, {
    String source = 'settings',
  }) async {
    // Only a restore() already under way is awaited; otherwise this stays
    // synchronous up to the first real await, as before.
    if (_restoring != null) await _awaitRestore();
    if (_disposed || !available || saving) return false;
    saving = true;
    lastError = null;
    notifyListeners();
    try {
      if (next.anyEnabled) {
        permission = await _gateway!.requestPermission();
        if (!permission.canReceive) {
          throw const NotificationException(
            'Las notificaciones están desactivadas en la configuración del dispositivo.',
          );
        }
        await _ensureInstallation();
        await _syncEndpoint();
      } else if (_credential == null) {
        preferences = next;
        await _persistPreferences();
        return true;
      }
      preferences = next;
      await _syncPreferences(source: source);
      await _persistPreferences();
      if (preferences.personalizedOffers) {
        await _syncProfile(force: true);
      }
      await _updateCartReminder();
      return true;
    } catch (error) {
      lastError = _friendlyError(error);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// Shows the operating system's notification prompt once and registers the
  /// device when the shopper accepts. Personalized offers and product alerts
  /// remain opt-in at their own points of intent.
  Future<bool> requestSystemPermission() async {
    // Only a restore() already under way is awaited; otherwise this stays
    // synchronous up to the first real await, as before.
    if (_restoring != null) await _awaitRestore();
    if (_disposed || !available || saving) return false;
    if (permission != NotificationPermissionState.notDetermined) {
      return permission.canReceive;
    }
    saving = true;
    lastError = null;
    notifyListeners();
    try {
      permission = await _gateway!.requestPermission();
      if (!permission.canReceive) return false;

      preferences = preferences.copyWith(announcements: true);
      // Persist consent before registration so a temporary network failure is
      // retried by restore() on the next launch without another OS prompt.
      await _persistPreferences();
      await _ensureInstallation();
      await _syncEndpoint();
      await _syncPreferences(source: 'permission_prompt');
      await _updateCartReminder();
      return true;
    } catch (error) {
      lastError = _friendlyError(error);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> createRestockAlert(String rawProductId) async {
    // Only a restore() already under way is awaited; otherwise this stays
    // synchronous up to the first real await, as before.
    if (_restoring != null) await _awaitRestore();
    if (_disposed || !available || saving) return false;
    saving = true;
    lastError = null;
    notifyListeners();
    try {
      permission = await _gateway!.requestPermission();
      if (!permission.canReceive) {
        throw const NotificationException(
          'Activa las notificaciones del dispositivo para recibir este aviso.',
        );
      }
      await _ensureInstallation();
      await _syncEndpoint();
      final next = preferences.copyWith(productAlerts: true);
      preferences = next;
      await _syncPreferences(source: 'product_alert');
      await _persistPreferences();
      await _api!.createProductAlert(
        credential: _credential!,
        productKey: _shopifyProductKey(rawProductId),
      );
      return true;
    } catch (error) {
      lastError = _friendlyError(error);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  void recordPushOutcome(String event) {
    final deliveryId = _activeDeliveryId;
    final credential = _credential;
    final api = _api;
    if (deliveryId == null || credential == null || api == null) return;
    if (!const {
      'product_viewed',
      'add_to_cart',
      'checkout_started',
      'purchased',
    }.contains(event)) {
      return;
    }
    unawaited(
      api.recordInteraction(
        credential: credential,
        deliveryId: deliveryId,
        event: event,
      ),
    );
  }

  void _listenToProviders() {
    _tokenSubscription = _gateway!.tokenChanges.listen((token) async {
      if (_credential == null || !preferences.anyEnabled) return;
      try {
        await _api!.putPushEndpoint(
          credential: _credential!,
          registrationId: token,
          permissionState: permission,
        );
      } catch (_) {
        // Token rotation is retried on the next app start/rotation event.
      }
    });
    _foregroundSubscription = _gateway.foregroundMessages.listen((message) {
      final local = _local;
      if (local != null) unawaited(local.showForeground(message));
    });
    _openedSubscription = _gateway.openedMessages.listen(
      (message) => _openRoute(message.route),
    );
  }

  Future<void> _ensureInstallation() async {
    if (_credential != null) return;
    await _refreshInstallation();
  }

  Future<void> _refreshInstallation() async {
    final next = await _api!.registerInstallation(
      deviceId: deviceId,
      platform: Platform.isIOS ? 'ios' : 'android',
      locale: Platform.localeName.replaceAll('_', '-'),
      timezone: config.timezone,
      appVersion: '0.1.0',
      existingCredential: _credential,
    );
    _credential = next;
    await secureStore.write(_credentialKey, next);
  }

  Future<void> _syncEndpoint() async {
    String? token;
    for (var attempt = 0; attempt < 3 && token == null; attempt++) {
      token = await _gateway!.registrationToken();
      if (token == null && attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    if (token == null || token.isEmpty) {
      throw const NotificationException(
        'El dispositivo todavía no generó un token de notificaciones.',
      );
    }
    await _api!.putPushEndpoint(
      credential: _credential!,
      registrationId: token,
      permissionState: permission,
    );
  }

  Future<void> _syncPreferences({required String source}) {
    return _api!.putPreferences(
      credential: _credential!,
      preferences: preferences,
      source: source,
    );
  }

  Future<void> _persistPreferences() {
    return secureStore.write(
      _preferencesKey,
      jsonEncode(preferences.toJson(source: 'settings')),
    );
  }

  void _onCatalogChanged() {
    unawaited(_updateCartReminder());
    if (!preferences.personalizedOffers || _credential == null) return;
    _profileDebounce?.cancel();
    _profileDebounce = Timer(
      const Duration(seconds: 2),
      () => unawaited(_syncProfile()),
    );
  }

  Future<void> _syncProfile({bool force = false}) async {
    final entries = catalogStore.profile.weights.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final fingerprint = '${catalogStore.profile.eventCount}|${entries.map(
          (entry) => '${entry.key}:${entry.value.toStringAsFixed(3)}',
        ).join(',')}';
    if (!force && fingerprint == _lastProfileFingerprint) return;
    _profileVersion++;
    final snapshot = InterestProfileSnapshot.fromTasteProfile(
      catalogStore.profile,
      profileVersion: _profileVersion,
    );
    await _api!.putInterestProfile(
      credential: _credential!,
      profile: snapshot,
    );
    _lastProfileFingerprint = fingerprint;
    await secureStore.write(_profileVersionKey, '$_profileVersion');
  }

  Future<void> _updateCartReminder() async {
    final quantity = catalogStore.bagQuantity;
    if (_lastBagQuantity == quantity) return;
    _lastBagQuantity = quantity;
    if (_local == null) return;
    final canSchedule = _localConfig.enabled &&
        preferences.personalizedOffers &&
        permission.canReceive &&
        quantity > 0;
    if (canSchedule) {
      await _local.scheduleCartReminder(config: _localConfig);
    } else {
      await _local.cancelCartReminder();
    }
  }

  void _openRoute(NotificationRouteData route) {
    final deliveryId = route.deliveryId;
    final api = _api;
    if (deliveryId != null && _credential != null && api != null) {
      _activeDeliveryId = deliveryId;
      unawaited(
        api.recordOpen(
          credential: _credential!,
          deliveryId: deliveryId,
        ),
      );
    }
    onOpenRoute(route);
  }

  static String _shopifyProductKey(String raw) {
    return raw.startsWith('shopify:') ? raw : 'shopify:$raw';
  }

  static String _friendlyError(Object error) {
    return error is NotificationException
        ? error.message
        : 'No pudimos guardar tu preferencia. Inténtalo de nuevo.';
  }

  @override
  void dispose() {
    _disposed = true;
    catalogStore.removeListener(_onCatalogChanged);
    _profileDebounce?.cancel();
    unawaited(_tokenSubscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    _api?.close();
    _gateway?.dispose();
    super.dispose();
  }
}
