/// App-wide `InheritedNotifier` scopes.
///
/// All of them are mounted above the app Navigator (see `AppRouteScopes`), so a
/// pushed route sees exactly the scopes the home sees.
library;

import 'package:flutter/widgets.dart';

import '../account_controller.dart';
import '../admin_controller.dart';
import '../admin_notification_controller.dart';
import '../cart_controller.dart';
import '../catalog_store.dart';
import '../editorial_content_controller.dart';
import '../featured_catalog_controller.dart';
import '../home_content_controller.dart';
import '../notification_controller.dart';
import '../onboarding_controller.dart';
import '../shopify_checkout_coordinator.dart';

/// Exposes the store to the widget tree.
///
/// Deliberately plain Flutter rather than Riverpod for now: the store is a
/// single object and this keeps the demo free of state-management wiring that
/// will be rewritten anyway when `data/local` lands.
class StoreScope extends InheritedNotifier<CatalogStore> {
  const StoreScope({
    required CatalogStore super.notifier,
    required super.child,
    super.key,
  });

  static CatalogStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope?.notifier != null, 'StoreScope is missing from the tree');
    return scope!.notifier!;
  }

  static CatalogStore? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StoreScope>()?.notifier;
  }
}

/// Exposes owner-editable About and reseller content. The controller always
/// contains a complete bundled fallback, so this scope never represents a
/// loading gate.
class EditorialContentScope
    extends InheritedNotifier<EditorialContentController> {
  const EditorialContentScope({
    required EditorialContentController super.notifier,
    required super.child,
    super.key,
  });

  static EditorialContentController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<EditorialContentScope>()
        ?.notifier;
  }
}

/// Exposes the Shopify/Loox-backed home composition. Like editorial content,
/// it always starts with a complete bundled fallback and never gates startup.
class HomeContentScope extends InheritedNotifier<HomeContentController> {
  const HomeContentScope({
    required HomeContentController super.notifier,
    required super.child,
    super.key,
  });

  static HomeContentController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<HomeContentScope>()
        ?.notifier;
  }
}

/// Shopify-backed Today's Picks. It is separate from [HomeContentScope]
/// because membership is a mutable commerce collection, not editorial copy.
class FeaturedCatalogScope
    extends InheritedNotifier<FeaturedCatalogController> {
  const FeaturedCatalogScope({
    required FeaturedCatalogController super.notifier,
    required super.child,
    super.key,
  });

  static FeaturedCatalogController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FeaturedCatalogScope>()
      ?.notifier;
}

/// Exposes account state to the widget tree. See `app/account_controller.dart`
/// — `account == null` is a normal, fully-functional state, not a loading
/// gap. Only mounted once `AppDependencies.load` has resolved, since
/// [AccountController] needs an async-bootstrapped device id to exist at
/// all — see `AppDependencies.load`.
class AccountScope extends InheritedNotifier<AccountController> {
  const AccountScope({
    required AccountController super.notifier,
    required super.child,
    super.key,
  });

  static AccountController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    assert(scope?.notifier != null, 'AccountScope is missing from the tree');
    return scope!.notifier!;
  }

  static AccountController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
}

/// Optional production Shopify cart stack. It is absent in builds without
/// public Storefront configuration and performs no work merely by being built.
class CartScope extends InheritedNotifier<CartController> {
  const CartScope({
    required this.shopDomain,
    this.checkoutCoordinator,
    required CartController super.notifier,
    required super.child,
    super.key,
  });

  final String shopDomain;
  final ShopifyCheckoutCoordinator? checkoutCoordinator;

  static CartScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CartScope>();
}

/// Places every app scope above the app Navigator, so the home and any route
/// pushed on it observe the same controllers and buyer scope.
///
/// [accountController] and [cartController] are the original contract. The
/// remaining controllers are optional so a test can mount just the scopes a
/// widget needs; each one is mounted only when it is provided.
class AppRouteScopes extends StatelessWidget {
  const AppRouteScopes({
    required this.accountController,
    required this.cartController,
    this.checkoutCoordinator,
    this.catalogStore,
    this.notificationController,
    this.editorialContentController,
    this.homeContentController,
    this.featuredCatalogController,
    this.adminController,
    this.adminNotificationController,
    this.onboardingController,
    required this.shopDomain,
    required this.child,
    super.key,
  });

  final AccountController accountController;
  final CartController? cartController;
  final ShopifyCheckoutCoordinator? checkoutCoordinator;
  final CatalogStore? catalogStore;
  final NotificationController? notificationController;
  final EditorialContentController? editorialContentController;
  final HomeContentController? homeContentController;
  final FeaturedCatalogController? featuredCatalogController;
  final AdminController? adminController;
  final AdminNotificationController? adminNotificationController;
  final OnboardingController? onboardingController;
  final String shopDomain;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cart = cartController;
    Widget routedApp = cart == null
        ? child
        : CartScope(
            shopDomain: shopDomain,
            notifier: cart,
            checkoutCoordinator: checkoutCoordinator,
            child: child,
          );
    final onboarding = onboardingController;
    if (onboarding != null) {
      routedApp = OnboardingScope(notifier: onboarding, child: routedApp);
    }
    final admin = adminController;
    if (admin != null) {
      routedApp = AdminScope(notifier: admin, child: routedApp);
    }
    final adminNotifications = adminNotificationController;
    if (adminNotifications != null) {
      routedApp = AdminNotificationScope(
        notifier: adminNotifications,
        child: routedApp,
      );
    }
    final notifications = notificationController;
    if (notifications != null) {
      routedApp = NotificationScope(
        notifier: notifications,
        child: routedApp,
      );
    }
    final featured = featuredCatalogController;
    if (featured != null) {
      routedApp = FeaturedCatalogScope(notifier: featured, child: routedApp);
    }
    final homeContent = homeContentController;
    if (homeContent != null) {
      routedApp = HomeContentScope(notifier: homeContent, child: routedApp);
    }
    final editorial = editorialContentController;
    if (editorial != null) {
      routedApp = EditorialContentScope(notifier: editorial, child: routedApp);
    }
    final store = catalogStore;
    if (store != null) {
      routedApp = StoreScope(notifier: store, child: routedApp);
    }
    return AccountScope(notifier: accountController, child: routedApp);
  }
}

/// Exposes owner administration alongside account and catalog state. The
/// controller is always mounted, but its entry point remains hidden unless
/// the signed-in email matches `AdminConfig.ownerEmails` (or an explicit
/// preview build was requested).
class AdminScope extends InheritedNotifier<AdminController> {
  const AdminScope({
    required AdminController super.notifier,
    required super.child,
    super.key,
  });

  static AdminController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminScope>();
    assert(scope?.notifier != null, 'AdminScope is missing from the tree');
    return scope!.notifier!;
  }

  static AdminController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminScope>()?.notifier;
  }
}

/// Exposes opt-in notification state without coupling feature widgets to FCM.
class NotificationScope extends InheritedNotifier<NotificationController> {
  const NotificationScope({
    required NotificationController super.notifier,
    required super.child,
    super.key,
  });

  static NotificationController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NotificationScope>();
    assert(scope?.notifier != null, 'NotificationScope is missing');
    return scope!.notifier!;
  }

  static NotificationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NotificationScope>()
        ?.notifier;
  }
}

class AdminNotificationScope
    extends InheritedNotifier<AdminNotificationController> {
  const AdminNotificationScope({
    required AdminNotificationController super.notifier,
    required super.child,
    super.key,
  });

  static AdminNotificationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AdminNotificationScope>()
        ?.notifier;
  }
}
