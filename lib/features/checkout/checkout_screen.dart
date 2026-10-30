/// Monetta's pre-checkout experience — paquete D (Fig.13 bolsa, Fig.14
/// checkout, Fig.15 confirmación).
///
/// La app muestra la bolsa y un checkout de un solo paso: el pedido, quién
/// paga y «IR A PAGAR». No pide contacto: quien está conectado con Shopify es
/// reconocido allá por su cuenta, y a un invitado el checkout alojado de
/// Shopify le pide lo necesario si la tienda permite comprar sin cuenta.
/// Dirección, envío y pago viven en esa URL alojada, así que los datos de
/// tarjeta nunca entran a la app. Nunca se inventan métodos (Oxxo/Meses/
/// PayPal): solo se nombran opciones reales recibidas por config. Los totales
/// finales son de Shopify; los locales van marcados como estimación.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/account_controller.dart';
import '../../app/cart_controller.dart';
import '../../app/storefront_layout.dart';
import '../../platform/system_layout_context.dart';
import '../navigation/adaptive_storefront_scaffold.dart';
import '../navigation/duo_workspace.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../catalog/categories_screen.dart';
import '../../app/checkout_buyer_identity.dart';
import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/monetta_tokens.g.dart';
import '../boutique/client_guide_components.dart';
import 'purchase_notices.dart';
import '../../app/shopify_checkout_coordinator.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/local/database.dart' show Account, OrderSummary;
import '../../data/media/media_url.dart';
import '../../data/shopify/cart/cart_repository.dart';
import '../../data/shopify/cart/cart_session_store.dart';
import '../../data/shopify/cart/checkout_launcher.dart';
import '../../domain/bag_line.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_screen.dart';
import 'checkout_double_charge_sheet.dart';
import 'checkout_order_lookup.dart';
import 'checkout_return.dart';
import 'checkout_return_banner.dart';
import 'reviewing_checkout.dart';
import 'order_confirmation_screen.dart';
import 'shopify_cart_summary.dart';

/// Datos transitorios que un launcher real necesita para crear el Cart y
/// precargar buyer identity antes de abrir `cart.checkoutUrl`.
///
/// Nunca se persiste desde esta feature. Solo se envía directo a Shopify para
/// no pedir la dirección dos veces. No guarda tarjeta. El correo es el de la
/// cuenta conectada; vacío para un invitado, a quien Shopify se lo pide en su
/// propio checkout.
class CheckoutDraft {
  const CheckoutDraft({
    required this.lines,
    required this.email,
    required this.phone,
  });

  final List<BagLine> lines;
  final String email;
  final String phone;
}

typedef SecureCheckoutLauncher = Future<CheckoutResult> Function(
  CheckoutDraft draft,
);

/// The cart session of the shopper as they are now: their account's once
/// they are signed in, this installation's guest cart before.
CartSessionScope _sessionScopeFor(String shopDomain, Account? account) =>
    account == null
        ? CartSessionScope.guest(shopDomain: shopDomain)
        : CartSessionScope.authenticated(
            shopDomain: shopDomain,
            localAccountId: account.localAccountId,
          );
typedef ExternalCheckoutFallback = Future<bool> Function();

void openCheckoutOrders(BuildContext context) {
  final account = AccountScope.maybeOf(context);
  if (account == null || !account.isSignedIn) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Inicia sesión para ver Mis pedidos. Te enviamos la '
          'confirmación a tu correo.',
        ),
      ),
    );
    return;
  }
  unawaited(openOrders(context, controller: account));
}

Future<void> openBag(
  BuildContext context, {
  SecureCheckoutLauncher? launchSecureCheckout,
}) {
  // A two-sided window keeps the bag on its right side.
  if (DuoWorkspace.showBag(context)) return Future<void>.value();
  final store = StoreScope.of(context);
  return DuoWorkspace.navigatorFor(context).push(
    monettaFadeRoute(
      StoreScope(
        notifier: store,
        child: BagScreen(launchSecureCheckout: launchSecureCheckout),
      ),
      settings: const RouteSettings(name: DuoWorkspace.bagRoute),
    ),
  );
}

