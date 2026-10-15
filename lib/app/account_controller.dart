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
import '../data/customer_auth/customer_auth_error.dart';
import '../data/customer_auth/customer_session_repository.dart';
import '../data/accounts_orders/account_deletion_client.dart';
import '../data/local/account_store.dart';
import '../data/local/database.dart' as local show Account, OrderSummary;
import '../data/local/wishlist_store.dart';
import '../data/repositories/order_history_repository.dart';

/// Which of the two entry points a failure came from. They fail for different
/// reasons and deserve different sentences: a Shopify login can be cancelled
/// in a browser, and a Monetta password login cannot.
enum AccountAuthFlow { shopify, monetta }

/// A login failure the UI can render without ever printing an exception.
class AccountError {
  const AccountError({
    required this.flow,
    required this.kind,
    this.debugDetail,
  });

  final AccountAuthFlow flow;

  /// Precise for [AccountAuthFlow.shopify] (see
  /// `data/customer_auth/customer_auth_error.dart`); coarse for
  /// [AccountAuthFlow.monetta], where the accounts service reports failures
  /// as bare status codes and the screen shows one generic sentence anyway.
  final CustomerAuthErrorKind kind;

  /// Logs and telemetry only — never rendered, never a token or a password.
  final String? debugDetail;

  /// The shopper backing out of the browser is not a problem to report.
  bool get isSilent => kind == CustomerAuthErrorKind.cancelled;

  @override
  String toString() => 'AccountError(${flow.name}/${kind.name})';
}

class AccountController extends ChangeNotifier {
  AccountController({
    CustomerSessionRepository? sessionRepository,
    SystemAccountSessionRepository? systemSessionRepository,
    required AccountStore accountStore,
    required DeviceStore deviceStore,
    required OrderHistoryRepository orderHistoryRepository,
    CustomerAccountConfig? config,
    required String deviceId,
    WishlistStore? wishlistStore,
    Future<void> Function(String? accountId)? onAccountScopeChanged,
  })  : _sessionRepository = sessionRepository,
        _systemSessionRepository = systemSessionRepository,
        _accountStore = accountStore,
        _deviceStore = deviceStore,
        _orderHistoryRepository = orderHistoryRepository,
        _config = config,
        _deviceId = deviceId,
        _wishlistStore = wishlistStore,
        _onAccountScopeChanged = onAccountScopeChanged;

  final CustomerSessionRepository? _sessionRepository;
  final SystemAccountSessionRepository? _systemSessionRepository;
  final AccountStore _accountStore;
  final DeviceStore _deviceStore;
  final OrderHistoryRepository _orderHistoryRepository;
  final CustomerAccountConfig? _config;
  final String _deviceId;
  final WishlistStore? _wishlistStore;
  final Future<void> Function(String? accountId)? _onAccountScopeChanged;
  HeldShopifyLogin? _heldDeletionLogin;

  local.Account? account;
  bool isLoading = false;

  /// The last failure, or null if the last attempt succeeded (or there has
  /// been none). Classified, never a raw exception — the shopper must never
  /// be shown a platform error string.
  AccountError? lastError;

  /// "Mis pedidos" — Shopify Customer Account history (primary) plus
  /// WhatsApp apartado enrichment from the Monetta mirror when available.
  /// Populated by [loadOrders]; cleared on logout / account switch.
  List<local.OrderSummary> orders = const [];
  OrderHistoryStatus ordersStatus = OrderHistoryStatus.unavailable;
  bool ordersLoading = false;
  int _ordersGeneration = 0;

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

  /// Credential for the owner control plane. Both first-party Monetta sessions
  /// and Shopify Customer sessions are accepted; the server resolves the
  /// subject and role, and Shopify Admin credentials never enter the app.
  Future<String?> accessTokenForAdmin() => accessTokenForBackend();

