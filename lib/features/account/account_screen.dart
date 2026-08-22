/// The account entry point — reachable from the home drawer, never forced.
///
/// `docs/CHECKOUT_DESIGN.md` states "no account wall" as a design rule for
/// checkout; this screen is the other half of that promise. Signed out is a
/// complete, ordinary state here, not an error or a nag — see
/// `lib/data/customer_auth/README.md` § 5.
library;

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/theme.dart';
import '../../data/customer_auth/customer_auth_error.dart';
import '../../data/local/database.dart' show OrderSummary;

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    required this.controller,
    this.openHostedLoginOnStart = false,
    this.canOpenAdmin,
    this.onOpenAdmin,
    this.onOpenPartner,
    super.key,
  });

  final AccountController controller;

  /// Starts Shopify's hosted sign-in as soon as this route is presented.
  ///
  /// Navigation entry points set this to true so tapping Account behaves like
  /// a native shopping app: the secure web authentication sheet is the first
  /// interactive surface. Keeping it opt-in makes this screen reusable after
  /// cancellation and in widget tests without repeatedly opening a browser.
  final bool openHostedLoginOnStart;

  /// Owner administration remains an optional capability so account flows
  /// stay reusable in tests and in builds without a configured control plane.
  final bool Function()? canOpenAdmin;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenPartner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const MonettaWordmark(height: 20)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.isSignedIn
              ? _SignedIn(
                  controller: controller,
                  showAdmin: canOpenAdmin?.call() == true,
                  onOpenAdmin: onOpenAdmin,
                  onOpenPartner: onOpenPartner,
                )
              : _SignedOut(
                  controller: controller,
                  openHostedLoginOnStart: openHostedLoginOnStart,
                  onOpenPartner: onOpenPartner,
                ),
        ),
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({
    required this.controller,
    required this.showAdmin,
    required this.onOpenAdmin,
    required this.onOpenPartner,
  });

  final AccountController controller;
  final bool showAdmin;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenPartner;

  @override
  Widget build(BuildContext context) {
    final account = controller.account!;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Sesión iniciada', style: display(20)),
        const SizedBox(height: 8),
        Text(
          account.displayName ?? account.email ?? 'Tu cuenta',
          style: sans(size: 14, color: kInkMuted),
        ),
        if (account.displayName != null && account.email != null) ...[
          const SizedBox(height: 2),
          Text(account.email!, style: sans(size: 12, color: kInkMuted)),
        ],
        if (showAdmin && onOpenAdmin != null) ...[
          const SizedBox(height: 24),
          InkWell(
            key: const ValueKey('open-owner-admin'),
            onTap: onOpenAdmin,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: kInk,
                border: Border.all(color: kGold, width: .6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: kGold,
                    size: 23,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ADMINISTRAR MONETTA',
                          style: eyebrow(
                            size: 9,
                            color: kGold,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Productos, portada, fuentes y sincronización',
                          style: sans(
                            size: 11,
                            color: const Color(0xFFD2D2D2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (onOpenPartner != null) ...[
          const SizedBox(height: 18),
          _PartnerAccountLink(onTap: onOpenPartner!),
        ],
        const SizedBox(height: 28),
        FilledButton(
          onPressed: controller.isLoading ? null : controller.logout,
          child: controller.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('CERRAR SESIÓN'),
        ),
        const SizedBox(height: 36),
        const Divider(height: 0.5),
        const SizedBox(height: 20),
        Text('Mis pedidos'.toUpperCase(), style: eyebrow()),
        const SizedBox(height: 16),
        _OrdersList(controller: controller),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.controller});

  final AccountController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.orders.isEmpty) {
      return Text(
        controller.ordersLoading ? 'Cargando…' : 'Aún no tienes pedidos.',
        style: sans(size: 13, color: kInkMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final order in controller.orders) _OrderRow(order: order),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final isApartado = order.source == 'whatsapp_apartado';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApartado ? 'Apartado · WhatsApp' : 'Pedido',
                  style: sans(size: 13, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _placedAtLabel(order.placedAt),
                  style: sans(size: 11, color: kInkMuted),
                ),
              ],
            ),
          ),
          Text(kMoney.format(order.totalAmount), style: sans(size: 13)),
        ],
      ),
    );
  }

  String _placedAtLabel(DateTime placedAt) {
    // Kept a plain manual format rather than adding another `intl`
    // formatter for one field — this is the only place in the app that
    // renders a bare date without a time component.
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${placedAt.day} ${months[placedAt.month - 1]} ${placedAt.year}';
  }
}

