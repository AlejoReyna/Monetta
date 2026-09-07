/// Monetta's pre-checkout experience.
///
/// The flow intentionally stops before card entry. Product review, delivery
/// details and the final order check belong to Monetta; payment belongs to the
/// Shopify checkout URL so card data never enters this application.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/media/monetta_image.dart';
import '../../app/cart_controller.dart';
import '../../app/checkout_buyer_identity.dart';
import '../../app/motion.dart';
import '../../app/shopify_checkout_coordinator.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../data/shopify/cart/cart_repository.dart';
import '../../data/shopify/cart/cart_session_store.dart';
import '../../data/shopify/cart/checkout_launcher.dart';
import '../../domain/bag_line.dart';
import '../../main.dart';
import 'shopify_cart_summary.dart';

/// The transient data a real Shopify launcher needs to create the Cart and
/// prefill buyer identity before opening `cart.checkoutUrl`.
///
/// It is never persisted by this feature. A launcher may send it directly to
/// Shopify so the shopper does not type the delivery address twice.
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
    MaterialPageRoute<void>(
      builder: (_) => StoreScope(
        notifier: store,
        child: BagScreen(launchSecureCheckout: launchSecureCheckout),
      ),
    ),
  );
}

/// A reusable header action so home and product screens expose one live bag.
class BagAction extends StatelessWidget {
  const BagAction({this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
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
                  color: context.monettaColors.contentPrimary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: sans(
                    size: 9,
                    color: context.monettaColors.canvas,
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
      appBar: _CheckoutAppBar(
        showSecurityIndicator: false,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 20),
        ),
      ),
      body: lines.isEmpty
          ? const _EmptyBag()
          : _BagContents(
              lines: lines,
              launchSecureCheckout: widget.launchSecureCheckout,
              cartController: cartScope?.notifier,
              checkoutCoordinator: cartScope?.checkoutCoordinator,
              cartScope: sessionScope,
              localIntent: localIntent,
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
    final count = store.bagQuantity;
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
                  // Rebuild intent from the live bag immediately before
                  // Shopify reconciliation — never reuse the bag snapshot that
                  // existed when this screen was first opened (F17).
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
                    onCompleted: (purchasedVariantIds) async {
                      await store.clearPurchasedBagLines(purchasedVariantIds);
                      await accountController?.loadOrders();
                    },
                  );
                };
      final launcher = launchSecureCheckout ?? productionLauncher;
      // F05: refuse to collect delivery/contact when checkout cannot finish.
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
        MaterialPageRoute<void>(
          builder: (_) => StoreScope(
            notifier: store,
            child: CheckoutFlowScreen(
              launchSecureCheckout: launcher,
              // The coordinator decides at invocation time whether the fresh
              // reconciled URL is available; do not snapshot that state before
              // the checkout screen performs its final reconciliation.
              openExternalCheckout: checkout?.openExternalFallback,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        final list = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CheckoutProgress(activeIndex: 0),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
              child: Row(
                key: const ValueKey('bag-heading-row'),
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text('Tu bolsa', style: display(wide ? 36 : 30)),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$count ${count == 1 ? 'artículo' : 'artículos'}',
                    style: sans(
                      size: 12.5,
                      color: context.monettaColors.contentMuted,
                    ),
                  ),
                ],
              ),
            ),
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
                ctaLabel: 'Continuar a contacto',
                onContinue: continueToCheckout,
              );

        if (wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 56),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: list,
                    ),
                    const SizedBox(width: 52),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 74),
                        child: summary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            list,
            summary,
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
    super.key,
  });

  final SecureCheckoutLauncher? launchSecureCheckout;
  final ExternalCheckoutFallback? openExternalCheckout;

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
  bool _didPrefillContact = false;

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
    _scrollController.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
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
    final lines = StoreScope.of(context).bagLines;
    if (widget.launchSecureCheckout case final launcher?) {
      NotificationScope.maybeOf(context)?.recordPushOutcome('checkout_started');
      setState(() => _launching = true);
      try {
        final result = await launcher(
          CheckoutDraft(
            lines: lines,
            email: _email.text.trim(),
            phone: _phone.text.trim(),
          ),
        );
        if (!mounted) return;
        switch (result) {
          case CheckoutCompleted():
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Shopify confirmó tu compra. Revisaremos Mis pedidos; '
                  'artículos no comprados se conservan en tu bolsa.',
                ),
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
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
    final store = StoreScope.of(context);
    if (store.bagLines.isEmpty) {
      return Scaffold(
        appBar: const _CheckoutAppBar(),
        body: const _EmptyBag(),
      );
    }

    return Scaffold(
      appBar: _CheckoutAppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: _reviewing
              ? () => setState(() => _reviewing = false)
              : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, size: 20),
        ),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 44),
        child: Column(
          children: [
            _CheckoutProgress(activeIndex: _reviewing ? 2 : 1),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final form = _reviewing
                    ? _ReviewPanel(
                        email: _email.text,
                        phone: _phone.text,
                        shipping: _shippingFor(store.bagSubtotal),
                        launching: _launching,
                        onEdit: () => setState(() => _reviewing = false),
                        onPay: () => unawaited(_pay()),
                      )
                    : _ContactForm(
                        formKey: _formKey,
                        email: _email,
                        phone: _phone,
                        shipping: _shippingFor(store.bagSubtotal),
                        onContinue: _review,
                      );

                final summary = _CheckoutSummary(
                  lines: store.bagLines,
                  subtotal: store.bagSubtotal,
                );

                if (!wide) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                        child: form,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: summary,
                      ),
                    ],
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 46, 32, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: form),
                          const SizedBox(width: 64),
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
    );
  }
}