  /// Credential for customer-scoped Monetta backend routes. Shopify accounts
  /// use their short-lived Customer Account token; legacy Monetta accounts use
  /// the opaque server session already stored in the platform keychain.
  Future<String?> accessTokenForBackend() async {
    final current = account;
    if (current == null) return null;
    try {
      if (current.authProvider == 'monetta') {
        return await _systemSessionRepository?.accessTokenFor(
          current.localAccountId,
        );
      }
      return await _sessionRepository?.accessTokenFor(current.localAccountId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _publishAccountScope() async {
    final callback = _onAccountScopeChanged;
    if (callback == null) return;
    await callback(account?.localAccountId);
  }

  /// Restores whichever account this device was last signed into, if any —
  /// call once at startup so "still logged in" survives a restart. Cheap:
  /// reads local rows only, no network.
  Future<void> restore() async {
    final device = await _deviceStore.byId(_deviceId);
    final accountId = device?.accountId;
    if (accountId == null) return;
    final restored = await _accountStore.byLocalId(accountId);
    if (!await _hasUsableSessionFor(restored, accountId)) {
      // Nothing to sign back in with — a secure-storage entry wiped by a
      // reinstall or an OS-level credential reset. Detaching is what keeps
      // this a clean guest state instead of a signed-in-looking screen whose
      // every action fails. The guest bag and wishlist are untouched: they
      // are device-scoped rows, not account-scoped ones.
      await _deviceStore.detachAccount(_deviceId);
      await _publishAccountScope();
      return;
    }
    account = restored;
    notifyListeners();
    await _publishAccountScope();
  }

  Future<bool> _hasUsableSessionFor(
    local.Account? restored,
    String accountId,
  ) async {
    if (restored == null) return false;
    if (restored.authProvider == 'monetta') {
      return await _systemSessionRepository?.hasUsableLocalSession(accountId) ==
          true;
    }
    // A Shopify account restored on a build with no Customer Account
    // credentials compiled in cannot refresh anything, but it also has no
    // broken affordance: nothing here needs an access token until the shopper
    // asks for something that does. Keep the row, let the UI show them signed
    // in, and let `revalidateSession` decide.
    final repository = _sessionRepository;
    if (repository == null) return true;
    return repository.hasUsableLocalSession(accountId);
  }

  /// Confirms with Shopify — silently, no browser — that the restored session
  /// is still real, and signs out locally if it is not. Safe to call
  /// fire-and-forget right after [restore]: it never blocks the first frame,
  /// and being offline is not treated as being signed out.
  Future<void> revalidateSession() async {
    final current = account;
    final repository = _sessionRepository;
    if (current == null ||
        repository == null ||
        current.authProvider == 'monetta') {
      return;
    }
    try {
      await repository.accessTokenFor(current.localAccountId);
    } on CustomerAuthException catch (error) {
      if (error.kind != CustomerAuthErrorKind.sessionExpired) return;
      await _signOutLocally(repository, current.localAccountId);
    } on NoActiveSessionException {
      await _signOutLocally(repository, current.localAccountId);
    }
  }

  Future<void> _signOutLocally(
    CustomerSessionRepository repository,
    String localAccountId,
  ) async {
    await repository.logout(localAccountId);
    account = null;
    orders = const [];
    ordersStatus = OrderHistoryStatus.unavailable;
    _ordersGeneration += 1;
    lastError = const AccountError(
      flow: AccountAuthFlow.shopify,
      kind: CustomerAuthErrorKind.sessionExpired,
      debugDetail: 'revalidation found no usable session',
    );
    notifyListeners();
    await _publishAccountScope();
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
      // Classified rather than stringified: a cancelled browser (by far the
      // most common outcome that isn't success) must not read like a crash,
      // and an AppAuth exception's own text is not something to put in front
      // of a shopper.
      lastError = AccountError(
        flow: AccountAuthFlow.shopify,
        kind: classifyCustomerAuthError(error),
        debugDetail: error is CustomerAuthException
            ? error.debugDetail
            : error.runtimeType.toString(),
      );
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
    if (isSignedIn) {
      await _publishAccountScope();
      await loadOrders();
    }
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
      lastError = _monettaError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
    if (isSignedIn) await _publishAccountScope();
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
      lastError = _monettaError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
    if (isSignedIn) {
      await _publishAccountScope();
      await loadOrders();
    }
  }

  /// The accounts service reports every failure as a status code inside an
  /// exception message, so there is no honest way to tell "wrong password"
  /// from "service down" here. Kept deliberately coarse rather than guessed
  /// at: the legacy password screen shows one sentence covering both, and
  /// `debugDetail` keeps the message itself for logs. Never carries the
  /// password — the exception is built from the response, not the request.
  AccountError _monettaError(Object error) => AccountError(
        flow: AccountAuthFlow.monetta,
        kind: CustomerAuthErrorKind.unknown,
        debugDetail: '$error',
      );

  /// Shopify login for a legacy Monetta session. The device account stays on
  /// the legacy row until the server says the emails match.
  Future<LegacyDeletionSignIn> signInForAccountDeletion(
    AccountDeletionClient? client,
  ) async {
    if (client == null) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.configuration,
        debugDetail: 'account deletion client is unavailable',
      );
    }
    final repository = _sessionRepository;
    final current = account;
    if (repository == null ||
        current == null ||
        current.authProvider != 'monetta') {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.configuration,
        debugDetail: 'legacy deletion login is unavailable',
      );
    }
    final legacyToken = await _systemSessionRepository?.accessTokenFor(
      current.localAccountId,
    );
    if (legacyToken == null || legacyToken.trim().isEmpty) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'legacy session token is missing',
      );
    }
    final held = await repository.holdLogin();
    _heldDeletionLogin = held;
    final idToken = held.idToken;
    if (idToken == null) {
      await abandonUnmatchedDeletionLogin();
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'reauthentication returned no id token',
      );
    }
    final AccountDeletionOutcome outcome;
    try {
      outcome = await client.matchLegacyEmail(
        shopifyAccessToken: held.accessToken,
        legacySessionToken: legacyToken,
      );
    } catch (error) {
      await abandonUnmatchedDeletionLogin();
      if (error is CustomerAuthException) rethrow;
      throw const CustomerAuthException(
        CustomerAuthErrorKind.server,
        debugDetail: 'email match failed',
      );
    }
    switch (outcome) {
      case AccountDeletionEmailMatch():
        final session = await repository.commitHeldLogin(held);
        _heldDeletionLogin = null;
        account = session.account;
        notifyListeners();
        await _publishAccountScope();
        await loadOrders();
        return LegacyDeletionMatched(
          FreshCustomerLogin(
            accessToken: session.accessToken,
            idToken: idToken,
          ),
          legacySessionToken: legacyToken,
        );
      case AccountDeletionEmailMismatch(:final maskedEmail):
        return LegacyDeletionMismatch(maskedEmail);
      case AccountDeletionOffline():
        await abandonUnmatchedDeletionLogin();
        throw const CustomerAuthException(CustomerAuthErrorKind.offline);
      default:
        await abandonUnmatchedDeletionLogin();
        throw const CustomerAuthException(
          CustomerAuthErrorKind.server,
          debugDetail: 'email match failed',
        );
    }
  }

  /// Ends a Shopify login that did not match the legacy account.
  Future<void> abandonUnmatchedDeletionLogin() async {
    final held = _heldDeletionLogin;
    _heldDeletionLogin = null;
    if (held == null) return;
    await _sessionRepository?.abandonHeldLogin(held);
  }

  /// Opens Shopify's hosted login again and returns the fresh tokens the
  /// deletion endpoint requires. Does not accept a silently refreshed token.
  ///
  /// This adopts the Shopify account immediately. The legacy deletion path
  /// uses [signInForAccountDeletion], which waits for the email match.
  Future<FreshCustomerLogin> reauthenticateForDeletion() async {
    final repository = _sessionRepository;
    if (repository == null) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.configuration,
        debugDetail: 'customer session repository unavailable',
      );
    }
    final login = await repository.reauthenticate();
    final device = await _deviceStore.byId(_deviceId);
    final accountId = device?.accountId;
    final restored =
        accountId == null ? null : await _accountStore.byLocalId(accountId);
    if (restored != null) {
      account = restored;
      notifyListeners();
      await _publishAccountScope();
      await loadOrders();
    }
    return FreshCustomerLogin(
      accessToken: login.accessToken,
      idToken: login.idToken,
    );
  }

  /// Local sign-out after the server has accepted deletion. Guest wishlist
  /// rows stay on the device; this account's profile and saved items do not.
  Future<void> completeAccountDeletion() async {
    final localId = account?.localAccountId;
    try {
      await logout();
    } catch (_) {
      account = null;
      orders = const [];
      ordersStatus = OrderHistoryStatus.unavailable;
      notifyListeners();
    }
    if (localId == null) return;
    await _wishlistStore?.deleteForAccount(localId);
    await _accountStore.deleteLocal(localId);
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
      ordersStatus = OrderHistoryStatus.unavailable;
      _ordersGeneration += 1;
      await _publishAccountScope();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Cache-first: account-bound local rows paint immediately, then a refresh
  /// prefers Customer Account API (Shopify sessions) and optionally merges
  /// mirror apartados. Unavailable / failed / stale-cache are distinct from
  /// a confirmed empty list (F13).
  ///
  /// Each await re-checks that [account] is still the same generation so a
  /// delayed response for A cannot repopulate orders after logout or after B
  /// signed in (F14 / post-checkout refresh safety).
  Future<void> loadOrders() async {
    final current = account;
    if (current == null) return;
    final generation = ++_ordersGeneration;
    final accountId = current.localAccountId;

    ordersLoading = true;
    notifyListeners();

    try {
      final cached = await _orderHistoryRepository.loadCached(accountId);
      if (!_ordersStillCurrent(generation, accountId)) return;
      if (cached.isNotEmpty) {
        orders = cached;
        // Provisional until refresh settles — never call this "empty".
        ordersStatus = OrderHistoryStatus.populated;
        notifyListeners();
      }

      final customerAccountToken = current.authProvider == 'shopify'
          ? await accessTokenForShopifyCheckout()
          : null;
      if (!_ordersStillCurrent(generation, accountId)) return;

      final backendToken = await accessTokenForBackend();
      if (!_ordersStillCurrent(generation, accountId)) return;

      final view = await _orderHistoryRepository.refresh(
        accountId: accountId,
        customerAccountAccessToken: customerAccountToken,
        backendAccessToken: backendToken,
      );
      if (!_ordersStillCurrent(generation, accountId)) return;
      orders = view.orders;
      ordersStatus = view.status;
    } finally {
      if (_ordersStillCurrent(generation, accountId)) {
        ordersLoading = false;
        notifyListeners();
      }
    }
  }

  bool _ordersStillCurrent(int generation, String accountId) =>
      generation == _ordersGeneration && account?.localAccountId == accountId;

  /// Fresh Customer Account access token for authenticated Shopify checkout.
  /// Returns null for guests, legacy Monetta accounts, or refresh failures.
  Future<String?> accessTokenForShopifyCheckout() async {
    final current = account;
    if (current == null || current.authProvider != 'shopify') return null;
    try {
      return await _sessionRepository?.accessTokenFor(current.localAccountId);
    } on Object {
      return null;
    }
  }
}