/// Acción reutilizable para que home y producto expongan una sola bolsa viva.
/// Contrato del orquestador: se conserva tal cual.
class BagAction extends StatelessWidget {
  const BagAction({this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final count = StoreScope.of(context).bagQuantity;
    return IconButton(
      tooltip: count == 0 ? 'Mi bolsa' : 'Mi bolsa, $count artículos',
      onPressed: onPressed ?? () => unawaited(openBag(context)),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 23),
          if (count > 0)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.ink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: boutiqueText(
                    size: 9,
                    color: palette.canvas,
                    weight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class BagScreen extends StatefulWidget {
  const BagScreen({
    this.launchSecureCheckout,
    this.embedded = false,
    super.key,
  });

  final SecureCheckoutLauncher? launchSecureCheckout;

  /// The bag as the first page of a two-sided window's right side: no header
  /// or way back (the catalog stays on the left), no recommendations, and an
  /// empty state that only says what will appear here.
  final bool embedded;

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  CartSessionScope? _requestedScope;
  String? _requestedIntentShape;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final lines = store.bagLines;
    final cartScope = CartScope.maybeOf(context);
    final account = AccountScope.maybeOf(context)?.account;
    final sessionScope = cartScope == null
        ? null
        : _sessionScopeFor(cartScope.shopDomain, account);
    final localIntent = [
      for (final line in lines)
        LocalCartIntent(variantId: line.variant.id, quantity: line.quantity),
    ];
    // The right side keeps the bag mounted; it reconciles only while shown.
    final shown = !widget.embedded || TickerMode.valuesOf(context).enabled;
    if (cartScope != null &&
        sessionScope != null &&
        lines.isNotEmpty &&
        shown) {
      _scheduleReconciliation(
        cartScope.notifier!,
        cartScope.checkoutCoordinator,
        sessionScope,
        localIntent,
      );
    }

    return AdaptiveStorefrontScaffold(
      backgroundColor: palette.canvas,
      appBar: widget.embedded
          ? null
          : _BoutiqueBar(
              leading: IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
      body: SafeArea(
        bottom: true,
        child: SystemUsableSurface(
          child: lines.isEmpty
              ? _EmptyBag(embedded: widget.embedded)
              : _BagContents(
                  lines: lines,
                  launchSecureCheckout: widget.launchSecureCheckout,
                  cartController: cartScope?.notifier,
                  checkoutCoordinator: cartScope?.checkoutCoordinator,
                  cartScope: sessionScope,
                  localIntent: localIntent,
                  embedded: widget.embedded,
                ),
        ),
      ),
      bottomNavigationBar: !SystemLayoutScope.of(context).supported
          ? null
          : MonettaBottomNavigation(
              current: MonettaBottomDestination.bag,
              bagCount: store.bagQuantity,
              onSelected: (destination) {
                switch (destination) {
                  case MonettaBottomDestination.home:
                    DuoWorkspace.navigatorFor(context)
                        .popUntil((route) => route.isFirst);
                  case MonettaBottomDestination.catalog:
                    unawaited(openCategories(context));
                  case MonettaBottomDestination.bag:
                    break;
                  case MonettaBottomDestination.account:
                    final controller = AccountScope.maybeOf(context);
                    if (controller != null) {
                      unawaited(openAccount(context, controller: controller));
                    }
                }
              },
            ),
    );
  }

  void _scheduleReconciliation(
    CartController controller,
    ShopifyCheckoutCoordinator? checkoutCoordinator,
    CartSessionScope scope,
    List<LocalCartIntent> localIntent,
  ) {
    final shape = localIntent
        .map((item) => '${item.variantId}:${item.quantity}')
        .join('|');
    if (_requestedScope == scope && _requestedIntentShape == shape) return;
    _requestedScope = scope;
    _requestedIntentShape = shape;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(() async {
        final refreshed = await controller.reconcileLocalBag(
          scope: scope,
          localIntent: localIntent,
        );
        if (!mounted || refreshed == null) return;
        await checkoutCoordinator?.preload(refreshed);
      }());
    });
  }
}

class _BagContents extends StatelessWidget {
  const _BagContents({
    required this.lines,
    required this.launchSecureCheckout,
    required this.cartController,
    required this.checkoutCoordinator,
    required this.cartScope,
    required this.localIntent,
    this.embedded = false,
  });

  final List<BagLine> lines;
  final SecureCheckoutLauncher? launchSecureCheckout;
  final CartController? cartController;
  final ShopifyCheckoutCoordinator? checkoutCoordinator;
  final CartSessionScope? cartScope;
  final List<LocalCartIntent> localIntent;

  /// On a two-sided window's right side the catalog beside it is the place to
  /// discover more, so the bag carries no recommendations.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final count = store.bagQuantity;
    final subtotal = store.bagSubtotal;

    Future<void> continueToCheckout() async {
      final guard = ReviewingCheckoutScope.maybeOf(context);
      if (guard != null) {
        await guard.ensureLoaded();
        if (!context.mounted) return;
      }
      if (guard != null &&
          guard.blocksCheckout(bagEmpty: store.bagLines.isEmpty)) {
        final choice = await showCheckoutDoubleChargeSheet(context);
        if (!context.mounted) return;
        if (choice == CheckoutDoubleChargeChoice.viewOrders) {
          openCheckoutOrders(context);
          return;
        }
        if (choice != CheckoutDoubleChargeChoice.payAnyway) return;
      }
      if (!context.mounted) return;
      final controller = cartController;
      final scope = cartScope;
      final checkout = checkoutCoordinator;
      final accountController = AccountScope.maybeOf(context);
      final productionLauncher = controller == null ||
              scope == null ||
              checkout == null
          ? null
          : (CheckoutDraft draft) async {
              // Reconstruye el intent desde la bolsa viva justo antes de
              // reconciliar — nunca reusa el snapshot de apertura (F17).
              final currentIntent = [
                for (final line in store.bagLines)
                  LocalCartIntent(
                    variantId: line.variant.id,
                    quantity: line.quantity,
                  ),
              ];
              // The account is read once: the identity, the cart scope
              // and the check after the await all describe the same one.
              final account = accountController?.account;
              final buyerIdentity = await resolveCheckoutBuyerIdentity(
                account: account,
                shopifyAccessToken:
                    accountController?.accessTokenForShopifyCheckout,
                email: draft.email,
                phone: draft.phone,
              );
              // The token of one account must never meet the cart scope of
              // another: if the account changed while it was awaited, stop
              // before reconciling or presenting anything.
              if (accountController?.account?.localAccountId !=
                  account?.localAccountId) {
                return const CheckoutFailed(
                  code: CheckoutFailureCode.unavailable,
                  userMessage: 'Tu cuenta cambió. Revisa tu bolsa e intenta de '
                      'nuevo.',
                  allowExternalBrowser: false,
                );
              }
              return checkout.present(
                controller: controller,
                // Signing in on the checkout screen moves the guest cart
                // to the account; the scope follows the shopper as now.
                scope: _sessionScopeFor(scope.shopDomain, account),
                localIntent: currentIntent,
                buyerIdentity: buyerIdentity,
                onCompleted: (purchase) async {
                  await store.applyCheckoutPurchase(purchase);
                  await accountController?.loadOrders();
                },
              );
            };
      final launcher = launchSecureCheckout ?? productionLauncher;
      // F05: no capturar contacto/entrega cuando el checkout no puede cerrar.
      if (launcher == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El checkout seguro no está disponible en esta configuración. '
              'Tu bolsa se conserva.',
            ),
          ),
        );
        return;
      }
      unawaited(
        // With two sides, checkout spans both: summary left, payment right.
        DuoWorkspace.taskNavigatorFor(context).push(
          monettaFadeRoute(
            StoreScope(
              notifier: store,
              child: CheckoutFlowScreen(
                launchSecureCheckout: launcher,
                // El coordinador decide al invocar si hay URL fresca; no se
                // congela estado antes de la reconciliación final.
                openExternalCheckout: checkout?.openExternalFallback,
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= StorefrontLayout.cartSplitWidth &&
            StorefrontLayout.canSplit(
              constraints.biggest,
              MediaQuery.textScalerOf(context),
            );
        final heading = Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))
              ? Column(
                  key: const ValueKey('bag-heading-stacked'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mi bolsa', style: boutiqueDisplay(wide ? 32 : 28)),
                    const SizedBox(height: 8),
                    Text(
                      '$count ${count == 1 ? 'artículo' : 'artículos'}',
                      style: boutiqueText(
                        size: 12,
                        color: context.boutique.inkMuted,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('bag-heading-row'),
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        'Mi bolsa',
                        style: boutiqueDisplay(wide ? 32 : 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$count ${count == 1 ? 'artículo' : 'artículos'}',
                      style: boutiqueText(
                        size: 12,
                        color: context.boutique.inkMuted,
                      ),
                    ),
                  ],
                ),
        );

        final lineTiles = Column(
          children: [
            for (final line in lines)
              _BagLineTile(
                line: line,
                onChanged: (quantity) =>
                    store.updateBagQuantity(line.variant.id, quantity),
                onRemove: () => store.removeFromBag(line.variant.id),
              ),
          ],
        );

        final incentive = Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: const PurchasePolicyNotice(
            key: ValueKey('purchase-policy-notice'),
          ),
        );

        final controller = cartController;
        final scope = cartScope;
        final hasRemoteCart = controller?.scopedSnapshot?.scope == scope &&
            controller?.snapshot?.cart != null;
        final summary = controller != null && scope != null && hasRemoteCart
            ? ShopifyCartSummary(
                controller: controller,
                scope: scope,
                localIntent: localIntent,
                onContinue: () => unawaited(continueToCheckout()),
              )
            : _OrderSummary(
                subtotal: subtotal,
                ctaLabel: 'Continuar al checkout',
                onContinue: () => unawaited(continueToCheckout()),
              );

        final bagIds = {for (final line in lines) line.product.id};
        final recommendations = embedded
            ? const SizedBox.shrink()
            : _BagRecommendations(excludeIds: bagIds);

        if (wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 12, 32, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [heading, lineTiles],
                          ),
                        ),
                        const SizedBox(width: 48),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 64),
                            child: Column(
                              children: [
                                const PurchasePolicyNotice(
                                  key: ValueKey('purchase-policy-notice'),
                                ),
                                const SizedBox(height: 16),
                                summary,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    recommendations,
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            heading,
            lineTiles,
            incentive,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: summary,
            ),
            recommendations,
          ],
        );
      },
    );
  }
}

