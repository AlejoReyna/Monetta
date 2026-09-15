/// First-visit gate for the editorial welcome.
///
/// ## Persistence
///
/// There is exactly one first-run marker on the device today:
/// `app_preferences.onboarding_state` (`pending` | `completed` | `skipped`),
/// owned by [OnboardingController]. This gate reads it and never writes a new
/// one, so no existing preference — appearance, wishlist, bag, account — is
/// touched or reset.
///
/// * `pending`  → first visit → the welcome is shown once.
/// * anything else → returning shopper → straight to the child.
///
/// Tapping *Comenzar* opens the optional onboarding; whichever way it ends
/// (continue or skip) the state leaves `pending`, so the welcome does not come
/// back on the next launch. There is no artificial wait: the gate renders only
/// after `main.dart` has finished loading, on top of an already-built home.
///
/// ## Known gap — one shared contract the orchestrator must decide
///
/// Installs that predate this package also sit at `pending`, because the
/// onboarding panel was never opened automatically (see the note in
/// `features/home/home_screen.dart`). They will therefore see the welcome once.
/// Suppressing it for them needs a dedicated `welcome_seen` flag on
/// `AppPreferences` (`data/local/tables.dart` + a schema-8 migration in
/// `data/local/database.dart` + regenerated `database.g.dart`) — shared
/// persistence this package deliberately does not modify. [WelcomeGate] is
/// written so that flag drops in as a second condition and nothing else moves.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/onboarding_controller.dart';
import '../../app/product_telemetry.dart';
import '../../main.dart';
import '../onboarding/onboarding_sheet.dart';
import 'welcome_screen.dart';

/// Lets descendants — the home, chiefly — know the welcome is covering them,
/// so nothing asks the shopper for a system permission behind it.
class WelcomeScope extends InheritedWidget {
  const WelcomeScope({
    required this.visible,
    required super.child,
    super.key,
  });

  final bool visible;

  static bool isVisible(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WelcomeScope>()?.visible ??
      false;

  @override
  bool updateShouldNotify(WelcomeScope oldWidget) =>
      visible != oldWidget.visible;
}

class WelcomeGate extends StatefulWidget {
  const WelcomeGate({required this.child, super.key});

  final Widget child;

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  /// Resolved once, on the first build that has the controller in scope. Kept
  /// latched so a later `notifyListeners` cannot re-open the welcome over a
  /// shopper who is already browsing.
  bool? _showWelcome;
  bool _presenting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _showWelcome ??= OnboardingScope.maybeOf(context)?.shouldShow ?? false;
  }

  Future<void> _handleStart() async {
    if (_presenting) return;
    _presenting = true;
    try {
      final onboarding = OnboardingScope.maybeOf(context);
      if (onboarding == null || !onboarding.shouldShow) {
        // Nothing left to decide — the correct destination is the home.
        _dismiss();
        return;
      }
      final store = StoreScope.of(context);
      final completed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => StoreScope(
          notifier: store,
          child: const OnboardingSheet(),
        ),
      );
      if (!mounted) return;
      if (completed == true) {
        await onboarding.complete();
        if (!mounted) return;
        logProductEvent(context, ProductEvent.onboardingCompleted);
      } else {
        await onboarding.skip();
        if (!mounted) return;
        logProductEvent(context, ProductEvent.onboardingSkipped);
      }
      _dismiss();
    } finally {
      _presenting = false;
    }
  }

  void _dismiss() {
    if (!mounted || _showWelcome == false) return;
    setState(() => _showWelcome = false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _showWelcome ?? false;
    return WelcomeScope(
      visible: visible,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The home builds underneath so dismissing the welcome reveals a
          // settled screen rather than a cold first frame.
          ExcludeSemantics(
            excluding: visible,
            child: ExcludeFocus(
              excluding: visible,
              child: widget.child,
            ),
          ),
          if (visible)
            WelcomeScreen(
              key: const ValueKey('welcome-screen'),
              onStart: () => unawaited(_handleStart()),
            ),
        ],
      ),
    );
  }
}
