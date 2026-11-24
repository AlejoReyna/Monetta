/// Monetta's pre-checkout experience — paquete D (Fig.13 bolsa, Fig.14
/// checkout, Fig.15 confirmación).
///
/// El flujo se detiene antes de tarjeta: producto, entrega y revisión son de
/// Monetta; el pago vive en la URL alojada de Shopify para que los datos de
/// tarjeta nunca entren a la app. Nunca se inventan métodos (Oxxo/Meses/
/// PayPal): el panel de pago solo lista opciones reales recibidas por config;
/// sin config muestra el aviso alojado. Los totales finales son de Shopify;
/// los locales van marcados como estimación.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/account_controller.dart';
import '../../app/cart_controller.dart';
import '../../app/catalog_store.dart';
import '../../app/storefront_layout.dart';
import '../../data/customer_auth/customer_auth_error.dart';
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
import '../../data/local/database.dart' show OrderSummary;
import '../../data/media/media_url.dart';
import '../../data/shopify/cart/cart_repository.dart';
import '../../data/shopify/cart/cart_session_store.dart';
import '../../data/shopify/cart/checkout_launcher.dart';
import '../../domain/bag_line.dart';
import '../../domain/cart.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../catalog/quick_add_button.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_screen.dart';
import '../product/purchase_dock.dart';
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
/// no pedir la dirección dos veces. No guarda tarjeta.
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

/// Starts checkout directly with Shopify for the live bag, preserving account,
/// double-charge guards, and post-return verification without an intermediate
/// "Todo listo" screen.
Future<void> openCheckout(
  BuildContext context, {
  SecureCheckoutLauncher? launchSecureCheckout,
  ExternalCheckoutFallback? openExternalCheckout,
  CheckoutOrderLookup? orderLookup,
  CheckoutAttemptIdentity? attemptIdentity,
  Duration orderLookupInterval = kCheckoutOrderLookupInterval,
  Duration orderLookupTimeout = kCheckoutOrderLookupTimeout,
  CheckoutOrderDelay? orderLookupDelay,
  Future<void> Function(BuildContext context, CheckoutOrderMatch match)?
      onOrderFound,
  bool correlationAvailable = kCheckoutTokenCorrelationAvailable,
  Future<bool> Function(Uri uri)? openUri,
}) async {
  final store = StoreScope.of(context);
  final guard = ReviewingCheckoutScope.maybeOf(context);
  if (guard != null) {
    await guard.ensureLoaded();
    if (!context.mounted) return;
  }
  if (guard != null && guard.blocksCheckout(bagEmpty: store.bagLines.isEmpty)) {
    final choice = await showCheckoutDoubleChargeSheet(context);
    if (!context.mounted) return;
    if (choice == CheckoutDoubleChargeChoice.viewOrders) {
      openCheckoutOrders(context);
      return;
    }
    if (choice != CheckoutDoubleChargeChoice.payAnyway) return;
  }
  if (!context.mounted) return;
  final cart = CartScope.maybeOf(context);
  final controller = cart?.notifier;
  final checkout = cart?.checkoutCoordinator;
  final accountController = AccountScope.maybeOf(context);
  final hasProductionLauncher =
      controller != null && cart != null && checkout != null;
  // F05: no iniciar checkout cuando la configuración no puede abrir el pago.
  if (launchSecureCheckout == null && !hasProductionLauncher) {
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
  if (accountController != null &&
      !accountController.isSignedIn &&
      accountController.canLogin) {
    final decision = await _showGuestCheckoutChoiceSheet(
      context,
      accountController: accountController,
    );
    if (!context.mounted || decision == null) return;
  }
  final scope = cart == null
      ? null
      : _checkoutSessionScope(cart, accountController?.account?.localAccountId);
  final productionLauncher =
      controller == null || scope == null || checkout == null
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
              final buyerIdentity = await resolveCheckoutBuyerIdentity(
                account: accountController?.account,
                shopifyAccessToken:
                    accountController?.accessTokenForShopifyCheckout,
                email: draft.email,
                phone: draft.phone,
              );
              return checkout.present(
                controller: controller,
                scope: scope,
                localIntent: currentIntent,
                buyerIdentity: buyerIdentity,
                onCompleted: (purchase) async {
                  await store.applyCheckoutPurchase(purchase);
                  await accountController?.loadOrders();
                },
              );
            };
  final launcher = launchSecureCheckout ?? productionLauncher;
  if (launcher == null) return;

  final email = accountController?.account?.email?.trim() ?? '';
  final externalFallback =
      openExternalCheckout ?? checkout?.openExternalFallback;
  final resolvedLookup = orderLookup ??
      (accountController != null && accountController.isSignedIn
          ? AccountCheckoutOrderLookup(accountController)
          : null);
  CheckoutAttemptIdentity currentAttempt() {
    final cartSnapshot = controller?.snapshot?.cart;
    return attemptIdentity ??
        checkoutAttemptFromCart(
          cartId: cartSnapshot?.id,
          checkoutUrl: cartSnapshot?.checkoutUrl,
        );
  }

  NotificationScope.maybeOf(context)?.recordPushOutcome('checkout_started');
  final result = await launcher(
    CheckoutDraft(
      lines: List<BagLine>.of(store.bagLines),
      email: email,
      phone: '',
    ),
  );
  if (!context.mounted) return;

  switch (result) {
    case CheckoutCompleted():
      ReviewingCheckoutScope.maybeOf(context)?.clear();
      await _showCompletedOrderConfirmation(context, email: email);
    case CheckoutCancelled():
    case CheckoutFailed():
      final kind = classifyCheckoutResult(result);
      final initialPhase = switch (kind) {
        CheckoutReturnKind.completed => CheckoutReturnPhase.paymentNotCompleted,
        CheckoutReturnKind.sheetDidNotOpen =>
          CheckoutReturnPhase.sheetDidNotOpen,
        CheckoutReturnKind.paymentNotConfirmed => resolvedLookup == null
            ? CheckoutReturnPhase.reviewing
            : CheckoutReturnPhase.confirming,
      };
      if (initialPhase == CheckoutReturnPhase.reviewing) {
        ReviewingCheckoutScope.maybeOf(context)?.markActive();
      }
      await _showCheckoutReturnSheet(
        context,
        store: store,
        initialPhase: initialPhase,
        initialFailure: result is CheckoutFailed ? result : null,
        email: email,
        launcher: launcher,
        externalFallback: externalFallback,
        lookup: resolvedLookup,
        currentAttempt: currentAttempt,
        orderLookupInterval: orderLookupInterval,
        orderLookupTimeout: orderLookupTimeout,
        orderLookupDelay: orderLookupDelay,
        correlationAvailable: correlationAvailable,
        onOrderFound: onOrderFound,
        openUri: openUri,
      );
  }
}

