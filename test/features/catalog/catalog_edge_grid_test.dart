// Catalog cards retain the catalog data, typography and interactions, with
// white rounded surfaces and slightly inset photographs.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/account_controller.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/app/card_lift.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/accounts_orders/accounts_orders_config.dart';
import 'package:monetta_app/data/local/account_store.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/local/order_summary_store.dart';
import 'package:monetta_app/data/repositories/order_history_repository.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';
import 'package:monetta_app/main.dart';

import '../../support/catalog_browse_fixtures.dart';

const _longName =
    'Bolso Michael Kors Marilyn Medium Signature Convertible Satchel Crossbody';
const double _price = 11624;
const _priceLabel = r'$11,624 MXN';

BrowseEntry _monetta(int i, {String? title, double price = 1999}) =>
    browseEntry(i, title: title, price: price);

List<BrowseEntry> _items(int count, {String? title, double? price}) => [
      for (var i = 1; i <= count; i++)
        _monetta(i, title: title, price: price ?? 1999),
    ];

/// A text scaler that is deliberately not a single multiplier: small type
/// doubles, large type only grows by a constant. Reserving room by scaling a
/// pre-summed height as if it were a font size gets this wrong.
class _StepTextScaler extends TextScaler {
  const _StepTextScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 16 ? fontSize * 2 : fontSize + 16;

  @override
  double get textScaleFactor => 2;
}

/// Layout errors raised while a test runs, the bottom bar's included: it is
/// on screen in every test and has to hold at every text size as well.
class _ErrorLog {
  _ErrorLog._(this._original) {
    FlutterError.onError = (details) {
      _unexpected.add(details.exceptionAsString());
    };
  }

  final void Function(FlutterErrorDetails)? _original;
  final List<String> _unexpected = [];

  /// Restores the framework's handler (it must be back in place before any
  /// `expect`, or a failing expectation is swallowed) and returns the errors
  /// raised meanwhile.
  List<String> takeUnexpected() {
    restore();
    return List.of(_unexpected);
  }

  void restore() => FlutterError.onError = _original;
}

_ErrorLog _captureErrors() {
  final log = _ErrorLog._(FlutterError.onError);
  addTearDown(log.restore);
  return log;
}

/// Fixes the phone-sized surface. [logical] is in logical points.
void _setView(
  WidgetTester tester,
  Size logical, {
  double dpr = 3,
  FakeViewPadding? padding,
}) {
  tester.view.physicalSize = logical * dpr;
  tester.view.devicePixelRatio = dpr;
  if (padding != null) {
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
  }
  addTearDown(tester.view.reset);
}

const _ownerEmail = 'owner@example.com';

/// Wraps [app] in a signed-in owner's session. The piece count under the
/// title is an owner aid that shoppers never see.
Widget _asOwner(Widget app) {
  final db = openTestDatabase();
  final account = AccountController(
    accountStore: AccountStore(db),
    deviceStore: DeviceStore(db),
    orderHistoryRepository: OrderHistoryRepository(
      store: OrderSummaryStore(db),
      config: AccountsOrdersConfig.disabled,
    ),
    deviceId: 'dev-1',
  )..account = Account(
      localAccountId: 'acct-1',
      email: _ownerEmail,
      authProvider: 'monetta',
      createdAt: DateTime.utc(2026),
      lastSeenAt: DateTime.utc(2026),
    );
  final admin = AdminController(
    config: const AdminConfig(baseUrl: null, ownerEmails: {_ownerEmail}),
  );
  addTearDown(() async {
    admin.dispose();
    account.dispose();
    await db.close();
  });
  return AdminScope(
    notifier: admin,
    child: AccountScope(notifier: account, child: app),
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<BrowseEntry> items, {
  TextScaler? textScaler,
  bool pushed = false,
  bool owner = false,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  final app = MaterialApp(
    navigatorKey: navigator,
    builder: textScaler == null
        ? null
        : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
    home:
        pushed ? const Scaffold(body: SizedBox.shrink()) : browseScreen(items),
  );
  await tester.pumpWidget(owner ? _asOwner(app) : app);
  if (pushed) {
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => browseScreen(items),
        ),
      ),
    );
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Global rect honouring any transform between the box and the screen (a
/// `FittedBox` scales its child without changing the child's own size).
Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder.first);
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

Finder _photoOf(Finder tile) =>
    find.descendant(of: tile, matching: find.byType(AspectRatio)).first;

Finder _brandOf(Finder tile) =>
    find.descendant(of: tile, matching: find.text('Guess'));

Finder _nameOf(Finder tile) => find.descendant(
      of: tile,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            ((widget.data ?? '').startsWith('Monetta Item') ||
                (widget.data ?? '').startsWith('Bolso')),
      ),
    );

