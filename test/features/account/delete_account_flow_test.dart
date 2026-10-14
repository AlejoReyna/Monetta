import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/data/accounts_orders/account_deletion_client.dart';
import 'package:monetta_app/data/customer_auth/customer_auth_error.dart';
import 'package:monetta_app/features/account/delete_account_screen.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';

class _Client implements AccountDeletionClient {
  _Client(this.precheckResult);

  AccountDeletionOutcome precheckResult;
  AccountDeletionOutcome deleteResult = const AccountDeletionDeleted();
  int precheckCalls = 0;
  int deleteCalls = 0;
  Completer<AccountDeletionOutcome>? pendingPrecheck;

  @override
  Future<AccountDeletionOutcome> precheck(String accessToken) {
    precheckCalls += 1;
    final pending = pendingPrecheck;
    if (pending != null) return pending.future;
    return Future.value(precheckResult);
  }

  @override
  Future<AccountDeletionOutcome> delete({
    required String accessToken,
    required String idToken,
  }) async {
    deleteCalls += 1;
    return deleteResult;
  }

  @override
  void close() {}
}

Future<void> _open(
  WidgetTester tester, {
  required _Client client,
  required Future<FreshCustomerLogin> Function() reauthenticate,
  required Future<void> Function() signOut,
  void Function(AccountDeletionOrderRef order)? onViewOrder,
  Duration confirmDelay = const Duration(seconds: 2),
  Duration slowAfter = const Duration(seconds: 10),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openDeleteAccount(
              context,
              client: client,
              accessToken: () async => 'access-token',
              reauthenticate: reauthenticate,
              signOutToHome: signOut,
              onViewOrder: onViewOrder ?? (_) {},
              confirmDelay: confirmDelay,
              slowAfter: slowAfter,
              openUri: (_) async => true,
            ),
            child: const Text('Inicio'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Inicio'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('info screen continues only after the server block check', (
    tester,
  ) async {
    final client = _Client(
      const AccountDeletionBlocked(
        AccountDeletionOrderRef(id: '15', shopifyOrderId: '900'),
      ),
    );
    var viewed = false;
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('should not reauth'),
      signOut: () async {},
      onViewOrder: (_) => viewed = true,
    );

    expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();

    expect(client.precheckCalls, 1);
    expect(client.deleteCalls, 0);
    expect(find.text(kDeleteAccountBlocked), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('delete-account-view-order')));
    expect(viewed, isTrue);
    expect(find.text('Escríbenos por WhatsApp'), findsOneWidget);
  });

  testWidgets('confirm stays disabled for 2 seconds and is announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final client = _Client(const AccountDeletionClear());
    var signedOut = false;
    await _open(
      tester,
      client: client,
      reauthenticate: () async => const FreshCustomerLogin(
        accessToken: 'fresh-access',
        idToken: 'fresh-id',
      ),
      signOut: () async => signedOut = true,
    );

    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
    final disabled = tester.widget<BoutiqueButton>(
      find.byKey(const ValueKey('delete-account-confirm')),
    );
    expect(disabled.onPressed, isNull);
    expect(
      find.bySemanticsLabel(
        'Eliminar cuenta. Se habilita en unos segundos.',
      ),
      findsOneWidget,
    );
    expect(client.deleteCalls, 0);

    await tester.pump(const Duration(seconds: 2));
    final enabled = tester.widget<BoutiqueButton>(
      find.byKey(const ValueKey('delete-account-confirm')),
    );
    expect(enabled.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(kDeleteAccountSuccess), findsOneWidget);
    expect(client.deleteCalls, 1);

    await tester.tap(find.byKey(const ValueKey('delete-account-done')));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text(kDeleteAccountSuccess), findsNothing);
  });

  testWidgets('shows the slow loading copy after 10 seconds', (tester) async {
    final client = _Client(
      const AccountDeletionBlocked(
        AccountDeletionOrderRef(id: '1'),
      ),
    );
    final gate = Completer<AccountDeletionOutcome>();
    client.pendingPrecheck = gate;
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('still loading'),
      signOut: () async {},
    );

    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('delete-account-progress')),
      findsOneWidget,
    );
    expect(find.text(kDeleteAccountSlow), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text(kDeleteAccountSlow), findsOneWidget);

    gate.complete(client.precheckResult);
    await tester.pumpAndSettle();
    expect(find.text(kDeleteAccountBlocked), findsOneWidget);
  });

  testWidgets('shows offline, error, and cancelled reauthentication', (
    tester,
  ) async {
    final offline = _Client(const AccountDeletionOffline());
    await _open(
      tester,
      client: offline,
      reauthenticate: () async => const FreshCustomerLogin(
        accessToken: 'a',
        idToken: 'b',
      ),
      signOut: () async {},
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(find.text(kDeleteAccountOffline), findsOneWidget);

    final failed = _Client(const AccountDeletionFailed());
    await _open(
      tester,
      client: failed,
      reauthenticate: () async => const FreshCustomerLogin(
        accessToken: 'a',
        idToken: 'b',
      ),
      signOut: () async {},
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(find.text(kDeleteAccountError), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    final clear = _Client(const AccountDeletionClear());
    await _open(
      tester,
      client: clear,
      reauthenticate: () async => throw const CustomerAuthException(
        CustomerAuthErrorKind.cancelled,
      ),
      signOut: () async {},
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    expect(find.text(kDeleteAccountError), findsNothing);
    expect(clear.deleteCalls, 0);
  });
}