void _showBrowserFallbackSnackBar(
  BuildContext context,
  CheckoutFailed failure,
  ExternalCheckoutFallback? fallback,
) {
  if (!failure.allowExternalBrowser || fallback == null) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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

Future<void> _showCompletedOrderConfirmation(
  BuildContext context, {
  required String email,
}) async {
  // Confirmación solo con evidencia del result. CheckoutCompleted no porta
  // identidad de pedido y la sincronización de Mis pedidos puede aún no incluir
  // el pedido nuevo: se muestra sin número hasta correlacionar por identidad.
  final navigator = Navigator.of(context);
  await showOrderConfirmation(
    context,
    orderLabel: null,
    email: email.isEmpty ? null : email,
    onViewOrder: () {
      navigator.pop();
      if (context.mounted) openCheckoutOrders(context);
    },
  );
}

Future<void> _openMatchedAccountOrder(
  BuildContext context,
  CheckoutOrderMatch match, {
  Future<void> Function(BuildContext context, CheckoutOrderMatch match)?
      onOrderFound,
  bool replaceRoute = false,
}) async {
  if (onOrderFound != null) {
    await onOrderFound(context, match);
    return;
  }
  if (!context.mounted) return;
  final account = AccountScope.maybeOf(context);
  if (account != null) await account.loadOrders();
  if (!context.mounted) return;
  OrderSummary? summary;
  for (final order in account?.orders ?? const <OrderSummary>[]) {
    if (order.id == match.orderId ||
        (order.shopifyOrderId != null &&
            order.shopifyOrderId == match.orderId)) {
      summary = order;
      break;
    }
  }
  if (summary == null || !context.mounted) return;
  final matched = summary;
  final route = MaterialPageRoute<void>(
    builder: (_) => OrderDetailScreen(
      order: matched,
      rewardsController: account,
    ),
  );
  if (replaceRoute) {
    await Navigator.of(context).pushReplacement(route);
  } else {
    await Navigator.of(context).push(route);
  }
}

Future<void> _openConciergeWhatsAppUri(
  BuildContext context, {
  Future<bool> Function(Uri uri)? openUri,
}) async {
  final uri = conciergeWhatsAppUri();
  final open = openUri ??
      ((target) => launchUrl(target, mode: LaunchMode.externalApplication));
  final ok = await open(uri);
  if (!ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el enlace.')),
    );
  }
}

