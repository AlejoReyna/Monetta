/// Collections and navigation — both owner-controlled from Shopify Admin.
///
/// Pure Dart. See `lib/data/shopify/README.md` for why navigation is a *query*
/// rather than a constant.
library;

class Collection {
  const Collection({
    required this.id,
    required this.handle,
    required this.title,
    this.description = '',
    this.imageUrl,
    this.productCount,
  });

  final String id;
  final String handle;
  final String title;
  final String description;
  final String? imageUrl;

  /// Null when not requested. Used to hide empty collections — 7 of the store's
  /// 21 collections currently have zero products and would otherwise render as
  /// dead ends.
  final int? productCount;

  bool get isEmpty => productCount == 0;
}

/// One entry in the Shopify navigation menu.
///
/// The app's category navigation is built from this at runtime, so adding a
/// collection to the menu in Shopify → Navigation puts it in the app on the
/// next open.
class MenuEntry {
  const MenuEntry({
    required this.title,
    required this.url,
    this.resourceHandle,
    this.type = MenuEntryType.unknown,
    this.children = const [],
  });

  final String title;
  final String url;

  /// Handle of the linked collection/product, parsed from [url].
  final String? resourceHandle;

  final MenuEntryType type;
  final List<MenuEntry> children;

  bool get hasChildren => children.isNotEmpty;
}

enum MenuEntryType { collection, product, page, http, unknown }

/// A page of products plus the cursor needed to fetch the next one.
class ProductPage<T> {
  const ProductPage({
    required this.items,
    required this.hasNextPage,
    this.endCursor,
  });

  final List<T> items;
  final bool hasNextPage;
  final String? endCursor;
}
