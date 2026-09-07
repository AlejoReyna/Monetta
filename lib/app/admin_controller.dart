/// State and mutation routing for the in-app owner panel.
library;

import 'package:flutter/foundation.dart';

import '../data/admin/admin_client.dart';
import '../domain/admin_control.dart';
import '../domain/product.dart';
import 'admin_config.dart';

class AdminController extends ChangeNotifier {
  AdminController({
    required this.config,
    AdminClient? client,
    Future<void> Function()? refreshApp,
  })  : _client = client,
        _refreshApp = refreshApp;

  final AdminConfig config;
  final AdminClient? _client;
  final Future<void> Function()? _refreshApp;

  List<AdminProductRecord> products = const [];
  AdminStorefrontSettings storefront = AdminStorefrontSettings.defaults;
  List<AdminSourcePolicy> sources = const [];
  List<AdminAuditEvent> audit = const [];
  AdminFeaturedCatalog? featuredCatalog;
  final Set<String> featuredPendingProductIds = <String>{};
  String? auditCursor;
  bool loadingAudit = false;
  String? productsCursor;
  bool loadingMoreProducts = false;
  AdminProductsPageMeta? productsMeta;
  String? productSearchQuery;

  /// Server capabilities from GET /admin/me. Null until resolved in live mode.
  AdminCapabilities? serverCapabilities;
  bool loadingCapabilities = false;

  bool loading = false;
  bool saving = false;
  String? lastError;
  DateTime? lastSyncedAt;

  AdminConnectionMode get mode => config.hasLiveApi && _client != null
      ? AdminConnectionMode.live
      : AdminConnectionMode.preview;

  /// Entry point is driven by `/admin/me` in live mode (F20). Preview is an
  /// explicit design-review flag and must not fake a live owner panel.
  bool canAccess({
    required bool signedIn,
    required String? email,
    String? authProvider,
  }) {
    if (!signedIn) return false;
    if (mode == AdminConnectionMode.live) {
      return serverCapabilities?.openAdmin == true;
    }
    if (config.previewEnabled) return true;
    // Without a live API client, the compile-time email allow-list remains a
    // soft local gate (no server session to resolve).
    if (!config.hasLiveApi) return config.allowsEmail(email);
    return false;
  }

  Future<void> refreshCapabilities() async {
    final client = _client;
    if (mode != AdminConnectionMode.live || client == null) {
      serverCapabilities = null;
      return;
    }
    if (loadingCapabilities) return;
    loadingCapabilities = true;
    try {
      serverCapabilities = await client.fetchMe();
      lastError = null;
    } on Object catch (error) {
      serverCapabilities = const AdminCapabilities.none();
      lastError = _errorMessage(error);
    } finally {
      loadingCapabilities = false;
      notifyListeners();
    }
  }