Future<void> _showCheckoutReturnSheet(
  BuildContext context, {
  required CatalogStore store,
  required CheckoutReturnPhase initialPhase,
  required CheckoutFailed? initialFailure,
  required String email,
  required SecureCheckoutLauncher launcher,
  required ExternalCheckoutFallback? externalFallback,
  required CheckoutOrderLookup? lookup,
  required CheckoutAttemptIdentity Function() currentAttempt,
  required Duration orderLookupInterval,
  required Duration orderLookupTimeout,
  required CheckoutOrderDelay? orderLookupDelay,
  required bool correlationAvailable,
  required Future<void> Function(
    BuildContext context,
    CheckoutOrderMatch match,
  )? onOrderFound,
  required Future<bool> Function(Uri uri)? openUri,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => StoreScope(
      notifier: store,
      child: _CheckoutReturnSheet(
        checkoutContext: context,
        initialPhase: initialPhase,
        initialFailure: initialFailure,
        email: email,
        launcher: launcher,
        externalFallback: externalFallback,
        lookup: lookup,
        currentAttempt: currentAttempt,
        orderLookupInterval: orderLookupInterval,
        orderLookupTimeout: orderLookupTimeout,
        orderLookupDelay: orderLookupDelay,
        correlationAvailable: correlationAvailable,
        onOrderFound: onOrderFound,
        openUri: openUri,
      ),
    ),
  );
}

class _CheckoutReturnSheet extends StatefulWidget {
  const _CheckoutReturnSheet({
    required this.checkoutContext,
    required this.initialPhase,
    required this.initialFailure,
    required this.email,
    required this.launcher,
    required this.externalFallback,
    required this.lookup,
    required this.currentAttempt,
    required this.orderLookupInterval,
    required this.orderLookupTimeout,
    required this.orderLookupDelay,
    required this.correlationAvailable,
    required this.onOrderFound,
    required this.openUri,
  });

  final BuildContext checkoutContext;
  final CheckoutReturnPhase initialPhase;
  final CheckoutFailed? initialFailure;
  final String email;
  final SecureCheckoutLauncher launcher;
  final ExternalCheckoutFallback? externalFallback;
  final CheckoutOrderLookup? lookup;
  final CheckoutAttemptIdentity Function() currentAttempt;
  final Duration orderLookupInterval;
  final Duration orderLookupTimeout;
  final CheckoutOrderDelay? orderLookupDelay;
  final bool correlationAvailable;
  final Future<void> Function(BuildContext context, CheckoutOrderMatch match)?
      onOrderFound;
  final Future<bool> Function(Uri uri)? openUri;

  @override
  State<_CheckoutReturnSheet> createState() => _CheckoutReturnSheetState();
}

class _CheckoutReturnSheetState extends State<_CheckoutReturnSheet> {
  late CheckoutReturnPhase _phase = widget.initialPhase;
  late CheckoutFailed? _failure = widget.initialFailure;
  String? _browserError;
  bool _openingSheet = false;
  int _generation = 0;
  Timer? _pollTimer;
  Completer<void>? _pollDelay;

  @override
  void initState() {
    super.initState();
    if (_phase == CheckoutReturnPhase.confirming && widget.lookup != null) {
      unawaited(_runReturnLookup(widget.lookup!, ++_generation));
    }
  }

  @override
  void dispose() {
    _generation += 1;
    _pollTimer?.cancel();
    final completer = _pollDelay;
    if (completer != null && !completer.isCompleted) completer.complete();
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

  Future<void> _runReturnLookup(
    CheckoutOrderLookup lookup,
    int generation,
  ) async {
    final decision = await resolvePaymentReturn(
      lookup: lookup,
      attempt: widget.currentAttempt(),
      interval: widget.orderLookupInterval,
      timeout: widget.orderLookupTimeout,
      correlationAvailable: widget.correlationAvailable,
      delay: _delayPoll,
      isCancelled: () => !mounted || generation != _generation,
    );
    if (!mounted || generation != _generation) return;
    if (decision is CheckoutOrderFound) {
      ReviewingCheckoutScope.maybeOf(context)?.clear();
      final checkoutContext = widget.checkoutContext;
      Navigator.pop(context);
      if (checkoutContext.mounted) {
        await _openMatchedAccountOrder(
          checkoutContext,
          decision.match,
          onOrderFound: widget.onOrderFound,
        );
      }
      return;
    }
    if (decision is! CheckoutOrderNotFound) {
      ReviewingCheckoutScope.maybeOf(context)?.markActive();
    }
    setState(() {
      _phase = decision is CheckoutOrderNotFound
          ? CheckoutReturnPhase.paymentNotCompleted
          : CheckoutReturnPhase.reviewing;
    });
  }

  Future<void> _retry() async {
    if (_openingSheet) return;
    final store = StoreScope.of(context);
    final generation = ++_generation;
    setState(() {
      _openingSheet = true;
      _failure = null;
      _browserError = null;
    });
    try {
      final result = await widget.launcher(
        CheckoutDraft(
          lines: List<BagLine>.of(store.bagLines),
          email: widget.email,
          phone: '',
        ),
      );
      if (!mounted || generation != _generation) return;
      setState(() => _openingSheet = false);
      switch (result) {
        case CheckoutCompleted():
          ReviewingCheckoutScope.maybeOf(context)?.clear();
          final checkoutContext = widget.checkoutContext;
          Navigator.pop(context);
          if (checkoutContext.mounted) {
            await _showCompletedOrderConfirmation(
              checkoutContext,
              email: widget.email,
            );
          }
        case CheckoutCancelled():
        case CheckoutFailed():
          _failure = result is CheckoutFailed ? result : null;
          final kind = classifyCheckoutResult(result);
          if (kind == CheckoutReturnKind.sheetDidNotOpen) {
            setState(() {
              _phase = CheckoutReturnPhase.sheetDidNotOpen;
            });
            return;
          }
          final lookup = widget.lookup;
          if (lookup == null) {
            ReviewingCheckoutScope.maybeOf(context)?.markActive();
            setState(() => _phase = CheckoutReturnPhase.reviewing);
            return;
          }
          setState(() => _phase = CheckoutReturnPhase.confirming);
          await _runReturnLookup(lookup, generation);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _openingSheet = false);
      }
    }
  }

