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
          account.email ?? account.displayName ?? 'Tu cuenta',
          style: sans(size: 14, color: kInkMuted),
        ),
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

class _SignedOut extends StatefulWidget {
  const _SignedOut({required this.controller});

  final AccountController controller;

  @override
  State<_SignedOut> createState() => _SignedOutState();
}

class _SignedOutState extends State<_SignedOut> {
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
      child: ListView(
        children: [
          Text(
            _isRegistering ? 'Crea tu cuenta' : 'Inicia sesión',
            style: display(20),
          ),
          const SizedBox(height: 8),
          Text(
            _isRegistering
                ? 'Regístrate directamente con Monetta. No necesitas una cuenta de Shopify.'
                : 'Entra con el correo y contraseña de tu cuenta Monetta.',
            style: sans(size: 13, color: kInkMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
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
          if (controller.lastError != null) ...[
            Text(
              _isRegistering
                  ? 'No se pudo crear la cuenta. Revisa los datos o usa Iniciar sesión.'
                  : 'Correo o contraseña incorrectos.',
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
