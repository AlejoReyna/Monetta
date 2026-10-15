import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/shopper_copy.dart';
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
  Future<AccountDeletionOutcome> matchLegacyEmail({
    required String shopifyAccessToken,
    required String legacySessionToken,
  }) async {
    return const AccountDeletionFailed();
  }

  @override
  Future<AccountDeletionOutcome> delete({
    required String accessToken,
    required String idToken,
    String? legacySessionToken,
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
  Future<bool> Function(Uri uri)? openUri,
  Future<LegacyDeletionSignIn> Function()? signInForDeletion,
  Future<void> Function()? abandonUnmatchedLogin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
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
              openUri: openUri ?? (_) async => true,
              signInForDeletion: signInForDeletion,
              abandonUnmatchedLogin: abandonUnmatchedLogin,
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
    try {
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
      expect(
        kDeleteAccountSuccess,
        'Tu cuenta fue eliminada. Tus datos de compra se borrarán en un '
        'proceso que puede tardar hasta 6 meses.',
      );
      expect(find.text(kDeleteAccountSuccess), findsOneWidget);
      expect(find.textContaining('correo'), findsNothing);
      expect(find.textContaining('email'), findsNothing);
      expect(client.deleteCalls, 1);

      await tester.tap(find.byKey(const ValueKey('delete-account-done')));
      await tester.pumpAndSettle();
      expect(signedOut, isTrue);
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text(kDeleteAccountSuccess), findsNothing);
    } finally {
      semantics.dispose();
    }
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

  testWidgets('a charged cancellation uses the refund block screen', (
    tester,
  ) async {
    final client = _Client(
      const AccountDeletionBlocked(
        AccountDeletionOrderRef(
          id: '9',
          shopifyOrderId: '9',
          reason: 'refund_in_progress',
        ),
      ),
    );
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('should not reauth'),
      signOut: () async {},
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(find.text(kDeleteAccountRefundBlocked), findsOneWidget);
    expect(find.text('Ver pedido'), findsOneWidget);
    expect(find.text(kDeleteAccountBlocked), findsNothing);
  });

  testWidgets('legacy reauth returns to the delete screen and Ahora no closes',
      (
    tester,
  ) async {
    final client = _Client(const AccountDeletionReauthRequired());
    var logins = 0;
    await _open(
      tester,
      client: client,
      reauthenticate: () async {
        logins += 1;
        return const FreshCustomerLogin(accessToken: 'fresh', idToken: 'id');
      },
      signOut: () async {},
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(find.text(kDeleteAccountReauthTitle), findsOneWidget);
    expect(find.text(kDeleteAccountReauthBody), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-account-reauth')));
    await tester.pumpAndSettle();
    expect(logins, 1);
    expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    expect(find.text('Eliminar cuenta'), findsOneWidget);
    expect(find.text(kDeleteAccountReauthTitle), findsNothing);
    expect(find.text('Inicio'), findsNothing);
    expect(client.deleteCalls, 0);

    client.precheckResult = const AccountDeletionReauthRequired();
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('delete-account-reauth-dismiss')));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text(kDeleteAccountReauthTitle), findsNothing);
  });

  testWidgets('a failed order check explains that nothing was deleted', (
    tester,
  ) async {
    final client = _Client(const AccountDeletionOrderCheckUnavailable());
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('should not reauth'),
      signOut: () async {},
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(find.text(kDeleteAccountOrderCheckTitle), findsOneWidget);
    expect(find.text(kDeleteAccountOrderCheckBody), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    client.precheckResult = const AccountDeletionClear();
    await tester
        .tap(find.byKey(const ValueKey('delete-account-order-check-retry')));
    await tester.pumpAndSettle();
    expect(client.precheckCalls, 2);
  });

  testWidgets('a cancelled partial refund names the order and opens WhatsApp', (
    tester,
  ) async {
    final client = _Client(
      const AccountDeletionBlocked(
        AccountDeletionOrderRef(
          id: '9',
          shopifyOrderId: '9',
          reason: 'refund_review',
          orderName: '#1042',
        ),
      ),
    );
    Uri? opened;
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('should not reauth'),
      signOut: () async {},
      openUri: (uri) async {
        opened = uri;
        return true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text(deleteAccountRefundReviewMessage('#1042')),
      findsOneWidget,
    );
    expect(find.text(kDeleteAccountRefundBlocked), findsNothing);

    await tester.tap(find.byKey(const ValueKey('delete-account-whatsapp')));
    await tester.pumpAndSettle();
    expect(opened, accountDeletionRefundReviewUri(orderNumber: '#1042'));
    expect(opened?.queryParameters['text'], contains('#1042'));
    expect(client.deleteCalls, 0);
  });

  testWidgets('a cancelled charge with no refund asks to review the payment', (
    tester,
  ) async {
    final client = _Client(
      const AccountDeletionBlocked(
        AccountDeletionOrderRef(
          id: '9',
          shopifyOrderId: '9',
          reason: 'payment_review',
          orderName: '#1042',
        ),
      ),
    );
    Uri? opened;
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('should not reauth'),
      signOut: () async {},
      openUri: (uri) async {
        opened = uri;
        return true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text(deleteAccountPaymentReviewMessage('#1042')),
      findsOneWidget,
    );
    expect(find.text(kDeleteAccountRefundBlocked), findsNothing);
    expect(find.text('Escríbenos por WhatsApp'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-account-whatsapp')));
    await tester.pumpAndSettle();
    expect(opened, accountDeletionPaymentReviewUri(orderNumber: '#1042'));
    expect(opened.toString(), contains('wa.me/528261066868'));
    expect(opened?.queryParameters['text'], contains('#1042'));
    expect(client.deleteCalls, 0);
  });

  testWidgets('a mismatched Shopify login stays on the delete flow', (
    tester,
  ) async {
    final client = _Client(const AccountDeletionReauthRequired());
    var signIns = 0;
    var abandoned = 0;
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('should not reauth'),
      signOut: () async {},
      abandonUnmatchedLogin: () async {
        abandoned += 1;
      },
      signInForDeletion: () async {
        signIns += 1;
        if (signIns == 1) {
          return const LegacyDeletionMismatch('a•••@gmail.com');
        }
        return const LegacyDeletionMatched(
          FreshCustomerLogin(accessToken: 'fresh', idToken: 'id'),
          legacySessionToken: 'legacy-token',
        );
      },
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-account-reauth')));
    await tester.pumpAndSettle();

    expect(find.text(kDeleteAccountEmailMismatchTitle), findsOneWidget);
    expect(
      find.text(deleteAccountEmailMismatchBody('a•••@gmail.com')),
      findsOneWidget,
    );
    expect(find.text('Iniciar sesión con otra cuenta'), findsOneWidget);
    expect(client.deleteCalls, 0);
    expect(find.text('Inicio'), findsNothing);

    await tester
        .tap(find.byKey(const ValueKey('delete-account-other-account')));
    await tester.pumpAndSettle();
    expect(abandoned, 1);
    expect(signIns, 2);
    expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    expect(find.text(kDeleteAccountEmailMismatchTitle), findsNothing);

    client.precheckResult = const AccountDeletionClear();
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
    expect(signIns, 2);
    expect(client.deleteCalls, 0);
  });

  testWidgets('Cancelar on a mismatched login closes without deleting', (
    tester,
  ) async {
    final client = _Client(const AccountDeletionReauthRequired());
    var abandoned = 0;
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('should not reauth'),
      signOut: () async {},
      abandonUnmatchedLogin: () async {
        abandoned += 1;
      },
      signInForDeletion: () async =>
          const LegacyDeletionMismatch('a•••@gmail.com'),
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-account-reauth')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-account-email-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(abandoned, greaterThan(0));
    expect(client.deleteCalls, 0);
  });

  testWidgets('too many orders opens WhatsApp and does not delete', (
    tester,
  ) async {
    final client = _Client(const AccountDeletionTooManyOrders());
    Uri? opened;
    await _open(
      tester,
      client: client,
      reauthenticate: () async => throw StateError('should not reauth'),
      signOut: () async {},
      openUri: (uri) async {
        opened = uri;
        return true;
      },
    );
    await tester.tap(find.byKey(const ValueKey('delete-account-continue')));
    await tester.pumpAndSettle();
    expect(find.text(kDeleteAccountTooManyTitle), findsOneWidget);
    expect(find.text(kDeleteAccountTooManyBody), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('delete-account-too-many-whatsapp')));
    await tester.pumpAndSettle();
    expect(opened, accountDeletionManualRequestUri());
    expect(opened?.queryParameters['text'], kDeleteAccountManualWhatsAppText);
    expect(client.deleteCalls, 0);
  });
}
