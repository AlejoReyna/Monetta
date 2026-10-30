import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_gateway.dart';
import 'package:monetta_app/data/customer_auth/customer_profile.dart';
import 'package:monetta_app/data/customer_auth/customer_session_repository.dart';
import 'package:monetta_app/data/customer_auth/secure_token_store.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/bag_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/local/wishlist_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/navigation/monetta_bottom_navigation.dart';
import 'package:monetta_app/main.dart' show AccountScope;

// The bar's «Cuenta» destination shows the signed-in shopper's profile photo
// in place of the person glyph (on the flat bar, the iOS capsule and the rail).

/// A valid 1x1 PNG, so `Image.memory` has something real to decode.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _SecureStore implements SecureTokenStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _Gateway implements CustomerAuthGateway {
  CustomerAuthResult _result() {
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'gid://shopify/Customer/1',
              'email': 'ana@example.com',
            }),
          ),
        )
        .replaceAll('=', '');
    return CustomerAuthResult(
      accessToken: 'access',
      refreshToken: 'refresh',
      idToken: 'header.$payload.signature',
      accessTokenExpiresAt: DateTime.utc(2027),
    );
  }

  @override
  Future<CustomerAuthResult> login() async => _result();

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) async => _result();

  @override
  Future<void> endSession({required String idTokenHint}) async {}
}

class _ProfileService implements CustomerProfileService {
  _ProfileService({this.photoDataUrl});

  String? photoDataUrl;
  int fetches = 0;

  @override
  Future<CustomerProfile> fetch(String accessToken) async {
    fetches += 1;
    return CustomerProfile(
      shopifyCustomerId: 'gid://shopify/Customer/1',
      firstName: 'Ana',
      photoDataUrl: photoDataUrl,
    );
  }

  @override
  Future<String?> updateFirstName(String accessToken, String firstName) async =>
      firstName;

  @override
  Future<void> setPhoto(
    String accessToken,
    String customerId,
    String dataUrl,
  ) async {}

  @override
  Future<void> removePhoto(String accessToken, String customerId) async {}
}

Future<AccountController> _controller(
  WidgetTester tester,
  AppDatabase db, {
  required _ProfileService service,
  bool signIn = true,
}) async {
  final deviceStore = DeviceStore(db);
  await deviceStore.upsert(
    deviceId: 'dev-1',
    platform: 'ios',
    appVersion: '1',
  );
  final controller = AccountController(
    sessionRepository: CustomerSessionRepository(
      authGateway: _Gateway(),
      accountStore: AccountStore(db),
      sessionStore: SessionStore(db),
      deviceStore: deviceStore,
      wishlistStore: WishlistStore(db),
      bagStore: BagStore(db),
      secureStore: _SecureStore(),
      deviceId: 'dev-1',
    ),
    accountStore: AccountStore(db),
    deviceStore: deviceStore,
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    config: const CustomerAccountConfig(
      shopDomain: 'shop.example.com',
      shopId: '1',
      clientId: 'client-id',
      redirectUri: 'shop.1.oauth://callback',
    ),
    deviceId: 'dev-1',
    profileService: service,
  );
  if (signIn) {
    await controller.login();
    // Lets the background profile load land (microtasks only: no timers).
    await tester.pump();
  }
  return controller;
}

enum _Layout { flat, ios, rail }

final _photo = find.byKey(const Key('bottom-nav-account-photo'));
final _accountItem = find.byKey(const Key('bottom-nav-account'));

/// The bar's painted outline glyph inside the «Cuenta» item. The painter's
/// class is private, so it is recognised by name.
final _personGlyph = find.descendant(
  of: _accountItem,
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint &&
        widget.painter.runtimeType.toString() == '_NavGlyphPainter',
  ),
);

Widget _app(
  _Layout layout, {
  AccountController? controller,
  MonettaBottomDestination current = MonettaBottomDestination.account,
}) {
  var bar = MonettaBottomNavigation(
    current: current,
    bagCount: 0,
    onSelected: (_) {},
  );
  if (layout == _Layout.rail) bar = bar.asRail();
  final Widget home = layout == _Layout.rail
      ? Scaffold(
          body: Row(children: [bar, const Expanded(child: SizedBox.expand())]),
        )
      : Scaffold(body: const SizedBox.expand(), bottomNavigationBar: bar);
  Widget app = MaterialApp(
    theme: buildLightTheme().copyWith(
      platform: layout == _Layout.ios ? TargetPlatform.iOS : null,
    ),
    home: home,
  );
  if (controller != null) {
    app = AccountScope(notifier: controller, child: app);
  }
  return app;
}

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
}

Color _ringColor(WidgetTester tester) {
  final box = tester.widget<Container>(_photo);
  final decoration = box.foregroundDecoration! as BoxDecoration;
  return (decoration.border! as Border).top.color;
}

