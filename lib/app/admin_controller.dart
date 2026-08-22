/// State and mutation routing for the in-app owner panel.
library;

import 'package:flutter/foundation.dart';

import '../data/admin/admin_client.dart';
import '../data/external_catalog/external_catalog_models.dart';
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

  bool loading = false;
  bool saving = false;
  String? lastError;
  DateTime? lastSyncedAt;

  AdminConnectionMode get mode => config.hasLiveApi && _client != null
      ? AdminConnectionMode.live
      : AdminConnectionMode.preview;

  bool canAccess({
    required bool signedIn,
    required String? email,
    String? authProvider,
  }) {
    if (!signedIn) return false;
    if (config.hasLiveApi && authProvider != 'shopify') {
      return false;
    }
    return config.allowsEmail(email) || config.previewEnabled;
  }

  Future<void> load({
    required List<Product> appProducts,
    required List<ExternalCatalogSourceStatus> externalSources,
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
          ),
        )
        .toList();
    sources = _fallbackSources(externalSources);
    lastError = null;
    notifyListeners();

    if (mode != AdminConnectionMode.live) return;
    loading = true;
    notifyListeners();
    try {
      final snapshot = await _client!.fetchSnapshot();
      products = snapshot.products;
      storefront = snapshot.storefront;
      sources = snapshot.sources;
    } catch (_) {
      lastError = 'No pudimos conectar con el panel. Mostramos los datos '
          'guardados en la app.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProduct(AdminProductRecord next) async {
    return _mutate(
      action: () async {
        await _client?.updateProduct(next);
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

  Future<bool> saveStorefront(AdminStorefrontSettings next) async {
    return _mutate(
      action: () async {
        await _client?.updateStorefront(next);
        storefront = next;
      },
      description: 'Actualizó la portada de la tienda',
      channels: const {AdminChannel.shopify, AdminChannel.app},
    );
  }

  Future<bool> saveSource(AdminSourcePolicy next) async {
    return _mutate(
      action: () async {
        await _client?.updateSource(next);
        sources = [
          for (final source in sources)
            if (source.id == next.id) next else source,
        ];
      },
      description: 'Actualizó la fuente ${next.merchant}',
      channels: const {AdminChannel.externalCatalog, AdminChannel.app},
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
        AdminChannel.externalCatalog,
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
    } catch (_) {
      lastError = 'No se guardó el cambio. Revisa tu conexión e inténtalo de '
          'nuevo.';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  static List<AdminSourcePolicy> _fallbackSources(
    List<ExternalCatalogSourceStatus> statuses,
  ) {
    const merchants = <String, String>{
      'coach_us': 'Coach',
      'michael_kors_us': 'Michael Kors',
      'guess_us': 'Guess',
      'steve_madden_us': 'Steve Madden',
      'marc_jacobs_us': 'Marc Jacobs',
      'tory_burch_us': 'Tory Burch',
      'kate_spade_us': 'Kate Spade',
      'guess_factory_us': 'Guess Factory',
      'gp_mcallen_perfumes': 'GP McAllen · Perfumes',
    };
    return [
      for (final entry in merchants.entries)
        () {
          ExternalCatalogSourceStatus? status;
          for (final candidate in statuses) {
            if (candidate.source == entry.key) {
              status = candidate;
              break;
            }
          }
          return AdminSourcePolicy(
            id: entry.key,
            merchant: status?.merchant.isNotEmpty == true
                ? status!.merchant
                : entry.value,
            enabled: true,
            itemLimit: 12,
            baseCommissionRate: .18,
            highValueCommissionRate: .12,
            highValueThreshold: 4000,
            itemCount: status?.itemCount ?? 0,
            lastSuccessfulRunAt: status?.lastSuccessfulRunAt,
          );
        }(),
    ];
  }
}
