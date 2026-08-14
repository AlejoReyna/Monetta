# `data/local` — the on-device database

The Drift/SQLite layer `docs/ARCHITECTURE.md` has described since Phase 1 planning, built for
real in `docs/ACCOUNTS_AND_SYNC_PLAN.md` Phase 0. Holds the catalog cache, sync cursor,
wishlist, bag, recommendation event log, and the account/device/session schema Phase 1's
login populates.

## 1. Shape

`tables.dart` defines eleven tables; `database.dart` wires them into `AppDatabase`. On top of
that, one hand-written store class per concern (`catalog_cache_store.dart`,
`wishlist_store.dart`, `bag_store.dart`, `interaction_event_store.dart`,
`sync_cursor_store.dart`, `account_store.dart`, `order_summary_store.dart`) — no separate
`@DriftAccessor` DAO codegen layer on top of the table codegen already required. Two codegen
layers for a schema this size would be the kind of ceremony `data/shopify/README.md` § 3
argues against; plain classes over `AppDatabase` do the same job with less machinery.

`AppDatabase.connect()` opens the real on-device file (under the app support directory, not
Documents — this is app data, not something a shopper should find in the Files app).
`openTestDatabase()` is the in-memory equivalent every test in `test/data/local/` uses —
inject one or the other; nothing in this module should ever choose for itself which one to
open.

## 2. Three gotchas that cost real debugging time building this

**An `INTEGER PRIMARY KEY` column omitted from an insert gets a fresh SQLite-assigned rowid,
never the column's `withDefault`.** `SyncCursors` is a singleton table (id is always `0`), and
the very first version of its upsert omitted `id` — SQLite silently auto-incremented it
instead of colliding on conflict, so the "upsert" just kept inserting new rows. Every write to
a singleton-row table in this module passes `id: const Value(0)` explicitly — see
`sync_cursor_store.dart`.

**Drift's default (non-text) `DateTime` storage reads back as local time, not UTC — even for
a value that was written as UTC.** Same instant, different `isUtc` flag, and Dart's
`DateTime.==` is flag-sensitive (`DateTime.utc(2026,1,1) != DateTime.utc(2026,1,1).toLocal()`
by `==`, despite being the same moment). Compare stored timestamps with `isAtSameMomentAs`,
not `==`, and call `.toUtc()` before handing a value to something that assumes UTC throughout
(`data/shopify/catalog_sync.dart`'s `SyncCursor`, most notably).

**Drift generates a row data class per table, and several of those names collide with
existing types.** `SyncCursors` → `SyncCursor` collides with `data/shopify/catalog_sync.dart`'s
`SyncCursor`; `BagLines` → `BagLine` collides with `domain/bag_line.dart`'s `BagLine`;
`InteractionEvents` → `InteractionEvent` collides with `reco/events.dart`'s `InteractionEvent`.
Every file that needs both sides imports `database.dart` with `hide <Name>` (when only the
domain/reco type is needed unprefixed) or `as local show <Name>` (when the generated type is
what's actually wanted) — never both unprefixed in the same file. Search for `hide` and
`as local` across this module and `app/` for the concrete pattern.

## 3. How `CatalogStore` uses this without becoming async everywhere

`app/catalog_store.dart` was, and remains, a synchronous-getter `ChangeNotifier` — five widget
test files and every screen read `.products`, `.bagLines`, `.wishlist` mid-frame with no
`await`. Nothing here changes that contract: `loadFromAsset()` hydrates the in-memory fields
from Drift once, at startup (seeding from the bundled catalog snapshot first if the cache is
empty), and every mutating method (`toggleWishlist`, `addToBag`, `record`, …) updates the
in-memory field immediately and fires an `unawaited()` write to the matching store alongside
it — the same fire-and-forget shape `main.dart` already used for
`ExternalCatalogController.loadAndRefresh()` before this module existed.

The one place that pattern was wrong was `AccountController.login()` firing
`unawaited(loadOrders())` — a dangling, untracked Future that could still be touching the
database after a test's `tearDown` closed it. `login()` now `await`s `loadOrders()` instead
(see `app/account_controller.dart`); `isLoading`, the login button's own spinner flag, still
flips false before that await starts, so the visible timing didn't change — only whether the
whole operation is deterministically finished when `login()`'s `Future` completes.

## 4. Tests

```bash
flutter test test/data/local
```

`database_test.dart` exercises the schema directly (cascade deletes, the singleton-row upsert,
the UTC round-trip). `stores_test.dart` and `order_summary_store_test.dart` exercise each store
class, including the device-to-account wishlist/bag merge
(`docs/ACCOUNTS_AND_SYNC_PLAN.md` § 5) and the apartado/checkout order unification
(§ Phase 3).