class _CheckoutAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CheckoutAppBar({
    this.leading,
    this.showSecurityIndicator = true,
  });

  final Widget? leading;
  final bool showSecurityIndicator;

  @override
  Size get preferredSize => const Size.fromHeight(64.5);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 64,
      leading: leading,
      automaticallyImplyLeading: false,
      title: const MonettaWordmark.appBar(),
      centerTitle: true,
      actions: showSecurityIndicator
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 18),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'SEGURO',
                      style: eyebrow(
                        size: 8.5,
                        color: context.monettaColors.contentPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ]
          : null,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(.5),
        child: Divider(height: .5),
      ),
    );
  }
}

class _CheckoutProgress extends StatelessWidget {
  const _CheckoutProgress({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    const labels = ['Bolsa', 'Contacto', 'Pago'];
    return Container(
      color: context.monettaColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            children: [
              for (var index = 0; index < labels.length; index++) ...[
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: .5,
                      color: index <= activeIndex
                          ? context.monettaColors.contentPrimary
                          : context.monettaColors.divider,
                    ),
                  ),
                _ProgressStep(
                  label: labels[index],
                  number: index + 1,
                  active: index == activeIndex,
                  complete: index < activeIndex,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.number,
    required this.active,
    required this.complete,
  });

  final String label;
  final int number;
  final bool active;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '$label, ${active ? 'paso actual' : complete ? 'completado' : 'pendiente'}',
      child: Column(
        children: [
          Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || complete
                  ? context.monettaColors.contentPrimary
                  : context.monettaColors.surface,
              border: Border.all(
                color: active || complete
                    ? context.monettaColors.contentPrimary
                    : context.monettaColors.divider,
              ),
            ),
            child: complete
                ? Icon(
                    Icons.check,
                    size: 13,
                    color: context.monettaColors.canvas,
                  )
                : Text(
                    '$number',
                    style: sans(
                      size: 10,
                      color: active
                          ? context.monettaColors.canvas
                          : context.monettaColors.contentMuted,
                      weight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            label.toUpperCase(),
            style: eyebrow(
              size: 8.5,
              color: active || complete
                  ? context.monettaColors.contentPrimary
                  : context.monettaColors.contentMuted,
            ),
          ),
        ],
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
    final store = StoreScope.of(context);
    final brand = store.facetsFor(line.product.id)?.brand?.value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.monettaColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            height: 132,
            child: _ProductImage(url: line.product.primaryImage),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (brand != null) ...[
                  Text(brand.toUpperCase(), style: eyebrow(size: 8.5)),
                  const SizedBox(height: 7),
                ],
                Text(
                  line.product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: sans(size: 14, weight: FontWeight.w500, height: 1.35),
                ),
                if (!line.variant.isDefault) ...[
                  const SizedBox(height: 5),
                  Text(
                    line.variant.title,
                    style: sans(
                      size: 11.5,
                      color: context.monettaColors.contentMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  kMoney.format(line.lineTotal),
                  style: sans(size: 14, weight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _QuantityControl(
                      quantity: line.quantity,
                      onChanged: onChanged,
                    ),
                    UnderlineLink(
                      label: 'Eliminar',
                      onTap: onRemove,
                      size: 10.5,
                      color: context.monettaColors.contentMuted,
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

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({required this.quantity, required this.onChanged});

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: context.monettaColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            tooltip: 'Quitar uno',
            icon: Icons.remove,
            onPressed: () => onChanged(quantity - 1),
          ),
          Semantics(
            label: 'Cantidad $quantity',
            child: SizedBox(
              width: 36,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: sans(size: 12, weight: FontWeight.w500),
              ),
            ),
          ),
          _QuantityButton(
            tooltip: 'Agregar uno',
            icon: Icons.add,
            onPressed: quantity >= 10 ? null : () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
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
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
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
    return Container(
      key: const ValueKey('bag-order-summary'),
      color: context.monettaColors.surfaceMuted,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen', style: display(22, weight: FontWeight.w400)),
          const SizedBox(height: 22),
          _SummaryRow(
            label: 'Subtotal local estimado',
            value: kMoney.format(subtotal),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Envío estimado',
            value: shipping == 0
                ? 'Estimado: gratis'
                : 'Estimado: ${kMoney.format(shipping)}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(),
          ),
          _SummaryRow(
            label: 'Estimación local',
            value: kMoney.format(subtotal + shipping),
            prominent: true,
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: onContinue,
            child: Text(ctaLabel.toUpperCase()),
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 14,
                color: context.monettaColors.contentMuted,
              ),
              const SizedBox(width: 7),
              Text(
                'Pago procesado de forma segura',
                style:
                    sans(size: 10.5, color: context.monettaColors.contentMuted),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: sans(
              size: prominent ? 14 : 12.5,
              weight: prominent ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: sans(
            size: prominent ? 15 : 12.5,
            weight: prominent ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
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
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController phone;
  final double shipping;
  final VoidCallback onContinue;

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Completa este campo' : null;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Cómo te contactamos?', style: display(30)),
          const SizedBox(height: 8),
          Text(
            'La dirección y el envío se capturan en el checkout seguro de '
            'Shopify para no pedirlos dos veces. Totales finales también '
            'vienen de Shopify.',
            style: sans(size: 12.5, color: context.monettaColors.contentMuted),
          ),
          const SizedBox(height: 30),
          Text('Contacto'.toUpperCase(), style: eyebrow(size: 9)),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          _CheckoutField(
            controller: phone,
            label: 'Teléfono',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: _required,
          ),
          const SizedBox(height: 26),
          _DeliveryOption(shipping: shipping),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: onContinue,
            child: const Text('REVISAR PEDIDO'),
          ),
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
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      style: sans(size: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: sans(size: 12.5, color: context.monettaColors.contentMuted),
        floatingLabelStyle:
            sans(size: 11, color: context.monettaColors.contentPrimary),
        filled: true,
        fillColor: context.monettaColors.inputFill,
        contentPadding: const EdgeInsets.fromLTRB(15, 17, 15, 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: kSquare,
          borderSide:
              BorderSide(color: context.monettaColors.divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: kSquare,
          borderSide:
              BorderSide(color: context.monettaColors.contentPrimary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: kSquare,
          borderSide: BorderSide(color: context.monettaColors.sale, width: .8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: kSquare,
          borderSide: BorderSide(color: context.monettaColors.sale, width: 1),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: context.monettaColors.contentPrimary,
          width: .8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 15,
            height: 15,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.monettaColors.contentPrimary),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.monettaColors.contentPrimary,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Envío estándar',
                  style: sans(size: 13, weight: FontWeight.w500),
                ),
                Text(
                  'Recíbelo en 3 a 5 días hábiles',
                  style:
                      sans(size: 11, color: context.monettaColors.contentMuted),
                ),
              ],
            ),
          ),
          Text(
            shipping == 0
                ? 'ESTIMADO: GRATIS'
                : 'ESTIMADO: ${kMoney.format(shipping)}',
            style:
                eyebrow(size: 8.5, color: context.monettaColors.contentPrimary),
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
    required this.onEdit,
    required this.onPay,
  });

  final String email;
  final String phone;
  final double shipping;
  final bool launching;
  final VoidCallback onEdit;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Todo listo', style: display(30)),
        const SizedBox(height: 8),
        Text(
          'Revisa tu contacto. Dirección, envío e impuestos finales se '
          'confirman en Shopify.',
          style: sans(size: 12.5, color: context.monettaColors.contentMuted),
        ),
        const SizedBox(height: 30),
        _ReviewBlock(
          title: 'Contacto',
          value: '$email\n$phone',
          onEdit: onEdit,
        ),
        _ReviewBlock(
          title: 'Entrega y envío',
          value: 'Se capturan en Shopify Checkout\n'
              'Estimado local previo: '
              '${shipping == 0 ? 'gratis' : kMoney.format(shipping)} '
              '(no final)',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: launching ? null : onPay,
          icon: launching
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: context.monettaColors.canvas,
                  ),
                )
              : const Icon(Icons.lock_outline, size: 16),
          label: Text(
            launching ? 'ABRIENDO…' : 'CONTINUAR AL PAGO SEGURO',
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Shopify procesa el pago. Monetta nunca ve los datos de tu tarjeta.',
          style: sans(size: 11.5, color: context.monettaColors.contentMuted),
        ),
      ],
    );
  }
}

class _ReviewBlock extends StatelessWidget {
  const _ReviewBlock({required this.title, required this.value, this.onEdit});

  final String title;
  final String value;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.monettaColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(title.toUpperCase(), style: eyebrow(size: 8.5)),
          ),
          Expanded(child: Text(value, style: sans(size: 12.5))),
          if (onEdit != null)
            UnderlineLink(label: 'Editar', onTap: onEdit!, size: 10.5),
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
    final shipping = _shippingFor(subtotal);
    return Container(
      color: context.monettaColors.surfaceMuted,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tu pedido',
                  style: display(20, weight: FontWeight.w400),
                ),
              ),
              Text(
                '${lines.fold(0, (sum, line) => sum + line.quantity)} ART.',
                style: eyebrow(size: 8.5),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    height: 70,
                    child: _ProductImage(url: line.product.primaryImage),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: sans(size: 11.5, weight: FontWeight.w500),
                        ),
                        Text(
                          'Cantidad ${line.quantity}',
                          style: sans(
                            size: 10.5,
                            color: context.monettaColors.contentMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(kMoney.format(line.lineTotal), style: sans(size: 11.5)),
                ],
              ),
            ),
          const Divider(),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Subtotal local estimado',
            value: kMoney.format(subtotal),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Envío estimado',
            value: shipping == 0
                ? 'Estimado: gratis'
                : 'Estimado: ${kMoney.format(shipping)}',
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Estimación local',
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
    return MonettaImage(url: url, cacheWidth: MediaUrl.thumbWidth);
  }
}

class _EmptyBag extends StatelessWidget {
  const _EmptyBag();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 34),
            const SizedBox(height: 22),
            Text('Tu bolsa está vacía', style: display(26)),
            const SizedBox(height: 9),
            Text(
              'Encuentra una pieza que quieras llevar contigo.',
              textAlign: TextAlign.center,
              style:
                  sans(size: 12.5, color: context.monettaColors.contentMuted),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 260,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('VOLVER A LA TIENDA'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _shippingFor(double subtotal) => shippingFor(subtotal);
