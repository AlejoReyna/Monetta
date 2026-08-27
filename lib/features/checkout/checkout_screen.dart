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
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../domain/bag_line.dart';
import '../../main.dart';

/// The transient data a real Shopify launcher needs to create the Cart and
/// prefill buyer identity before opening `cart.checkoutUrl`.
///
/// It is never persisted by this feature. A launcher may send it directly to
/// Shopify so the shopper does not type the delivery address twice.
class CheckoutDraft {
  const CheckoutDraft({
    required this.lines,
    required this.email,
    required this.name,
    required this.phone,
    required this.street,
    required this.neighborhood,
    required this.postalCode,
    required this.city,
    required this.state,
  });

  final List<BagLine> lines;
  final String email;
  final String name;
  final String phone;
  final String street;
  final String neighborhood;
  final String postalCode;
  final String city;
  final String state;
}

typedef SecureCheckoutLauncher = Future<void> Function(CheckoutDraft draft);

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
                decoration: const BoxDecoration(
                  color: kInk,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: sans(
                    size: 9,
                    color: Colors.white,
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

class BagScreen extends StatelessWidget {
  const BagScreen({this.launchSecureCheckout, super.key});

  final SecureCheckoutLauncher? launchSecureCheckout;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lines = store.bagLines;

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
              launchSecureCheckout: launchSecureCheckout,
            ),
    );
  }
}

class _BagContents extends StatelessWidget {
  const _BagContents({
    required this.lines,
    required this.launchSecureCheckout,
  });

  final List<BagLine> lines;
  final SecureCheckoutLauncher? launchSecureCheckout;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final count = store.bagQuantity;
    final subtotal = store.bagSubtotal;
    final shipping = _shippingFor(subtotal);

    void continueToCheckout() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StoreScope(
            notifier: store,
            child: CheckoutFlowScreen(
              launchSecureCheckout: launchSecureCheckout,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tu bolsa', style: display(wide ? 36 : 30)),
                  const SizedBox(height: 6),
                  Text(
                    '$count ${count == 1 ? 'artículo' : 'artículos'}',
                    style: sans(size: 12.5, color: kInkMuted),
                  ),
                ],
              ),
            ),
            for (final line in lines)
              _BagLineTile(
                line: line,
                onChanged: (quantity) =>
                    store.updateBagQuantity(line.product.id, quantity),
                onRemove: () => store.removeFromBag(line.product.id),
              ),
          ],
        );

        final summary = _OrderSummary(
          subtotal: subtotal,
          shipping: shipping,
          ctaLabel: 'Continuar a entrega',
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          list,
                          const _TrustBar(),
                        ],
                      ),
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
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            list,
            Padding(padding: const EdgeInsets.all(20), child: summary),
            const _TrustBar(),
          ],
        );
      },
    );
  }
}

class CheckoutFlowScreen extends StatefulWidget {
  const CheckoutFlowScreen({this.launchSecureCheckout, super.key});

  final SecureCheckoutLauncher? launchSecureCheckout;

  @override
  State<CheckoutFlowScreen> createState() => _CheckoutFlowScreenState();
}