  Future<void> load({
    required List<Product> appProducts,
  }) async {
    products = appProducts
        .map(
          (product) => AdminProductRecord(
            id: product.id,
            title: product.title,
            imageUrl: product.primaryImage,
            price: product.price,
            inStock: product.isInStock,
            visible: true,
            variantCount: product.variants.length,
            descriptionHtml: product.descriptionHtml,
            updatedAt: product.updatedAt,
            variants: product.variants
                .map(
                  (variant) => AdminProductVariant(
                    id: variant.id,
                    title: variant.title,
                    price: variant.price,
                    compareAtPrice: variant.compareAtPrice,
                    availableForSale: variant.available,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList();
    // External monitor sources retired (WP-02 / F03 / F22).
    sources = const [];
    auditCursor = null;
    lastError = null;
    notifyListeners();

    if (mode != AdminConnectionMode.live) return;
    loading = true;
    notifyListeners();
    try {
      await refreshCapabilities();
      final snapshot = await _client!.fetchSnapshot(query: productSearchQuery);
      if (snapshot.shopifyHealthStatus == null ||
          snapshot.shopifyHealthStatus == 'ready') {
        products = snapshot.products;
        productsMeta = snapshot.productsMeta;
        productsCursor = snapshot.productsMeta?.endCursor;
      }
      storefront = snapshot.storefront;
      if (snapshot.sourcesHealthStatus == null ||
          snapshot.sourcesHealthStatus == 'ready') {
        sources = snapshot.sources;
      }
      final featuredClient = _client;
      if (featuredClient is FeaturedAdminClient) {
        try {
          featuredCatalog = await (featuredClient as FeaturedAdminClient)
              .fetchFeaturedCatalog();
        } on Object {
          // The product panel remains usable when the featured collection is
          // not configured or temporarily unavailable.
        }
      }
      final auditClient = _client;
      if (auditClient is AuditAdminClient) {
        try {
          final page = await (auditClient as AuditAdminClient).fetchAudit();
          audit = page.events;
          auditCursor = page.nextCursor;
        } on Object {
          // Audit degradation must not blank the operational sections.
        }
      }
    } catch (_) {
      lastError = 'No pudimos conectar con el panel. Mostramos los datos '
          'guardados en la app.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> loadFeaturedCatalog() async {
    final client = _client;
    if (mode != AdminConnectionMode.live || client is! FeaturedAdminClient) {
      featuredCatalog ??= AdminFeaturedCatalog(
        eligibleProducts: products,
        selectedProductIds: const [],
        healthStatus: 'unavailable',
      );
      notifyListeners();
      return false;
    }
    final featuredClient = client as FeaturedAdminClient;
    try {
      featuredCatalog = await featuredClient.fetchFeaturedCatalog();
      lastError = null;
      notifyListeners();
      return true;
    } on Object catch (error) {
      lastError = _errorMessage(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setProductFeatured(
    AdminProductRecord product, {
    required bool featured,
  }) async {
    final client = _client;
    final current = featuredCatalog;
    if (client is! FeaturedAdminClient ||
        current?.collectionUpdatedAt == null ||
        featuredPendingProductIds.contains(product.id)) {
      lastError = current?.collectionUpdatedAt == null
          ? 'La colección de Hoy no está configurada.'
          : lastError;
      notifyListeners();
      return false;
    }
    final featuredClient = client as FeaturedAdminClient;
    featuredPendingProductIds.add(product.id);
    lastError = null;
    notifyListeners();
    try {
      featuredCatalog = await featuredClient.setProductFeatured(
        productId: product.id,
        featured: featured,
        expectedCollectionUpdatedAt: current!.collectionUpdatedAt!,
      );
      await _refreshApp?.call();
      lastSyncedAt = DateTime.now();
      return true;
    } on Object catch (error) {
      lastError = _errorMessage(error);
      return false;
    } finally {
      featuredPendingProductIds.remove(product.id);
      notifyListeners();
    }
  }

  Future<bool> replaceFeaturedOrder(List<String> productIds) async {
    final client = _client;
    final current = featuredCatalog;
    if (client is! FeaturedAdminClient ||
        current?.collectionUpdatedAt == null) {
      lastError = 'La colección de Hoy no está configurada.';
      notifyListeners();
      return false;
    }
    final featuredClient = client as FeaturedAdminClient;
    saving = true;
    lastError = null;
    notifyListeners();
    try {
      final result = await featuredClient.replaceFeaturedCatalog(
        productIds: productIds,
        expectedCollectionUpdatedAt: current!.collectionUpdatedAt!,
      );
      if (result.catalog != null) featuredCatalog = result.catalog;
      await _refreshApp?.call();
      lastSyncedAt = DateTime.now();
      return true;
    } on Object catch (error) {
      lastError = _errorMessage(error);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<bool> saveProduct(AdminProductRecord next) async {
    return _mutate(
      action: () async {
        final client = _client;
        AdminProductRecord? existing;
        for (final product in products) {
          if (product.id == next.id) {
            existing = product;
            break;
          }
        }
        if (client is ProductAdminClient && existing != null) {
          final productClient = client as ProductAdminClient;
          next = await productClient.updateProductCanonical(
            before: existing,
            next: next,
          );
        } else {
          await client?.updateProduct(next);
        }
        products = [
          for (final product in products)
            if (product.id == next.id) next else product,
        ];
      },
      description: 'Actualizó ${next.title}',
      channels: const {AdminChannel.shopify, AdminChannel.app},
      refreshAfter: true,
    );
  }

  Future<void> loadMoreAudit() async {
    final client = _client;
    final cursor = auditCursor;
    if (client is! AuditAdminClient || cursor == null || loadingAudit) return;
    loadingAudit = true;
    notifyListeners();
    try {
      final page =
          await (client as AuditAdminClient).fetchAudit(cursor: cursor);
      audit = [...audit, ...page.events].take(50).toList(growable: false);
      auditCursor = page.nextCursor;
    } on Object {
      // Keep the already loaded audit page when the next page is unavailable.
    } finally {
      loadingAudit = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreProducts() async {
    final client = _client;
    final cursor = productsCursor;
    if (mode != AdminConnectionMode.live ||
        client == null ||
        cursor == null ||
        loadingMoreProducts ||
        productsMeta?.hasNextPage != true) {
      return;
    }
    loadingMoreProducts = true;
    notifyListeners();
    try {
      final page = await client.fetchProductsPage(
        cursor: cursor,
        query: productSearchQuery,
        limit: productsMeta?.limit,
      );
      final seen = products.map((p) => p.id).toSet();
      products = [
        ...products,
        for (final product in page.products)
          if (!seen.contains(product.id)) product,
      ];
      productsMeta = AdminProductsPageMeta(
        loadedCount: products.length,
        hasNextPage: page.productsMeta?.hasNextPage ?? false,
        endCursor: page.productsMeta?.endCursor,
        totalCount: page.productsMeta?.totalCount ?? productsMeta?.totalCount,
        query: productSearchQuery,
        limit: page.productsMeta?.limit ?? productsMeta?.limit ?? 50,
      );
      productsCursor = productsMeta?.endCursor;
    } on Object catch (error) {
      lastError = _errorMessage(error);
    } finally {
      loadingMoreProducts = false;
      notifyListeners();
    }
  }

  Future<void> searchProducts(String query) async {
    productSearchQuery = query.trim().isEmpty ? null : query.trim();
    productsCursor = null;
    final client = _client;
    if (mode != AdminConnectionMode.live || client == null) {
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final snapshot = await client.fetchProductsPage(
        query: productSearchQuery,
      );
      products = snapshot.products;
      productsMeta = snapshot.productsMeta;
      productsCursor = snapshot.productsMeta?.endCursor;
      lastError = null;
    } on Object catch (error) {
      lastError = _errorMessage(error);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveStorefront(AdminStorefrontSettings next) async {
    return _mutate(
      action: () async {
        final client = _client;
        if (client is StorefrontAdminClient) {
          storefront = await (client as StorefrontAdminClient)
              .updateStorefrontCanonical(next);
        } else {
          await client?.updateStorefront(next);
          storefront = next.copyWith(version: next.version + 1);
        }
      },
      description: 'Actualizó la portada de la tienda',
      channels: const {AdminChannel.shopify, AdminChannel.app},
      // F23: shopper HomeContent (and catalog) must refresh after content writes.
      refreshAfter: true,
    );
  }

  Future<bool> saveSource(AdminSourcePolicy next) async {
    return _mutate(
      action: () async {
        final client = _client;
        if (client is ExternalSourceAdminClient) {
          next = await (client as ExternalSourceAdminClient)
              .updateSourceCanonical(next);
        } else {
          await client?.updateSource(next);
        }
        sources = [
          for (final source in sources)
            if (source.id == next.id) next else source,
        ];
      },
      description: 'Actualizó la fuente ${next.merchant}',
      channels: const {AdminChannel.app},
      refreshAfter: true,
    );
  }

  Future<bool> syncAll() async {
    return _mutate(
      action: () async {
        await _client?.syncAll();
      },
      description: 'Sincronizó catálogo e inventario',
      channels: const {
        AdminChannel.shopify,
        AdminChannel.app,
      },
      refreshAfter: true,
    );
  }

  Future<bool> _mutate({
    required Future<void> Function() action,
    required String description,
    required Set<AdminChannel> channels,
    bool refreshAfter = false,
  }) async {
    if (saving) return false;
    saving = true;
    lastError = null;
    notifyListeners();
    try {
      await action();
      if (refreshAfter && mode == AdminConnectionMode.live) {
        await _refreshApp?.call();
      }
      lastSyncedAt = DateTime.now();
      audit = [
        AdminAuditEvent(
          description: description,
          channels: channels,
          createdAt: lastSyncedAt!,
          previewOnly: mode == AdminConnectionMode.preview,
        ),
        ...audit,
      ].take(12).toList();
      return true;
    } catch (error) {
      if (error is AdminClientException && error.statusCode == 409) {
        await _reloadCanonicalState();
      }
      lastError = _errorMessage(error);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  String _errorMessage(Object error) {
    if (error is AdminClientException && error.requestId != null) {
      if (error.code == 'STALE_RESOURCE') {
        return 'El recurso cambió; revisa el valor actual (${error.requestId}).';
      }
      return 'No se guardó el cambio (${error.requestId}).';
    }
    if (error is AdminClientException && error.code == 'STALE_RESOURCE') {
      return 'El recurso cambió; revisa el valor actual.';
    }
    return 'No se guardó el cambio. Revisa tu conexión e inténtalo de nuevo.';
  }

  Future<void> _reloadCanonicalState() async {
    final client = _client;
    if (client == null) return;
    try {
      final snapshot = await client.fetchSnapshot();
      if (snapshot.shopifyHealthStatus == null ||
          snapshot.shopifyHealthStatus == 'ready') {
        products = snapshot.products;
      }
      storefront = snapshot.storefront;
      if (snapshot.sourcesHealthStatus == null ||
          snapshot.sourcesHealthStatus == 'ready') {
        sources = snapshot.sources;
      }
      featuredCatalog = snapshot.featured;
    } on Object {
      // Keep the draft and the last error when a conflict recovery read also
      // encounters an outage.
    }
  }

}
