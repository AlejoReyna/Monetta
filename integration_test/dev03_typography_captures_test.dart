// DEV-03 reference captures for RF-17 (typography and bounded text scale).
//
// Walks the real app through home, a collection, a product page, the bag and
// the account screen, and saves a PNG of each one at three text scales:
// default (1.0), large (1.3) and the platform maximum (iOS 3.1, roughly AX5 of
// Dynamic Type; Android 2.0). That is 15 captures per device. They are the
// BEFORE pictures: RF-17 compares its later captures against them.
//
// Run it on a simulator or emulator (never `flutter test`: the host test font
// is not the system font, and how iOS resolves the type families is exactly
// what these pictures are for). Start from a clean install so the bag holds
// only the one piece this test adds: uninstall the app from the device first.
//
//   iOS (iPhone 17e, then iPhone 18 Pro Max):
//     flutter drive --no-pub \
//       --driver=test_driver/integration_test.dart \
//       --target=integration_test/dev03_typography_captures_test.dart \
//       -d "<simulator id>" \
//       --dart-define-from-file=config/dart_defines.ci.json \
//       --dart-define=DEV03_DEVICE=iphone17e
//
//   Android (emulator Medium_Phone_API_37.0). Android defines the staging and
//   production flavors, so name one, as G6 does: without --flavor the tool
//   looks for app-debug.apk and stops with "Gradle build failed to produce an
//   .apk file". The app installs as Monetta Staging.
//     flutter drive --no-pub --flavor staging \
//       --driver=test_driver/integration_test.dart \
//       --target=integration_test/dev03_typography_captures_test.dart \
//       -d "<emulator id>" \
//       --dart-define-from-file=config/dart_defines.ci.json \
//       --dart-define=DEV03_DEVICE=pixel_api37
//
// List the ids with `flutter devices`. Captures land in
// build/dev03_captures/, named
// [<DEV03_DEVICE>_]<platform>_<scale>_<screen>.png, for example
// iphone17e_ios_1.0_home.png or pixel_api37_android_2.0_bag.png.
//
// The test asserts no design: it only checks that each screen was reached and
// fails with the name of the step that did not find its widget.
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:monetta_app/features/account/account_screen.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/checkout/checkout_screen.dart';
import 'package:monetta_app/features/checkout/mini_cart.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/product/product_screen.dart';
import 'package:monetta_app/main.dart' as app;

/// Optional device label baked into every file name.
const String _device = String.fromEnvironment('DEV03_DEVICE');

/// Bounded wait for something to appear, in 250 ms frames.
const Duration _frame = Duration(milliseconds: 250);
const int _maxWaitFrames = 80; // 20 s

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'DEV-03 reference captures: home, collection, product, bag and account '
    'at default, large and maximum text scale',
    (tester) async {
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      final platform = isIos ? 'ios' : 'android';
      final scales = <double>[1.0, 1.3, isIos ? 3.1 : 2.0];
      var bagSeeded = false;
      var surfaceConverted = false;

      Future<void> capture(double scale, String screen) async {
        // Let layout, images and any entrance animation settle a moment.
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pump(const Duration(milliseconds: 400));
        if (!surfaceConverted && !kIsWeb && Platform.isAndroid) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pump(const Duration(milliseconds: 400));
          surfaceConverted = true;
        }
        final parts = <String>[
          if (_device.isNotEmpty) _device,
          platform,
          scale.toStringAsFixed(1),
          screen,
        ];
        await binding.takeScreenshot(parts.join('_'));
      }

      try {
        await app.main();
        await _waitFor(tester, find.byType(HomeScreen), 'app start (home)');
        await _dismissWelcome(tester);

        for (final scale in scales) {
          binding.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pump(const Duration(milliseconds: 600));

          // Home: back to the root route and to the top of its scroll.
          await _backToHome(tester);
          await capture(scale, 'home');

          // Collection: the first editorial collection card on home. Its key
          // is home-collection-card-<handle>, so no handle is hard-coded.
          await _scrollTo(
            tester,
            _keyStartingWith('home-collection-card-'),
            'a collection card on home (home-collection-card-*)',
          );
          await _tapFirst(
            tester,
            _keyStartingWith('home-collection-card-'),
            'collection card',
          );
          await _waitFor(
            tester,
            find.byType(CollectionScreen),
            'collection screen after tapping the collection card',
          );
          await capture(scale, 'collection');

          // Product: the first in-stock card of that collection. Only
          // in-stock cards carry quick-add-<id>, so a sold-out piece is never
          // picked; the tap goes to the card that contains that button.
          final quickAdd = _keyStartingWith('quick-add-');
          await _scrollTo(
            tester,
            quickAdd,
            'an in-stock product card in the collection (quick-add-*)',
          );
          final card = find.ancestor(
            of: quickAdd.hitTestable().first,
            matching: _keyStartingWith('product-card-'),
          );
          await _tapFirst(tester, card, 'in-stock product card');
          await _waitFor(
            tester,
            find.byType(ProductScreen),
            'product screen after tapping the product card',
          );
          await _waitFor(
            tester,
            find.byKey(const Key('purchase-dock-primary')),
            'purchase dock on the product screen',
          );
          await capture(scale, 'product');

          // Bag: the first pass adds that piece (the dock button) so the bag
          // is never empty; later passes find it already there, which keeps
          // the three bag captures comparable.
          if (!bagSeeded) {
            await _tapFirst(
              tester,
              find.byKey(const Key('purchase-dock-primary')),
              'purchase dock button (Agregar al carrito)',
            );
            await _waitFor(
              tester,
              find.byType(MiniCartSheet),
              'mini cart after adding to the bag (variant 0 must be '
              'available)',
            );
            Navigator.of(tester.element(find.byType(MiniCartSheet))).pop();
            await tester.pump(const Duration(milliseconds: 600));
            bagSeeded = true;
          }
          await _backToHome(tester);
          await _tapFirst(
            tester,
            find.byKey(const Key('bottom-nav-bag')),
            'bottom navigation: bag',
          );
          await _waitFor(
            tester,
            find.byType(BagScreen),
            'bag screen after tapping bottom-nav-bag',
          );
          await _waitFor(
            tester,
            find.byKey(const ValueKey('bag-heading-row')),
            'bag heading row (bag-heading-row)',
          );
          await capture(scale, 'bag');

          // Account.
          await _backToHome(tester);
          await _tapFirst(
            tester,
            find.byKey(const Key('bottom-nav-account')),
            'bottom navigation: account',
          );
          await _waitFor(
            tester,
            find.byType(AccountScreen),
            'account screen after tapping bottom-nav-account',
          );
          await capture(scale, 'account');

          await _backToHome(tester);
        }
      } finally {
        binding.platformDispatcher.clearTextScaleFactorTestValue();
      }
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