void main() {
  for (final layout in _Layout.values) {
    group('${layout.name} bar', () {
      testWidgets('shows the photo of a signed-in shopper as a 24 px circle', (
        tester,
      ) async {
        _phone(tester);
        final db = openTestDatabase();
        addTearDown(db.close);
        final controller = await _controller(
          tester,
          db,
          service: _ProfileService(photoDataUrl: profilePhotoDataUrl(_tinyPng)),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(layout, controller: controller));
        await tester.pumpAndSettle();

        expect(_photo, findsOneWidget);
        expect(tester.getSize(_photo), const Size.square(24));
        expect(
          find.descendant(of: _photo, matching: find.byType(ClipOval)),
          findsOneWidget,
        );
        final image = tester.widget<Image>(
          find.descendant(of: _photo, matching: find.byType(Image)),
        );
        expect(image.fit, BoxFit.cover);
        expect(image.gaplessPlayback, isTrue);
        // The controller's cached bytes, not a fresh decode.
        expect(
          identical(
            (image.image as MemoryImage).bytes,
            controller.profilePhotoBytes,
          ),
          isTrue,
        );
        // The photo replaces the glyph, in the same box, at the same place.
        expect(
          _personGlyph,
          findsNothing,
        );
        // The other three destinations keep their glyphs.
        expect(find.byKey(const Key('bottom-nav-home')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps the person glyph when signed out', (tester) async {
        _phone(tester);
        final db = openTestDatabase();
        addTearDown(db.close);
        final controller = await _controller(
          tester,
          db,
          service: _ProfileService(photoDataUrl: profilePhotoDataUrl(_tinyPng)),
          signIn: false,
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(layout, controller: controller));
        await tester.pumpAndSettle();

        expect(controller.isSignedIn, isFalse);
        expect(_photo, findsNothing);
        expect(
          _personGlyph,
          findsOneWidget,
        );
      });

      testWidgets('keeps the person glyph when the account has no photo', (
        tester,
      ) async {
        _phone(tester);
        final db = openTestDatabase();
        addTearDown(db.close);
        final controller =
            await _controller(tester, db, service: _ProfileService());
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(layout, controller: controller));
        await tester.pumpAndSettle();

        expect(controller.isSignedIn, isTrue);
        expect(controller.profile, isNotNull);
        expect(_photo, findsNothing);
        expect(
          _personGlyph,
          findsOneWidget,
        );
      });

      testWidgets('keeps the person glyph without an account scope', (
        tester,
      ) async {
        _phone(tester);

        await tester.pumpWidget(_app(layout));
        await tester.pumpAndSettle();

        expect(_photo, findsNothing);
        expect(
          _personGlyph,
          findsOneWidget,
        );
      });

      testWidgets('the photo appears when the profile lands and goes on logout',
          (tester) async {
        _phone(tester);
        final db = openTestDatabase();
        addTearDown(db.close);
        final controller = await _controller(
          tester,
          db,
          service: _ProfileService(photoDataUrl: profilePhotoDataUrl(_tinyPng)),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(layout, controller: controller));
        await tester.pumpAndSettle();
        expect(_photo, findsOneWidget);

        await controller.logout();
        await tester.pumpAndSettle();

        expect(_photo, findsNothing);
        expect(
          _personGlyph,
          findsOneWidget,
        );
      });
    });
  }

  for (final layout in [_Layout.flat, _Layout.ios]) {
    group('${layout.name} bar semantics and ring', () {
      testWidgets('the item is still «Cuenta» and the photo is decorative', (
        tester,
      ) async {
        _phone(tester);
        final handle = tester.ensureSemantics();
        final db = openTestDatabase();
        addTearDown(db.close);
        final controller = await _controller(
          tester,
          db,
          service: _ProfileService(photoDataUrl: profilePhotoDataUrl(_tinyPng)),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(layout, controller: controller));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Cuenta'), findsOneWidget);
        final node = tester.getSemantics(find.bySemanticsLabel('Cuenta'));
        expect(node.label, 'Cuenta');
        expect(
          find.bySemanticsLabel(RegExp('foto|imagen|photo')),
          findsNothing,
        );
        handle.dispose();
      });

      testWidgets('the ring follows the selected and unselected colour', (
        tester,
      ) async {
        _phone(tester);
        final db = openTestDatabase();
        addTearDown(db.close);
        final controller = await _controller(
          tester,
          db,
          service: _ProfileService(photoDataUrl: profilePhotoDataUrl(_tinyPng)),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(layout, controller: controller));
        await tester.pumpAndSettle();
        final colors = tester.element(_photo).monettaColors;
        expect(_ringColor(tester), colors.navigationForeground);
        final border = (tester.widget<Container>(_photo).foregroundDecoration!
                as BoxDecoration)
            .border! as Border;
        expect(border.top.width, lessThanOrEqualTo(2));

        await tester.pumpWidget(
          _app(
            layout,
            controller: controller,
            current: MonettaBottomDestination.home,
          ),
        );
        await tester.pumpAndSettle();
        expect(_ringColor(tester), colors.navigationForegroundMuted);
      });
    });
  }

  testWidgets('the bar does not ask Shopify again when it rebuilds', (
    tester,
  ) async {
    _phone(tester);
    final db = openTestDatabase();
    addTearDown(db.close);
    final service = _ProfileService(
      photoDataUrl: profilePhotoDataUrl(_tinyPng),
    );
    final controller = await _controller(tester, db, service: service);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(_Layout.flat, controller: controller));
    await tester.pumpAndSettle();
    final first = tester.widget<Image>(
      find.descendant(of: _photo, matching: find.byType(Image)),
    );
    controller.notifyListeners();
    await tester.pump();
    final second = tester.widget<Image>(
      find.descendant(of: _photo, matching: find.byType(Image)),
    );

    expect(service.fetches, 1);
    expect(
      identical(
        (first.image as MemoryImage).bytes,
        (second.image as MemoryImage).bytes,
      ),
      isTrue,
    );
  });

  testWidgets('the overflow popup is unchanged: text rows only', (
    tester,
  ) async {
    // A cramped view pushes the destinations into the overflow menu.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 300);
    addTearDown(tester.view.reset);
    final db = openTestDatabase();
    addTearDown(db.close);
    final controller = await _controller(
      tester,
      db,
      service: _ProfileService(photoDataUrl: profilePhotoDataUrl(_tinyPng)),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(_Layout.flat, controller: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('navigation-overflow')), findsOneWidget);
    expect(_photo, findsNothing);

    await tester.tap(find.byKey(const Key('navigation-overflow')));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta'), findsOneWidget);
    expect(_photo, findsNothing);
  });
}
