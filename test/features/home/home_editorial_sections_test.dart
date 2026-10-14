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
  testWidgets('all monetta.mx brands render with their logo artwork', (
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

    expect(find.byKey(const ValueKey('home-brand-coach')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-brand-rhode')), findsOneWidget);
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

  testWidgets('collection cards use full-bleed editorial overlays', (
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

    final card = find.byKey(const ValueKey('home-collection-card-guess'));
    final homeScroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(card, 500, scrollable: homeScroll);
    await tester.pump();
    final cardSize = tester.getSize(card);
    expect(cardSize.width, inInclusiveRange(280, 460));
    expect(cardSize.height, closeTo(cardSize.width / .7, .1));

    final cardBottom = tester.getBottomLeft(card).dy;
    final titleBottom = tester
        .getBottomLeft(find.descendant(of: card, matching: find.text('Bolsas')))
        .dy;
    expect(cardBottom - titleBottom, lessThan(52));
    expect(
      find.descendant(of: card, matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('home exposes the story and reseller hub without a new nav tab', (
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
    await tester.scrollUntilVisible(
      find.text('Conoce nuestra historia'),
      600,
      scrollable: homeScroll,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Conoce nuestra historia')),
      alignment: .35,
    );
    await tester.pumpAndSettle();

    final aboutCard = find.byKey(const ValueKey('home-about-card'));
    final aboutImage = find.byKey(const ValueKey('home-about-image'));
    expect(tester.getSize(aboutCard).width, 350);
    expect(tester.getSize(aboutImage).width, closeTo(133, .01));
    expect(tester.getSize(aboutImage).height, closeTo(172.9, .01));

    await tester.tap(find.text('Conoce nuestra historia'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutMonettaScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Volver').first);
    await tester.pumpAndSettle();
    final partnerButton = find.byKey(const ValueKey('home-open-partner'));
    await tester.scrollUntilVisible(
      partnerButton,
      500,
      scrollable: homeScroll,
    );
    await Scrollable.ensureVisible(
      tester.element(partnerButton),
      alignment: .35,
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