/// Photo rects of the first grid row, left to right.
List<Rect> _firstRowPhotos(WidgetTester tester) {
  final tiles = find.byType(MonettaProductTile);
  final photos = <Rect>[
    for (var i = 0; i < tiles.evaluate().length; i++)
      _rect(tester, _photoOf(tiles.at(i))),
  ];
  final top = photos.map((r) => r.top).reduce((a, b) => a < b ? a : b);
  return photos.where((r) => (r.top - top).abs() < 0.01).toList()
    ..sort((a, b) => a.left.compareTo(b.left));
}

void main() {
  group('UI-CAT-01 the grid uses spaced product cards', () {
    testWidgets(
      'UI-CAT-01 at 390 pt: two 189 pt cards, 12 pt apart',
      (tester) async {
        _setView(tester, const Size(390, 844));
        await _pump(tester, _items(6));

        final tiles = find.byType(MonettaProductTile);
        expect(tiles, findsAtLeastNWidgets(4));
        final photo = [
          for (var i = 0; i < 4; i++) _rect(tester, _photoOf(tiles.at(i))),
        ];

        // Row 1.
        expect(photo[0].left, closeTo(0, 0.01));
        expect(photo[0].width, closeTo(189, 0.01));
        expect(photo[0].height, closeTo(236.25, 0.01));
        expect(photo[1].left, closeTo(201, 0.01));
        expect(photo[1].right, closeTo(390, 0.01));
        expect(photo[1].width, closeTo(189, 0.01));
        expect(photo[1].top, closeTo(photo[0].top, 0.01));

        // Row 2 is aligned with itself and one full tile further down:
        // 236.25 photo + 115.85 caption + 12 pt between card rows.
        expect(photo[3].top, closeTo(photo[2].top, 0.01));
        expect(photo[2].left, closeTo(0, 0.01));
        expect(photo[2].top - photo[0].top, closeTo(364.1, 0.01));
      },
    );

    testWidgets(
      'UI-CAT-01 tiles use rounded cards and inset photos without a lift',
      (tester) async {
        _setView(tester, const Size(390, 844));
        await _pump(tester, _items(6));

        expect(find.byType(MonettaCardLift), findsNothing);

        final tiles = find.byType(MonettaProductTile);
        expect(tiles, findsWidgets);
        for (var i = 0; i < tiles.evaluate().length; i++) {
          final tile = tiles.at(i);
          expect(
            find.descendant(of: tile, matching: find.byType(ClipRRect)),
            findsNWidgets(2),
            reason: 'tile $i clips the card and the inset photograph',
          );
          final image = _rect(
            tester,
            find.descendant(of: tile, matching: find.byType(MonettaImage)),
          );
          expect(
            image,
            _rect(tester, _photoOf(tile)).deflate(8),
            reason: 'tile $i',
          );
        }
      },
    );

    testWidgets(
      'UI-CAT-01 caption sits 12 pt in from the photo and 10 pt below it',
      (tester) async {
        _setView(tester, const Size(390, 844));
        await _pump(tester, _items(6));

        final tile = find.byType(MonettaProductTile).first;
        final photo = _rect(tester, _photoOf(tile));
        final brand = _rect(tester, _brandOf(tile));
        final name = _rect(tester, _nameOf(tile));

        expect(brand.left, closeTo(photo.left + 12, 0.01));
        expect(name.left, closeTo(photo.left + 12, 0.01));
        expect(brand.top, closeTo(photo.bottom + 10, 0.01));
      },
    );

    for (final (width, columns) in const [
      (320.0, 1),
      (360.0, 2),
      (768.0, 3),
      (1100.0, 4),
    ]) {
      testWidgets(
        'UI-CAT-01 at ${width.toInt()} pt the grid has $columns column(s) '
        'measured on the real width',
        (tester) async {
          _setView(tester, Size(width, 1400), dpr: 1);
          await _pump(tester, _items(8));

          final row = _firstRowPhotos(tester);
          final tileWidth = (width - 12.0 * (columns - 1)) / columns;
          expect(row.length, columns);
          expect(row.first.left, closeTo(0, 0.01));
          expect(row.last.right, closeTo(width, 0.01));
          for (final photo in row) {
            expect(photo.width, closeTo(tileWidth, 0.01));
            expect(photo.height, closeTo(tileWidth * 1.25, 0.01));
          }
        },
      );
    }

    testWidgets(
      'UI-CAT-01 respects the lateral safe area (47 pt each side)',
      (tester) async {
        _setView(
          tester,
          const Size(844, 390),
          padding: const FakeViewPadding(left: 141, right: 141),
        );
        await _pump(tester, _items(6));

        final row = _firstRowPhotos(tester);
        expect(row, isNotEmpty);
        expect(row.first.left, closeTo(47, 0.01));
        expect(row.last.right, closeTo(844 - 47, 0.01));
      },
    );
  });

  group('UI-CAT-03 caption and text scale', () {
    final scalers = <String, TextScaler>{
      'x1.0': TextScaler.noScaling,
      'x1.3': const TextScaler.linear(1.3),
      'x2.0': const TextScaler.linear(2),
      'non-linear': const _StepTextScaler(),
    };

    for (final MapEntry(key: label, value: scaler) in scalers.entries) {
      testWidgets(
        'UI-CAT-03 $label: no overflow, rows stay aligned, the price is '
        'never ellipsized',
        (tester) async {
          _setView(tester, const Size(390, 844));
          final errors = _captureErrors();
          await _pump(
            tester,
            _items(4, title: _longName, price: _price),
            textScaler: scaler,
          );
          await tester.pump();

          expect(errors.takeUnexpected(), isEmpty);

          final tiles = find.byType(MonettaProductTile);
          expect(tiles, findsAtLeastNWidgets(4));
          final photo = [
            for (var i = 0; i < 4; i++) _rect(tester, _photoOf(tiles.at(i))),
          ];
          expect(photo[1].top, closeTo(photo[0].top, 0.01));
          expect(photo[3].top, closeTo(photo[2].top, 0.01));
          expect(photo[2].top, greaterThan(photo[0].top));

          final prices = find.text(_priceLabel);
          expect(prices, findsAtLeastNWidgets(4));
          for (var i = 0; i < prices.evaluate().length; i++) {
            expect(
              tester
                  .renderObject<RenderParagraph>(prices.at(i))
                  .didExceedMaxLines,
              isFalse,
              reason: 'the price of tile $i must shrink, not end in "..."',
            );
          }
        },
      );
    }
  });

  group('UI-CAT-04 the header sits beside back', () {
    // Measured as an owner sees it: shoppers get the title alone, owners also
    // get the piece count under it.
    for (final pushed in [true, false]) {
      for (final (label, scaler) in const [
        ('x1.0', TextScaler.noScaling),
        ('x2.0', TextScaler.linear(2)),
      ]) {
        final route = pushed ? 'with BackButton' : 'as root route';

        testWidgets(
          'UI-CAT-04 title and count align beside the back arrow '
          '($route, $label)',
          (tester) async {
            _setView(tester, const Size(390, 844));
            final errors = _captureErrors();
            await _pump(
              tester,
              _items(6),
              textScaler: scaler,
              pushed: pushed,
              owner: true,
            );

            expect(errors.takeUnexpected(), isEmpty);
            expect(
              find.byKey(const ValueKey('monetta-page-back')),
              findsOneWidget,
            );
            expect(
              _rect(tester, find.text('Productos')).left,
              closeTo(
                _rect(tester, find.byKey(const ValueKey('monetta-page-back')))
                    .right,
                0.5,
              ),
            );
            expect(
              _rect(tester, find.text('6 piezas')).left,
              closeTo(_rect(tester, find.text('Productos')).left, 0.5),
            );
          },
        );

        testWidgets(
          'UI-CAT-04 back left, search and filter right, nothing overlaps '
          'the title ($route, $label)',
          (tester) async {
            _setView(tester, const Size(390, 844));
            final errors = _captureErrors();
            await _pump(
              tester,
              _items(6),
              textScaler: scaler,
              pushed: pushed,
              owner: true,
            );
            final unexpected = errors.takeUnexpected();

            final search = _rect(
              tester,
              find.byKey(const Key('catalog-search-button')),
            );
            final filter = _rect(
              tester,
              find.byKey(const Key('catalog-filter-button')),
            );
            final buttons = [search, filter];
            if (pushed) {
              final back = _rect(
                tester,
                find.byKey(const ValueKey('monetta-page-back')),
              );
              expect(back.left, lessThan(60));
              buttons.add(back);
            }
            expect(filter.right, greaterThanOrEqualTo(380));
            expect(search.right, lessThanOrEqualTo(filter.left + 0.01));

            for (final text in ['Productos', '6 piezas']) {
              final rect = _rect(tester, find.text(text));
              for (final button in buttons) {
                expect(
                  rect.overlaps(button),
                  isFalse,
                  reason: '"$text" $rect overlaps a header button $button',
                );
              }
            }
            expect(unexpected, isEmpty);
          },
        );
      }
    }
  });

  group('UI-CAT-05 the filter icon is its own drawing', () {
    final button = find.byKey(const Key('catalog-filter-button'));

    testWidgets('UI-CAT-05 the button no longer uses the tune glyph',
        (tester) async {
      _setView(tester, const Size(390, 844));
      await _pump(tester, _items(6));

      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.tune_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('UI-CAT-05 it holds a painted icon between 24 and 26 pt',
        (tester) async {
      _setView(tester, const Size(390, 844));
      await _pump(tester, _items(6));

      final painted = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter != null,
        ),
      );
      // The button's own ink layers may paint too; one of the painted
      // widgets must be the 24-26 pt icon.
      final sizes = [
        for (var i = 0; i < painted.evaluate().length; i++)
          tester.getSize(painted.at(i)),
      ];
      expect(
        sizes.any(
          (size) =>
              size.width >= 24 &&
              size.width <= 26 &&
              size.height >= 24 &&
              size.height <= 26,
        ),
        isTrue,
        reason: 'painted sizes found inside the filter button: $sizes',
      );
    });

    testWidgets(
      'UI-CAT-05 the button keeps its 48 pt target, tooltip, panel and count '
      '(holds today and after)',
      (tester) async {
        _setView(tester, const Size(800, 1600), dpr: 1);
        await _pump(tester, [
          _monetta(1),
          browseEntry(2, title: 'Bolsa de mano 2', category: 'bolsa'),
        ]);

        final size = tester.getSize(button);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(find.byTooltip('Filtrar y ordenar'), findsOneWidget);
        expect(find.byKey(const Key('catalog-filter-count')), findsNothing);

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('catalog-filter-apply')), findsOneWidget);

        await tester.tap(find.byKey(const Key('catalog-filter-type')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Bolsa de mano'));
        await tester.tap(find.text('Bolsa de mano'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('catalog-filter-apply')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('catalog-filter-count')), findsOneWidget);
      },
    );
  });
}
