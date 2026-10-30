// Geometry of the default product card after the «tarjetas y barra»
// redesign: one rounded warm container, a square photograph inside 12 pt of
// padding, the caption under it, 8/8 grid gaps.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/card_lift.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/catalog/product_card.dart';
import 'package:monetta_app/main.dart';

const _data = ProductTileData(
  brand: 'Guess',
  title: 'Bolsa Tabby',
  priceLabel: r'$6,490 MXN',
  imageUrls: <String>[],
);

Widget _host(Widget child) => MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 200, child: child),
        ),
      ),
    );

Future<SliverGridDelegateWithFixedCrossAxisCount> _delegateFor(
  WidgetTester tester, {
  required double availableWidth,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  late SliverGridDelegate delegate;
  // The delegate is built inside a real context, as the screens do.
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Builder(
          builder: (context) {
            delegate = productGridDelegate(
              context,
              availableWidth: availableWidth,
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
  testWidgets(
    'UI-CAT-02 the default tile is one rounded card: square photo inside 12 '
    'pt of padding, the clip and the lift',
    (tester) async {
      await tester.pumpWidget(
        _host(MonettaProductTile(data: _data, onTap: () {})),
      );
      await tester.pump();

      final card = tester.getRect(find.byType(MonettaProductTile));
      expect(card.width, 200);
      final photo = tester.getRect(find.byType(AspectRatio).first);
      expect(photo.width, 176);
      expect(photo.height, closeTo(176, 0.01), reason: 'square photograph');
      expect(photo.left - card.left, 12);
      expect(photo.top - card.top, 12);

      // The photo fills its square: the card's own ground is the frame.
      final image = tester.getRect(find.byType(MonettaImage));
      expect(image, photo);

      final clips = tester
          .widgetList<ClipRRect>(
            find.descendant(
              of: find.byType(MonettaProductTile),
              matching: find.byType(ClipRRect),
            ),
          )
          .where((clip) => clip.borderRadius == BorderRadius.circular(4));
      expect(clips, isNotEmpty);

      expect(find.byType(MonettaCardLift), findsOneWidget);

      // Caption: flush with the photo's left edge, 8 pt below its bottom.
      final brand = tester.getRect(find.text('Guess'));
      expect(brand.left, closeTo(photo.left, 0.01));
      expect(brand.top, closeTo(photo.bottom + 8, 0.01));
    },
  );

  testWidgets(
    'UI-CAT-02 productGridDelegate without extras uses 8/8 spacing and '
    'reserves padding, a square photo, the caption and the pill',
    (tester) async {
      final delegate = await _delegateFor(tester, availableWidth: 350);
      expect(delegate.crossAxisCount, 2);
      expect(delegate.crossAxisSpacing, 8);
      expect(delegate.mainAxisSpacing, 8);
      // tile 171: 12 + 147 photo + caption + 48 pill + 12; the caption is
      // 8 + 2 + 4 + 0.5 allowance + 1.015 * (15*1.25 + 14*1.3*2 + 15*1.2).
      expect(delegate.mainAxisExtent, closeTo(307.747, 0.01));
    },
  );

  testWidgets(
    'UI-CAT-02 productGridDelegate scales the caption reserve with the text',
    (tester) async {
      final delegate = await _delegateFor(
        tester,
        availableWidth: 350,
        textScaler: const TextScaler.linear(2),
      );
      expect(delegate.crossAxisCount, 1);
      // Each type size scales on its own; padding, gaps and the pill do not:
      // 12 + 326 + caption + 48 + 12, the caption being 14.5 + 1.015 * 146.3.
      expect(delegate.mainAxisExtent, closeTo(560.994, 0.01));
    },
  );

  testWidgets(
    'UI-CAT-02 ProductCardGrid uses 8/8 spacing inside 390 pt',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final store = CatalogStore(database: openTestDatabase());
      addTearDown(store.dispose);
      await store.loadFromAsset();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: StoreScope(
            notifier: store,
            child: Scaffold(
              body: SizedBox(
                width: 390,
                child:
                    ProductCardGrid(products: store.products.take(6).toList()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(delegate.crossAxisSpacing, 8);
      expect(delegate.mainAxisSpacing, 8);
      expect(find.byType(ProductCard), findsWidgets);
    },
  );
}