class CheckoutFlowScreen extends StatefulWidget {
  const CheckoutFlowScreen({
    this.launchSecureCheckout,
    this.openExternalCheckout,
    this.availablePaymentMethods = const [],
    this.orderLookup,
    this.attemptIdentity,
    this.orderLookupInterval = kCheckoutOrderLookupInterval,
    this.orderLookupTimeout = kCheckoutOrderLookupTimeout,
    this.orderLookupDelay,
    this.onOrderFound,
    this.correlationAvailable = kCheckoutTokenCorrelationAvailable,
    this.openUri,
    super.key,
  });

  final SecureCheckoutLauncher? launchSecureCheckout;
  final ExternalCheckoutFallback? openExternalCheckout;

  /// Payment method names configured in Shopify. There are no radios and no
  /// hosted notice any more: they only appear as text in `SecurePaymentLine`
  /// (empty = nothing is claimed about methods).
  final List<String> availablePaymentMethods;

  /// When null, the signed-in account's existing order sources are used.
  /// Tests pass a fake. With no account and no fake, there is nothing to poll.
  final CheckoutOrderLookup? orderLookup;

  /// Overrides the cart/checkout token read from the reconciled cart.
  final CheckoutAttemptIdentity? attemptIdentity;

  final Duration orderLookupInterval;
  final Duration orderLookupTimeout;
  final CheckoutOrderDelay? orderLookupDelay;

