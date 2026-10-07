// Target-state tests for the edge-to-edge catalog screen (UI-CAT-01, 03, 04,
// 05). They use only API that exists today, so they compile now and fail on
// assertions until the redesign lands.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/card_lift.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/domain/catalog_item.dart';
import 'package:monetta_app/features/catalog/catalog_browse_screen.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';

const _longName =
    'Bolso Michael Kors Marilyn Medium Signature Convertible Satchel Crossbody';
const _price = Money(amount: 11624, currency: Currency.mxn);
const _priceLabel = r'$11,624 MXN';

CatalogItem _monetta(
  int i, {
  String? title,
  Money price = const Money(amount: 1999, currency: Currency.mxn),
}) =>
    CatalogItem(
      sourceScopedId: 'monetta:$i',
      source: CatalogSourceType.monettaShopify,
      merchant: 'Monetta',
      title: title ?? 'Monetta Item $i',
      brand: 'Guess',
      category: null,
      imageUrl: null,
      price: price,
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://monetta.mx/products/item-$i',
      marketRestriction: MarketRestriction.mexico,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.monettaCheckout,
      shopifyProductId: '$i',
      vertical: CatalogVertical.general,
    );

CatalogItem _external(int i) => CatalogItem(
      sourceScopedId: 'coach_us:$i',
      source: CatalogSourceType.coachUs,
      merchant: 'Coach',
      title: 'External Item $i',
      brand: 'Coach',
      category: 'Handbags',
      imageUrl: null,
      price: const Money(amount: 300, currency: Currency.usd),
      availability: CatalogAvailability.inStock,
      detailUrl: 'https://www.coach.com/products/item-$i/C$i.html',
      marketRestriction: MarketRestriction.unitedStates,
      lastObservedAt: DateTime.utc(2026, 8, 10),
      purchaseMode: PurchaseMode.externalResearch,
    );

List<CatalogItem> _items(int count, {String? title, Money? price}) => [
      for (var i = 1; i <= count; i++)
        _monetta(
          i,
          title: title,
          price: price ?? const Money(amount: 1999, currency: Currency.mxn),
        ),
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

/// Layout errors raised while a test runs, minus the one known defect that
/// does not belong to this screen: the bottom bar's destination column
/// overflows by 4-18 pt from text scale 1.3 up (`monetta_bottom_navigation.dart`
/// builds a 52 pt column). It predates this redesign and would otherwise turn
/// every enlarged-text test red for a reason the redesign cannot touch.
class _ErrorLog {
  _ErrorLog._(this._original) {
    FlutterError.onError = (details) {
      // Described right away: once the tree is torn down the creator chain
      // can no longer be read.
      final description = details.toDiagnosticsNode().toStringDeep();
      if (!description.contains('monetta_bottom_navigation.dart')) {
        _unexpected.add(details.exceptionAsString());
      }
    };
  }

  final void Function(FlutterErrorDetails)? _original;
  final List<String> _unexpected = [];

  /// Restores the framework's handler (it must be back in place before any
  /// `expect`, or a failing expectation is swallowed) and returns the errors
  /// that are not the known bottom-bar defect.
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

Future<void> _pump(
  WidgetTester tester,
  List<CatalogItem> items, {
  TextScaler? textScaler,
  bool pushed = false,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
      home: pushed
          ? const Scaffold(body: SizedBox.shrink())
          : CatalogBrowseScreen(items: items),
    ),
  );
  if (pushed) {
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => CatalogBrowseScreen(items: items),
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
  group('UI-CAT-01 the grid runs edge to edge', () {
    testWidgets(
      'UI-CAT-01 at 390 pt: two 193 pt columns, 4 pt apart, no row gap',
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
        expect(photo[0].width, closeTo(193, 0.01));
        expect(photo[0].height, closeTo(241.25, 0.01));
        expect(photo[1].left, closeTo(197, 0.01));
        expect(photo[1].right, closeTo(390, 0.01));
        expect(photo[1].width, closeTo(193, 0.01));
        expect(photo[1].top, closeTo(photo[0].top, 0.01));

        // Row 2 is aligned with itself and one full tile further down:
        // 241.25 photo + 115.85 caption, with no extra space between rows.
        expect(photo[3].top, closeTo(photo[2].top, 0.01));
        expect(photo[2].left, closeTo(0, 0.01));
        expect(photo[2].top - photo[0].top, closeTo(357.1, 0.01));
      },
    );

    testWidgets(
      'UI-CAT-01 tiles carry no card: no lift, no clip, no photo inset',
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
            findsNothing,
            reason: 'tile $i must not clip its photo into a rounded card',
          );
          final image = _rect(
            tester,
            find.descendant(of: tile, matching: find.byType(MonettaImage)),
          );
          expect(image, _rect(tester, _photoOf(tile)), reason: 'tile $i');
        }
      },
    );

    testWidgets(
      'UI-CAT-01 caption sits 8 pt in from the photo and 10 pt below it',
      (tester) async {
        _setView(tester, const Size(390, 844));
        await _pump(tester, _items(6));

        final tile = find.byType(MonettaProductTile).first;
        final photo = _rect(tester, _photoOf(tile));
        final brand = _rect(tester, _brandOf(tile));
        final name = _rect(tester, _nameOf(tile));

        expect(brand.left, closeTo(photo.left + 8, 0.01));
        expect(name.left, closeTo(photo.left + 8, 0.01));
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
          final tileWidth = (width - 4.0 * (columns - 1)) / columns;
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

  group('UI-CAT-04 the header is centred', () {
    for (final pushed in [true, false]) {
      for (final (label, scaler) in const [
        ('x1.0', TextScaler.noScaling),
        ('x2.0', TextScaler.linear(2)),
      ]) {
        final route = pushed ? 'with BackButton' : 'as root route';

        testWidgets(
          'UI-CAT-04 title and count are centred on the screen '
          '($route, $label)',
          (tester) async {
            _setView(tester, const Size(390, 844));
            final errors = _captureErrors();
            await _pump(
              tester,
              _items(6),
              textScaler: scaler,
              pushed: pushed,
            );

            expect(errors.takeUnexpected(), isEmpty);
            expect(
              find.byType(BackButton),
              pushed ? findsOneWidget : findsNothing,
            );
            expect(
              _rect(tester, find.text('Productos')).center.dx,
              closeTo(195, 0.5),
            );
            expect(
              _rect(tester, find.text('6 piezas')).center.dx,
              closeTo(195, 0.5),
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
              final back = _rect(tester, find.byType(BackButton));
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
        await _pump(tester, [_monetta(1), _external(1)]);

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
