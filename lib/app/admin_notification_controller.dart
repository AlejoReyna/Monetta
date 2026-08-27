/// State for the owner-facing campaign composer and automation switches.
library;

import 'package:flutter/foundation.dart';

import '../data/notifications/admin_notification_client.dart';

class AdminNotificationController extends ChangeNotifier {
  AdminNotificationController({
    required this.deviceId,
    AdminNotificationClient? client,
  }) : _client = client;

  final String deviceId;
  final AdminNotificationClient? _client;

  NotificationAdminOverview overview = NotificationAdminOverview.empty;
  List<NotificationAutomationRule> rules = const [];
  CampaignPreview? pendingCampaign;
  bool loading = false;
  bool saving = false;
  String? lastError;

  bool get available => _client != null;

  Future<void> load() async {
    if (_client == null || loading) return;
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final results = await Future.wait<Object>([
        _client.overview(),
        _client.rules(),
      ]);
      overview = results[0] as NotificationAdminOverview;
      rules = results[1] as List<NotificationAutomationRule>;
    } catch (_) {
      lastError = 'No pudimos cargar campañas y automatizaciones.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> createDraft(CampaignDraftInput input) async {
    if (_client == null || saving) return false;
    return _mutate(() async {
      pendingCampaign = await _client.createAndPreview(input);
    });
  }

  Future<bool> sendPendingTest() async {
    final pending = pendingCampaign;
    if (_client == null || pending == null || saving) return false;
    return _mutate(() => _client.sendTest(pending.id, deviceId));
  }

  Future<bool> schedulePending() async {
    final pending = pendingCampaign;
    if (_client == null || pending == null || saving) return false;
    return _mutate(() async {
      await _client.scheduleNow(pending.id);
      pendingCampaign = null;
      await loadAfterMutation();
    });
  }

  Future<bool> toggleRule(NotificationAutomationRule current) async {
    if (_client == null || saving) return false;
    final next = current.copyWith(enabled: !current.enabled);
    return _mutate(() async {
      await _client.setRule(next);
      rules = [
        for (final rule in rules)
          if (rule.key == next.key) next else rule,
      ];
    });
  }

  void discardPending() {
    pendingCampaign = null;
    notifyListeners();
  }

  Future<void> loadAfterMutation() async {
    final client = _client;
    if (client == null) return;
    overview = await client.overview();
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    saving = true;
    lastError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (_) {
      lastError = 'No pudimos guardar el cambio. Inténtalo de nuevo.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }
}