/// Signed out, with Shopify's hosted flow as the one primary action.
///
/// The Monetta email/password form below it is legacy on purpose: real
/// shoppers registered that way before Customer Account login existed
/// (`docs/ACCOUNTS_AND_SYNC_PLAN.md`), so it stays reachable — collapsed when
/// Shopify login is available, and the only thing on screen when it isn't.
class _SignedOut extends StatefulWidget {
  const _SignedOut({
    required this.controller,
    required this.openHostedLoginOnStart,
    required this.onOpenPartner,
  });

  final AccountController controller;
  final bool openHostedLoginOnStart;
  final VoidCallback? onOpenPartner;

  @override
  State<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends State<_SignedOut> {
  bool _showLegacyForm = false;
  bool _isShopLoginLoading = false;
  bool _isRegistrationLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.openHostedLoginOnStart && widget.controller.canLogin) {
      // Wait until the route has painted before presenting AppAuth's native
      // browser. Starting a platform presentation while Navigator is still
      // pushing this route is racy on iOS and can be ignored by UIKit.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loginWithShop();
      });
    }
  }

  Future<void> _loginWithShop() async {
    setState(() => _isShopLoginLoading = true);
    try {
      await widget.controller.login();
    } finally {
      if (mounted) setState(() => _isShopLoginLoading = false);
    }
  }

  Future<void> _registerWithShop() async {
    setState(() => _isRegistrationLoading = true);
    try {
      // Shopify Customer Accounts uses the same hosted entry point for a
      // returning shopper and somebody creating their account for the first
      // time. The hosted page decides which path follows from their email.
      await widget.controller.login();
    } finally {
      if (mounted) setState(() => _isRegistrationLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final hasLegacy = controller.canSystemLogin || controller.canRegister;
    // Nothing to collapse behind a toggle when it is the only way in.
    final legacyExpanded = _showLegacyForm || !controller.canLogin;
    final error = controller.lastError;

    return LayoutBuilder(
      builder: (context, constraints) {
        const topPadding = 26.0;
        const bottomPadding = 28.0;
        final availableWidth = constraints.maxWidth - 48;
        final contentWidth = availableWidth > 460 ? 460.0 : availableWidth;
        final horizontalPadding = (constraints.maxWidth - contentWidth) / 2;
        final contentHeight = constraints.maxHeight > topPadding + bottomPadding
            ? constraints.maxHeight - topPadding - bottomPadding
            : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            topPadding,
            horizontalPadding,
            bottomPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: contentHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _AccountWelcome(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controller.canLogin) ...[
                        if (error != null &&
                            error.flow == AccountAuthFlow.shopify &&
                            !error.isSilent) ...[
                          _LoginError(
                            message: _shopifyErrorMessage(error.kind),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _ShopSignInButton(
                          onPressed:
                              controller.isLoading ? null : _loginWithShop,
                          isLoading: _isShopLoginLoading,
                        ),
                        const SizedBox(height: 12),
                        const _ShopSecurityNote(),
                      ] else if (!hasLegacy)
                        Text(
                          'El inicio de sesión no está disponible en esta '
                          'versión de la app. Puedes seguir comprando como '
                          'invitado.',
                          textAlign: TextAlign.center,
                          style: sans(
                            size: 12,
                            color: kInkMuted,
                            height: 1.5,
                          ),
                        ),
                      if (hasLegacy) ...[
                        if (controller.canLogin) ...[
                          const SizedBox(height: 26),
                          const _LoginDivider(label: 'o continúa con'),
                          const SizedBox(height: 20),
                        ],
                        if (!legacyExpanded)
                          OutlinedButton.icon(
                            onPressed: controller.isLoading
                                ? null
                                : () => setState(
                                      () => _showLegacyForm = true,
                                    ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kInk,
                              side: kHairline,
                            ),
                            icon: const Icon(
                              Icons.mail_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('CORREO Y CONTRASEÑA'),
                          )
                        else
                          _LegacyLoginPanel(
                            child: _MonettaPasswordForm(
                              controller: controller,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.canLogin)
                      _RegistrationPanel(
                        onPressed:
                            controller.isLoading ? null : _registerWithShop,
                        isLoading: _isRegistrationLoading,
                      ),
                    if (widget.onOpenPartner != null) ...[
                      const SizedBox(height: 16),
                      _PartnerAccountLink(onTap: widget.onOpenPartner!),
                    ],
                    if (Navigator.of(context).canPop()) ...[
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton(
                          onPressed: controller.isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('SEGUIR COMO INVITADO'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PartnerAccountLink extends StatelessWidget {
  const _PartnerAccountLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('account-open-partner'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kMist,
          border: Border.all(color: kLine),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 21, color: kGold),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VENDE CON MONETTA', style: eyebrow(size: 9)),
                  const SizedBox(height: 3),
                  Text(
                    'Catálogos y cotizaciones para tu negocio',
                    style: sans(size: 11.5, color: kInkMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AccountWelcome extends StatelessWidget {
  const _AccountWelcome();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('TU CUENTA MONETTA', style: eyebrow(color: kGold)),
        const SizedBox(height: 8),
        Text('Inicia sesión', textAlign: TextAlign.center, style: display(32)),
        const SizedBox(height: 12),
        Text(
          'Consulta tus pedidos, guarda tus favoritos y disfruta una compra '
          'más rápida.',
          textAlign: TextAlign.center,
          style: sans(size: 13.5, color: kInkMuted, height: 1.55),
        ),
        const SizedBox(height: 26),
        const _AccountBenefits(),
      ],
    );
  }
}

class _AccountBenefits extends StatelessWidget {
  const _AccountBenefits();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 19),
      decoration: const BoxDecoration(color: kMist),
      child: const Row(
        children: [
          _AccountBenefit(
            icon: Icons.favorite_border_rounded,
            label: 'Favoritos',
          ),
          _AccountBenefit(
            icon: Icons.local_shipping_outlined,
            label: 'Tus pedidos',
          ),
          _AccountBenefit(
            icon: Icons.bolt_outlined,
            label: 'Compra ágil',
          ),
        ],
      ),
    );
  }
}

class _AccountBenefit extends StatelessWidget {
  const _AccountBenefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: kInk),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: sans(size: 10.5, weight: FontWeight.w500, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// Shop's standard high-emphasis sign-in treatment: its official purple,
/// white lock-up, rounded corners, and no extra decoration or shadow.
class _ShopSignInButton extends StatelessWidget {
  const _ShopSignInButton({required this.onPressed, required this.isLoading});

  static const Color _shopPurple = Color(0xFF5A31F4);

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Iniciar sesión con Shop',
      child: Material(
        key: const ValueKey('shop-sign-in-button'),
        color: onPressed == null
            ? _shopPurple.withValues(alpha: 0.55)
            : _shopPurple,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: 54,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Iniciar sesión con '),
                          TextSpan(
                            text: 'shop',
                            style: sans(
                              size: 17,
                              color: Colors.white,
                              weight: FontWeight.w700,
                              height: 1,
                            ).copyWith(letterSpacing: -0.7),
                          ),
                        ],
                      ),
                      style: sans(
                        size: 16,
                        color: Colors.white,
                        weight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopSecurityNote extends StatelessWidget {
  const _ShopSecurityNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 13, color: kInkMuted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Acceso seguro. Shop completa tus datos al pagar.',
            textAlign: TextAlign.center,
            style: sans(size: 10.5, color: kInkMuted, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(label, style: sans(size: 11, color: kInkMuted)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _LoginError extends StatelessWidget {
  const _LoginError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(color: kMist),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: kInk),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: sans(size: 12, height: 1.4))),
        ],
      ),
    );
  }
}

class _RegistrationPanel extends StatelessWidget {
  const _RegistrationPanel({
    required this.onPressed,
    required this.isLoading,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: kMist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Primera vez en Monetta?',
            textAlign: TextAlign.center,
            style: display(19, weight: FontWeight.w400),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea tu cuenta para guardar tus piezas favoritas y consultar '
            'todos tus pedidos.',
            textAlign: TextAlign.center,
            style: sans(size: 11.5, color: kInkMuted, height: 1.45),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const ValueKey('shop-register-button'),
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: kInk,
              side: const BorderSide(color: kInk, width: 0.8),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kInk,
                    ),
                  )
                : const Text('CREAR CUENTA'),
          ),
        ],
      ),
    );
  }
}

class _LegacyLoginPanel extends StatelessWidget {
  const _LegacyLoginPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: kMist),
      child: child,
    );
  }
}

