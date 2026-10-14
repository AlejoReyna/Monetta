// Characterization of the default product card.
//
// Product cards share a white rounded surface and a small inset photograph.
// The grid reserve includes air beneath the unchanged caption typography.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/app/card_lift.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
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
    'UI-CAT-02 the default tile keeps the framed photo, the clip and the lift',
    (tester) async {
      await tester.pumpWidget(
        _host(MonettaProductTile(data: _data, onTap: () {})),
      );
      await tester.pump();

      final photo = tester.getRect(find.byType(AspectRatio).first);
      expect(photo.width, 200);
      expect(photo.height, closeTo(250, 0.01));

      // The framed photo: 8 pt of ground around the picture on each side.
      final image = tester.getRect(find.byType(MonettaImage));
      expect(image, photo.deflate(8));

      final clips = tester
          .widgetList<ClipRRect>(
            find.descendant(
              of: find.byType(MonettaProductTile),
              matching: find.byType(ClipRRect),
            ),
          )
          .where((clip) => clip.borderRadius == BoutiqueRadius.tile);
      expect(clips, isNotEmpty);

      expect(find.byType(MonettaCardLift), findsOneWidget);

      // Caption: inset 12 pt, with the existing 12 pt gap beneath the photo.
      final brand = tester.getRect(find.text('Guess'));
      expect(brand.left, closeTo(photo.left + 12, 0.01));
      expect(brand.top, closeTo(photo.bottom + 12, 0.01));
    },
  );

  testWidgets(
    'UI-CAT-02 productGridDelegate without extras keeps 12/24 spacing and '
    'the 124 pt caption reserve',
    (tester) async {
      final delegate = await _delegateFor(tester, availableWidth: 350);
      expect(delegate.crossAxisCount, 2);
      expect(delegate.crossAxisSpacing, 12);
      expect(delegate.mainAxisSpacing, 24);
      expect(delegate.mainAxisExtent, closeTo(169 * 1.25 + 124, 0.01));
    },
  );

  testWidgets(
    'UI-CAT-02 productGridDelegate scales the caption reserve linearly',
    (tester) async {
      final delegate = await _delegateFor(
        tester,
        availableWidth: 350,
        textScaler: const TextScaler.linear(2),
      );
      expect(delegate.crossAxisCount, 2);
      expect(delegate.mainAxisExtent, closeTo(169 * 1.25 + 248, 0.01));
    },
  );

  testWidgets(
    'UI-CAT-02 ProductCardGrid keeps 12/24 spacing inside 390 pt',
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
      expect(delegate.crossAxisSpacing, 12);
      expect(delegate.mainAxisSpacing, 24);
      expect(find.byType(ProductCard), findsWidgets);
    },
  );
}
