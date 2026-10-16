import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/editorial_content_controller.dart';
import 'package:monetta_app/app/theme.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/data/shopify/editorial_content_repository.dart';
import 'package:monetta_app/data/shopify/storefront_client.dart';
import 'package:monetta_app/data/shopify/storefront_config.dart';
import 'package:monetta_app/domain/seasonal_campaign.dart';
import 'package:monetta_app/features/boutique/boutique_tokens.dart';
import 'package:monetta_app/features/catalog/collection_screen.dart';
import 'package:monetta_app/features/home/seasonal_banner.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

const String _pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

final Uint8List _pixelBytes = base64Decode(_pixel);

SeasonalCampaign _campaign({String? imageUrl}) {
  return SeasonalCampaign(
    title: 'Nueva temporada',
    tag: 'Otoño',
    subtitle: 'Piezas nuevas',
    ctaText: 'VER COLECCIÓN',
    collectionHandle: 'otono',
    imageUrl: imageUrl,
  );
}

void _view(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

Widget _bannerHarness(SeasonalBanner banner) {
  return MaterialApp(
    theme: buildLightTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: banner,
      ),
    ),
  );
}

class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_FailingImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError('seasonal image failed')),
    );
  }

  @override
  bool operator ==(Object other) => other is _FailingImage;

  @override
  int get hashCode => 0;
}

