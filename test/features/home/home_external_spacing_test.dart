import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/catalog_store.dart';
import 'package:monetta_app/app/external_catalog_config.dart';
import 'package:monetta_app/app/external_catalog_controller.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_cache.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_client.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_models.dart';
import 'package:monetta_app/data/external_catalog/external_catalog_repository.dart';
import 'package:monetta_app/data/local/database.dart';
import 'package:monetta_app/features/home/external_catalog_section.dart';
import 'package:monetta_app/features/home/home_screen.dart';
import 'package:monetta_app/main.dart';

class _StaticCache implements ExternalCatalogCache {
  const _StaticCache(this.snapshot);

  final CachedExternalCatalog snapshot;

  @override
  Future<CachedExternalCatalog?> load() async => snapshot;

  @override
  Future<void> save(CachedExternalCatalog snapshot) async {}
}

class _NotModifiedClient implements ExternalCatalogClient {
  const _NotModifiedClient();

  @override
  Future<ExternalCatalogFetchResult> fetch({String? etag}) async =>
      const ExternalCatalogFetchResult.notModified();
}

ExternalCatalogResponse _externalResponse() => ExternalCatalogResponse(
      schemaVersion: 1,
      generatedAt: DateTime.utc(2026, 8, 31),
      sources: const [],
      items: [
        {
          'sourceScopedId': 'coach_us:CU068',
          'source': 'coach_us',
          'merchant': 'Coach',
          'title': 'Brooklyn Shoulder Bag 28',
          'brand': 'Coach',
          'category': 'Handbags',
          'imageUrl': null,
          'price': {'amount': 295, 'currency': 'USD'},
          'availability': 'inStock',
          'detailUrl':
              'https://www.coach.com/products/brooklyn-shoulder-bag-28/CU068.html',
          'vertical': 'bags_wallets',
          'lastObservedAt': '2026-08-31T12:00:00.000Z',
        },
      ],
    );

void main() {
  testWidgets('US selection keeps the standard Home section spacing', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = CatalogStore(database: openTestDatabase());
    addTearDown(store.dispose);
    await store.loadFromAsset();

    final response = _externalResponse();
    final repository = ExternalCatalogRepository(
      enabled: true,
      client: const _NotModifiedClient(),
      cache: _StaticCache(
        CachedExternalCatalog(etag: '"fixture"', response: response),
      ),
    );
    await repository.loadCache();
    final external = ExternalCatalogController(
      config: const ExternalCatalogConfig(
        enabled: true,
        baseUrl: 'https://catalog.example.test',
      ),
      repository: repository,
    );
    addTearDown(external.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StoreScope(
          notifier: store,
          child: ExternalCatalogScope(
            notifier: external,
            child: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final offers = find.byKey(const ValueKey('home-section-offers'));
    final externalSection = find.byType(ExternalCatalogSection);
    expect(offers, findsOneWidget);
    expect(externalSection, findsOneWidget);

    final gap =
        tester.getTopLeft(externalSection).dy - tester.getBottomLeft(offers).dy;
    expect(gap, closeTo(72, .1));
  });
}