class _CheckoutFlowScreenState extends State<CheckoutFlowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _postalCode = TextEditingController();
  final _street = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  bool _reviewing = false;
  bool _launching = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _email.dispose();
    _name.dispose();
    _phone.dispose();
    _postalCode.dispose();
    _street.dispose();
    _neighborhood.dispose();
    _city.dispose();
    _state.dispose();
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
    NotificationScope.maybeOf(context)?.recordPushOutcome('checkout_started');
    final lines = StoreScope.of(context).bagLines;
    if (widget.launchSecureCheckout case final launcher?) {
      setState(() => _launching = true);
      try {
        await launcher(
          CheckoutDraft(
            lines: lines,
            email: _email.text.trim(),
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            street: _street.text.trim(),
            neighborhood: _neighborhood.text.trim(),
            postalCode: _postalCode.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
          ),
        );
      } finally {
        if (mounted) setState(() => _launching = false);
      }
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _SecureHandoffPreview(),
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
                        name: _name.text,
                        phone: _phone.text,
                        shipping: _shippingFor(store.bagSubtotal),
                        address:
                            '${_street.text}, ${_neighborhood.text}\n${_postalCode.text} ${_city.text}, ${_state.text}',
                        launching: _launching,
                        onEdit: () => setState(() => _reviewing = false),
                        onPay: () => unawaited(_pay()),
                      )
                    : _DeliveryForm(
                        formKey: _formKey,
                        email: _email,
                        name: _name,
                        phone: _phone,
                        postalCode: _postalCode,
                        street: _street,
                        neighborhood: _neighborhood,
                        city: _city,
                        state: _state,
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
                      style: eyebrow(size: 8.5, color: kInk),
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
    const labels = ['Bolsa', 'Entrega', 'Pago'];
    return Container(
      color: kMist,
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
                      color: index <= activeIndex ? kInk : kLine,
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
              color: active || complete ? kInk : Colors.white,
              border: Border.all(color: active || complete ? kInk : kLine),
            ),
            child: complete
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : Text(
                    '$number',
                    style: sans(
                      size: 10,
                      color: active ? Colors.white : kInkMuted,
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
              color: active || complete ? kInk : kInkMuted,
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
      decoration: const BoxDecoration(border: Border(top: kHairline)),
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
                    style: sans(size: 11.5, color: kInkMuted),
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
                      color: kInkMuted,
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
      decoration: BoxDecoration(border: Border.all(color: kLine)),
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
      color: kMist,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen', style: display(22, weight: FontWeight.w400)),
          const SizedBox(height: 22),
          _SummaryRow(label: 'Subtotal', value: kMoney.format(subtotal)),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Envío estándar',
            value: shipping == 0 ? 'Gratis' : kMoney.format(shipping),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(),
          ),
          _SummaryRow(
            label: 'Total estimado',
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
              const Icon(Icons.lock_outline, size: 14, color: kInkMuted),
              const SizedBox(width: 7),
              Text(
                'Pago procesado de forma segura',
                style: sans(size: 10.5, color: kInkMuted),
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

class _TrustBar extends StatelessWidget {
  const _TrustBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 22, 24, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: kHairline)),
        child: Padding(
          padding: EdgeInsets.only(top: 18),
          child: MonettaTrustRows(),
        ),
      ),
    );
  }
}

