/// Where the app can send the shopper, as a value.
///
/// Every navigation to a place in the app (a notification, a card, a link) is
/// described by an [AppDestination] and opened by `DestinationNavigator`, so
/// there is one resolver instead of one `push` per call site.
library;

import '../../data/notifications/notification_models.dart';

/// The surface that asked to navigate. It does not change where the shopper
/// lands; it is carried so a later step can attribute the navigation.
enum NavigationOrigin {
  notification,
  home,
  search,
  collection,
  catalog,
  product,
  bag,
  account,
  other,
}

sealed class AppDestination {
  const AppDestination({this.origin = NavigationOrigin.other});

  /// Resolves the route of a tapped notification.
  ///
  /// * a product whose key starts with `external:` is a link into the retired
  ///   external catalog, so it resolves to [UnavailableLinkDestination];
  /// * any other product key (with or without the `shopify:` prefix) resolves
  ///   to [ProductDestination];
  /// * a collection with a handle resolves to [CollectionDestination];
  /// * everything else, including a product without a key and a collection
  ///   without a handle, resolves to [HomeDestination].
  factory AppDestination.fromNotification(NotificationRouteData route) {
    const origin = NavigationOrigin.notification;
    final key = route.productKey;
    if (route.type == 'product' && key != null) {
      if (key.startsWith(_externalPrefix)) {
        return const UnavailableLinkDestination(origin: origin);
      }
      final productId = key.startsWith(_shopifyPrefix)
          ? key.substring(_shopifyPrefix.length)
          : key;
      if (productId.isNotEmpty) {
        return ProductDestination(productId, origin: origin);
      }
    }
    final handle = route.collectionHandle;
    if (route.type == 'collection' && handle != null && handle.isNotEmpty) {
      // Collection identity is the Shopify handle, not a facet category slug.
      return CollectionDestination(handle, origin: origin);
    }
    return const HomeDestination(origin: origin);
  }

  final NavigationOrigin origin;

  static const String _externalPrefix = 'external:';
  static const String _shopifyPrefix = 'shopify:';
}

/// A product page, by Shopify product GID.
final class ProductDestination extends AppDestination {
  const ProductDestination(
    this.productId, {
    this.initialVariantIndex = 0,
    super.origin,
  });

  final String productId;
  final int initialVariantIndex;
}

/// A Shopify collection, by handle. [title] defaults to the handle.
final class CollectionDestination extends AppDestination {
  const CollectionDestination(this.handle, {this.title, super.origin});

  final String handle;
  final String? title;
}

/// The first route of the app.
final class HomeDestination extends AppDestination {
  const HomeDestination({super.origin});
}

/// A link that no longer leads anywhere in the app.
final class UnavailableLinkDestination extends AppDestination {
  const UnavailableLinkDestination({super.origin});
}
