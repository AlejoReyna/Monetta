/// App-level account state. Plain `ChangeNotifier`, same deliberate choice
/// as `CatalogStore` (see its doc comment) — this is a single object, and
/// Riverpod wiring is still a Phase-2-or-later concern, not something to
/// introduce for one more controller.
///
/// Login is additive, never a wall: `account == null` is a perfectly normal,
/// fully-functional state — see `lib/data/customer_auth/README.md` § 5.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show Value;

import '../data/customer_auth/customer_identity.dart';

import '../data/accounts_orders/system_account_session_repository.dart';
import '../data/customer_auth/customer_account_config.dart';
import '../data/customer_auth/customer_auth_error.dart';
import '../data/customer_auth/customer_profile.dart';
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

/// How a [AccountController.saveProfile] call ended.
enum ProfileSaveStatus {
  saved,
  tooLarge,
  sessionExpired,
  failed,

  /// The account changed (logout or switch) while the request was in flight;
  /// nothing was applied.
  discarded,
}

const String kProfilePhotoTooLargeMessage =
    'La foto es demasiado grande. Elige otra.';
const String kProfileOfflineMessage =
    'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
const String kProfileSessionExpiredMessage =
    'Tu sesión terminó. Inicia sesión de nuevo.';
const String kProfileSaveFailedMessage =
    'No pudimos guardar tu perfil. Inténtalo de nuevo.';

/// A typed result the editor can render without inspecting an exception.
class ProfileSaveOutcome {
  const ProfileSaveOutcome(this.status, {this.message});

  final ProfileSaveStatus status;

  /// Spanish, ready to show; null when [status] is saved or discarded.
  final String? message;

