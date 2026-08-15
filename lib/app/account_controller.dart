/// App-level account state. Plain `ChangeNotifier`, same deliberate choice
/// as `CatalogStore` (see its doc comment) — this is a single object, and
/// Riverpod wiring is still a Phase-2-or-later concern, not something to
/// introduce for one more controller.
///
/// Login is additive, never a wall: `account == null` is a perfectly normal,
/// fully-functional state — see `lib/data/customer_auth/README.md` § 5.
library;

import 'package:flutter/foundation.dart';

import '../data/accounts_orders/system_account_session_repository.dart';
import '../data/customer_auth/customer_account_config.dart';
import '../data/customer_auth/customer_session_repository.dart';
import '../data/local/account_store.dart';
import '../data/local/database.dart' as local show Account, OrderSummary;
import '../data/repositories/order_history_repository.dart';

class AccountController extends ChangeNotifier {
  AccountController({
    CustomerSessionRepository? sessionRepository,
    SystemAccountSessionRepository? systemSessionRepository,
    required AccountStore accountStore,
    required DeviceStore deviceStore,
    required OrderHistoryRepository orderHistoryRepository,
    CustomerAccountConfig? config,
    required String deviceId,
  })  : _sessionRepository = sessionRepository,
        _systemSessionRepository = systemSessionRepository,
        _accountStore = accountStore,
        _deviceStore = deviceStore,
        _orderHistoryRepository = orderHistoryRepository,
        _config = config,
        _deviceId = deviceId;

  final CustomerSessionRepository? _sessionRepository;
  final SystemAccountSessionRepository? _systemSessionRepository;
  final AccountStore _accountStore;
  final DeviceStore _deviceStore;
  final OrderHistoryRepository _orderHistoryRepository;
  final CustomerAccountConfig? _config;
  final String _deviceId;

  local.Account? account;
  bool isLoading = false;
  String? lastError;

  /// "Mis pedidos" — real Shopify checkout orders and hand-entered WhatsApp
  /// apartado orders, unified (`docs/ACCOUNTS_AND_SYNC_PLAN.md` Phase 3).
  /// Populated by [loadOrders]; empty (not loading, not an error) whenever
  /// nobody is signed in.
  List<local.OrderSummary> orders = const [];
  bool ordersLoading = false;

  bool get isSignedIn => account != null;

  /// True once a Partner-dashboard registration exists — see
  /// `CustomerAccountConfig.isUsable`. The login entry point should hide or
  /// disable itself when this is false rather than let the shopper start a
  /// flow that cannot finish.
  bool get canLogin => _sessionRepository != null && _config?.isUsable == true;

  /// First-party registration is independent of Shopify and only needs the
  /// Monetta accounts service to be configured.
  bool get canRegister => _systemSessionRepository?.canRegister == true;
  bool get canSystemLogin => _systemSessionRepository?.canLogin == true;

  /// Restores whichever account this device was last signed into, if any —
  /// call once at startup so "still logged in" survives a restart. Cheap:
  /// reads local rows only, no network.
  Future<void> restore() async {
    final device = await _deviceStore.byId(_deviceId);
    final accountId = device?.accountId;
    if (accountId == null) return;
    final restored = await _accountStore.byLocalId(accountId);
    if (restored?.authProvider == 'monetta' &&
        await _systemSessionRepository?.hasUsableLocalSession(accountId) !=
            true) {
      await _deviceStore.detachAccount(_deviceId);
      return;
    }
    account = restored;
    notifyListeners();
  }

  Future<void> login() async {
    if (!canLogin || isLoading) return;
    final sessionRepository = _sessionRepository!;
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      final session = await sessionRepository.login();
      account = session.account;
    } catch (error) {
      // A cancelled system browser is the overwhelmingly common "failure"
      // here (the shopper backed out) — surfaced the same as any other
      // error rather than special-cased, since there is nothing more
      // actionable to tell them either way.
      lastError = '$error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    // Awaited, not fire-and-forget: `isLoading` (the login button's own
    // spinner) already flipped false above, so this doesn't change that
    // timing — but a dangling untracked Future here previously meant
    // `login()` could "complete" while `loadOrders()` was still mid-flight
    // against the database, which is exactly the kind of thing that races
    // a caller tearing the database down right after awaiting login().
    // `ordersLoading` is the separate flag that governs the order list's
    // own spinner.
    if (isSignedIn) await loadOrders();
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final repository = _systemSessionRepository;
    if (repository == null || !repository.canRegister || isLoading) return;
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      account = await repository.register(
        email: email.trim(),
        password: password,
        displayName:
            displayName?.trim().isEmpty == true ? null : displayName?.trim(),
      );
    } catch (error) {
      lastError = '$error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithSystemAccount({
    required String email,
    required String password,
  }) async {
    final repository = _systemSessionRepository;
    if (repository == null || !repository.canLogin || isLoading) return;
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      account = await repository.login(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      lastError = '$error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
    if (isSignedIn) await loadOrders();
  }

  Future<void> logout() async {
    final current = account;
    if (current == null) return;
    isLoading = true;
    notifyListeners();
    try {
      if (current.authProvider == 'monetta') {
        await _systemSessionRepository?.logout(current.localAccountId);
      } else {
        await _sessionRepository?.logout(current.localAccountId);
      }
      account = null;
      orders = const [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Cache-first, same shape as everything else in this app: local rows
  /// paint immediately, then a background refresh from
  /// `services/accounts_orders` (a safe no-op if that service isn't
  /// configured — see `OrderHistoryRepository.canRefresh`) replaces them.
  Future<void> loadOrders() async {
    final current = account;
    if (current == null) return;

    ordersLoading = true;
    notifyListeners();

    orders = await _orderHistoryRepository.loadCached(current.localAccountId);
    notifyListeners();

    final shopifyCustomerId = current.shopifyCustomerId;
    if (shopifyCustomerId != null) {
      await _orderHistoryRepository.refresh(
        accountId: current.localAccountId,
        shopifyCustomerId: shopifyCustomerId,
      );
      orders = await _orderHistoryRepository.loadCached(current.localAccountId);
    }

    ordersLoading = false;
    notifyListeners();
  }
}