  Future<void> _openBrowser(ExternalCheckoutFallback fallback) async {
    if (_openingSheet) return;
    final guard = ReviewingCheckoutScope.maybeOf(widget.checkoutContext);
    setState(() {
      _openingSheet = true;
      _browserError = null;
    });
    var opened = false;
    try {
      opened = await fallback();
    } on Exception {
      // Keep the retry and browser actions available if the browser fails.
    }
    if (opened && widget.checkoutContext.mounted) guard?.markActive();
    if (!mounted) return;
    setState(() {
      _openingSheet = false;
      if (opened) {
        _phase = CheckoutReturnPhase.reviewing;
        _failure = null;
      } else {
        _browserError = 'No se pudo abrir el navegador.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final fallback = _phase == CheckoutReturnPhase.sheetDidNotOpen &&
            _failure?.allowExternalBrowser == true
        ? widget.externalFallback
        : null;
    return Material(
      color: palette.canvas,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Cerrar',
                onPressed: _openingSheet ? null : () => Navigator.pop(context),
                icon: Icon(Icons.close, color: palette.inkMuted),
              ),
            ),
            CheckoutReturnBanner(
              phase: _phase,
              bodyOverride: _phase == CheckoutReturnPhase.sheetDidNotOpen
                  ? _failure?.userMessage
                  : null,
              onRetry: _openingSheet ? null : () => unawaited(_retry()),
              onViewOrders: () {
                final checkoutContext = widget.checkoutContext;
                Navigator.pop(context);
                if (checkoutContext.mounted) {
                  openCheckoutOrders(checkoutContext);
                }
              },
              onWhatsApp: () => unawaited(
                _openConciergeWhatsAppUri(context, openUri: widget.openUri),
              ),
            ),
            if (fallback != null)
              BoutiqueButton(
                label: 'Abrir en navegador',
                filled: false,
                onPressed: _openingSheet
                    ? null
                    : () => unawaited(_openBrowser(fallback)),
              ),
            if (_browserError case final error?) Text(error),
          ],
        ),
      ),
    );
  }
}

CartSessionScope _checkoutSessionScope(CartScope cart, String? accountId) =>
    accountId == null
        ? CartSessionScope.guest(shopDomain: cart.shopDomain)
        : CartSessionScope.authenticated(
            shopDomain: cart.shopDomain,
            localAccountId: accountId,
          );

enum _GuestCheckoutChoice { signedIn, guest }

Future<_GuestCheckoutChoice?> _showGuestCheckoutChoiceSheet(
  BuildContext context, {
  required AccountController accountController,
}) {
  return showModalBottomSheet<_GuestCheckoutChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (context) => _GuestCheckoutChoiceSheet(
      accountController: accountController,
    ),
  );
}

class _GuestCheckoutChoiceSheet extends StatefulWidget {
  const _GuestCheckoutChoiceSheet({required this.accountController});

  final AccountController accountController;

  @override
  State<_GuestCheckoutChoiceSheet> createState() =>
      _GuestCheckoutChoiceSheetState();
}

