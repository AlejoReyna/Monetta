import 'package:flutter_test/flutter_test.dart';
import 'package:monetta_app/app/admin_config.dart';
import 'package:monetta_app/app/admin_controller.dart';
import 'package:monetta_app/data/admin/admin_client.dart';
import 'package:monetta_app/domain/admin_control.dart';
import 'package:monetta_app/domain/product.dart';

class _AdminClient implements AdminClient {
  _AdminClient({required this.snapshot});

  final AdminSnapshot snapshot;
  AdminProductRecord? savedProduct;
  AdminStorefrontSettings? savedStorefront;
  AdminSourcePolicy? savedSource;
  int syncCalls = 0;

  @override
  Future<AdminSnapshot> fetchSnapshot() async => snapshot;

  @override
  Future<void> syncAll() async => syncCalls += 1;

  @override
  Future<void> updateProduct(AdminProductRecord product) async {
    savedProduct = product;
  }

  @override
  Future<void> updateSource(AdminSourcePolicy source) async {
    savedSource = source;
  }

  @override
  Future<void> updateStorefront(AdminStorefrontSettings settings) async {
    savedStorefront = settings;
  }
}

Product _product({double price = 2890}) {
  return Product(
    id: 'gid://shopify/Product/1',
    handle: 'bolsa-negra',
    title: 'Bolsa negra',
    vendor: 'Monetta',
    productType: 'Bolsa',
    tags: const [],
    variants: [
      ProductVariant(
        id: 'gid://shopify/ProductVariant/1',
        title: 'Default Title',
        price: price,
        available: true,
      ),
    ],
    images: const ['https://cdn.shopify.com/product.jpg'],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

void main() {
  test('only configured owner emails can open live administration', () {
    final controller = AdminController(
      config: AdminConfig(
        baseUrl: Uri.parse('https://admin.monetta.test'),
        ownerEmails: const {'duena@monetta.mx'},
      ),
    );

    expect(
      controller.canAccess(
        signedIn: true,
        email: 'DUENA@monetta.mx',
        authProvider: 'shopify',
      ),
      isTrue,
    );
    expect(
      controller.canAccess(
        signedIn: true,
        email: 'cliente@example.com',
        authProvider: 'shopify',
      ),
      isFalse,
    );
    expect(
      controller.canAccess(
        signedIn: false,
        email: 'duena@monetta.mx',
        authProvider: 'shopify',
      ),
      isFalse,
    );
    expect(
      controller.canAccess(
        signedIn: true,
        email: 'duena@monetta.mx',
        authProvider: 'monetta',
      ),
      isTrue,
    );
  });

  test('preview changes stay local and are marked in audit', () async {
    final controller = AdminController(
      config: const AdminConfig(
        baseUrl: null,
        ownerEmails: {'duena@monetta.mx'},
        previewEnabled: true,
      ),
    );

    await controller.load(appProducts: [_product()]);
    expect(controller.sources, isEmpty);
    final updated = controller.products.single.copyWith(price: 3100);
    final ok = await controller.saveProduct(updated);

    expect(ok, isTrue);
    expect(controller.products.single.price, 3100);
    expect(controller.audit.single.previewOnly, isTrue);
    expect(
      controller.audit.single.channels,
      containsAll({AdminChannel.shopify, AdminChannel.app}),
    );
  });

  test('live mutations go through the backend then refresh app channels',
      () async {
    final snapshot = AdminSnapshot(
      products: [
        AdminProductRecord(
          id: 'gid://shopify/Product/1',
          title: 'Bolsa negra',
          price: 2890,
          inStock: true,
          visible: true,
          variantCount: 1,
        ),
      ],
      storefront: AdminStorefrontSettings.defaults,
      sources: const [],
    );
    final client = _AdminClient(snapshot: snapshot);
    var refreshes = 0;
    final controller = AdminController(
      config: AdminConfig(
        baseUrl: Uri.parse('https://admin.monetta.test'),
        ownerEmails: const {'duena@monetta.mx'},
      ),
      client: client,
      refreshApp: () async => refreshes += 1,
    );

    await controller.load(appProducts: [_product()]);
    final changed = controller.products.single.copyWith(price: 3250);
    final ok = await controller.saveProduct(changed);

    expect(ok, isTrue);
    expect(client.savedProduct?.price, 3250);
    expect(refreshes, 1);
    expect(controller.audit.single.previewOnly, isFalse);
  });

  test('syncAll succeeds without external catalog channel (F22)', () async {
    final snapshot = AdminSnapshot(
      products: const [],
      storefront: AdminStorefrontSettings.defaults,
      sources: const [],
    );
    final client = _AdminClient(snapshot: snapshot);
    final controller = AdminController(
      config: AdminConfig(
        baseUrl: Uri.parse('https://admin.monetta.test'),
        ownerEmails: const {'duena@monetta.mx'},
      ),
      client: client,
    );

    await controller.load(appProducts: const []);
    final ok = await controller.syncAll();

    expect(ok, isTrue);
    expect(client.syncCalls, 1);
    expect(
      controller.audit.single.channels,
      isNot(contains(AdminChannel.externalCatalog)),
    );
  });
}
