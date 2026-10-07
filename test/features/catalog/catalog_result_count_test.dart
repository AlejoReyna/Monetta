/// The "N piezas" label is an owner aid: shoppers never see how many pieces a
/// listing holds; a signed-in account that may open the admin panel does.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/catalog/catalog_controls.dart';
import 'package:monetta_app/main.dart';

const _ownerEmail = 'owner@example.com';

AccountController _account(AppDatabase db, {String? signedInEmail}) {
  final controller = AccountController(
    accountStore: AccountStore(db),
    deviceStore: DeviceStore(db),
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    deviceId: 'dev-1',
  );
  if (signedInEmail != null) {
    controller.account = Account(
      localAccountId: 'acct-1',
      email: signedInEmail,
      authProvider: 'monetta',
      createdAt: DateTime.utc(2026),
      lastSeenAt: DateTime.utc(2026),
    );
  }
  return controller;
}

AdminController _admin() => AdminController(
      config: const AdminConfig(
        baseUrl: null,
        ownerEmails: {_ownerEmail},
      ),
    );

Widget _app({AccountController? account, AdminController? admin}) {
  Widget child = const Scaffold(body: CatalogResultCount(count: 3));
  if (account != null) child = AccountScope(notifier: account, child: child);
  if (admin != null) child = AdminScope(notifier: admin, child: child);
  return MaterialApp(theme: buildTheme(), home: child);
}

void main() {
  late AppDatabase db;
  late AdminController admin;

  setUp(() {
    db = openTestDatabase();
    admin = _admin();
  });

  tearDown(() async {
    admin.dispose();
    await db.close();
  });

  testWidgets('a shopper without a session does not see the piece count',
      (tester) async {
    final account = _account(db);
    addTearDown(account.dispose);

    await tester.pumpWidget(_app(account: account, admin: admin));

    expect(find.text('3 piezas'), findsNothing);
  });

  testWidgets('a signed-in shopper who is not an owner does not see it',
      (tester) async {
    final account = _account(db, signedInEmail: 'ana@example.com');
    addTearDown(account.dispose);

    await tester.pumpWidget(_app(account: account, admin: admin));

    expect(find.text('3 piezas'), findsNothing);
  });

  testWidgets('a signed-in owner sees the piece count', (tester) async {
    final account = _account(db, signedInEmail: _ownerEmail);
    addTearDown(account.dispose);

    await tester.pumpWidget(_app(account: account, admin: admin));

    expect(find.text('3 piezas'), findsOneWidget);
  });

  testWidgets('without account or admin state the count stays hidden',
      (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('3 piezas'), findsNothing);
  });
}