class _GuestCheckoutChoiceSheetState extends State<_GuestCheckoutChoiceSheet> {
  bool _signingIn = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });
    await widget.accountController.login();
    if (!mounted) return;
    if (widget.accountController.isSignedIn) {
      Navigator.of(context).pop(_GuestCheckoutChoice.signedIn);
      return;
    }
    final error = widget.accountController.lastError;
    setState(() {
      _signingIn = false;
      _errorMessage = error != null && !error.isSilent
          ? _guestSignInErrorMessage(error.kind)
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final bottom = math.max(
      MediaQuery.paddingOf(context).bottom,
      MediaQuery.viewInsetsOf(context).bottom,
    );
    return Material(
      key: const ValueKey('g39-choice-sheet'),
      color: palette.canvas,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          BoutiqueSpace.gutter,
          BoutiqueSpace.md,
          BoutiqueSpace.gutter,
          bottom + BoutiqueSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '¿Cómo deseas continuar?',
                    style: boutiqueDisplay(22),
                  ),
                ),
                IconButton(
                  key: const ValueKey('g39-close'),
                  tooltip: 'Cerrar',
                  onPressed:
                      _signingIn ? null : () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: palette.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: BoutiqueSpace.sm),
            Text(
              'Inicia sesión para asociar tu pedido a tu cuenta o continúa '
              'como invitado. Conservamos todos los artículos de tu carrito.',
              style: boutiqueText(size: 13, color: palette.inkMuted),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: BoutiqueSpace.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorMessage!,
                  key: const ValueKey('g39-error'),
                  style: boutiqueText(size: 13, color: palette.sale),
                ),
              ),
            ],
            const SizedBox(height: BoutiqueSpace.xl),
            PurchaseDockButton(
              key: const ValueKey('g39-sign-in'),
              label: _signingIn ? 'Iniciando sesión…' : 'Iniciar sesión',
              pending: _signingIn,
              large: true,
              halo: true,
              onPressed: _signingIn ? null : _signIn,
            ),
            const SizedBox(height: BoutiqueSpace.sm),
            OutlinedButton(
              key: const ValueKey('g39-continue-guest'),
              onPressed: _signingIn
                  ? null
                  : () => Navigator.of(context).pop(_GuestCheckoutChoice.guest),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, kPurchaseButtonHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: BoutiqueSpace.xl,
                  vertical: BoutiqueSpace.sm,
                ),
                side: BorderSide(color: palette.borderControl),
                shape: const StadiumBorder(),
                foregroundColor: palette.ink,
                backgroundColor: palette.canvas,
              ),
              child: Text(
                'Continuar como invitado',
                textAlign: TextAlign.center,
                style: boutiqueText(
                  size: 15,
                  color: _signingIn
                      ? palette.ink.withValues(alpha: 0.45)
                      : palette.ink,
                  height: 1.2,
                ).copyWith(letterSpacing: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _guestSignInErrorMessage(CustomerAuthErrorKind kind) {
  switch (kind) {
    case CustomerAuthErrorKind.cancelled:
      return '';
    case CustomerAuthErrorKind.offline:
      return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
    case CustomerAuthErrorKind.configuration:
      return 'El inicio de sesión no está disponible en esta versión de la app.';
    case CustomerAuthErrorKind.sessionExpired:
      return 'Tu sesión terminó. Inicia sesión de nuevo.';
    case CustomerAuthErrorKind.server:
      return 'Shopify no pudo completar el inicio de sesión. Inténtalo en un momento.';
    case CustomerAuthErrorKind.unknown:
      return 'No se pudo iniciar sesión. Inténtalo de nuevo.';
  }
}

Future<void> openBag(
  BuildContext context, {
  SecureCheckoutLauncher? launchSecureCheckout,
}) {
  // A two-sided window keeps the bag on its right side.
  if (DuoWorkspace.showBag(context)) return Future<void>.value();
  return showBagDrawer(
    context,
    title: 'Carrito',
    launchSecureCheckout: launchSecureCheckout,
  );
}

Future<void> showBagDrawer(
  BuildContext context, {
  required String title,
  SecureCheckoutLauncher? launchSecureCheckout,
}) async {
  // Adds from recommendations update the bag already visible.
  if (ModalRoute.of(context)?.settings.name == DuoWorkspace.bagRoute) return;
  final origin = FocusManager.instance.primaryFocus;
  final store = StoreScope.of(context);
  final proceed = await showGeneralDialog<bool>(
    context: context,
    anchorPoint: presentationAnchor(context),
    routeSettings: const RouteSettings(name: DuoWorkspace.bagRoute),
    barrierLabel: 'Cerrar carrito',
    barrierDismissible: true,
    barrierColor: context.monettaColors.scrim,
    transitionDuration: reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    transitionBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(animation),
      child: child,
    ),
    pageBuilder: (_, __, ___) => Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: StoreScope(
            notifier: store,
            child: BagScreen(
              drawerTitle: title,
              launchSecureCheckout: launchSecureCheckout,
            ),
          ),
        ),
      ),
    ),
  );
  if (origin?.context?.mounted == true && origin!.canRequestFocus) {
    origin.requestFocus();
  }
  if (proceed == true && context.mounted) {
    await openCheckout(
      context,
      launchSecureCheckout: launchSecureCheckout,
    );
  }
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
    this.drawerTitle,
    super.key,
  });

  final SecureCheckoutLauncher? launchSecureCheckout;
  final String? drawerTitle;

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
  bool _openingCheckout = false;

  Future<void> _continueToCheckout() async {
    if (_openingCheckout) return;
    final navigator = Navigator.of(context);
    if (widget.drawerTitle != null &&
        ModalRoute.of(context)?.settings.name == DuoWorkspace.bagRoute &&
        navigator.canPop()) {
      navigator.pop(true);
      return;
    }
    setState(() => _openingCheckout = true);
    try {
      await openCheckout(
        context,
        launchSecureCheckout: widget.launchSecureCheckout,
      );
    } finally {
      if (mounted) setState(() => _openingCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final lines = store.bagLines;
    final drawerTitle = widget.drawerTitle;
    final cartScope = CartScope.maybeOf(context);
    final accountId = AccountScope.maybeOf(context)?.account?.localAccountId;
    final sessionScope =
        cartScope == null ? null : _checkoutSessionScope(cartScope, accountId);
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
      appBar: drawerTitle != null || widget.embedded
          ? null
          : _BoutiqueBar(
              leading: IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
      body: SafeArea(
        bottom: drawerTitle == null && !widget.embedded,
        child: Column(
          children: [
            if (drawerTitle != null)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(drawerTitle, style: boutiqueDisplay(26)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar carrito',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SystemUsableSurface(
                child: lines.isEmpty
                    ? _EmptyBag(
                        embedded: widget.embedded,
                        onContinueShopping: drawerTitle != null
                            ? () => Navigator.of(context).pop()
                            : null,
                      )
                    : _BagContents(
                        lines: lines,
                        onContinueToCheckout:
                            _openingCheckout ? null : _continueToCheckout,
                        cartController: cartScope?.notifier,
                        cartScope: sessionScope,
                        localIntent: localIntent,
                        embedded: widget.embedded,
                        inDrawer: drawerTitle != null,
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: drawerTitle != null ||
              !SystemLayoutScope.of(context).supported
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
    required this.onContinueToCheckout,
    required this.cartController,
    required this.cartScope,
    required this.localIntent,
    this.embedded = false,
    this.inDrawer = false,
  });

  final List<BagLine> lines;
  final VoidCallback? onContinueToCheckout;
  final CartController? cartController;
  final CartSessionScope? cartScope;
  final List<LocalCartIntent> localIntent;

  /// On a two-sided window's right side the catalog beside it is the place to
  /// discover more, so the bag carries no recommendations.
  final bool embedded;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final count = store.bagQuantity;

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

        final payLabel = onContinueToCheckout == null
            ? 'Abriendo pago seguro…'
            : (inDrawer ? 'Continuar al pago' : 'Continuar al checkout');
        final isLight = Theme.of(context).brightness == Brightness.light;
        final boutiqueCta = BoutiqueButton(
          key: const ValueKey('bag-continue-button'),
          label: payLabel,
          filled: !isLight,
          onPressed: onContinueToCheckout,
        );
        final payButton = SizedBox(
          width: double.infinity,
          child: isLight
              ? GuideGlassSurface(
                  halo: true,
                  radius: MonettaTokens.radiusPill,
                  child: boutiqueCta,
                )
              : boutiqueCta,
        );

        final Widget? summary =
            controller != null && scope != null && hasRemoteCart
                ? ShopifyCartSummary(
                    controller: controller,
                    scope: scope,
                    localIntent: localIntent,
                  )
                : null;

        final bagIds = {for (final line in lines) line.product.id};
        final recommendations = embedded
            ? const SizedBox.shrink()
            : _BagRecommendations(excludeIds: bagIds, inDrawer: inDrawer);

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
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const PurchasePolicyNotice(
                                  key: ValueKey('purchase-policy-notice'),
                                ),
                                const SizedBox(height: 16),
                                payButton,
                                if (summary != null) ...[
                                  const SizedBox(height: 16),
                                  summary,
                                ],
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

        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: 32 + (inDrawer ? MediaQuery.paddingOf(context).bottom : 0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              lineTiles,
              incentive,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: payButton,
              ),
              if (summary != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: summary,
                ),
              recommendations,
              if (inDrawer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Center(
                    child: _ContinueShoppingButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
            ],
          ),
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

  /// Métodos reales configurados en Shopify (nombres oficiales). Vacío = no
  /// hay evidencia de config, así que no se dibuja ningún radio inventado y
  /// se muestra el aviso alojado. El orquestador los conecta cuando existan.
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
  final _email = TextEditingController();
  bool _openingSheet = false;
  bool _checkingOrder = false;
  bool _orderFound = false;
  bool _didPrefillContact = false;
  int _returnGeneration = 0;
  CheckoutReturnPhase? _returnPhase;
  String? _returnDetail;
  String? _selectedPayment;
  Timer? _pollTimer;
  Completer<void>? _pollDelay;

  bool get _retryBlocked => _openingSheet || _checkingOrder || _orderFound;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrefillContact) return;
    _didPrefillContact = true;
    final account = AccountScope.maybeOf(context)?.account;
    final email = account?.email?.trim();
    if (email != null && email.isNotEmpty && _email.text.isEmpty) {
      _email.text = email;
    }
  }

  @override
  void dispose() {
    _returnGeneration += 1;
    _finishPollDelay();
    _scrollController.dispose();
    _email.dispose();
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

  void _showBrowserFallback(CheckoutFailed failure) =>
      _showBrowserFallbackSnackBar(
        context,
        failure,
        widget.openExternalCheckout,
      );

  Future<void> _openConciergeWhatsApp() =>
      _openConciergeWhatsAppUri(context, openUri: widget.openUri);

  void _viewOrders() => openCheckoutOrders(context);

  void _activateReviewing() {
    ReviewingCheckoutScope.maybeOf(context)?.markActive();
  }

  void _deactivateReviewing() {
    ReviewingCheckoutScope.maybeOf(context)?.clear();
  }

  Future<void> _openMatchedOrder(CheckoutOrderMatch match) =>
      _openMatchedAccountOrder(
        context,
        match,
        onOrderFound: widget.onOrderFound,
        replaceRoute: true,
      );

  Future<void> _pay() async {
    if (_retryBlocked) return;
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
        final email = _email.text.trim();
        final result = await launcher(
          CheckoutDraft(
            lines: lines,
            email: email,
            phone: '',
          ),
        );
        if (!mounted || generation != _returnGeneration) return;
        setState(() => _openingSheet = false);
        switch (result) {
          case CheckoutCompleted():
            _deactivateReviewing();
            setState(() => _returnPhase = null);
            await _showCompletedOrderConfirmation(context, email: email);
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
            final form = _ReviewPanel(
              email: _email.text,
              openingSheet: _openingSheet,
              returnPhase: _returnPhase,
              returnDetail: _returnDetail,
              payEnabled: !_retryBlocked,
              showPayButton: !_orderFound,
              paymentMethods: widget.availablePaymentMethods,
              selectedPayment: _selectedPayment,
              onSelectPayment: (value) =>
                  setState(() => _selectedPayment = value),
              onPay: () => unawaited(_pay()),
              onViewOrders: _viewOrders,
              onWhatsApp: () => unawaited(_openConciergeWhatsApp()),
            );

            final summary = _CheckoutSummary(
              lines: store.bagLines,
              subtotal: store.bagSubtotal,
            );

            // A two-sided window: the form on the left of the crease and the
            // order summary held on the right, each scrolling on its own.
            final crease = _creaseWithin(context, origin & box.biggest);
            if (crease != null) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: crease.left,
                    child: SingleChildScrollView(
                      key: const Key('checkout-duo-form'),
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: form,
                      ),
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
                      key: const Key('checkout-duo-summary'),
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                      child: summary,
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
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                          child: form,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: summary,
                        ),
                      ],
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
                            Expanded(flex: 6, child: form),
                            const SizedBox(width: 56),
                            Expanded(flex: 4, child: summary),
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
              child: _ProductImage(
                url: line.variant.imageUrls.firstOrNull ??
                    line.product.primaryImage,
              ),
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
              onPressed: quantity <= 1 ? null : () => onChanged(quantity - 1),
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
  const _BagRecommendations({required this.excludeIds, required this.inDrawer});

  final Set<String> excludeIds;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final limit = inDrawer ? 3 : 8;
    final feed = store
        .feed(limit: 20)
        .map((r) => r.product)
        .where(
          (p) => !excludeIds.contains(p.id) && p.isInStock,
        )
        .take(limit)
        .toList(growable: false);
    final items = feed.isNotEmpty
        ? feed
        : store.products
            .where((p) => !excludeIds.contains(p.id) && p.isInStock)
            .take(limit)
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
              inDrawer ? 'Le quedaría bien con esto…' : 'Recomendaciones',
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductCard(
                        product: product,
                        density: ProductTileDensity.compact,
                      ),
                      if (inDrawer)
                        Positioned(
                          top: 94,
                          right: 4,
                          child: ProductQuickAddButton(
                            key: ValueKey(
                              'bag-recommendation-add-${product.id}',
                            ),
                            product: product,
                            productName: product.title,
                          ),
                        ),
                    ],
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

class _ContinueShoppingButton extends StatelessWidget {
  const _ContinueShoppingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: palette.ink),
      onPressed: onPressed,
      child: Text(
        'Seguir comprando',
        style: boutiqueText(
          size: 14,
          weight: FontWeight.w500,
          color: palette.ink,
        ),
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

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.email,
    required this.openingSheet,
    required this.returnPhase,
    this.returnDetail,
    required this.payEnabled,
    required this.showPayButton,
    required this.paymentMethods,
    required this.selectedPayment,
    required this.onSelectPayment,
    required this.onPay,
    required this.onViewOrders,
    required this.onWhatsApp,
  });

  final String email;
  final bool openingSheet;
  final CheckoutReturnPhase? returnPhase;
  final String? returnDetail;
  final bool payEnabled;
  final bool showPayButton;
  final List<String> paymentMethods;
  final String? selectedPayment;
  final ValueChanged<String> onSelectPayment;
  final VoidCallback onPay;
  final VoidCallback onViewOrders;
  final VoidCallback onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final cleanEmail = email.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Todo listo', style: boutiqueDisplay(28)),
        const SizedBox(height: 8),
        Text(
          'Revisa tu pedido y continúa al pago seguro.',
          style: boutiqueText(size: 13, color: palette.inkMuted),
        ),
        const SizedBox(height: 28),
        if (cleanEmail.isNotEmpty)
          _ReviewBlock(
            title: 'Contacto',
            value: cleanEmail,
          ),
        _PaymentBlock(
          methods: paymentMethods,
          selected: selectedPayment,
          onSelect: onSelectPayment,
        ),
        const SizedBox(height: 24),
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
            label: 'CONTINUAR AL PAGO SEGURO',
            onPressed: payEnabled ? onPay : null,
          ),
        const SizedBox(height: 14),
        Text(
          'Shopify procesa el pago. Monetta nunca ve los datos de tu tarjeta.',
          style: boutiqueText(size: 12, color: palette.inkMuted),
        ),
      ],
    );
  }
}

