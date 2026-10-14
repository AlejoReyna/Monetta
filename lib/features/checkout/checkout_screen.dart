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

import 'package:flutter/material.dart';

import '../navigation/monetta_page_header.dart';
import 'package:flutter/services.dart';

import '../../app/cart_controller.dart';
import '../../app/checkout_buyer_identity.dart';
import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/shopify_checkout_coordinator.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../data/shopify/cart/cart_repository.dart';
import '../../data/shopify/cart/cart_session_store.dart';
import '../../data/shopify/cart/checkout_launcher.dart';
import '../../domain/bag_line.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../catalog/product_card.dart';
import '../product/quick_view.dart';
import 'checkout_summary_row.dart';
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

Future<void> openBag(
  BuildContext context, {
  SecureCheckoutLauncher? launchSecureCheckout,
}) {
  final store = StoreScope.of(context);
  return Navigator.of(context).push(
    monettaPageRoute(
      StoreScope(
        notifier: store,
        child: BagScreen(launchSecureCheckout: launchSecureCheckout),
      ),
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
  const BagScreen({this.launchSecureCheckout, super.key});

  final SecureCheckoutLauncher? launchSecureCheckout;

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
        : account == null
            ? CartSessionScope.guest(shopDomain: cartScope.shopDomain)
            : CartSessionScope.authenticated(
                shopDomain: cartScope.shopDomain,
                localAccountId: account.localAccountId,
              );
    final localIntent = [
      for (final line in lines)
        LocalCartIntent(variantId: line.variant.id, quantity: line.quantity),
    ];
    if (cartScope != null && sessionScope != null && lines.isNotEmpty) {
      _scheduleReconciliation(
        cartScope.notifier!,
        cartScope.checkoutCoordinator,
        sessionScope,
        localIntent,
      );
    }

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: buildMonettaPageAppBar(
        context,
        title: 'Mi bolsa',
        titleRowKey: const ValueKey('bag-heading-row'),
        trailingLabel:
            '${store.bagQuantity} ${store.bagQuantity == 1 ? 'artículo' : 'artículos'}',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: SafeArea(
        bottom: true,
        child: lines.isEmpty
            ? const _EmptyBag()
            : _BagContents(
                lines: lines,
                launchSecureCheckout: widget.launchSecureCheckout,
                cartController: cartScope?.notifier,
                checkoutCoordinator: cartScope?.checkoutCoordinator,
                cartScope: sessionScope,
                localIntent: localIntent,
              ),
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
  });

  final List<BagLine> lines;
  final SecureCheckoutLauncher? launchSecureCheckout;
  final CartController? cartController;
  final ShopifyCheckoutCoordinator? checkoutCoordinator;
  final CartSessionScope? cartScope;
  final List<LocalCartIntent> localIntent;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final subtotal = store.bagSubtotal;
    final shipping = _shippingFor(subtotal);

    void continueToCheckout() {
      final controller = cartController;
      final scope = cartScope;
      final checkout = checkoutCoordinator;
      final accountController = AccountScope.maybeOf(context);
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
                  final currentAccount = accountController?.account;
                  final currentScope = currentAccount == null
                      ? CartSessionScope.guest(shopDomain: scope.shopDomain)
                      : CartSessionScope.authenticated(
                          shopDomain: scope.shopDomain,
                          localAccountId: currentAccount.localAccountId,
                        );
                  return checkout.present(
                    controller: controller,
                    scope: currentScope,
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
      Navigator.of(context).push(
        monettaPageRoute(
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
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
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

        final controller = cartController;
        final scope = cartScope;
        final hasRemoteCart = controller?.scopedSnapshot?.scope == scope &&
            controller?.snapshot?.cart != null;
        final summary = controller != null && scope != null && hasRemoteCart
            ? ShopifyCartSummary(
                controller: controller,
                scope: scope,
                localIntent: localIntent,
                onContinue: continueToCheckout,
              )
            : _OrderSummary(
                subtotal: subtotal,
                shipping: shipping,
                ctaLabel: 'Continuar al checkout',
                onContinue: continueToCheckout,
              );

        final bagIds = {for (final line in lines) line.product.id};
        final recommendations = _BagRecommendations(excludeIds: bagIds);

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
                            children: [lineTiles],
                          ),
                        ),
                        const SizedBox(width: 48),
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: summary,
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
            lineTiles,
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
    super.key,
  });

  final SecureCheckoutLauncher? launchSecureCheckout;
  final ExternalCheckoutFallback? openExternalCheckout;

  /// Métodos reales configurados en Shopify (nombres oficiales). Vacío = no
  /// hay evidencia de config, así que no se dibuja ningún radio inventado y
  /// se muestra el aviso alojado. El orquestador los conecta cuando existan.
  final List<String> availablePaymentMethods;

  @override
  State<CheckoutFlowScreen> createState() => _CheckoutFlowScreenState();
}

class _CheckoutFlowScreenState extends State<CheckoutFlowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _reviewing = false;
  bool _launching = false;
  String? _prefilledAccountId;
  String? _selectedPayment;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = AccountScope.maybeOf(context)?.account;
    if (account == null || _prefilledAccountId == account.localAccountId) {
      return;
    }
    _prefilledAccountId = account.localAccountId;
    final email = account.email?.trim();
    if (email != null && email.isNotEmpty && _email.text.isEmpty) {
      _email.text = email;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final controller = AccountScope.maybeOf(context);
    if (controller == null || !controller.canLogin || controller.isLoading) {
      return;
    }
    await controller.login();
    if (!mounted || controller.isSignedIn) return;
    final error = controller.lastError;
    if (error != null && !error.isSilent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos iniciar sesión. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  void _review() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _reviewing = true);
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pay() async {
    final store = StoreScope.of(context);
    final lines = store.bagLines;
    if (widget.launchSecureCheckout case final launcher?) {
      NotificationScope.maybeOf(context)?.recordPushOutcome('checkout_started');
      setState(() => _launching = true);
      try {
        final email = _email.text.trim();
        final result = await launcher(
          CheckoutDraft(
            lines: lines,
            email: email,
            phone: _phone.text.trim(),
          ),
        );
        if (!mounted) return;
        switch (result) {
          case CheckoutCompleted():
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Checkout cancelado. Tu bolsa se conserva.'),
              ),
            );
          case CheckoutFailed(:final userMessage):
            final fallback = widget.openExternalCheckout;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  fallback == null
                      ? userMessage
                      : '$userMessage Abrir el navegador no confirma el pago; '
                          'revisa Mis pedidos si terminaste ahí.',
                ),
                action: fallback == null
                    ? null
                    : SnackBarAction(
                        label: 'ABRIR NAVEGADOR',
                        onPressed: () => unawaited(fallback()),
                      ),
              ),
            );
        }
      } finally {
        if (mounted) setState(() => _launching = false);
      }
      return;
    }
    if (!mounted) return;
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
        appBar: buildMonettaPageAppBar(context, title: 'Mi bolsa'),
        body: const SafeArea(child: _EmptyBag()),
      );
    }

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: buildMonettaPageAppBar(
        context,
        title: 'Checkout',
        onBack: _reviewing
            ? () => setState(() => _reviewing = false)
            : () => Navigator.of(context).pop(),
        actionsWidth: 96,
        actions: [
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
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final form = _reviewing
                      ? _ReviewPanel(
                          email: _email.text,
                          phone: _phone.text,
                          shipping: _shippingFor(store.bagSubtotal),
                          launching: _launching,
                          paymentMethods: widget.availablePaymentMethods,
                          selectedPayment: _selectedPayment,
                          onSelectPayment: (value) =>
                              setState(() => _selectedPayment = value),
                          onEdit: () => setState(() => _reviewing = false),
                          onPay: () => unawaited(_pay()),
                        )
                      : _ContactForm(
                          formKey: _formKey,
                          email: _email,
                          phone: _phone,
                          shipping: _shippingFor(store.bagSubtotal),
                          onContinue: _review,
                          onSignIn: () => unawaited(_signIn()),
                        );

                  final summary = _CheckoutSummary(
                    lines: store.bagLines,
                    subtotal: store.bagSubtotal,
                  );

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
            ],
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              width: 96,
              height: 116,
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
                    style: boutiqueEyebrow(size: 10, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  line.product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: boutiqueText(
                    size: 15,
                    weight: FontWeight.w600,
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
                const SizedBox(height: 7),
                Text(
                  kMoney.format(line.lineTotal),
                  style: boutiqueText(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                _QuantityStepper(
                  quantity: line.quantity,
                  onChanged: onChanged,
                ),
                const SizedBox(height: 2),
                _BagTextAction(
                  label: 'Eliminar',
                  onTap: onRemove,
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
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: palette.hairline),
          borderRadius: BoutiqueRadius.control,
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
              constraints: const BoxConstraints(minWidth: 48),
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: boutiqueText(size: 14, weight: FontWeight.w600),
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
      icon: Icon(icon, size: 16),
      constraints: const BoxConstraints.tightFor(width: 56, height: 48),
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
            height: 252,
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
                    showQuickAdd: false,
                    onQuickView: () => showProductQuickView(context, product),
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
    required this.shipping,
    required this.ctaLabel,
    required this.onContinue,
  });

  final double subtotal;
  final double shipping;
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
          Text('Resumen de compra', style: boutiqueTitle(color: palette.ink)),
          const SizedBox(height: 18),
          CheckoutSummaryRow(label: 'Subtotal', value: kMoney.format(subtotal)),
          const SizedBox(height: 10),
          CheckoutSummaryRow(
            label: 'Envío',
            value: shipping == 0 ? 'Gratis' : kMoney.format(shipping),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(height: .5, color: palette.hairline),
          ),
          CheckoutSummaryRow(
            label: 'Total',
            value: kMoney.format(subtotal + shipping),
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
                'Pago procesado de forma segura',
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

class _ContactForm extends StatelessWidget {
  const _ContactForm({
    required this.formKey,
    required this.email,
    required this.phone,
    required this.shipping,
    required this.onContinue,
    required this.onSignIn,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController phone;
  final double shipping;
  final VoidCallback onContinue;
  final VoidCallback onSignIn;

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Completa este campo' : null;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final accountController = AccountScope.maybeOf(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (accountController?.isSignedIn != true) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('checkout-shop-login'),
                onPressed: accountController?.canLogin == true &&
                        accountController?.isLoading == false
                    ? onSignIn
                    : null,
                child: Text(
                  accountController?.isLoading == true
                      ? 'Iniciando sesión…'
                      : 'Inicia sesión con Shop',
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'La dirección y el envío se capturan en el checkout seguro de '
            'Shopify para no pedirlos dos veces. Totales finales también '
            'vienen de Shopify.',
            style: boutiqueText(size: 13, color: palette.inkMuted),
          ),
          const SizedBox(height: 28),
          Text(
            'Contacto'.toUpperCase(),
            style: boutiqueEyebrow(size: 10, color: palette.inkMuted),
          ),
          const SizedBox(height: 12),
          _CheckoutField(
            controller: email,
            label: 'Correo electrónico',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              final required = _required(value);
              if (required != null) return required;
              return value!.contains('@') ? null : 'Ingresa un correo válido';
            },
          ),
          const SizedBox(height: 12),
          _CheckoutField(
            controller: phone,
            label: 'Teléfono',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: _required,
          ),
          const SizedBox(height: 24),
          _DeliveryOption(shipping: shipping),
          const SizedBox(height: 24),
          BoutiqueButton(label: 'REVISAR PEDIDO', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _CheckoutField extends StatelessWidget {
  const _CheckoutField({
    required this.controller,
    required this.label,
    required this.validator,
    this.keyboardType,
    this.autofillHints,
  }) : inputFormatters = null;

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      style: boutiqueText(size: 14, color: palette.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: boutiqueText(size: 13, color: palette.inkMuted),
        floatingLabelStyle: boutiqueText(size: 11, color: palette.ink),
        filled: true,
        fillColor: palette.surfaceDeep,
        contentPadding: const EdgeInsets.fromLTRB(15, 17, 15, 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BoutiqueRadius.control,
          borderSide: BorderSide(color: palette.hairline, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BoutiqueRadius.control,
          borderSide: BorderSide(color: palette.ink, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BoutiqueRadius.control,
          borderSide: BorderSide(color: palette.sale, width: .8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BoutiqueRadius.control,
          borderSide: BorderSide(color: palette.sale, width: 1),
        ),
      ),
    );
  }
}

class _DeliveryOption extends StatelessWidget {
  const _DeliveryOption({required this.shipping});

  final double shipping;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.ink, width: .8),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.ink),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Envío estándar',
                  style: boutiqueText(
                    size: 13,
                    weight: FontWeight.w500,
                    color: palette.ink,
                  ),
                ),
                Text(
                  'Recíbelo en 3 a 5 días hábiles',
                  style: boutiqueText(size: 11, color: palette.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            shipping == 0
                ? 'ESTIMADO: GRATIS'
                : 'ESTIMADO: ${kMoney.format(shipping)}',
            style: boutiqueEyebrow(size: 9, color: palette.ink),
          ),
        ],
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.email,
    required this.phone,
    required this.shipping,
    required this.launching,
    required this.paymentMethods,
    required this.selectedPayment,
    required this.onSelectPayment,
    required this.onEdit,
    required this.onPay,
  });

  final String email;
  final String phone;
  final double shipping;
  final bool launching;
  final List<String> paymentMethods;
  final String? selectedPayment;
  final ValueChanged<String> onSelectPayment;
  final VoidCallback onEdit;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Todo listo', style: boutiqueDisplay(28)),
        const SizedBox(height: 8),
        Text(
          'Revisa tu contacto. Dirección, envío e impuestos finales se '
          'confirman en Shopify.',
          style: boutiqueText(size: 13, color: palette.inkMuted),
        ),
        const SizedBox(height: 28),
        _ReviewBlock(
          title: 'Contacto',
          value: '$email\n$phone',
          onEdit: onEdit,
          editLabel: 'Cambiar',
        ),
        _ReviewBlock(
          title: 'Dirección de envío',
          value: 'Se captura en Shopify Checkout\n'
              'No la pedimos aquí para no duplicarla.',
        ),
        _ReviewBlock(
          title: 'Método de envío',
          value: 'Envío estándar · 3 a 5 días hábiles\n'
              'Estimado previo: ${shipping == 0 ? 'gratis' : kMoney.format(shipping)} (no final)',
        ),
        _PaymentBlock(
          methods: paymentMethods,
          selected: selectedPayment,
          onSelect: onSelectPayment,
        ),
        const SizedBox(height: 24),
        if (launching)
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
        BoutiqueButton(
          label: 'CONTINUAR AL PAGO SEGURO',
          onPressed: launching ? null : onPay,
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
                    'Pago seguro en Shopify',
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
    this.onEdit,
    this.editLabel = 'Editar',
  });

  final String title;
  final String value;
  final VoidCallback? onEdit;
  final String editLabel;

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
          if (onEdit != null) _BagTextAction(label: editLabel, onTap: onEdit!),
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
    final shipping = _shippingFor(subtotal);
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
                child:
                    Text('Tu pedido', style: boutiqueTitle(color: palette.ink)),
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
          CheckoutSummaryRow(label: 'Subtotal', value: kMoney.format(subtotal)),
          const SizedBox(height: 8),
          CheckoutSummaryRow(
            label: 'Envío estimado',
            value: shipping == 0 ? 'Gratis' : kMoney.format(shipping),
          ),
          const SizedBox(height: 14),
          CheckoutSummaryRow(
            label: 'Total estimado',
            value: kMoney.format(subtotal + shipping),
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
  const _EmptyBag();

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
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

double _shippingFor(double subtotal) => shippingFor(subtotal);