void main() {
  test('reserved frame is 3:4 on a phone and 16:9 on iPad 13', () {
    expect(seasonalBannerHeightFor(const Size(390, 844)), 520);
    expect(seasonalBannerUsesIpadFrame(const Size(390, 844)), isFalse);
    expect(seasonalBannerHeightFor(const Size(1024, 1366)), 576);
    expect(seasonalBannerUsesIpadFrame(const Size(1024, 1366)), isTrue);
  });

  testWidgets('placeholder is full bleed with the shipped caption', (
    tester,
  ) async {
    _view(tester, const Size(390, 844));
    await tester.pumpWidget(
      _bannerHarness(
        const SeasonalBanner(phase: SeasonalBannerPhase.placeholder),
      ),
    );

    final banner = find.byKey(SeasonalBanner.bannerKey);
    expect(tester.getSize(banner), const Size(390, 520));
    expect(tester.getTopLeft(banner).dx, 0);
    expect(find.text(kSeasonalPlaceholderCaption), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-seasonal-placeholder')),
      findsOneWidget,
    );
    expect(find.byType(ClipRRect), findsNothing);
    expect(find.byIcon(Icons.broken_image), findsNothing);
    expect(
      tester.widget<Text>(find.text('M')).style!.color!.a,
      closeTo(1, 0.01),
    );
    expect(
      tester.widget<Opacity>(find.byType(Opacity)).opacity,
      0.15,
    );
  });

  testWidgets('hidden banner takes no space', (tester) async {
    _view(tester, const Size(390, 844));
    await tester.pumpWidget(
      _bannerHarness(
        const SeasonalBanner(phase: SeasonalBannerPhase.hidden),
      ),
    );

    expect(tester.getSize(find.byKey(SeasonalBanner.bannerKey)).height, 0);
    expect(find.text(kSeasonalPlaceholderCaption), findsNothing);
  });

  testWidgets('loading and loaded share the reserved height', (tester) async {
    _view(tester, const Size(390, 844));
    await tester.pumpWidget(
      _bannerHarness(
        const SeasonalBanner(phase: SeasonalBannerPhase.loading),
      ),
    );
    expect(find.byKey(const ValueKey('home-seasonal-shimmer')), findsOneWidget);
    expect(find.text(kSeasonalPlaceholderCaption), findsNothing);
    final loadingHeight =
        tester.getSize(find.byKey(SeasonalBanner.bannerKey)).height;

    var opened = 0;
    await tester.pumpWidget(
      _bannerHarness(
        SeasonalBanner(
          phase: SeasonalBannerPhase.ready,
          campaign: _campaign(),
          imageOverride: MemoryImage(_pixelBytes),
          onOpenCollection: (_) => opened++,
        ),
      ),
    );
    // Image codecs run outside the test's fake async zone.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(
      tester.getSize(find.byKey(SeasonalBanner.bannerKey)).height,
      loadingHeight,
    );
    expect(find.byKey(const ValueKey('home-seasonal-image')), findsOneWidget);
    expect(find.text('Nueva temporada'), findsOneWidget);
    expect(find.text('OTOÑO'), findsOneWidget);
    expect(find.text('Piezas nuevas'), findsOneWidget);
    expect(find.text('VER COLECCIÓN →'), findsOneWidget);
    expect(find.text(kSeasonalPlaceholderCaption), findsNothing);
    expect(find.byIcon(Icons.broken_image), findsNothing);

    final title = tester.widget<Text>(find.text('Nueva temporada'));
    expect(title.style!.fontFamily, kEditorialFontFamily);
    expect(title.style!.fontSize, 32);
    expect(title.textAlign, TextAlign.left);
    expect(title.maxLines, 2);
    final tag = tester.widget<Text>(find.text('OTOÑO'));
    expect(tag.style!.fontFamily, kBoutiqueSansFamily);
    expect(tag.style!.fontSize, 12);
    expect(tag.style!.letterSpacing, 2);
    final subtitle = tester.widget<Text>(find.text('Piezas nuevas'));
    expect(subtitle.style!.fontSize, 15);
    expect(subtitle.style!.color!.a, closeTo(0.85, 0.02));
    expect(subtitle.maxLines, 2);

    await tester.tap(find.byKey(SeasonalBanner.bannerKey));
    expect(opened, 1);
  });

  testWidgets('a failed image keeps the placeholder and the campaign title', (
    tester,
  ) async {
    _view(tester, const Size(390, 844));
    await tester.pumpWidget(
      _bannerHarness(
        SeasonalBanner(
          phase: SeasonalBannerPhase.ready,
          campaign: _campaign(imageUrl: 'https://cdn.example/missing.jpg'),
          imageOverride: const _FailingImage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    while (tester.takeException() != null) {}

    expect(
      find.byKey(const ValueKey('home-seasonal-placeholder')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-seasonal-image')), findsNothing);
    expect(find.text('Nueva temporada'), findsOneWidget);
    expect(find.byIcon(Icons.broken_image), findsNothing);
  });

  testWidgets('iPad 13 reserves 16:9 and keeps the type left aligned', (
    tester,
  ) async {
    _view(tester, const Size(1024, 1366));
    await tester.pumpWidget(
      _bannerHarness(
        SeasonalBanner(
          phase: SeasonalBannerPhase.ready,
          campaign: _campaign(),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(SeasonalBanner.bannerKey)),
      const Size(1024, 576),
    );
    final title = tester.widget<Text>(find.text('Nueva temporada'));
    expect(title.textAlign, TextAlign.left);
    expect(title.style!.fontSize, 36);
  });

  testWidgets('home shows the placeholder when no source is configured', (
    tester,
  ) async {
    _view(tester, const Size(390, 9000));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: StoreScope(notifier: store, child: const HomeScreen()),
      ),
    );
    await tester.pump();

    final banner = find.byKey(SeasonalBanner.bannerKey);
    expect(banner, findsOneWidget);
    expect(find.text(kSeasonalPlaceholderCaption), findsOneWidget);
    expect(tester.getSize(banner).height, 520);
    expect(tester.getTopLeft(banner).dx, 0);
    expect(tester.getTopLeft(banner).dx + tester.getSize(banner).width, 390);
    final collections = find.byKey(const ValueKey('home-section-collections'));
    expect(collections, findsOneWidget);
    expect(
      tester.getTopLeft(banner).dy,
      greaterThan(tester.getBottomLeft(collections).dy),
    );
  });

  testWidgets('a configured source with no live campaign leaves no gap', (
    tester,
  ) async {
    _view(tester, const Size(390, 9000));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();
    final controller = EditorialContentController(
      repository: EditorialContentRepository(
        client: StorefrontClient(
          config: const StorefrontConfig(
            shopDomain: 'shop.example.com',
            accessToken: 'public-token',
          ),
          transport: (_, __, ___) async => <String, dynamic>{
            'data': <String, dynamic>{
              'about': null,
              'partner': null,
              'catalogs': null,
            },
          },
        ),
      ),
      now: () => DateTime.utc(2026, 10, 14),
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: EditorialContentScope(
          notifier: controller,
          child: StoreScope(notifier: store, child: const HomeScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(SeasonalBanner.bannerKey), findsNothing);
    expect(find.text(kSeasonalPlaceholderCaption), findsNothing);
    final collections = tester.getRect(
      find.byKey(const ValueKey('home-reveal-collections')),
    );
    final next = tester.getRect(
      find.byKey(const ValueKey('home-reveal-todaysPicks')),
    );
    expect(next.top - collections.bottom, inInclusiveRange(24, 40));
  });

  testWidgets('a live campaign opens its Shopify collection', (tester) async {
    _view(tester, const Size(390, 9000));
    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();
    final controller = EditorialContentController(
      repository: EditorialContentRepository(
        client: StorefrontClient(
          config: const StorefrontConfig(
            shopDomain: 'shop.example.com',
            accessToken: 'public-token',
          ),
          transport: (_, __, ___) async => <String, dynamic>{
            'data': <String, dynamic>{
              'about': null,
              'partner': null,
              'catalogs': null,
              'seasonalBanners': <String, dynamic>{
                'edges': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'node': <String, dynamic>{
                      'handle': 'otono-2026',
                      'fields': <Map<String, dynamic>>[
                        <String, dynamic>{
                          'key': 'title',
                          'value': 'Nueva temporada',
                        },
                        <String, dynamic>{
                          'key': 'tag',
                          'value': 'Otoño',
                        },
                        <String, dynamic>{
                          'key': 'ctaText',
                          'value': 'VER COLECCIÓN',
                        },
                        <String, dynamic>{
                          'key': 'collectionId',
                          'value': 'otono',
                        },
                        <String, dynamic>{
                          'key': 'startsAt',
                          'value': '2026-09-01T00:00:00Z',
                        },
                        <String, dynamic>{
                          'key': 'endsAt',
                          'value': '2026-12-01T00:00:00Z',
                        },
                      ],
                    },
                  },
                ],
              },
            },
          },
        ),
      ),
      now: () => DateTime.utc(2026, 10, 14),
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: EditorialContentScope(
          notifier: controller,
          child: StoreScope(notifier: store, child: const HomeScreen()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Nueva temporada'), findsOneWidget);
    expect(find.text('VER COLECCIÓN →'), findsOneWidget);
    await tester.tap(find.byKey(SeasonalBanner.bannerKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CollectionScreen), findsOneWidget);
  });
}