  bool get isSaved => status == ProfileSaveStatus.saved;
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
    CustomerProfileService? profileService,
  })  : _sessionRepository = sessionRepository,
        _systemSessionRepository = systemSessionRepository,
        _accountStore = accountStore,
        _deviceStore = deviceStore,
        _orderHistoryRepository = orderHistoryRepository,
        _config = config,
        _deviceId = deviceId,
        _wishlistStore = wishlistStore,
        _onAccountScopeChanged = onAccountScopeChanged,
        _profileService = profileService;

  final CustomerSessionRepository? _sessionRepository;
  final SystemAccountSessionRepository? _systemSessionRepository;
  final AccountStore _accountStore;
  final DeviceStore _deviceStore;
  final OrderHistoryRepository _orderHistoryRepository;
  final CustomerAccountConfig? _config;
  final String _deviceId;
  final WishlistStore? _wishlistStore;
  final Future<void> Function(String? accountId)? _onAccountScopeChanged;
  final CustomerProfileService? _profileService;
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

  /// Shopify-stored name and photo of the signed-in account. Memory only —
  /// never persisted (the photo especially: no schema change). Null until
  /// [loadProfile] succeeds; cleared whenever the account changes.
  CustomerProfile? profile;
  bool profileLoading = false;
  bool profileSaving = false;

  /// Bumped whenever the signed-in account changes, so an answer that was
  /// requested for account A is never applied once B (or nobody) is signed
  /// in. Same idea as [_ordersGeneration], kept separate because orders
  /// reload on their own schedule.
  int _profileGeneration = 0;
  String? _profileOwnerId;

  /// The profile request currently in flight and the generation it was made
  /// for, so a second caller (the identity card, say) joins it instead of
  /// asking Shopify again.
  Future<void>? _profileLoad;
  int _profileLoadGeneration = -1;
  String? _photoBytesSource;
  Uint8List? _photoBytes;

  bool get isSignedIn => account != null;

  /// Fetches a missing name for a restored account, without blocking its UI.
  Future<void> refreshProfile() async {
    final current = account;
    final repository = _sessionRepository;
    if (current == null ||
        repository == null ||
        current.authProvider != 'shopify' ||
        customerProfileName(current.displayName) != null) {
      return;
    }
    try {
      final updated = await repository.refreshProfile(current.localAccountId);
      if (updated != null &&
          account?.localAccountId == current.localAccountId) {
        account = updated;
        notifyListeners();
      }
    } catch (_) {
      // A missing name or offline lookup must not interrupt the session.
    }
  }

  /// A personal display name, scoped to the account on this device.
  Future<void> saveProfileName(String value) async {
    final current = account;
    final name = customerProfileName(value);
    if (current == null || name == null) return;
    await _accountStore.updateDisplayName(current.localAccountId, name);
    if (account?.localAccountId != current.localAccountId) return;
    account = current.copyWith(displayName: Value(name));
    notifyListeners();
  }

  /// Only Shopify accounts can edit: the name and photo are Shopify's.
  /// Legacy Monetta accounts keep the plain avatar.
  bool get canEditProfile =>
      _profileService != null &&
      _sessionRepository != null &&
      account?.authProvider == 'shopify';

  /// The decoded profile photo, cached so the avatar does not re-decode (and
  /// re-upload to the image cache) on every rebuild.
  Uint8List? get profilePhotoBytes {
    final source = profile?.photoDataUrl;
    if (source == null) return null;
    if (source != _photoBytesSource) {
      _photoBytesSource = source;
      _photoBytes = decodeProfilePhotoDataUrl(source);
    }
    return _photoBytes;
  }

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
    _syncProfileScope();
    notifyListeners();
    _prefetchProfile();
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
    _syncProfileScope();
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
      _syncProfileScope();
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
      _prefetchProfile();
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
      _syncProfileScope();
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
      _syncProfileScope();
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
        _syncProfileScope();
        notifyListeners();
        _prefetchProfile();
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

  /// Opens Shopify's hosted login again without adopting another customer.
  /// Legacy accounts use [signInForAccountDeletion] for the server email check.
  Future<FreshCustomerLogin> reauthenticateForDeletion() async {
    final repository = _sessionRepository;
    // Account is immutable: retain both the customer ID and email before
    // opening the browser, even if the controller changes during login.
    final target = account;
    if (repository == null ||
        target == null ||
        target.authProvider != 'shopify' ||
        target.shopifyCustomerId == null ||
        target.shopifyCustomerId!.isEmpty) {
      throw const CustomerAuthException(
        CustomerAuthErrorKind.configuration,
        debugDetail: 'Shopify account for deletion is unavailable',
      );
    }
    final login = await repository.reauthenticate();
    // The stable customer ID decides identity; an email change on the same
    // Shopify customer must not turn it into another account.
    if (login.identity.shopifyCustomerId != target.shopifyCustomerId) {
      await repository.abandonHeldLogin(login);
      throw const AccountDeletionIdentityMismatch();
    }
    final session = await repository.commitHeldLogin(login);
    account = session.account;
    _syncProfileScope();
    notifyListeners();
    await _publishAccountScope();
    await loadOrders();
    return FreshCustomerLogin(
      accessToken: login.accessToken,
      idToken: login.idToken!,
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
      _syncProfileScope();
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
      _syncProfileScope();
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

  /// Customer Account orders and the accounts_orders mirror, without
  /// replacing the shopper cache. Empty when signed out or the session
  /// changed mid-read. Neither source currently carries a checkout token.
  Future<OrderCorrelationSnapshot> loadCheckoutCorrelation() async {
    final current = account;
    if (current == null) return const OrderCorrelationSnapshot.empty();
    final generation = _ordersGeneration;
    final accountId = current.localAccountId;

    final customerAccountToken = current.authProvider == 'shopify'
        ? await accessTokenForShopifyCheckout()
        : null;
    if (!_ordersStillCurrent(generation, accountId)) {
      return const OrderCorrelationSnapshot.empty();
    }

    final backendToken = await accessTokenForBackend();
    if (!_ordersStillCurrent(generation, accountId)) {
      return const OrderCorrelationSnapshot.empty();
    }

    final snapshot = await _orderHistoryRepository.loadForCheckoutCorrelation(
      customerAccountAccessToken: customerAccountToken,
      backendAccessToken: backendToken,
    );
    if (!_ordersStillCurrent(generation, accountId)) {
      return const OrderCorrelationSnapshot.empty();
    }
    return snapshot;
  }

  bool _ordersStillCurrent(int generation, String accountId) =>
      generation == _ordersGeneration && account?.localAccountId == accountId;

  bool _profileStillCurrent(int generation, String accountId) =>
      generation == _profileGeneration && account?.localAccountId == accountId;

  /// Call after every assignment to [account]. When the signed-in account
  /// actually changed (login, logout, switch) the profile is dropped and the
  /// generation advances, which orphans any load or save still in flight. A
  /// re-login of the same account keeps what it already has.
  void _syncProfileScope() {
    final currentId = account?.localAccountId;
    if (currentId == _profileOwnerId) return;
    _profileOwnerId = currentId;
    _profileGeneration += 1;
    profile = null;
    profileLoading = false;
    profileSaving = false;
    _photoBytesSource = null;
    _photoBytes = null;
  }

  /// Starts [loadProfile] without waiting for it, so the bottom bar can show
  /// the photo on every screen rather than only after the account screen has
  /// been opened. Silent on failure, like [loadProfile] itself.
  void _prefetchProfile() => unawaited(loadProfile());

  /// Fetches the Shopify name and photo for the signed-in Shopify account.
  /// Failure is silent: the identity card simply keeps its initial, and the
  /// editor falls back to the stored display name.
  ///
  /// Joins a request already in flight for the same account and does nothing
  /// once the profile is loaded; a failed load can be retried by calling it
  /// again.
  Future<void> loadProfile() {
    final current = account;
    if (!canEditProfile || current == null || profile != null) {
      return Future<void>.value();
    }
    final inFlight = _profileLoad;
    if (inFlight != null && _profileLoadGeneration == _profileGeneration) {
      return inFlight;
    }
    final generation = _profileGeneration;
    final request = _fetchProfile(generation, current.localAccountId);
    _profileLoad = request;
    _profileLoadGeneration = generation;
    unawaited(
      request.whenComplete(() {
        if (identical(_profileLoad, request)) _profileLoad = null;
      }),
    );
    return request;
  }

  Future<void> _fetchProfile(int generation, String accountId) async {
    final service = _profileService!;
    profileLoading = true;
    notifyListeners();
    try {
      final token = await accessTokenForShopifyCheckout();
      if (!_profileStillCurrent(generation, accountId) || token == null) {
        return;
      }
      final fetched = await service.fetch(token);
      if (!_profileStillCurrent(generation, accountId)) return;
      profile = fetched;
    } on Object {
      // Deliberately swallowed: nothing here is worth interrupting the shopper
      // for, and the exception text is not something to keep around.
    } finally {
      if (_profileStillCurrent(generation, accountId)) {
        profileLoading = false;
        notifyListeners();
      }
    }
  }

  /// Saves only what is passed: [firstName], a new [photoJpeg], or
  /// [removePhoto]. The name goes first; if the photo then fails, the name
  /// stays saved and applied, so a retry sends just the photo.
  Future<ProfileSaveOutcome> saveProfile({
    String? firstName,
    Uint8List? photoJpeg,
    bool removePhoto = false,
  }) async {
    assert(
      !(removePhoto && photoJpeg != null),
      'Pass either a new photo or removePhoto, not both.',
    );
    final current = account;
    final service = _profileService;
    final name = firstName?.trim();
    if (!canEditProfile ||
        current == null ||
        service == null ||
        (name != null && name.isEmpty)) {
      return const ProfileSaveOutcome(
        ProfileSaveStatus.failed,
        message: kProfileSaveFailedMessage,
      );
    }
    if (profileSaving) {
      return const ProfileSaveOutcome(ProfileSaveStatus.discarded);
    }
    final generation = _profileGeneration;
    final accountId = current.localAccountId;

    profileSaving = true;
    notifyListeners();
    try {
      final token = await accessTokenForShopifyCheckout();
      if (!_profileStillCurrent(generation, accountId)) {
        return const ProfileSaveOutcome(ProfileSaveStatus.discarded);
      }
      final customerId =
          profile?.shopifyCustomerId ?? current.shopifyCustomerId;
      if (token == null || customerId == null || customerId.isEmpty) {
        return const ProfileSaveOutcome(
          ProfileSaveStatus.failed,
          message: kProfileSaveFailedMessage,
        );
      }

      if (name != null) {
        final reported = await service.updateFirstName(token, name);
        if (!_profileStillCurrent(generation, accountId)) {
          return const ProfileSaveOutcome(ProfileSaveStatus.discarded);
        }
        final displayName = reported ?? name;
        profile = _profileOrBase(customerId, current)
            .copyWith(firstName: name, displayName: displayName);
        await _storeDisplayName(current, displayName);
        if (!_profileStillCurrent(generation, accountId)) {
          return const ProfileSaveOutcome(ProfileSaveStatus.discarded);
        }
        notifyListeners();
      }

      if (photoJpeg != null) {
        final dataUrl = profilePhotoDataUrl(photoJpeg);
        await service.setPhoto(token, customerId, dataUrl);
        if (!_profileStillCurrent(generation, accountId)) {
          return const ProfileSaveOutcome(ProfileSaveStatus.discarded);
        }
        profile =
            _profileOrBase(customerId, current).copyWith(photoDataUrl: dataUrl);
      } else if (removePhoto) {
        await service.removePhoto(token, customerId);
        if (!_profileStillCurrent(generation, accountId)) {
          return const ProfileSaveOutcome(ProfileSaveStatus.discarded);
        }
        profile = _profileOrBase(customerId, current).copyWith(
          clearPhoto: true,
        );
      }
      return const ProfileSaveOutcome(ProfileSaveStatus.saved);
    } on ProfilePhotoTooLargeException {
      return _stillCurrentOr(
        generation,
        accountId,
        const ProfileSaveOutcome(
          ProfileSaveStatus.tooLarge,
          message: kProfilePhotoTooLargeMessage,
        ),
      );
    } on CustomerAuthException catch (error) {
      final outcome = switch (error.kind) {
        CustomerAuthErrorKind.sessionExpired => const ProfileSaveOutcome(
            ProfileSaveStatus.sessionExpired,
            message: kProfileSessionExpiredMessage,
          ),
        CustomerAuthErrorKind.offline => const ProfileSaveOutcome(
            ProfileSaveStatus.failed,
            message: kProfileOfflineMessage,
          ),
        _ => const ProfileSaveOutcome(
            ProfileSaveStatus.failed,
            message: kProfileSaveFailedMessage,
          ),
      };
      return _stillCurrentOr(generation, accountId, outcome);
    } on Object {
      return _stillCurrentOr(
        generation,
        accountId,
        const ProfileSaveOutcome(
          ProfileSaveStatus.failed,
          message: kProfileSaveFailedMessage,
        ),
      );
    } finally {
      if (_profileStillCurrent(generation, accountId)) {
        profileSaving = false;
        notifyListeners();
      }
    }
  }

  ProfileSaveOutcome _stillCurrentOr(
    int generation,
    String accountId,
    ProfileSaveOutcome outcome,
  ) =>
      _profileStillCurrent(generation, accountId)
          ? outcome
          : const ProfileSaveOutcome(ProfileSaveStatus.discarded);

  CustomerProfile _profileOrBase(String customerId, local.Account current) =>
      profile ??
      CustomerProfile(
        shopifyCustomerId: customerId,
        displayName: current.displayName,
      );

  /// Mirrors the new name into the existing `Accounts.displayName` column so
  /// the identity card shows it; every other column is written back as it was.
  Future<void> _storeDisplayName(
    local.Account current,
    String displayName,
  ) async {
    await _accountStore.upsert(
      localAccountId: current.localAccountId,
      shopifyCustomerId: current.shopifyCustomerId,
      email: current.email,
      displayName: displayName,
      authProvider: current.authProvider,
      createdAt: current.createdAt,
    );
    final updated = await _accountStore.byLocalId(current.localAccountId);
    if (updated != null && account?.localAccountId == current.localAccountId) {
      account = updated;
    }
  }

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
