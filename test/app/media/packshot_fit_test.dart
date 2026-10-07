// UI-CAT-06: the packshot fit rule, the image widget that applies it, and the
// edge-to-edge variant of the shared tile. All of this API is new, so the file
// does not compile until the redesign lands.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/product_tile.dart';

/// Frame of an edge-to-edge photo at 390 pt: 193 pt wide, 4:5.
const _frame = Size(193, 241.25);

/// A pre-decoded image served synchronously, so no network or codec is
/// involved.
class _TestImageProvider extends ImageProvider<_TestImageProvider> {
  const _TestImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_TestImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_TestImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _TestImageProvider key,
    ImageDecoderCallback decode,
  ) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
      );
}

/// A scaler that is not a single multiplier; see the caption reserve tests.
class _StepTextScaler extends TextScaler {
  const _StepTextScaler();

  @override
  double scale(double fontSize) =>
      fontSize <= 16 ? fontSize * 2 : fontSize + 16;

  @override
  double get textScaleFactor => 2;
}

Future<ui.Image> _photo(WidgetTester tester, int width, int height) async {
  final image = (await tester.runAsync(
    () => createTestImage(width: width, height: height),
  ))!;
  addTearDown(image.dispose);
  return image;
}

Future<void> _pumpPackshot(WidgetTester tester, ui.Image photo) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _frame.width,
            height: _frame.height,
            child: PackshotImage(image: _TestImageProvider(photo)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _ground() => find.descendant(
      of: find.byType(PackshotImage),
      matching: find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == kPackshotGround,
      ),
    );

const _data = ProductTileData(
  brand: 'Guess',
  title: 'Bolsa Tabby',
  priceLabel: r'$6,490 MXN',
  imageUrls: <String>[],
);