  /// Replaces the default route to order detail. Used by tests.
  final Future<void> Function(
    BuildContext context,
    CheckoutOrderMatch match,
  )? onOrderFound;

  /// Banner 1 is allowed only when this is true. Production stays false
  /// until order sources return a checkout or cart token.
  final bool correlationAvailable;

  /// Opens the concierge WhatsApp link. Tests pass a fake.
  final Future<bool> Function(Uri uri)? openUri;

  @override
  State<CheckoutFlowScreen> createState() => _CheckoutFlowScreenState();
}

class _CheckoutFlowScreenState extends State<CheckoutFlowScreen> {
  final _scrollController = ScrollController();
  bool _openingSheet = false;
  bool _checkingOrder = false;
  bool _orderFound = false;
  int _returnGeneration = 0;
  CheckoutReturnPhase? _returnPhase;
  String? _returnDetail;
  Timer? _pollTimer;
  Completer<void>? _pollDelay;

  bool get _retryBlocked => _openingSheet || _checkingOrder || _orderFound;

  @override
  void dispose() {
    _returnGeneration += 1;
    _finishPollDelay();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _delayPoll(Duration duration) {
    final injected = widget.orderLookupDelay;
    if (injected != null) return injected(duration);
    final completer = Completer<void>();
    _pollDelay = completer;
    _pollTimer?.cancel();
    _pollTimer = Timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  void _finishPollDelay() {
    _pollTimer?.cancel();
    _pollTimer = null;
    final completer = _pollDelay;
    _pollDelay = null;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  CheckoutOrderLookup? _lookup() {
    final injected = widget.orderLookup;
    if (injected != null) return injected;
    final account = AccountScope.maybeOf(context);
    if (account == null) return null;
    return AccountCheckoutOrderLookup(account);
  }

  CheckoutAttemptIdentity _attemptIdentity() {
    final override = widget.attemptIdentity;
    if (override != null) return override;
    final cart = CartScope.maybeOf(context)?.notifier?.snapshot?.cart;
    return checkoutAttemptFromCart(
      cartId: cart?.id,
      checkoutUrl: cart?.checkoutUrl,
    );
  }

  void _showBrowserFallback(CheckoutFailed failure) {
    if (!failure.allowExternalBrowser) return;
    final fallback = widget.openExternalCheckout;
    if (fallback == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${failure.userMessage} Abrir el navegador no confirma el pago; '
          'revisa Mis pedidos si terminaste ahí.',
        ),
        action: SnackBarAction(
          label: 'ABRIR NAVEGADOR',
          onPressed: () => unawaited(fallback()),
        ),
      ),
    );
  }

  Future<void> _openConciergeWhatsApp() async {
    final uri = conciergeWhatsAppUri();
    final open = widget.openUri ??
        ((target) => launchUrl(target, mode: LaunchMode.externalApplication));
    final ok = await open(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  void _viewOrders() => openCheckoutOrders(context);

  void _activateReviewing() {
    ReviewingCheckoutScope.maybeOf(context)?.markActive();
  }

  void _deactivateReviewing() {
    ReviewingCheckoutScope.maybeOf(context)?.clear();
  }

  Future<void> _openMatchedOrder(CheckoutOrderMatch match) async {
    final handler = widget.onOrderFound;
    if (handler != null) {
      await handler(context, match);
      return;
    }
    if (!mounted) return;
    final account = AccountScope.maybeOf(context);
    if (account != null) await account.loadOrders();
    if (!mounted) return;
    OrderSummary? summary;
    for (final order in account?.orders ?? const <OrderSummary>[]) {
      if (order.id == match.orderId ||
          (order.shopifyOrderId != null &&
              order.shopifyOrderId == match.orderId)) {
        summary = order;
        break;
      }
    }
    if (summary == null || !mounted) return;
    final matched = summary;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailScreen(
          order: matched,
          rewardsController: account,
        ),
      ),
    );
  }

  Future<void> _pay() async {
    if (_retryBlocked) return;
    // Signing in and paying are exclusive: the account would change under the
    // checkout that is about to open.
    if (AccountScope.maybeOf(context)?.isLoading == true) return;
    final store = StoreScope.of(context);
    final lines = store.bagLines;
    if (widget.launchSecureCheckout case final launcher?) {
      NotificationScope.maybeOf(context)?.recordPushOutcome('checkout_started');
      final generation = ++_returnGeneration;
      setState(() {
        _openingSheet = true;
        _returnPhase = null;
        _returnDetail = null;
      });
      try {
        // Nothing is asked here: a connected shopper is recognized by Shopify
        // through their account, and Shopify's own checkout asks a guest for
        // contact details when the store allows buying without an account.
        final email =
            AccountScope.maybeOf(context)?.account?.email?.trim() ?? '';
        final result = await launcher(
          CheckoutDraft(lines: lines, email: email, phone: ''),
        );
        if (!mounted || generation != _returnGeneration) return;
        setState(() => _openingSheet = false);
        switch (result) {
          case CheckoutCompleted():
            _deactivateReviewing();
            setState(() => _returnPhase = null);
            // Confirmación solo con evidencia del result. CheckoutCompleted no
            // porta identidad de pedido y la sincronización de Mis pedidos
            // puede aún no incluir el pedido nuevo: tomar el primer
            // displayNumber atribuiría a la compra un pedido anterior. Se
            // muestra el estado honesto sin número hasta correlacionar por
            // identidad autoritativa.
            final accountController = AccountScope.maybeOf(context);
            final navigator = Navigator.of(context);
            final controllerForOrders = accountController;
            final signedIn = controllerForOrders?.isSignedIn == true;
            if (!mounted) return;
            await showOrderConfirmation(
              context,
              orderLabel: null,
              email: email.isEmpty ? null : email,
              onViewOrder: () {
                navigator.popUntil((route) => route.isFirst);
                final controller = controllerForOrders;
                if (controller != null && signedIn) {
                  unawaited(
                    openAccount(navigator.context, controller: controller),
                  );
                } else {
                  ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Inicia sesión para ver Mis pedidos. Te enviamos la '
                        'confirmación a tu correo.',
                      ),
                    ),
                  );
                }
              },
            );
          case CheckoutCancelled():
          case CheckoutFailed():
            if (result is CheckoutFailed) _showBrowserFallback(result);
            final kind = classifyCheckoutResult(result);
            if (kind == CheckoutReturnKind.sheetDidNotOpen) {
              final detail =
                  result is CheckoutFailed && !result.allowExternalBrowser
                      ? result.userMessage
                      : null;
              setState(() {
                _returnPhase = CheckoutReturnPhase.sheetDidNotOpen;
                _returnDetail = detail;
              });
              return;
            }
            final lookup = _lookup();
            final attempt = _attemptIdentity();
            if (lookup == null) {
              // Nothing to correlate against. That is not proof of no charge.
              _activateReviewing();
              setState(() => _returnPhase = CheckoutReturnPhase.reviewing);
              return;
            }
            setState(() {
              _checkingOrder = true;
              _returnPhase = CheckoutReturnPhase.confirming;
            });
            final decision = await resolvePaymentReturn(
              lookup: lookup,
              attempt: attempt,
              interval: widget.orderLookupInterval,
              timeout: widget.orderLookupTimeout,
              correlationAvailable: widget.correlationAvailable,
              delay: _delayPoll,
              isCancelled: () => !mounted || generation != _returnGeneration,
            );
            if (!mounted || generation != _returnGeneration) return;
            if (decision is CheckoutOrderFound) {
              _deactivateReviewing();
              setState(() {
                _checkingOrder = false;
                _orderFound = true;
                _returnPhase = null;
              });
              await _openMatchedOrder(decision.match);
              return;
            }
            if (decision is! CheckoutOrderNotFound) {
              _activateReviewing();
            }
            setState(() {
              _checkingOrder = false;
              _returnPhase = decision is CheckoutOrderNotFound
                  ? CheckoutReturnPhase.paymentNotCompleted
                  : CheckoutReturnPhase.reviewing;
            });
        }
      } finally {
        if (mounted && generation == _returnGeneration) {
          setState(() {
            _openingSheet = false;
            _checkingOrder = false;
          });
        }
      }
      return;
    }
    if (!mounted) return;
    setState(() => _returnPhase = CheckoutReturnPhase.sheetDidNotOpen);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'El checkout seguro no está disponible en esta configuración. Tu bolsa se conserva.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final signingIn = AccountScope.maybeOf(context)?.isLoading == true;
    if (store.bagLines.isEmpty) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: const _BoutiqueBar(),
        body: const SafeArea(child: _EmptyBag()),
      );
    }

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: _BoutiqueBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 20),
        ),
        title: 'Checkout',
      ),
      body: SafeArea(
        bottom: true,
        child: ViewRelativeLayout(
          builder: (context, box, origin) {
            final summary = _CheckoutSummary(
              lines: store.bagLines,
              subtotal: store.bagSubtotal,
            );
            final pay = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CheckoutIdentity(connectEnabled: !_retryBlocked),
                _CheckoutPayPanel(
                  openingSheet: _openingSheet,
                  returnPhase: _returnPhase,
                  returnDetail: _returnDetail,
                  payEnabled: !_retryBlocked && !signingIn,
                  showPayButton: !_orderFound,
                  paymentMethods: widget.availablePaymentMethods,
                  onPay: () => unawaited(_pay()),
                  onViewOrders: _viewOrders,
                  onWhatsApp: () => unawaited(_openConciergeWhatsApp()),
                ),
              ],
            );

            // A two-sided window: the order on the left of the crease and the
            // way to pay on the right, where the bag was, each scrolling on
            // its own.
            final crease = _creaseWithin(context, origin & box.biggest);
            if (crease != null) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: crease.left,
                    child: SingleChildScrollView(
                      key: const Key('checkout-duo-summary'),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: summary,
                    ),
                  ),
                  SizedBox(
                    width: crease.width,
                    child: Center(
                      child: SizedBox(
                        width: .5,
                        child: ColoredBox(color: palette.hairline),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('checkout-duo-pay'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                      child: pay,
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 40),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  if (!wide) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          const SizedBox(height: 24),
                          pay,
                        ],
                      ),
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: summary),
                            const SizedBox(width: 56),
                            Expanded(flex: 4, child: pay),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The vertical division a full-width checkout spans on a two-sided window,
