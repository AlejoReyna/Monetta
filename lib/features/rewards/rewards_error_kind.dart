/// Single classifier that maps any Rewards failure to a UI state.
///
/// Shared by the account section and the balance card so the sets of error
/// codes live in one place.
library;

import 'rewards_account.dart';
import 'rewards_models.dart';

/// The four distinct states a Rewards failure can map to.
enum RewardsErrorKind {
  /// The program is off or the route does not exist on this server.
  unavailable,

  /// The session ended; the user must sign in again.
  session,

  /// The request never reached the server (offline, DNS, timeout).
  network,

  /// The server answered, but it is failing or not responding properly.
  serviceDown,
}

const Set<String> _unavailableCodes = {
  'feature_disabled',
  'not_found',
  'unavailable',
};

const Set<String> _sessionCodes = {
  'unauthenticated',
  'unauthorized',
  'session_expired',
};

/// Classifies [error], which may be a [RewardsApiError], a
/// [RewardsException] or any other object (treated as a transport failure).
RewardsErrorKind classifyRewardsError(Object? error) {
  final String code;
  if (error is RewardsApiError) {
    code = error.code;
  } else if (error is RewardsException) {
    code = error.code;
  } else {
    return RewardsErrorKind.network;
  }
  if (_unavailableCodes.contains(code)) return RewardsErrorKind.unavailable;
  if (_sessionCodes.contains(code)) return RewardsErrorKind.session;
  if (code == 'network') return RewardsErrorKind.network;
  return RewardsErrorKind.serviceDown;
}