/// Deliberately generic: the accounts service reports failures as status
/// codes, so claiming "wrong password" when the service is down would be a
/// lie. See `AccountController._monettaError`.
String _shopifyErrorMessage(CustomerAuthErrorKind kind) {
  switch (kind) {
    case CustomerAuthErrorKind.cancelled:
      // Never rendered — `AccountError.isSilent` filters this out before the
      // UI asks for a sentence. Present so this switch stays exhaustive.
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

class _MonettaPasswordForm extends StatefulWidget {
  const _MonettaPasswordForm({required this.controller});

  final AccountController controller;

  @override
  State<_MonettaPasswordForm> createState() => _MonettaPasswordFormState();
}

class _MonettaPasswordFormState extends State<_MonettaPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  bool _isRegistering = false;

  @override
  void dispose() {
    _email.dispose();
    _displayName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _register() {
    if (_formKey.currentState?.validate() != true) return;
    widget.controller.register(
      email: _email.text,
      password: _password.text,
      displayName: _displayName.text,
    );
  }

  void _login() {
    if (_formKey.currentState?.validate() != true) return;
    widget.controller.loginWithSystemAccount(
      email: _email.text,
      password: _password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final canSubmit =
        _isRegistering ? controller.canRegister : controller.canSystemLogin;
    return Form(
      key: _formKey,
      // A Column, not a ListView: this sits inside the signed-out screen's
      // own scroll view.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isRegistering
                ? 'Regístrate con tu correo y una contraseña Monetta.'
                : 'Entra con el correo y contraseña de tu cuenta Monetta.',
            style: sans(size: 13, color: kInkMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('INICIAR SESIÓN')),
              ButtonSegment(value: true, label: Text('REGISTRARME')),
            ],
            selected: {_isRegistering},
            onSelectionChanged: controller.isLoading
                ? null
                : (selection) => setState(() {
                      _isRegistering = selection.single;
                      _formKey.currentState?.reset();
                    }),
          ),
          const SizedBox(height: 24),
          if (_isRegistering) ...[
            TextFormField(
              controller: _displayName,
              enabled: canSubmit && !controller.isLoading,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Nombre (opcional)'),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _email,
            enabled: canSubmit && !controller.isLoading,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty ||
                  !email.contains('@') ||
                  !email.contains('.')) {
                return 'Escribe un correo válido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            enabled: canSubmit && !controller.isLoading,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: _isRegistering
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Contraseña'),
            validator: (value) {
              if ((value ?? '').length < 8) {
                return 'Usa al menos 8 caracteres.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _isRegistering ? _register() : _login(),
          ),
          const SizedBox(height: 24),
          if (controller.lastError?.flow == AccountAuthFlow.monetta) ...[
            Text(
              _isRegistering
                  ? 'No se pudo crear la cuenta. Revisa los datos o usa Iniciar sesión.'
                  : 'No pudimos entrar con esos datos. Revísalos e inténtalo de nuevo.',
              style: sans(size: 12, color: kInk),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: (!canSubmit || controller.isLoading)
                ? null
                : (_isRegistering ? _register : _login),
            child: controller.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isRegistering ? 'CREAR CUENTA' : 'ENTRAR'),
          ),
          if (!canSubmit) ...[
            const SizedBox(height: 12),
            Text(
              'El servicio de cuentas aún no está configurado en esta versión.',
              style: sans(size: 11, color: kInkMuted),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Tu sesión se guarda de forma segura en este dispositivo.',
              style: sans(size: 11, color: kInkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
