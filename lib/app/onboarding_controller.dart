/// Owns the persisted first-run onboarding decision.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/local/onboarding_preference_store.dart';

enum OnboardingState { pending, completed, skipped }

class OnboardingController extends ChangeNotifier {
  OnboardingController({required OnboardingPreferenceStore store})
      : _store = store;

  final OnboardingPreferenceStore _store;
  OnboardingState _state = OnboardingState.pending;

  OnboardingState get state => _state;
  bool get shouldShow => _state == OnboardingState.pending;

  Future<void> restore() async {
    try {
      _state = _decode(await _store.readState());
    } on Object catch (error) {
      debugPrint('Onboarding preference could not be restored: $error');
      _state = OnboardingState.pending;
    }
    notifyListeners();
  }

  Future<void> complete() => _set(OnboardingState.completed);
  Future<void> skip() => _set(OnboardingState.skipped);

  Future<void> _set(OnboardingState next) async {
    if (_state == next) return;
    _state = next;
    notifyListeners();
    try {
      await _store.writeState(next.name);
    } on Object catch (error) {
      // The decision still applies for this session when disk is unavailable.
      debugPrint('Onboarding preference could not be saved: $error');
    }
  }

  static OnboardingState _decode(String value) => switch (value) {
        'completed' => OnboardingState.completed,
        'skipped' => OnboardingState.skipped,
        _ => OnboardingState.pending,
      };
}

class OnboardingScope extends InheritedNotifier<OnboardingController> {
  const OnboardingScope({
    required OnboardingController super.notifier,
    required super.child,
    super.key,
  });

  static OnboardingController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OnboardingScope>()
      ?.notifier;
}
