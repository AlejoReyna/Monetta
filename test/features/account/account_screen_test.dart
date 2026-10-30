import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/customer_auth/customer_account_config.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
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
import 'package:monetta_app/features/account/account_screen.dart';

class _SecureStore implements SecureTokenStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _PendingShopGateway implements CustomerAuthGateway {
  final loginCompleter = Completer<CustomerAuthResult>();
  int loginCalls = 0;

  @override
  Future<CustomerAuthResult> login() {
    loginCalls += 1;
    return loginCompleter.future;
  }

  void succeed() => loginCompleter.complete(_authResult());

  void cancel() => loginCompleter.completeError(
        const CustomerAuthException(CustomerAuthErrorKind.cancelled),
      );

  @override
  Future<CustomerAuthResult> refresh(String refreshToken) async =>
      _authResult();

  @override
  Future<void> endSession({required String idTokenHint}) async {}
}

CustomerAuthResult _authResult() {
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

Future<AccountController> _buildController(
  AppDatabase db,
  CustomerAuthGateway gateway, {
  CustomerProfileService? profileService,
}) async {
  final deviceStore = DeviceStore(db);
  await deviceStore.upsert(
    deviceId: 'dev-1',
    platform: 'ios',
    appVersion: '1',
  );
  return AccountController(
    sessionRepository: CustomerSessionRepository(
      authGateway: gateway,
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
    profileService: profileService,
  );
}

/// Records calls; each can be made to fail with [failure].
class _FakeProfileService implements CustomerProfileService {
  _FakeProfileService({this.photoDataUrl});

  String? photoDataUrl;
  Object? failure;
  final calls = <String>[];
  String? lastFirstName;
  String? lastDataUrl;

  @override
  Future<CustomerProfile> fetch(String accessToken) async {
    calls.add('fetch');
    return CustomerProfile(
      shopifyCustomerId: 'gid://shopify/Customer/1',
      firstName: 'Ana',
      lastName: 'Ruiz',
      displayName: 'Ana Ruiz',
      photoDataUrl: photoDataUrl,
    );
  }

  @override
  Future<String?> updateFirstName(String accessToken, String firstName) async {
    calls.add('updateFirstName');
    final error = failure;
    if (error != null) throw error;
    lastFirstName = firstName;
    return firstName;
  }

  @override
  Future<void> setPhoto(
    String accessToken,
    String customerId,
    String dataUrl,
  ) async {
    calls.add('setPhoto');
    final error = failure;
    if (error != null) throw error;
    lastDataUrl = dataUrl;
  }

  @override
  Future<void> removePhoto(String accessToken, String customerId) async {
    calls.add('removePhoto');
    final error = failure;
    if (error != null) throw error;
  }
}

/// A valid 1x1 PNG, so `Image.memory` has something real to decode.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets(
    'Account opens hosted auth directly and never renders the hardcoded login',
    (tester) async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final gateway = _PendingShopGateway();
      final controller = await _buildController(db, gateway);
      var openedAdmin = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => unawaited(
                  openAccount(
                    context,
                    controller: controller,
                    canOpenAdmin: () => true,
                    onOpenAdmin: () => openedAdmin = true,
                  ),
                ),
                child: const Text('ACCOUNT'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('ACCOUNT'));
      await tester.pump();

      expect(gateway.loginCalls, 1);
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byKey(const ValueKey('shop-sign-in-button')), findsNothing);
      expect(find.byKey(const ValueKey('shop-register-button')), findsNothing);

      gateway.succeed();
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('account-identity')), findsOneWidget);
      expect(find.text('ana@example.com'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      final adminEntry = find.byKey(const ValueKey('open-owner-admin'));
      expect(adminEntry, findsOneWidget);
      // La página boutique desplaza: llevar a vista antes de tocar.
      await tester.scrollUntilVisible(adminEntry, 400);
      await tester.pumpAndSettle();
      await tester.tap(adminEntry);
      expect(openedAdmin, isTrue);

      final deleteLink = find.text('Eliminar mi cuenta');
      await tester.scrollUntilVisible(deleteLink, 400);
      await tester.pumpAndSettle();
      expect(find.text('Política de privacidad'), findsOneWidget);
      expect(
        tester.widget<Text>(deleteLink).style?.color,
        const Color(0xFFA3342B),
      );

      // One «Cerrar sesión» only: the duplicate text button is gone.
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('CERRAR SESIÓN'), findsNothing);
      final logout = find.byKey(const ValueKey('account-logout'));
      await tester.scrollUntilVisible(logout, 400);
      await tester.pumpAndSettle();
      await tester.tap(logout);
      await tester.pumpAndSettle();
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Inicia sesión'), findsNothing);
    },
  );

  testWidgets('cancelling hosted auth keeps the shopper on the current page', (
    tester,
  ) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final gateway = _PendingShopGateway();
    final controller = await _buildController(db, gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                openAccount(context, controller: controller),
              ),
              child: const Text('ACCOUNT'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ACCOUNT'));
    await tester.pump();
    gateway.cancel();
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Inicia sesión'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('orders UI distinguishes failed from empty', (tester) async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final gateway = _PendingShopGateway();
    final controller = await _buildController(db, gateway);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                openAccount(context, controller: controller),
              ),
              child: const Text('ACCOUNT'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ACCOUNT'));
    await tester.pump();
    gateway.succeed();
    await tester.pumpAndSettle();

    // Force a failed status with no rows — must not read as empty history.
    // The history lives on its own screen now (Cuenta has no preview).
    await tester.tap(find.byKey(const ValueKey('account-open-orders')));
    await tester.pumpAndSettle();
    controller.orders = const [];
    controller.ordersStatus = OrderHistoryStatus.failed;
    controller.ordersLoading = false;
    controller.notifyListeners();
    await tester.pump();

    expect(find.text('Aún no tienes pedidos'), findsNothing);
    expect(
      find.textContaining('No pudimos cargar tus pedidos'),
      findsOneWidget,
    );

    controller.ordersStatus = OrderHistoryStatus.empty;
    controller.notifyListeners();
    await tester.pump();
    expect(find.text('Aún no tienes pedidos'), findsOneWidget);
  });

  group('Profile photo and name', () {
    Future<AccountController> pumpAccount(
      WidgetTester tester, {
      required _FakeProfileService service,
      Future<Uint8List?> Function()? picker,
    }) async {
      await tester.binding.setSurfaceSize(const Size(420, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = openTestDatabase();
      addTearDown(db.close);
      final gateway = _PendingShopGateway()..succeed();
      final controller = await _buildController(
        db,
        gateway,
        profileService: service,
      );
      await controller.login();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: AccountScreen(
            controller: controller,
            profilePhotoPicker: picker,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    Future<void> openEditor(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('account-edit-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Editar mi perfil'), findsOneWidget);
    }

    String nameField(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const ValueKey('profile-name-field')))
        .controller!
        .text;

    testWidgets('the avatar renders the Shopify photo when there is one',
        (tester) async {
      final service = _FakeProfileService(
        photoDataUrl: profilePhotoDataUrl(_tinyPng),
      );
      await pumpAccount(tester, service: service);

      expect(service.calls, ['fetch']);
      expect(
        find.byKey(const ValueKey('account-avatar-photo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('account-avatar-edit-badge')),
        findsOneWidget,
      );
    });

    testWidgets('without a photo the avatar keeps the initial', (tester) async {
      await pumpAccount(tester, service: _FakeProfileService());

      expect(find.byKey(const ValueKey('account-avatar-photo')), findsNothing);
      expect(find.text('A'), findsWidgets);
    });

    testWidgets('the identity row is a labelled editing button',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpAccount(tester, service: _FakeProfileService());

      expect(find.bySemanticsLabel(RegExp('Editar foto y nombre')), findsOne);
      final size = tester.getSize(
        find.byKey(const ValueKey('account-edit-profile')),
      );
      expect(size.height, greaterThanOrEqualTo(48));

      await openEditor(tester);
      expect(find.text('Elegir foto'), findsOneWidget);
      expect(find.text('Quitar foto'), findsNothing);
      expect(find.text('JPG o PNG. Se ajusta a 384 px.'), findsOneWidget);
      expect(find.text('Nombre que se muestra'), findsOneWidget);
      expect(
        find.text('Tu foto y tu nombre se guardan en tu cuenta de Monetta.'),
        findsOneWidget,
      );
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      // Prefilled with Shopify's first name, not the display name.
      expect(nameField(tester), 'Ana');
      semantics.dispose();
    });

    testWidgets('saving a changed name sends only the name', (tester) async {
      final service = _FakeProfileService();
      final controller = await pumpAccount(tester, service: service);
      await openEditor(tester);

      await tester.enterText(
        find.byKey(const ValueKey('profile-name-field')),
        '  Lucía ',
      );
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();

      expect(service.calls, ['fetch', 'updateFirstName']);
      expect(service.lastFirstName, 'Lucía');
      expect(find.text('Editar mi perfil'), findsNothing);
      expect(find.text('Perfil actualizado'), findsOneWidget);
      expect(controller.account?.displayName, 'Lucía');
      expect(find.text('Lucía'), findsWidgets);
    });

    testWidgets('a picked photo is sent alone, without touching the name',
        (tester) async {
      final service = _FakeProfileService();
      await pumpAccount(
        tester,
        service: service,
        picker: () async => _tinyPng,
      );
      await openEditor(tester);

      await tester.tap(find.byKey(const ValueKey('profile-choose-photo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-editor-photo')),
        findsOneWidget,
      );
      expect(find.text('Quitar foto'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();

      expect(service.calls, ['fetch', 'setPhoto']);
      expect(service.lastDataUrl, profilePhotoDataUrl(_tinyPng));
      expect(find.text('Perfil actualizado'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('account-avatar-photo')),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled picker changes nothing', (tester) async {
      final service = _FakeProfileService();
      await pumpAccount(tester, service: service, picker: () async => null);
      await openEditor(tester);

      await tester.tap(find.byKey(const ValueKey('profile-choose-photo')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();

      // Nothing changed: closes without calling Shopify or announcing a save.
      expect(service.calls, ['fetch']);
      expect(find.text('Perfil actualizado'), findsNothing);
    });

    testWidgets('«Quitar foto» removes the stored photo on save',
        (tester) async {
      final service = _FakeProfileService(
        photoDataUrl: profilePhotoDataUrl(_tinyPng),
      );
      final controller = await pumpAccount(tester, service: service);
      await openEditor(tester);

      expect(find.text('Quitar foto'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile-remove-photo')));
      await tester.pumpAndSettle();
      expect(find.text('Quitar foto'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();

      expect(service.calls, ['fetch', 'removePhoto']);
      expect(controller.profile?.photoDataUrl, isNull);
      expect(find.byKey(const ValueKey('account-avatar-photo')), findsNothing);
    });

    testWidgets('an empty name is refused before calling Shopify',
        (tester) async {
      final service = _FakeProfileService();
      await pumpAccount(tester, service: service);
      await openEditor(tester);

      await tester.enterText(
        find.byKey(const ValueKey('profile-name-field')),
        '   ',
      );
      await tester.tap(find.byKey(const ValueKey('profile-save')));
      await tester.pumpAndSettle();

      expect(service.calls, ['fetch']);
      expect(
        find.text('Escribe el nombre que quieres mostrar.'),
        findsOneWidget,
      );
      expect(find.text('Editar mi perfil'), findsOneWidget);
    });

    testWidgets('shows Spanish error copy and keeps the sheet open',
        (tester) async {
      final service = _FakeProfileService();
      await pumpAccount(
        tester,
        service: service,
        picker: () async => _tinyPng,
      );
      await openEditor(tester);
      await tester.tap(find.byKey(const ValueKey('profile-choose-photo')));
      await tester.pumpAndSettle();

      final cases = <Object, String>{
        const ProfilePhotoTooLargeException(61000):
            'La foto es demasiado grande. Elige otra.',
        const CustomerAuthException(CustomerAuthErrorKind.offline):
            'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
        const CustomerAuthException(CustomerAuthErrorKind.sessionExpired):
            'Tu sesión terminó. Inicia sesión de nuevo.',
        const CustomerAuthException(CustomerAuthErrorKind.server):
            'No pudimos guardar tu perfil. Inténtalo de nuevo.',
      };
      for (final entry in cases.entries) {
        service.failure = entry.key;
        // A rejected-as-too-large photo is dropped; pick it again each round.
        if (find.text('Quitar foto').evaluate().isEmpty) {
          await tester.tap(find.byKey(const ValueKey('profile-choose-photo')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('profile-save')));
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('Editar mi perfil'), findsOneWidget);
        expect(find.text('Perfil actualizado'), findsNothing);
      }
    });

    testWidgets('the editor does not overflow at 2.0 text scale',
        (tester) async {
      final service = _FakeProfileService(
        photoDataUrl: profilePhotoDataUrl(_tinyPng),
      );
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = openTestDatabase();
      addTearDown(db.close);
      final gateway = _PendingShopGateway()..succeed();
      final controller = await _buildController(
        db,
        gateway,
        profileService: service,
      );
      await controller.login();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: AccountScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('account-edit-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Editar mi perfil'), findsOneWidget);
      // The sheet scrolls; the last action is reachable.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-cancel')),
        200,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-editor')).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a legacy Monetta account has no edit affordance',
        (tester) async {
      final service = _FakeProfileService();
      await tester.binding.setSurfaceSize(const Size(420, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = openTestDatabase();
      addTearDown(db.close);
      final controller = await _buildController(
        db,
        _PendingShopGateway(),
        profileService: service,
      );
      final store = AccountStore(db);
      await store.upsert(
        localAccountId: 'legacy-1',
        email: 'ana@example.com',
        displayName: 'Ana',
        authProvider: 'monetta',
        createdAt: DateTime.utc(2026),
      );
      controller.account = await store.byLocalId('legacy-1');

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: AccountScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('account-identity')), findsOneWidget);
      expect(find.byKey(const ValueKey('account-edit-profile')), findsNothing);
      expect(
        find.byKey(const ValueKey('account-avatar-edit-badge')),
        findsNothing,
      );
      expect(find.text('A'), findsWidgets);
      expect(service.calls, isEmpty);
    });
  });
}
