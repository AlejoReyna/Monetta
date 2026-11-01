/// Home «Colecciones»: white cards (photo, serif title, grey «VER COLECCIÓN»
/// pill) in a focus carousel on phones and a single row on wide screens, in
/// the opening order style -> brands -> collections -> new arrivals.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/media/monetta_image.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

import '../../support/client_guide_capture.dart';

const _handles = ['guess', 'carteras-1', 'relojes'];

Finder _card(String handle) =>
    find.byKey(ValueKey('home-collection-card-$handle'));

Finder _pill(String handle) =>
    find.byKey(ValueKey('home-collection-button-$handle'));

Finder _homeScroll() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .first;

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => '/tmp',
    );
    debugMonettaFixtureImage = MemoryImage(
      File('test/support/fixture_product.jpg').readAsBytesSync(),
    );
  });
  tearDown(() => debugMonettaFixtureImage = null);

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(390, 900),
    double textScale = 1,
  }) async {
    final db = openTestDatabase();
    final catalog = CatalogStore(database: db);
    await catalog.loadFromAsset();
    addTearDown(() async {
      catalog.dispose();
      await db.close();
    });
    await pumpClientGuide(
      tester,
      StoreScope(notifier: catalog, child: const HomeScreen()),
      size: size,
      textScale: textScale,
    );
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 300, scrollable: _homeScroll());
    await tester.pumpAndSettle();
  }

  testWidgets('opening order: style, brands, collections, new arrivals', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(390, 4000));

    double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
    final style = top('home-section-bag-types');
    final collections = top('home-section-collections');
    final brands = top('home-section-brands');
    final fresh = top('home-section-new-products');
    expect(style, lessThan(brands));
    expect(brands, lessThan(collections));
    expect(collections, lessThan(fresh));
  });

  testWidgets('three cards with title and pill; tapping either opens it', (
    tester,
  ) async {
    await pumpHome(tester);
    await reveal(tester, _card('carteras-1'));

    for (final card in HomeContent.fallback.collections) {
      expect(
        find.descendant(
          of: _card(card.handle),
          matching: find.text(card.title),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _card(card.handle),
          matching: find.text('VER COLECCIÓN'),
        ),
        findsOneWidget,
      );
      // A 36px visual pill; the whole card is the tap target.
      expect(tester.getSize(_pill(card.handle)).height, 36);
      expect(
        tester.getSize(_card(card.handle)).height,
        greaterThanOrEqualTo(48),
      );
    }

    await tester.tap(_pill('carteras-1'));
    await tester.pumpAndSettle();
    var screen = tester.widget<CollectionScreen>(find.byType(CollectionScreen));
    expect(screen.filter.collectionHandle, 'carteras-1');
    expect(screen.filter.category, 'cartera');
    Navigator.of(tester.element(find.byType(CollectionScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(_card('carteras-1'), warnIfMissed: false);
    await tester.pumpAndSettle();
    screen = tester.widget<CollectionScreen>(find.byType(CollectionScreen));
    expect(screen.filter.collectionHandle, 'carteras-1');
  });

  testWidgets('each card is one button with a single semantic label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpHome(tester);
    await reveal(tester, _card('carteras-1'));

    expect(find.bySemanticsLabel('Ver colección Carteras'), findsOneWidget);
    // The pill and the title do not add semantic nodes of their own.
    expect(find.bySemanticsLabel('VER COLECCIÓN'), findsNothing);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Ver colección Carteras')),
      matchesSemantics(
        label: 'Ver colección Carteras',
        isButton: true,
        hasTapAction: true,
        hasEnabledState: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('phone: the carousel starts on the middle card, in focus', (
    tester,
  ) async {
    await pumpHome(tester);
    await reveal(tester, _card('carteras-1'));

    final left = tester.getRect(_card('guess'));
    final middle = tester.getRect(_card('carteras-1'));
    final right = tester.getRect(_card('relojes'));
    // Centred under the viewport, wider than its peeking neighbours.
    expect(middle.center.dx, closeTo(195, 1));
    expect(middle.width, greaterThan(left.width));
    expect(middle.width, greaterThan(right.width));
    expect(left.width, closeTo(right.width, .5));
    expect(left.width / middle.width, closeTo(.9, .02));
    // Neighbours peek in from both sides.
    expect(left.right, greaterThan(0));
    expect(right.left, lessThan(390));
    // No overflow of the card's own column.
    expect(tester.takeException(), isNull);

    // Swiping moves the focus to the next card.
    await tester.drag(_card('carteras-1'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    final focused = tester.getRect(_card('relojes'));
    expect(focused.center.dx, closeTo(195, 1));
    expect(
        focused.width, greaterThan(tester.getRect(_card('carteras-1')).width));
  });

  testWidgets('wide screens: three equal cards in one row, no carousel', (
    tester,
  ) async {
    await pumpHome(tester, size: const Size(1024, 900));
    await reveal(tester, _card('carteras-1'));

    final rects = [
      for (final handle in _handles) tester.getRect(_card(handle))
    ];
    expect(rects[0].top, rects[1].top);
    expect(rects[1].top, rects[2].top);
    expect(rects[0].width, closeTo(rects[1].width, .1));
    expect(rects[1].width, closeTo(rects[2].width, .1));
    expect(rects[0].right, lessThan(rects[1].left));
    expect(rects[1].right, lessThan(rects[2].left));
    // Row capped at 720 and centred.
    expect(rects[2].right - rects[0].left, lessThanOrEqualTo(720));
    expect((rects[0].left + rects[2].right) / 2, closeTo(512, 1));
  });

  for (final size in const [Size(320, 900), Size(390, 900), Size(1024, 900)]) {
    testWidgets('text scale 2.0 does not overflow the collections at $size', (
      tester,
    ) async {
      await pumpHome(tester, size: size, textScale: 2);
      await reveal(tester, _card('carteras-1'));

      expect(tester.takeException(), isNull);
      for (final handle in _handles) {
        expect(_card(handle), findsOneWidget);
        expect(_pill(handle), findsOneWidget);
      }
      final section = tester.getRect(
        find.byKey(const ValueKey('home-section-collections')),
      );
      final card = tester.getRect(_card('carteras-1'));
      // Room left for the shadow above and below the card.
      expect(card.bottom + 8, lessThanOrEqualTo(section.bottom));
      expect(card.top, greaterThanOrEqualTo(section.top));
    });
  }
}
