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
  const AccountScreen({required this.controller, super.key});

  final AccountController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.isSignedIn
              ? _SignedIn(controller: controller)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: _SignedOut(controller: controller),
                ),
        ),
      ),
    );
  }
}

class _SignedIn extends StatelessWidget {
  const _SignedIn({required this.controller});

  final AccountController controller;

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
  const _SignedOut({required this.controller});

  final AccountController controller;

  @override
  State<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends State<_SignedOut> {
  bool _showLegacyForm = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final hasLegacy = controller.canSystemLogin || controller.canRegister;
    // Nothing to collapse behind a toggle when it is the only way in.
    final legacyExpanded = _showLegacyForm || !controller.canLogin;
    final error = controller.lastError;

    return ListView(
      children: [
        Text('Tu cuenta', style: display(20)),
        const SizedBox(height: 8),
        Text(
          'Guarda tus favoritos, consulta tus pedidos y compra más rápido. '
          'No necesitas cuenta para comprar.',
          style: sans(size: 13, color: kInkMuted, height: 1.5),
        ),
        const SizedBox(height: 24),
        if (controller.canLogin) ...[
          if (error != null &&
              error.flow == AccountAuthFlow.shopify &&
              !error.isSilent) ...[
            Text(_shopifyErrorMessage(error.kind), style: sans(size: 12)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: controller.isLoading ? null : controller.login,
            child: controller.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('INICIAR SESIÓN'),
          ),
          const SizedBox(height: 12),
          Text(
            'Se abre la página segura de Shopify. Si aún no tienes cuenta, '
            'puedes crearla ahí mismo. Monetta nunca ve tu contraseña.',
            style: sans(size: 11, color: kInkMuted, height: 1.5),
          ),
        ] else if (!hasLegacy)
          Text(
            'El inicio de sesión no está disponible en esta versión de la '
            'app. Puedes seguir comprando como invitado.',
            style: sans(size: 12, color: kInkMuted, height: 1.5),
          ),
        if (Navigator.of(context).canPop()) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('SEGUIR COMO INVITADO'),
            ),
          ),
        ],
        if (hasLegacy) ...[
          const SizedBox(height: 28),
          const Divider(height: 0.5),
          const SizedBox(height: 20),
          Text('Cuenta Monetta (correo)'.toUpperCase(), style: eyebrow()),
          const SizedBox(height: 12),
          if (!legacyExpanded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showLegacyForm = true),
                child: const Text('USAR MI CUENTA MONETTA'),
              ),
            )
          else
            _MonettaPasswordForm(controller: controller),
        ],
      ],
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