/// Pago Fig.14 sin inventar: solo dibuja radios cuando hay opciones reales
/// configuradas. Sin config muestra el aviso alojado.
class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({
    required this.methods,
    required this.selected,
    required this.onSelect,
  });

  final List<String> methods;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    if (methods.isEmpty) {
      return Container(
        key: const ValueKey('payment-hosted-notice'),
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BoutiqueRadius.card,
          border: Border.all(color: palette.hairline, width: .5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 18, color: palette.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Método de pago',
                    style: boutiqueEyebrow(size: 10, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pagos seguros con Shopify.',
                    style: boutiqueText(
                      size: 13,
                      weight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elige tu método de pago en el checkout alojado. Monetta nunca ve los datos de tu tarjeta y no guarda métodos.',
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.hairline, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'MÉTODO DE PAGO',
              style: boutiqueEyebrow(size: 10, color: palette.inkMuted),
            ),
          ),
          for (final method in methods)
            _RealPaymentOption(
              label: method,
              selected: (selected ?? methods.first) == method,
              onTap: () => onSelect(method),
            ),
          SizedBox(height: MonettaTokens.space[3]),
          SecurePaymentLine(methods: methods),
        ],
      ),
    );
  }
}

class _RealPaymentOption extends StatelessWidget {
  const _RealPaymentOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Método de pago $label',
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BoutiqueRadius.tile,
        child: InkWell(
          onTap: onTap,
          borderRadius: BoutiqueRadius.tile,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.ink, width: 1.2),
                  ),
                  child: selected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: palette.ink,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: boutiqueText(size: 13, color: palette.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.hairline, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              title.toUpperCase(),
              style: boutiqueEyebrow(size: 9, color: palette.inkMuted),
            ),
          ),
          Expanded(
            child:
                Text(value, style: boutiqueText(size: 13, color: palette.ink)),
          ),
        ],
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
          Builder(
            builder: (context) {
              final cart = CartScope.maybeOf(context)?.notifier?.snapshot?.cart;
              final allocatedApplications = cart?.discountApplications
                      .where((item) => item.totalAllocatedAmount != null)
                      .toList(growable: false) ??
                  const <CartDiscountApplication>[];
              final hasShopifyDiscounts =
                  cart != null && allocatedApplications.isNotEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    label: 'Subtotal',
                    value: hasShopifyDiscounts
                        ? '${cart.cost.subtotal.amount} ${cart.cost.subtotal.currencyCode}'
                        : kMoney.format(subtotal),
                  ),
                  for (final application in allocatedApplications) ...[
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: application.code != null
                          ? 'Descuento (${application.code})'
                          : application.kind ==
                                  CartDiscountApplicationKind.automatic
                              ? 'Descuento automático'
                              : 'Descuento aplicado',
                      value:
                          '−${application.totalAllocatedAmount!.amount} ${application.totalAllocatedAmount!.currencyCode}',
                    ),
                  ],
                  const SizedBox(height: 14),
                  _SummaryRow(
                    label: 'Total estimado',
                    value: hasShopifyDiscounts
                        ? '${cart.cost.total.amount} ${cart.cost.total.currencyCode}'
                        : kMoney.format(subtotal),
                    prominent: true,
                  ),
                ],
              );
            },
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
  const _EmptyBag({this.embedded = false, this.onContinueShopping});

  /// Beside the catalog there is no store to go back to.
  final bool embedded;
  final VoidCallback? onContinueShopping;

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
            if (onContinueShopping != null) ...[
              const SizedBox(height: 12),
              _ContinueShoppingButton(onPressed: onContinueShopping!),
            ],
          ],
        ),
      ),
    );
  }
}