class _DeliveryForm extends StatelessWidget {
  const _DeliveryForm({
    required this.formKey,
    required this.email,
    required this.name,
    required this.phone,
    required this.postalCode,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.shipping,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController postalCode;
  final TextEditingController street;
  final TextEditingController neighborhood;
  final TextEditingController city;
  final TextEditingController state;
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
          Text('¿Dónde lo enviamos?', style: display(30)),
          const SizedBox(height: 8),
          Text(
            'Compra como invitado. Solo pedimos lo necesario para entregar tu pedido.',
            style: sans(size: 12.5, color: kInkMuted),
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
          const SizedBox(height: 28),
          Text('Dirección de entrega'.toUpperCase(), style: eyebrow(size: 9)),
          const SizedBox(height: 14),
          _CheckoutField(
            controller: name,
            label: 'Nombre completo',
            autofillHints: const [AutofillHints.name],
            validator: _required,
          ),
          const SizedBox(height: 14),
          _CheckoutField(
            controller: street,
            label: 'Calle y número',
            autofillHints: const [AutofillHints.streetAddressLine1],
            validator: _required,
          ),
          const SizedBox(height: 14),
          _CheckoutField(
            controller: neighborhood,
            label: 'Colonia',
            validator: _required,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _CheckoutField(
                  controller: postalCode,
                  label: 'Código postal',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.postalCode],
                  validator: (value) {
                    final required = _required(value);
                    if (required != null) return required;
                    return value!.length == 5 ? null : 'Usa 5 dígitos';
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CheckoutField(
                  controller: city,
                  label: 'Ciudad',
                  autofillHints: const [AutofillHints.addressCity],
                  validator: _required,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CheckoutField(
            controller: state,
            label: 'Estado',
            autofillHints: const [AutofillHints.addressState],
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
    this.inputFormatters,
    this.autofillHints,
  });

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
        labelStyle: sans(size: 12.5, color: kInkMuted),
        floatingLabelStyle: sans(size: 11, color: kInk),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(15, 17, 15, 14),
        enabledBorder: const OutlineInputBorder(
          borderRadius: kSquare,
          borderSide: kHairline,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: kSquare,
          borderSide: BorderSide(color: kInk, width: 1),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: kSquare,
          borderSide: BorderSide(color: kSale, width: .8),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: kSquare,
          borderSide: BorderSide(color: kSale, width: 1),
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
      decoration: BoxDecoration(border: Border.all(color: kInk, width: .8)),
      child: Row(
        children: [
          Container(
            width: 15,
            height: 15,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kInk),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: kInk),
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
                  style: sans(size: 11, color: kInkMuted),
                ),
              ],
            ),
          ),
          Text(
            shipping == 0 ? 'GRATIS' : kMoney.format(shipping),
            style: eyebrow(size: 8.5, color: kInk),
          ),
        ],
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({
    required this.email,
    required this.name,
    required this.phone,
    required this.shipping,
    required this.address,
    required this.launching,
    required this.onEdit,
    required this.onPay,
  });

  final String email;
  final String name;
  final String phone;
  final double shipping;
  final String address;
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
          'Revisa tu entrega antes de continuar al pago protegido.',
          style: sans(size: 12.5, color: kInkMuted),
        ),
        const SizedBox(height: 30),
        _ReviewBlock(
          title: 'Contacto',
          value: '$email\n$phone',
          onEdit: onEdit,
        ),
        _ReviewBlock(
          title: 'Entrega',
          value: '$name\n$address',
          onEdit: onEdit,
        ),
        _ReviewBlock(
          title: 'Método',
          value:
              'Envío estándar · 3 a 5 días hábiles\n${shipping == 0 ? 'Gratis' : kMoney.format(shipping)}',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: launching ? null : onPay,
          icon: launching
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.lock_outline, size: 16),
          label: const Text('CONTINUAR AL PAGO SEGURO'),
        ),
        const SizedBox(height: 14),
        Text(
          'Shopify procesa el pago. Monetta nunca ve ni guarda los datos de tu tarjeta.',
          textAlign: TextAlign.center,
          style: sans(size: 10.5, color: kInkMuted),
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
      decoration: const BoxDecoration(border: Border(top: kHairline)),
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
      color: kMist,
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
                          style: sans(size: 10.5, color: kInkMuted),
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
          _SummaryRow(label: 'Subtotal', value: kMoney.format(subtotal)),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Envío',
            value: shipping == 0 ? 'Gratis' : kMoney.format(shipping),
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Total',
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
              style: sans(size: 12.5, color: kInkMuted),
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

class _SecureHandoffPreview extends StatelessWidget {
  const _SecureHandoffPreview();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: kMist,
              ),
              child: const Icon(Icons.lock_outline, size: 21),
            ),
            const SizedBox(height: 18),
            Text('Pago protegido', style: display(25)),
            const SizedBox(height: 10),
            Text(
              'Este prototipo termina en la entrega segura a Shopify. Al conectar la tienda, aquí se abrirán los métodos de pago habilitados sin exponer los datos de tu tarjeta a Monetta.',
              textAlign: TextAlign.center,
              style: sans(size: 12.5, color: kInkMuted),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ENTENDIDO'),
            ),
          ],
        ),
      ),
    );
  }
}

double _shippingFor(double subtotal) => shippingFor(subtotal);
