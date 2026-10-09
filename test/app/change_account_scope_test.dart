/// CHAR-16b: the composition-level complement of CHAR-16. The use case runs
/// the store, the search history and the checkout invalidation in a fixed
/// order on every scope change, with or without a checkout.
library;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/change_account_scope.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/shopper_scope.dart';
import 'package:monetta_app/features/catalog/search_history.dart';

class _SpyStore extends CatalogStore {
  _SpyStore(this.log, {required super.database});

  final List<String> log;

  @override
  Future<void> setAccountScope(String? accountId) async {
    log.add('store:${accountId ?? 'guest'}');
  }
}

class _SpyHistory extends SearchHistory {
  _SpyHistory(this.log);

  final List<String> log;

  @override
  Future<void> setScope(String? accountId) async {
    log.add('history:${accountId ?? 'guest'}');
  }
}

ShopperScope _scope(String? accountId) =>
    ShopperScope(shopDomain: 'monetta.mx', accountId: accountId);

void main() {
  late AppDatabase db;
  late List<String> log;
  late _SpyStore store;
  late _SpyHistory history;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    log = <String>[];
    store = _SpyStore(log, database: db);
    history = _SpyHistory(log);
  });

  tearDown(() async {
    store.dispose();
    history.dispose();
    await db.close();
  });

  ChangeAccountScope build({bool withCheckout = true}) => ChangeAccountScope(
        store: store,
        searchHistory: history,
        invalidateCheckout: withCheckout
            ? () async {
                log.add('checkout');
              }
            : null,
      );

  test('CHAR-16b store, history and checkout run in that order', () async {
    await build()(_scope('A'));

    expect(log, ['store:A', 'history:A', 'checkout']);
  });

  test('CHAR-16b the checkout is invalidated on login', () async {
    await build()(_scope('A'));

    expect(log.where((e) => e == 'checkout'), hasLength(1));
  });

  test('CHAR-16b the checkout is invalidated on logout', () async {
    final change = build();
    await change(_scope('A'));
    log.clear();

    await change(_scope(null));

    expect(log, ['store:guest', 'history:guest', 'checkout']);
  });

  test('CHAR-16b the checkout is invalidated on every A to B switch', () async {
    final change = build();
    await change(_scope('A'));
    await change(_scope('B'));

    expect(log.where((e) => e == 'checkout'), hasLength(2));
    expect(
      log,
      ['store:A', 'history:A', 'checkout', 'store:B', 'history:B', 'checkout'],
    );
  });

  test('CHAR-16b it works without a checkout', () async {
    await build(withCheckout: false)(_scope('A'));

    expect(log, ['store:A', 'history:A']);
  });

  test('CHAR-16b the checkout waits for the history to settle', () async {
    var historyDone = false;
    final change = ChangeAccountScope(
      store: store,
      searchHistory: _SlowHistory(
        onDone: () => historyDone = true,
      ),
      invalidateCheckout: () async {
        log.add('checkout:historyDone=$historyDone');
      },
    );

    await change(_scope('A'));

    expect(log, ['store:A', 'checkout:historyDone=true']);
  });
}

class _SlowHistory extends SearchHistory {
  _SlowHistory({required this.onDone});

  final void Function() onDone;

  @override
  Future<void> setScope(String? accountId) async {
    await Future<void>.delayed(Duration.zero);
    onDone();
  }
}