/// in the body's own coordinates. Null unless the form keeps the browsing
/// side's minimum width and the summary a usable column.
Rect? _creaseWithin(BuildContext context, Rect body) {
  if (StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))) {
    return null;
  }
  for (final division in SystemLayoutScope.of(context).divisions) {
    final bounds = division.bounds;
    if (bounds.isEmpty || bounds.height < body.height * .5) continue;
    final left = bounds.left - body.left;
    final right = body.right - bounds.right;
    if (left >= StorefrontLayout.browseMinimum &&
        right >= StorefrontLayout.regionMinimumWidth) {
      return Rect.fromLTRB(left, 0, bounds.right - body.left, body.height);
    }
  }
  return null;
}

class _BoutiqueBar extends StatelessWidget implements PreferredSizeWidget {
  const _BoutiqueBar({this.leading, this.title});

  final Widget? leading;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(60.5);

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return AppBar(
      toolbarHeight: 60,
      leading: leading,
      automaticallyImplyLeading: false,
      backgroundColor: palette.bar,
      foregroundColor: palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: title == null
          ? const MonettaWordmark.appBar()
          : Text(title!, style: boutiqueTitle(size: 16, color: palette.ink)),
      actions: title == 'Checkout'
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'SEGURO',
                      style: boutiqueEyebrow(size: 9, color: palette.ink),
                    ),
                  ],
                ),
              ),
            ]
          : null,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(.5),
        child: Container(height: .5, color: palette.hairline),
      ),
    );
  }
}

