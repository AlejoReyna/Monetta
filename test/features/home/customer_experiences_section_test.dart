import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/home_content_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/domain/home_content.dart';
import 'package:monetta_app/features/home/customer_experiences_section.dart';

HomeTestimonial _review({
  required String reviewer,
  String body = 'Excelente calidad y envío rápido.',
  int rating = 5,
  String? imageUrl = 'https://images.loox.io/review.jpg',
  String fallbackAsset = 'assets/images/home_review_monse.jpg',
  bool verified = true,
  String? imageAlt,
  String? productName,
}) {
  return HomeTestimonial(
    reviewer: reviewer,
    body: body,
    rating: rating,
    imageUrl: imageUrl,
    fallbackAsset: fallbackAsset,
    verified: verified,
    imageAlt: imageAlt,
    productName: productName,
  );
}

Widget _app({
  required List<HomeTestimonial> testimonials,
  HomeReviewsStatus status = HomeReviewsStatus.live,
  double? average = 4.9,
  int? count = 139,
  Size size = const Size(390, 900),
  bool disableAnimations = false,
  VoidCallback? onSeeMore,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      disableAnimations: disableAnimations,
    ),
    child: MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: size.width,
            child: SingleChildScrollView(
              child: CustomerExperiencesSection(
                testimonials: testimonials,
                status: status,
                average: average,
                count: count,
                onSeeMore: onSeeMore,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  final liveReviews = <HomeTestimonial>[
    _review(
      reviewer: 'Gaby E.',
      body:
          'Me encanta que todo sea 100% original, muy bonitos los bolsos y carteras, súper recomendados para negocio, ya es mi tercer pedido',
      productName: 'Cartera Guess Negra Monograma',
      imageAlt: 'Foto de Cartera Guess Negra Monograma',
    ),
    _review(
      reviewer: 'Guadalupe G.',
      body: 'Mis clientas amaron las bolsas, la calidad viene súper bien.',
      rating: 4,
    ),
    _review(
      reviewer: 'Paty G.',
      body: 'Súper recomendado para emprender.',
    ),
  ];

  testWidgets('renders public reviews from the live carousel model',
      (tester) async {
    await tester.pumpWidget(_app(testimonials: liveReviews));
    await tester.pump();

    expect(find.text('EXPERIENCIAS DE CLIENTES'), findsOneWidget);
    expect(find.text('Gaby E.'), findsWidgets);
    expect(find.textContaining('100% original'), findsOneWidget);
    expect(find.text('139 reseñas'), findsOneWidget);
    expect(find.textContaining('Loox'), findsNothing);
    expect(find.textContaining('API'), findsNothing);
    expect(find.textContaining('fallback'), findsNothing);
    expect(find.textContaining('sync'), findsNothing);
  });

  testWidgets('keeps published order on the first card', (tester) async {
    await tester.pumpWidget(_app(testimonials: liveReviews));
    await tester.pump();

    expect(
      tester.widget<Text>(find.text('Gaby E.').first).data,
      'Gaby E.',
    );
    expect(find.text('Paty G.'), findsNothing);
  });

  testWidgets('shows five home reviews and exposes the full-review action',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var opened = false;
    final reviews = List<HomeTestimonial>.generate(
      7,
      (index) => _review(
        reviewer: 'Cliente $index',
        body: 'Reseña $index',
      ),
    );
    await tester.pumpWidget(
      _app(
        testimonials: reviews,
        onSeeMore: () => opened = true,
      ),
    );
    await tester.pump();

    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('customer-experiences-live-region')),
          )
          .label,
      'Reseña 1 de 5',
    );

    final seeMore = find.byKey(
      const ValueKey('customer-experiences-see-more'),
    );
    await tester.ensureVisible(seeMore);
    await tester.tap(seeMore);
    expect(opened, isTrue);
    semantics.dispose();
  });

  testWidgets('shows a readable star rating', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(testimonials: liveReviews));
    await tester.pump();

    expect(find.byIcon(Icons.star), findsWidgets);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('customer-experiences-stars')),
          )
          .label,
      '5 de 5 estrellas',
    );
    semantics.dispose();
  });

  testWidgets('clamps a long review to the live 200-character window',
      (tester) async {
    final long = 'Hermoso producto. ' * 40;
    await tester.pumpWidget(
      _app(
        testimonials: [
          _review(reviewer: 'Camila F.', body: long),
        ],
      ),
    );
    await tester.pump();

    final text = tester
        .widget<Text>(
          find
              .descendant(
                of: find.byType(CustomerExperiencesSection),
                matching: find.textContaining('Hermoso producto'),
              )
              .first,
        )
        .data!;
    expect(text.length, lessThanOrEqualTo(201));
    expect(text.endsWith('…'), isTrue);
    expect(find.text(long), findsNothing);
  });

  testWidgets('renders a review that has no customer photo', (tester) async {
    await tester.pumpWidget(
      _app(
        testimonials: [
          _review(
            reviewer: 'Rosa O.',
            imageUrl: null,
            fallbackAsset: '',
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Rosa O.'), findsOneWidget);
    expect(find.byType(MonettaWordmark), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is NetworkImage,
      ),
      findsNothing,
    );
  });

  testWidgets('does not load an insecure photo URL', (tester) async {
    await tester.pumpWidget(
      _app(
        testimonials: [
          _review(
            reviewer: 'Natalia C.',
            imageUrl: 'http://images.loox.io/review.jpg',
            fallbackAsset: '',
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Natalia C.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is NetworkImage &&
            (widget.image as NetworkImage).url.startsWith('http://'),
      ),
      findsNothing,
    );
  });

  testWidgets('loading keeps the carousel footprint without live copy',
      (tester) async {
    await tester.pumpWidget(
      _app(
        testimonials: liveReviews,
        status: HomeReviewsStatus.loading,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('customer-experiences-loading')),
      findsOneWidget,
    );
    expect(find.text('Gaby E.'), findsNothing);
    expect(find.text('EXPERIENCIAS DE CLIENTES'), findsOneWidget);
  });

  testWidgets('empty live response keeps the title and no cards',
      (tester) async {
    await tester.pumpWidget(
      _app(
        testimonials: const [],
        status: HomeReviewsStatus.empty,
        average: null,
        count: null,
      ),
    );
    await tester.pump();

    expect(find.text('EXPERIENCIAS DE CLIENTES'), findsOneWidget);
    expect(find.text('Gaby E.'), findsNothing);
    expect(
      find.byKey(const ValueKey('customer-experiences-carousel')),
      findsNothing,
    );
  });

  testWidgets('fallback still shows bundled public testimonials',
      (tester) async {
    await tester.pumpWidget(
      _app(
        testimonials: HomeContent.fallback.testimonials,
        status: HomeReviewsStatus.fallback,
        average: 4.9,
        count: 139,
      ),
    );
    await tester.pump();

    expect(find.text('Monse C.'), findsOneWidget);
    expect(find.textContaining('Loox'), findsNothing);
    expect(find.textContaining('fallback'), findsNothing);
  });

  testWidgets('mobile layout does not overflow', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    FlutterErrorDetails? overflow;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) overflow = details;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      _app(testimonials: liveReviews, size: const Size(390, 844)),
    );
    await tester.pump();

    expect(overflow, isNull);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(CustomerExperiencesSection)).width,
      390,
    );
  });

  testWidgets('wide layout shows two review photos at a time', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      _app(testimonials: liveReviews, size: const Size(1200, 900)),
    );
    await tester.pump();

    expect(find.text('Gaby E.'), findsWidgets);
    expect(
      find.byKey(const ValueKey('customer-experiences-photo-Gaby E.')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('customer-experiences-photo-Guadalupe G.')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('customer-experiences-next')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('customer-experiences-prev')),
      findsOneWidget,
    );
  });

  testWidgets('next control advances the carousel', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      _app(testimonials: liveReviews, size: const Size(1200, 900)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('customer-experiences-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Guadalupe G.'), findsWidgets);
  });

  testWidgets('horizontal swipe advances the carousel on mobile',
      (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      _app(testimonials: liveReviews, size: const Size(390, 844)),
    );
    await tester.pump();

    await tester.fling(
      find.byKey(const ValueKey('customer-experiences-carousel')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('clientas amaron'), findsWidgets);
  });

  testWidgets('exposes accessible labels and a live region', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(testimonials: liveReviews));
    await tester.pump();

    expect(find.text('EXPERIENCIAS DE CLIENTES'), findsOneWidget);
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('customer-experiences-live-region')),
          )
          .label,
      'Reseña 1 de 3',
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('customer-experiences-photo-Gaby E.')),
          )
          .label,
      contains('Foto de Cartera Guess Negra Monograma'),
    );
    expect(find.byTooltip('Reseña anterior'), findsNothing);
    semantics.dispose();
  });

  testWidgets('reduced motion does not autoplay the carousel', (tester) async {
    await tester.pumpWidget(
      _app(
        testimonials: liveReviews,
        disableAnimations: true,
        size: const Size(390, 844),
      ),
    );
    await tester.pump();
    expect(find.textContaining('100% original'), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    expect(find.textContaining('100% original'), findsOneWidget);
    expect(find.textContaining('clientas amaron'), findsNothing);
  });
}
