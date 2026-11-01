import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/home_content_controller.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/reviews/loox_reviews_repository.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/about/about_monetta_screen.dart';
import 'package:monetta_app/features/home/customer_experiences_section.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/features/partner/partner_hub_screen.dart';
import 'package:monetta_app/main.dart';

void main() {
  testWidgets(
      'the brands grid shows the catalog brands with their logo artwork', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final brandsSection = find.byKey(
      const ValueKey('home-section-brands'),
    );
    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      brandsSection,
      700,
      scrollable: homeScroll,
    );
    await tester.pump();

    // All twelve configured brands, each with its bundled logo, including
    // those the bundled catalog has no product of yet (Rhode, Olaplex...).
    for (final brand in HomeContent.fallback.brands) {
      expect(
        find.byKey(ValueKey('home-brand-${brand.handle}')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: brandsSection,
        matching: find.byType(SlideTransition),
      ),
      findsNWidgets(12),
    );
    expect(
      find.byKey(const ValueKey('home-brand-entrance-coach')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-brand-entrance-michael-kors')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: brandsSection, matching: find.byType(Image)),
      findsNWidgets(12),
    );
  });

  testWidgets(
      'Colecciones sits between Compra por estilo and the brands, opening on '
      'its first photo card', (tester) async {
    // Tall enough for the whole opening to be built at once.
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final section = find.byKey(const ValueKey('home-section-collections'));
    final styles = find.byKey(const ValueKey('home-section-bag-types'));
    final brands = find.byKey(const ValueKey('home-section-brands'));
    expect(
      tester.getTopLeft(section).dy,
      greaterThan(tester.getTopLeft(styles).dy),
    );
    expect(
      tester.getTopLeft(brands).dy,
      greaterThan(tester.getBottomLeft(section).dy),
    );

    // Changed with the web-parity pass: the track opens on the FIRST card,
    // «Bolsas», as the live web does (it used to open on the middle one).
    // It is centred and drawn full size.
    final first = find.byKey(const ValueKey('home-collection-card-guess'));
    expect(tester.getCenter(first).dx, closeTo(195, 1));
    // The web's card is 56% of the viewport (capped at 270): 218.4 at 390.
    expect(tester.getSize(first).width, closeTo(390 * .56, .5));
    expect(
      find.descendant(of: first, matching: find.text('Bolsas')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.text('VER COLECCIÓN')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: first, matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets(
      'home no longer shows Más sobre Monetta, even when the section order lists about',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();
    // The fallback content still lists the about section; Inicio must skip it.
    expect(HomeContent.fallback.sectionOrder, contains(HomeSectionId.about));

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    // Walk the whole page in small steps and check every lazily built slice,
    // so a card that scrolls out of the tree cannot hide from the assertions.
    void expectNoAbout() {
      expect(find.byKey(const ValueKey('home-about-card')), findsNothing);
      expect(find.byKey(const ValueKey('home-about-image')), findsNothing);
      expect(find.text('Más sobre Monetta'), findsNothing);
      expect(find.text('Conoce nuestra historia'), findsNothing);
    }

    final position = tester.state<ScrollableState>(homeScroll).position;
    var sawFooter = false;
    expectNoAbout();
    var previous = -1.0;
    for (var step = 0; step < 200 && position.pixels != previous; step++) {
      previous = position.pixels;
      await tester.drag(homeScroll, const Offset(0, -300));
      await tester.pump();
      expectNoAbout();
      sawFooter = sawFooter ||
          find
              .byKey(const ValueKey('client-guide-footer'))
              .evaluate()
              .isNotEmpty;
    }
    final atEnd = position.pixels == position.maxScrollExtent;
    expect(atEnd, isTrue, reason: 'the walk reached the end of the page');
    expect(sawFooter, isTrue, reason: 'the walk passed through the footer');
  });

  testWidgets('the home footer Nuestra historia still opens the story screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    final footerStory = find.descendant(
      of: find.byKey(const ValueKey('client-guide-footer')),
      matching: find.text('Nuestra historia'),
    );
    await tester.scrollUntilVisible(footerStory, 600, scrollable: homeScroll);
    await tester.pumpAndSettle();
    await tester.tap(footerStory);
    await tester.pumpAndSettle();
    expect(find.byType(AboutMonettaScreen), findsOneWidget);
  });

  testWidgets('home exposes the reseller hub without a new nav tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    // «Más sobre Monetta» left Inicio, so the hub is reached through the
    // footer's «Nuestra historia» and the story's «CONOCER EL PROGRAMA».
    final footerStory = find.descendant(
      of: find.byKey(const ValueKey('client-guide-footer')),
      matching: find.text('Nuestra historia'),
    );
    await tester.scrollUntilVisible(footerStory, 600, scrollable: homeScroll);
    await tester.pumpAndSettle();
    await tester.tap(footerStory);
    await tester.pumpAndSettle();
    final partnerButton = find.byKey(const ValueKey('about-open-partner'));
    await tester.scrollUntilVisible(
      partnerButton,
      400,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('about-monetta-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(partnerButton);
    await tester.pumpAndSettle();
    expect(find.byType(PartnerHubScreen), findsOneWidget);
  });

  testWidgets('experiencias de clientes sit after social on the home',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Nuestras redes'),
      700,
      scrollable: homeScroll,
    );
    await tester.pump();
    final socialOffset =
        tester.state<ScrollableState>(homeScroll).position.pixels;

    await tester.scrollUntilVisible(
      find.text('Experiencias de clientes'),
      700,
      scrollable: homeScroll,
    );
    await tester.pump();
    final experiencesOffset =
        tester.state<ScrollableState>(homeScroll).position.pixels;

    expect(find.byType(CustomerExperiencesSection), findsOneWidget);
    expect(experiencesOffset, greaterThan(socialOffset));
    expect(
      HomeContent.fallback.sectionOrder.last,
      HomeSectionId.testimonials,
    );
  });

  testWidgets('home updates experiencias when live reviews arrive',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    var payload = '{"data":{"agg":{"reviews":[]}}}';
    final home = HomeContentController(
      reviewsRepository: LooxReviewsRepository(
        config: const LooxConfig(publicStoreId: 'public-store'),
        get: (uri) async {
          if (uri.path.contains('dynamic-carousel/reviews')) {
            return http.Response(payload, 200);
          }
          return http.Response('', 404);
        },
      ),
    );
    addTearDown(home.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: HomeContentScope(
            notifier: home,
            child: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await home.refresh();
    await tester.pump();

    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Experiencias de clientes'),
      700,
      scrollable: homeScroll,
    );
    expect(find.text('Gaby E.'), findsNothing);

    payload = '''
    {
      "data": {
        "agg": {
          "reviews": [
            {
              "rating": 5,
              "reviewer": "Gaby E.",
              "review": "Me encanta que todo sea 100% original.",
              "verified": true,
              "midImage": "https://images.loox.io/gaby.jpg"
            }
          ]
        }
      }
    }
    ''';
    await home.refresh();
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Gaby E.'),
      400,
      scrollable: homeScroll,
    );
    expect(find.text('Gaby E.'), findsWidgets);
  });
}