Future<SliverGridDelegateWithFixedCrossAxisCount> _delegate(
  WidgetTester tester, {
  required double availableWidth,
  ProductTileVariant variant = ProductTileVariant.card,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  late SliverGridDelegate delegate;
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Builder(
          builder: (context) {
            delegate = productGridDelegate(
              context,
              availableWidth: availableWidth,
              variant: variant,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return delegate as SliverGridDelegateWithFixedCrossAxisCount;
}

void main() {
  group('UI-CAT-06 packshotFit', () {
    test('UI-CAT-06 covers photos that lose at most 3.3% per side', () {
      for (final (w, h) in const [
        (400.0, 533.0),
        (800.0, 1067.0),
        (400.0, 500.0),
        (400.0, 483.0),
        (400.0, 535.0),
      ]) {
        expect(
          packshotFit(Size(w, h), _frame),
          BoxFit.cover,
          reason: '${w.toInt()}x${h.toInt()} should fill the frame',
        );
      }
    });

    test('UI-CAT-06 contains photos that cover would cut more than that', () {
      for (final (w, h) in const [
        (400.0, 537.0),
        (400.0, 465.0),
        (400.0, 400.0),
        (400.0, 690.0),
        (400.0, 357.0),
      ]) {
        expect(
          packshotFit(Size(w, h), _frame),
          BoxFit.contain,
          reason: '${w.toInt()}x${h.toInt()} must be shown whole',
        );
      }
    });

    test('UI-CAT-06 never covers an empty or non-finite size', () {
      expect(packshotFit(Size.zero, _frame), BoxFit.contain);
      expect(packshotFit(const Size(400, 500), Size.zero), BoxFit.contain);
      expect(packshotFit(const Size(0, 500), _frame), BoxFit.contain);
      expect(packshotFit(const Size(400, 0), _frame), BoxFit.contain);
      expect(
        packshotFit(const Size(double.infinity, 500), _frame),
        BoxFit.contain,
      );
      expect(
        packshotFit(const Size(400, 500), const Size(double.nan, 200)),
        BoxFit.contain,
      );
    });

    test('UI-CAT-06 the threshold is a parameter and defaults to 3.3%', () {
      expect(kPackshotMaxCoverTrim, 0.033);
      // 400x537 trims about 3.44% per side: over the default, within 5%.
      expect(packshotFit(const Size(400, 537), _frame), BoxFit.contain);
      expect(
        packshotFit(const Size(400, 537), _frame, maxCoverTrim: 0.05),
        BoxFit.cover,
      );
    });
  });

  group('UI-CAT-06 PackshotImage', () {
    testWidgets('UI-CAT-06 a 300x400 photo fills the frame with cover',
        (tester) async {
      await _pumpPackshot(tester, await _photo(tester, 300, 400));

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(PackshotImage),
          matching: find.byType(Image),
        ),
      );
      expect(image.fit, BoxFit.cover);
      expect(_ground(), findsNothing);
    });

    testWidgets(
        'UI-CAT-06 a 400x400 photo is shown whole on a white ground the '
        'size of the frame', (tester) async {
      await _pumpPackshot(tester, await _photo(tester, 400, 400));

      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(PackshotImage),
          matching: find.byType(Image),
        ),
      );
      expect(image.fit, BoxFit.contain);
      expect(_ground(), findsOneWidget);
      expect(tester.getSize(_ground()), _frame);
    });
  });

  group('UI-CAT-06 the tile variant', () {
    testWidgets('UI-CAT-06 edge-to-edge tiles trim-cover; cards do not',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: MonettaProductTile(
                  data: _data,
                  onTap: () {},
                  variant: ProductTileVariant.edgeToEdge,
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<MonettaImage>(find.byType(MonettaImage)).maxCoverTrim,
        kPackshotMaxCoverTrim,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 200,
                child: MonettaProductTile(data: _data, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      final card = tester.widget<MonettaImage>(find.byType(MonettaImage));
      expect(card.maxCoverTrim, isNull);
      expect(card.fit, BoxFit.contain);
    });

    test('UI-CAT-06 variant metrics', () {
      expect(ProductTileVariant.card.columnSpacing, 12);
      expect(ProductTileVariant.edgeToEdge.columnSpacing, 4);
      expect(ProductTileVariant.card.rowSpacing, 24);
      expect(ProductTileVariant.edgeToEdge.rowSpacing, 0);
      expect(ProductTileVariant.card.photoInset, 8);
      expect(ProductTileVariant.edgeToEdge.photoInset, 0);
      expect(ProductTileVariant.card.photoRadius, BoutiqueRadius.tile);
      expect(ProductTileVariant.edgeToEdge.photoRadius, BorderRadius.zero);
      expect(ProductTileVariant.card.captionInset, 0);
      expect(ProductTileVariant.edgeToEdge.captionInset, 8);
      expect(ProductTileVariant.card.captionGap, 12);
      expect(ProductTileVariant.edgeToEdge.captionGap, 10);
      expect(ProductTileVariant.card.captionTrailing, 0);
      expect(ProductTileVariant.edgeToEdge.captionTrailing, 28);
      expect(ProductTileVariant.card.lifts, isTrue);
      expect(ProductTileVariant.edgeToEdge.lifts, isFalse);
    });

    test('UI-CAT-06 caption extent', () {
      // 10 + 13*1.25 + 2 + 14*1.3*2 + 4 + 16*1.2 + 28 = 115.85
      expect(
        ProductTileVariant.edgeToEdge.captionExtent(
          ProductTileDensity.grid,
          TextScaler.noScaling,
        ),
        closeTo(115.85, 0.001),
      );
      expect(
        ProductTileVariant.card.captionExtent(
          ProductTileDensity.grid,
          TextScaler.noScaling,
        ),
        112,
      );
    });

    testWidgets('UI-CAT-06 the edge-to-edge delegate: 4 pt, no rows gap',
        (tester) async {
      final delegate = await _delegate(
        tester,
        availableWidth: 390,
        variant: ProductTileVariant.edgeToEdge,
      );
      expect(delegate.crossAxisCount, 2);
      expect(delegate.crossAxisSpacing, 4);
      expect(delegate.mainAxisSpacing, 0);
      expect(delegate.mainAxisExtent, closeTo(357.1, 0.001));
    });

    testWidgets(
        'UI-CAT-06 the edge-to-edge delegate scales each type size on its own',
        (tester) async {
      final delegate = await _delegate(
        tester,
        availableWidth: 390,
        variant: ProductTileVariant.edgeToEdge,
        textScaler: const _StepTextScaler(),
      );
      // brand 13 -> 26, name 14 -> 28, price 16 -> 32 (small type doubles).
      expect(
        delegate.mainAxisExtent,
        closeTo(
          241.25 + 10 + 2 + 4 + 28 + 26 * 1.25 + 28 * 1.3 * 2 + 32 * 1.2,
          0.001,
        ),
      );
    });

    testWidgets('UI-CAT-06 the card delegate is unchanged', (tester) async {
      final delegate = await _delegate(tester, availableWidth: 350);
      expect(delegate.crossAxisSpacing, 12);
      expect(delegate.mainAxisSpacing, 24);
      expect(delegate.mainAxisExtent, closeTo(169 * 1.25 + 112, 0.001));
    });
  });
}
