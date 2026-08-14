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
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${placedAt.day} ${months[placedAt.month - 1]} ${placedAt.year}';
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.controller});

  final AccountController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inicia sesión', style: display(20)),
        const SizedBox(height: 8),
        Text(
          'Guarda tu bolsa y tu lista de deseos entre dispositivos, y revisa '
          'tu historial de pedidos. Nunca es necesario para comprar — '
          'puedes seguir comprando como invitado.',
          style: sans(size: 13, color: kInkMuted, height: 1.5),
        ),
        const SizedBox(height: 24),
        if (controller.lastError != null) ...[
          Text(
            'No se pudo iniciar sesión. Intenta de nuevo.',
            style: sans(size: 12, color: kInk),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: (!controller.canLogin || controller.isLoading) ? null : controller.login,
          child: controller.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('INICIAR SESIÓN'),
        ),
        if (!controller.canLogin) ...[
          const SizedBox(height: 12),
          Text(
            'El inicio de sesión aún no está disponible en esta versión.',
            style: sans(size: 11, color: kInkMuted),
          ),
        ],
      ],
    );
  }
}
