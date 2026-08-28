/// The signed-in account page.
///
/// Signed-out shoppers never see a Flutter login page: [openAccount] launches
/// Shopify's hosted authentication first and only pushes this route after a
/// successful callback.
library;

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/theme.dart';
import '../../data/customer_auth/customer_auth_error.dart';
import '../../data/local/database.dart' show OrderSummary;

/// Opens the hosted Shopify flow when needed, then presents the signed-in
/// account. Keeping authentication before the route push prevents the old
/// in-app login design from flashing underneath the system browser.
Future<void> openAccount(
  BuildContext context, {
  required AccountController controller,
  bool Function()? canOpenAdmin,
  VoidCallback? onOpenAdmin,
  VoidCallback? onOpenPartner,
}) async {
  if (controller.isLoading) return;

  if (!controller.isSignedIn) {
    if (!controller.canLogin) {
      _showAccountMessage(
        context,
        'El inicio de sesión no está disponible en esta versión de la app.',
      );
      return;
    }

    await controller.login();
    if (!context.mounted) return;
    if (!controller.isSignedIn) {
      final error = controller.lastError;
      if (error != null && !error.isSilent) {
        _showAccountMessage(context, _shopifyErrorMessage(error.kind));
      }
      return;
    }
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AccountScreen(
        controller: controller,
        canOpenAdmin: canOpenAdmin,
        onOpenAdmin: onOpenAdmin,
        onOpenPartner: onOpenPartner,
      ),
    ),
  );
}

void _showAccountMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({
    required this.controller,
    this.canOpenAdmin,
    this.onOpenAdmin,
    this.onOpenPartner,
    super.key,
  });

  final AccountController controller;

  /// Owner administration remains an optional capability so account flows
  /// stay reusable in tests and in builds without a configured control plane.
  final bool Function()? canOpenAdmin;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenPartner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const MonettaWordmark.appBar()),
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
              : const SizedBox.shrink(),
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

  Future<void> _logout(BuildContext context) async {
    await controller.logout();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

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
          onPressed: controller.isLoading ? null : () => _logout(context),
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