/// Matches any widget whose [ValueKey] string starts with [prefix].
Finder _keyStartingWith(String prefix) => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    });

/// Pumps frames until [finder] matches, up to a fixed bound. Never uses
/// `pumpAndSettle`: the app has animations that never settle.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder,
  String step,
) async {
  for (var i = 0; i < _maxWaitFrames; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(_frame);
  }
  fail('DEV-03 step failed: waited 20 s for $step and did not find it.');
}

/// Taps the first match of [finder] that can actually receive the tap.
Future<void> _tapFirst(
  WidgetTester tester,
  Finder finder,
  String step,
) async {
  final tappable = finder.hitTestable();
  await _waitFor(tester, tappable, step);
  await tester.tap(tappable.first);
  await tester.pump(const Duration(milliseconds: 600));
}

/// Drags the page up in steps until [finder] has a match on screen. A vertical
/// drag from the middle of the screen scrolls the page even when it starts on
/// a horizontal rail.
Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder,
  String step,
) async {
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  final from = Offset(size.width / 2, size.height / 2);
  for (var i = 0; i < 60; i++) {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    await tester.dragFrom(from, const Offset(0, -320));
    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('DEV-03 step failed: scrolled 60 steps looking for $step.');
}

/// Pops to the root route (home) and scrolls it to the top, so every capture
/// starts from the same state.
Future<void> _backToHome(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.popUntil((route) => route.isFirst);
  await tester.pump(const Duration(milliseconds: 600));
  await _waitFor(tester, find.byType(HomeScreen), 'home screen');
  final homeTab = find.byKey(const Key('bottom-nav-home'));
  if (homeTab.hitTestable().evaluate().isNotEmpty) {
    // On home this scrolls the page back to the top.
    await tester.tap(homeTab.hitTestable().first);
    await tester.pump(const Duration(milliseconds: 600));
  }
}

/// A fresh install opens on the first-visit welcome; skip it the way
/// app_smoke_test does. A device that already made the choice skips this.
Future<void> _dismissWelcome(WidgetTester tester) async {
  // Give the welcome time to show up before deciding it is absent.
  for (var i = 0; i < 12; i++) {
    if (find
        .byKey(const ValueKey('welcome-start-button'))
        .evaluate()
        .isNotEmpty) {
      break;
    }
    await tester.pump(_frame);
  }
  final startButton = find.byKey(const ValueKey('welcome-start-button'));
  if (startButton.evaluate().isEmpty) return;
  await tester.tap(startButton);
  await tester.pump(const Duration(milliseconds: 600));
  await _tapFirst(
    tester,
    find.byKey(const ValueKey('onboarding-skip')),
    'onboarding skip button (onboarding-skip)',
  );
  await tester.pump(const Duration(seconds: 1));
}