class _BagLineTile extends StatelessWidget {
  const _BagLineTile({
    required this.line,
    required this.onChanged,
    required this.onRemove,
  });

  final BagLine line;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final brand = store.facetsFor(line.product.id)?.brand?.value;
    final wishlisted = store.wishlist.contains(line.product.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.hairline, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BoutiqueRadius.tile,
            child: SizedBox(
              width: 76,
              height: 92,
              child: _ProductImage(url: line.product.primaryImage),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (brand != null) ...[
                  Text(
                    brand.toUpperCase(),
                    style: boutiqueEyebrow(size: 9, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  line.product.title,
                  maxLines: StorefrontLayout.enlargedText(
                    MediaQuery.textScalerOf(context),
                  )
                      ? null
                      : 2,
                  overflow: StorefrontLayout.enlargedText(
                    MediaQuery.textScalerOf(context),
                  )
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: boutiqueText(
                    size: 14,
                    weight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                if (!line.variant.isDefault) ...[
                  const SizedBox(height: 3),
                  Text(
                    line.variant.title,
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  kMoney.format(line.lineTotal),
                  style: boutiqueText(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _QuantityStepper(
                  quantity: line.quantity,
                  onChanged: onChanged,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _BagTextAction(
                      label: 'Eliminar',
                      onTap: onRemove,
                    ),
                    _BagTextAction(
                      label: wishlisted ? 'Guardado ✓' : 'Guardar para después',
                      onTap: () =>
                          unawaited(store.toggleWishlist(line.product.id)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BagTextAction extends StatelessWidget {
  const _BagTextAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BoutiqueRadius.capsule,
        child: InkWell(
          onTap: onTap,
          borderRadius: BoutiqueRadius.capsule,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: boutiqueText(
                    size: 12,
                    color: palette.inkMuted,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Container(height: .8, width: 48, color: palette.hairline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stepper unificado de la bolsa: una sola anatomía en Fig.13 y Fig.14.
class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      label: 'Cantidad $quantity',
      child: Container(
        height: StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))
            ? math.max(
                48,
                MediaQuery.textScalerOf(context).scale(13) * 1.4 + 12,
              )
            : 40,
        decoration: BoxDecoration(
          border: Border.all(color: palette.hairline),
          borderRadius: BoutiqueRadius.tile,
          color: palette.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepperButton(
              tooltip: 'Quitar uno',
              icon: Icons.remove,
              onPressed: () => onChanged(quantity - 1),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 36),
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: boutiqueText(size: 13, weight: FontWeight.w600),
              ),
            ),
            _StepperButton(
              tooltip: 'Agregar uno',
              icon: Icons.add,
              onPressed: quantity >= 10 ? null : () => onChanged(quantity + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      constraints: BoxConstraints.tightFor(
        width: StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))
            ? 48
            : 40,
        height: StorefrontLayout.enlargedText(MediaQuery.textScalerOf(context))
            ? math.max(
                48,
                MediaQuery.textScalerOf(context).scale(13) * 1.4 + 12,
              )
            : 40,
      ),
      padding: EdgeInsets.zero,
    );
  }
}

class _BagRecommendations extends StatelessWidget {
  const _BagRecommendations({required this.excludeIds});

  final Set<String> excludeIds;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final feed = store
        .feed(limit: 20)
        .map((r) => r.product)
        .where(
          (p) => !excludeIds.contains(p.id) && p.isInStock,
        )
        .take(8)
        .toList(growable: false);
    final items = feed.isNotEmpty
        ? feed
        : store.products
            .where((p) => !excludeIds.contains(p.id) && p.isInStock)
            .take(8)
            .toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Recomendaciones',
              style: boutiqueTitle(color: palette.ink),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            key: const ValueKey('bag-recommendations'),
            height: productTileExtent(
              tileWidth: 148,
              textScaler: MediaQuery.textScalerOf(context),
              density: ProductTileDensity.compact,
              priceLines: tilePriceLinesFor(items),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = items[index];
                return SizedBox(
                  width: 148,
                  child: ProductCard(
                    product: product,
                    density: ProductTileDensity.compact,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.subtotal,
    required this.ctaLabel,
    required this.onContinue,
  });

  final double subtotal;
  final String ctaLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      key: const ValueKey('bag-order-summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de compra',
            style: clientGuideStyle(context, MonettaTokens.sectionTitle),
          ),
          const SizedBox(height: 18),
          _SummaryRow(label: 'Subtotal', value: kMoney.format(subtotal)),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Envío',
            value: 'Se calcula en Shopify',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(height: .5, color: palette.hairline),
          ),
          _SummaryRow(
            label: 'Total estimado',
            value: kMoney.format(subtotal),
            prominent: true,
          ),
          const SizedBox(height: 6),
          Text(
            'Estimación local · totales finales en Shopify.',
            style: boutiqueText(size: 11, color: palette.inkMuted),
          ),
          const SizedBox(height: 18),
          BoutiqueButton(label: ctaLabel, onPressed: onContinue),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 7,
            runSpacing: 4,
            children: [
              Icon(Icons.lock_outline, size: 14, color: palette.inkMuted),
              Text(
                'Pagos seguros con Shopify.',
                textAlign: TextAlign.center,
                style: boutiqueText(size: 11, color: palette.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    // The value may be a sentence ("Se calcula en Shopify"), so it is capped
    // and allowed to wrap instead of overflowing at large text scales.
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: boutiqueText(
                size: prominent ? 15 : 13,
                weight: prominent ? FontWeight.w600 : FontWeight.w400,
                color: palette.ink,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * .65),
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: boutiqueText(
                size: prominent ? 16 : 13,
                weight: prominent ? FontWeight.w700 : FontWeight.w500,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The first pay control stays up, disabled, while we confirm. Settled
/// banners own their own actions, and banner 3 has no retry.
bool _showsCheckoutPayButton(CheckoutReturnPhase? phase) {
  return phase == null || phase == CheckoutReturnPhase.confirming;
}

/// The one step left in the app: going to Shopify's checkout, where the
/// address, shipping and payment method are chosen.
class _CheckoutPayPanel extends StatelessWidget {
  const _CheckoutPayPanel({
    required this.openingSheet,
    required this.returnPhase,
    this.returnDetail,
    required this.payEnabled,
    required this.showPayButton,
    required this.paymentMethods,
    required this.onPay,
    required this.onViewOrders,
    required this.onWhatsApp,
  });

  final bool openingSheet;
  final CheckoutReturnPhase? returnPhase;
  final String? returnDetail;
  final bool payEnabled;
  final bool showPayButton;
  final List<String> paymentMethods;
  final VoidCallback onPay;
  final VoidCallback onViewOrders;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (returnPhase != null)
          CheckoutReturnBanner(
            phase: returnPhase!,
            bodyOverride: returnDetail,
            onRetry: payEnabled ? onPay : null,
            onViewOrders: onViewOrders,
            onWhatsApp: onWhatsApp,
          ),
        if (openingSheet)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              label: 'Abriendo checkout seguro',
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Abriendo checkout seguro…',
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        if (showPayButton && _showsCheckoutPayButton(returnPhase))
          BoutiqueButton(
            key: const ValueKey('checkout-pay-button'),
            label: 'IR A PAGAR',
            onPressed: payEnabled ? onPay : null,
          ),
        const SizedBox(height: 12),
        SecurePaymentLine(methods: paymentMethods),
      ],
    );
  }
}

/// Who pays. A shopper connected with Shopify is recognized there through
/// their account, so nothing is asked. A guest pays as a guest, or connects
/// first; Shopify's checkout then applies the store's own rule for buying
/// without an account.
class _CheckoutIdentity extends StatelessWidget {
  const _CheckoutIdentity({required this.connectEnabled});

  /// False while a payment is opening or being confirmed.
  final bool connectEnabled;

  /// The narrowest the guest label may get before the button drops below it.
  static const _minLabelWidth = 100.0;

  Future<void> _connect(
    BuildContext context,
    AccountController controller,
  ) async {
    await controller.login();
    if (!context.mounted || controller.isSignedIn) return;
    final error = controller.lastError;
    if (error == null || error.isSilent) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('No pudimos iniciar sesión. Puedes pagar como invitado.'),
      ),
    );
  }

  /// Horizontal padding of the text button, per side.
  static const _connectPadding = 12.0;
  static const _identityMarkSize = 36.0;
  static const _identityGap = 12.0;

  /// Width of [text] on one line, at the shopper's text scale.
  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final controller = AccountScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final account = controller.account;
    final Widget content;
    if (account != null) {
      final email = account.email?.trim();
      content = Row(
        children: [
          _IdentityMark(photo: controller.profilePhotoBytes),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email == null || email.isEmpty ? 'Tu cuenta' : email,
                  key: const Key('checkout-identity-email'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: boutiqueText(
                    size: 14,
                    weight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
                if (account.authProvider == 'shopify')
                  Text(
                    'Conectado con Shopify',
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
              ],
            ),
          ),
        ],
      );
    } else if (controller.canLogin) {
      final connecting = controller.isLoading;
      final connectLabel = connecting ? 'Conectando…' : 'Iniciar sesión';
      final connectStyle = boutiqueText(
        size: 13,
        weight: FontWeight.w600,
        decoration: TextDecoration.underline,
      );
      final guestLabel = Text(
        'Comprando como invitado',
        style: boutiqueText(size: 14, color: palette.ink),
      );
      final connect = TextButton(
        key: const Key('checkout-connect'),
        onPressed: !connectEnabled || connecting
            ? null
            : () => unawaited(_connect(context, controller)),
        style: TextButton.styleFrom(
          foregroundColor: palette.ink,
          minimumSize: const Size(0, BoutiqueSpace.tapTarget),
        ),
        child: Text(connectLabel, style: connectStyle),
      );
      // The button keeps its own line of text; the label gets what is left of
      // the row. When that is too little to read, the button goes below.
      final buttonWidth = _textWidth(
            context,
            connectLabel,
            connectStyle,
          ) +
          2 * _connectPadding;
      content = LayoutBuilder(
        builder: (context, constraints) {
          const markWidth = _identityMarkSize + _identityGap;
          final labelWidth = constraints.maxWidth - markWidth - buttonWidth;
          if (labelWidth >= _minLabelWidth) {
            return Row(
              children: [
                const _IdentityMark(),
                const SizedBox(width: _identityGap),
                Expanded(child: guestLabel),
                connect,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _IdentityMark(),
                  const SizedBox(width: _identityGap),
                  Expanded(child: guestLabel),
                ],
              ),
              // Under the label, not under the mark.
              Padding(
                padding: const EdgeInsets.only(left: markWidth),
                child: connect,
              ),
            ],
          );
        },
      );
    } else {
      // Without sign-in in this build, Shopify's checkout handles the guest.
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: BoutiqueSpace.lg),
      child: Container(
        key: const Key('checkout-identity'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BoutiqueRadius.card,
          border: Border.all(color: palette.hairline, width: .5),
        ),
        child: content,
      ),
    );
  }
}

/// The shopper's photo, or the account glyph.
class _IdentityMark extends StatelessWidget {
  const _IdentityMark({this.photo});

  final Uint8List? photo;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final image = photo;
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surfaceDeep,
          border: Border.all(color: palette.hairline, width: .5),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? Icon(Icons.person_outline, size: 20, color: palette.ink)
            : Image.memory(
                image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                // Bytes that do not decode fall back to the glyph.
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.person_outline, size: 20, color: palette.ink),
              ),
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({required this.lines, required this.subtotal});

  final List<BagLine> lines;
  final double subtotal;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tu pedido',
                  style: clientGuideStyle(context, MonettaTokens.sectionTitle),
                ),
              ),
              Text(
                '${lines.fold(0, (sum, line) => sum + line.quantity)} ART.',
                style: boutiqueEyebrow(size: 9, color: palette.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BoutiqueRadius.tile,
                    child: SizedBox(
                      width: 52,
                      height: 64,
                      child: _ProductImage(url: line.product.primaryImage),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: boutiqueText(
                            size: 12,
                            weight: FontWeight.w500,
                            color: palette.ink,
                          ),
                        ),
                        Text(
                          'Cantidad ${line.quantity}',
                          style:
                              boutiqueText(size: 11, color: palette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    kMoney.format(line.lineTotal),
                    style: boutiqueText(size: 12, color: palette.ink),
                  ),
                ],
              ),
            ),
          Container(height: .5, color: palette.hairline),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Subtotal', value: kMoney.format(subtotal)),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Envío estimado',
            value: 'Se calcula en Shopify',
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Total estimado',
            value: kMoney.format(subtotal),
            prominent: true,
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ColoredBox(
      color: palette.surfaceDeep,
      child: MonettaImage(
        url: url,
        cacheWidth: MediaUrl.thumbWidth,
        fallbackLabel: 'Monetta',
      ),
    );
  }
}

class _EmptyBag extends StatelessWidget {
  const _EmptyBag({this.embedded = false});

  /// Beside the catalog there is no store to go back to.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    if (embedded) {
      return Center(
        key: const Key('duo-empty-bag'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surfaceDeep,
                  border: Border.all(color: palette.hairline, width: .5),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 30,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Tu bolsa está vacía',
                textAlign: TextAlign.center,
                style: boutiqueDisplay(26),
              ),
              const SizedBox(height: 9),
              Text(
                'Lo que agregues aparecerá aquí. También puedes mantener '
                'presionada una pieza del catálogo y arrastrarla a este lado.',
                textAlign: TextAlign.center,
                style: boutiqueText(
                  size: 13,
                  color: palette.inkMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surfaceDeep,
                border: Border.all(color: palette.hairline, width: .5),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 30,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 22),
            Text('Tu bolsa está vacía', style: boutiqueDisplay(26)),
            const SizedBox(height: 9),
            Text(
              'Encuentra una pieza que quieras llevar contigo.',
              textAlign: TextAlign.center,
              style: boutiqueText(size: 13, color: palette.inkMuted),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 260,
              child: BoutiqueButton(
                label: 'VOLVER A LA TIENDA',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
