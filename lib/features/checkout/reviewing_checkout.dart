/// In-memory record that banner 3 is active for one cart.
///
/// Keyed by the cart token the uncertain attempt recorded. Cleared when a
/// matching order is found, checkout completes, or the live Shopify cart is
/// emptied or replaced. This is not written to disk: an app restart drops it,
/// so the double-charge sheet will not appear again until the next uncertain
/// return in that process.
library;

import 'package:flutter/widgets.dart';

import '../../app/cart_controller.dart';
import 'checkout_return.dart';

final class ReviewingCheckoutCart extends ChangeNotifier {
  String? _cartToken;

  bool get isActive => _cartToken != null;

  bool isActiveFor(String? cartToken) {
    final active = _cartToken;
    if (active == null) return false;
    final current = cartToken?.trim();
    return current != null && current.isNotEmpty && current == active;
  }

  /// Records [cartToken] from the attempt that entered banner 3.
  ///
  /// A blank token cannot identify a cart, so it is ignored.
  void markActive(String? cartToken) {
    final token = cartToken?.trim();
    if (token == null || token.isEmpty) return;
    if (_cartToken == token) return;
    _cartToken = token;
    notifyListeners();
  }

  void clear() {
    if (_cartToken == null) return;
    _cartToken = null;
    notifyListeners();
  }

  /// Drops the warning when [cartId] is a different cart, or when the Shopify
  /// cart itself is empty. A missing cart id is not treated as a change: the
  /// snapshot may still be loading.
  void noteCart({String? cartId, bool emptied = false}) {
    if (_cartToken == null) return;
    if (emptied) {
      clear();
      return;
    }
    final token = cartTokenFromShopifyCartId(cartId);
    if (token == null) return;
    if (token != _cartToken) clear();
  }

  @override
  String toString() => 'ReviewingCheckoutCart(active: $isActive)';
}

class ReviewingCheckoutScope extends InheritedNotifier<ReviewingCheckoutCart> {
  const ReviewingCheckoutScope({
    required ReviewingCheckoutCart super.notifier,
    required super.child,
    super.key,
  });

  static ReviewingCheckoutCart? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ReviewingCheckoutScope>()
        ?.notifier;
  }
}

/// Owns the in-memory warning above the navigator and clears it when the
/// Shopify cart token changes or the cart is emptied.
class ReviewingCheckoutHost extends StatefulWidget {
  const ReviewingCheckoutHost({
    required this.child,
    this.cart,
    this.reviewing,
    super.key,
  });

  final CartController? cart;

  /// When null, this host creates a process-lifetime instance and disposes it.
  final ReviewingCheckoutCart? reviewing;
  final Widget child;

  @override
  State<ReviewingCheckoutHost> createState() => _ReviewingCheckoutHostState();
}

class _ReviewingCheckoutHostState extends State<ReviewingCheckoutHost> {
  ReviewingCheckoutCart? _owned;
  CartController? _cart;

  ReviewingCheckoutCart get _reviewing =>
      widget.reviewing ?? (_owned ??= ReviewingCheckoutCart());

  @override
  void initState() {
    super.initState();
    _cart = widget.cart;
    _cart?.addListener(_onCart);
  }

  @override
  void didUpdateWidget(ReviewingCheckoutHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cart == widget.cart) return;
    _cart?.removeListener(_onCart);
    _cart = widget.cart;
    _cart?.addListener(_onCart);
  }

  @override
  void dispose() {
    _cart?.removeListener(_onCart);
    _owned?.dispose();
    super.dispose();
  }

  void _onCart() {
    final cart = _cart?.snapshot?.cart;
    _reviewing.noteCart(
      cartId: cart?.id,
      emptied: cart != null && cart.isEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReviewingCheckoutScope(
      notifier: _reviewing,
      child: widget.child,
    );
  }
}
