/// Mi cuenta (paquete E): identidad, saldo, accesos y cierre de sesión.
///
/// La autenticación sigue alojada en Shopify: [openAccount] lanza el flujo
/// hospedado antes de presentar esta ruta, igual que antes. Secciones:
/// 1. identidad (nombre, correo, proveedor verificado),
/// 2. saldo Monetta (presentación reutilizable, datos de F),
/// 3. accesos (pedidos, favoritos, notificaciones, contacto, mayoreo, admin),
/// 4. cierre de sesión.
///
/// La figura de la lámina numera mal sus encabezados; se sigue su contenido:
/// perfil de Ana, filas de Mis pedidos / Favoritos / Notificaciones /
/// contacto y cierre de sesión. La fila antigua de "320 puntos / Nivel Plata"
/// no se implementa: Miguel la sustituyó por saldo en pesos.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/account_controller.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../data/accounts_orders/account_deletion_client.dart';
import '../../data/customer_auth/customer_auth_error.dart';
import '../../data/local/database.dart' show OrderSummary;
import '../../data/repositories/order_history_repository.dart';
import '../contact/contact_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notification_inbox.dart';
import '../notifications/notifications_screen.dart';
import '../orders/order_detail_screen.dart';
import '../orders/order_status.dart';
import '../orders/orders_screen.dart';
import '../rewards/rewards_section.dart';
import 'account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import 'delete_account_screen.dart';
import 'privacy_policy_config.dart';

/// Abre el flujo hospedado de Shopify cuando hace falta y luego presenta la
/// cuenta. La autenticación siempre ocurre antes del push de la ruta para que
/// el diseño anterior de login en la app nunca parpadee bajo el navegador.
Future<void> openAccount(
  BuildContext context, {
  required AccountController controller,
  bool Function()? canOpenAdmin,
  VoidCallback? onOpenAdmin,
  VoidCallback? onOpenPartner,
  RewardsReader? rewardsReader,
  NotificationInbox? notificationInbox,
  VoidCallback? onOpenInvite,
  AccountDeletionClient? deletionClient,
  PrivacyPolicyConfig? privacyPolicy,
  Future<bool> Function(Uri uri)? openExternalUri,
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
        rewardsReader: rewardsReader,
        notificationInbox: notificationInbox,
        onOpenInvite: onOpenInvite,
        deletionClient: deletionClient,
        privacyPolicy: privacyPolicy,
        openExternalUri: openExternalUri,
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
    this.rewardsReader,
    this.notificationInbox,
    this.onOpenInvite,
    this.deletionClient,
    this.privacyPolicy,
    this.openExternalUri,
    super.key,
  });

  final AccountController controller;

  /// La administración del propietario sigue siendo una capacidad opcional
  /// para que los flujos de cuenta se reutilicen en pruebas y en builds sin
  /// control plane configurado.
  final bool Function()? canOpenAdmin;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenPartner;

  /// Lector Rewards (paquete F) fijo, normalmente un fixture de prueba. Nulo
  /// = la sección lo resuelve del backend configurado o muestra el estado
  /// honesto de no disponible. Nunca un saldo ficticio.
  final RewardsReader? rewardsReader;

  /// Bandeja de notificaciones. Nula hasta que la integración global la
  /// alimente (ver parche en `PAQUETE_E_ENTREGA.md`); entonces los avisos
  /// aparecen aislados por cuenta.
  final NotificationInbox? notificationInbox;

  /// Punto de entrada público de F para invitar/referidos. Nulo = la fila
  /// no se muestra (no se inventa un programa de invitados).
  final VoidCallback? onOpenInvite;

  final AccountDeletionClient? deletionClient;
  final PrivacyPolicyConfig? privacyPolicy;
  final Future<bool> Function(Uri uri)? openExternalUri;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Mi cuenta',
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Container(height: .5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.isSignedIn
              ? _SignedIn(
                  controller: controller,
                  showAdmin: canOpenAdmin?.call() == true,
                  onOpenAdmin: onOpenAdmin,
                  onOpenPartner: onOpenPartner,
                  rewardsReader: rewardsReader,
                  notificationInbox: notificationInbox,
                  onOpenInvite: onOpenInvite,
                  deletionClient: deletionClient,
                  privacyPolicy: privacyPolicy,
                  openExternalUri: openExternalUri,
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
    required this.rewardsReader,
    required this.notificationInbox,
    required this.onOpenInvite,
    required this.deletionClient,
    required this.privacyPolicy,
    required this.openExternalUri,
  });

  final AccountController controller;
  final bool showAdmin;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenPartner;
  final RewardsReader? rewardsReader;
  final NotificationInbox? notificationInbox;
  final VoidCallback? onOpenInvite;
  final AccountDeletionClient? deletionClient;
  final PrivacyPolicyConfig? privacyPolicy;
  final Future<bool> Function(Uri uri)? openExternalUri;

  Future<void> _logout(BuildContext context) async {
    await controller.logout();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = controller.account!;
    final palette = context.boutique;
    // Desplazamiento con construcción total (no diferida): los accesos de
    // administración y partner hub deben existir en el árbol aunque queden
    // bajo el primer pantallazo, igual que antes del rediseño.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IdentityCard(
            controller: controller,
            onRelogin: controller.isLoading ? null : () => controller.login(),
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          AutoRewardsSection(
            controller: controller,
            reader: rewardsReader,
          ),
          if (onOpenInvite != null) ...[
            const SizedBox(height: BoutiqueSpace.md),
            ECard(
              children: [
                EAccessRow(
                  key: const ValueKey('account-invite'),
                  icon: Icons.card_giftcard_outlined,
                  title: 'Invitar a Monetta',
                  subtitle: 'Comparte tu enlace y gana saldo con referidos',
                  onTap: onOpenInvite,
                ),
              ],
            ),
          ],
          const SizedBox(height: BoutiqueSpace.sectionGapTight),
          const ESectionTitle(title: 'Mis accesos'),
          const SizedBox(height: BoutiqueSpace.sm),
          ECard(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            children: [
              EAccessRow(
                key: const ValueKey('account-open-orders'),
                icon: Icons.shopping_bag_outlined,
                title: 'Mis pedidos',
                subtitle: _ordersSubtitle(),
                onTap: () => openOrders(
                  context,
                  controller: controller,
                  rewardsReader: rewardsReader,
                ),
              ),
              EAccessRow(
                key: const ValueKey('account-open-favorites'),
                icon: Icons.favorite_border_rounded,
                title: 'Favoritos',
                subtitle: 'Tus piezas guardadas',
                onTap: () => openFavorites(context),
              ),
              EAccessRow(
                key: const ValueKey('account-open-notifications'),
                icon: Icons.notifications_none_rounded,
                title: 'Notificaciones',
                subtitle: 'Avisos de pedidos y saldo',
                onTap: () => openNotifications(
                  context,
                  inbox: notificationInbox ?? _sharedAccountInbox,
                  ownerId: account.localAccountId,
                  accountController: controller,
                  rewardsReader: rewardsReader,
                ),
              ),
              EAccessRow(
                key: const ValueKey('account-open-contact'),
                icon: Icons.chat_outlined,
                title: 'Contacto y ayuda',
                subtitle: 'WhatsApp, sitio y redes',
                onTap: () => openContact(context),
              ),
            ],
          ),
          const SizedBox(height: BoutiqueSpace.sectionGapTight),
          const ESectionTitle(title: 'Mis pedidos recientes'),
          const SizedBox(height: BoutiqueSpace.sm),
          _OrdersPreview(controller: controller),
          if (showAdmin && onOpenAdmin != null) ...[
            const SizedBox(height: BoutiqueSpace.sectionGapTight),
            InkWell(
              key: const ValueKey('open-owner-admin'),
              onTap: onOpenAdmin,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kInk,
                  borderRadius: BoutiqueRadius.card,
                  border: Border.all(
                    color: context.monettaColors.accent,
                    width: .6,
                  ),
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
            const SizedBox(height: BoutiqueSpace.md),
            _PartnerAccountLink(onTap: onOpenPartner!),
          ],
          const SizedBox(height: BoutiqueSpace.sectionGapTight),
          const ESectionTitle(title: 'Privacidad y datos'),
          const SizedBox(height: BoutiqueSpace.sm),
          _PrivacyLinks(
            onDelete: () => openDeleteAccount(
              context,
              client: deletionClient,
              accessToken: controller.accessTokenForBackend,
              reauthenticate: controller.reauthenticateForDeletion,
              signInForDeletion: controller.account?.authProvider == 'monetta'
                  ? () => controller.signInForAccountDeletion(deletionClient)
                  : null,
              abandonUnmatchedLogin: controller.abandonUnmatchedDeletionLogin,
              signOutToHome: controller.completeAccountDeletion,
              supportUri: accountDeletionSupportUri(),
              openUri: openExternalUri,
              onViewOrder: (ref) => _openBlockingOrder(context, ref),
            ),
            onPrivacyPolicy: () => _openPrivacyPolicy(context),
          ),
          const SizedBox(height: BoutiqueSpace.sectionGapTight),
          BoutiqueButton(
            key: const ValueKey('account-logout'),
            label: 'Cerrar sesión',
            filled: false,
            onPressed: controller.isLoading ? null : () => _logout(context),
          ),
          if (controller.isLoading) ...[
            const SizedBox(height: BoutiqueSpace.md),
            Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.inkMuted,
                ),
              ),
            ),
          ],
          const SizedBox(height: BoutiqueSpace.sm),
          Center(
            child: TextButton(
              onPressed: controller.isLoading ? null : () => _logout(context),
              child: controller.isLoading
                  ? const Text('Cerrando…')
                  : const Text('CERRAR SESIÓN'),
            ),
          ),
        ],
      ),
    );
  }

  void _openBlockingOrder(BuildContext context, AccountDeletionOrderRef ref) {
    OrderSummary? match;
    for (final order in controller.orders) {
      final shopifyId = order.shopifyOrderId;
      if (order.id == ref.id ||
          order.id == ref.shopifyOrderId ||
          order.id == 'apartado:${ref.id}' ||
          (shopifyId != null &&
              (shopifyId == ref.shopifyOrderId ||
                  shopifyId.endsWith('/${ref.shopifyOrderId}')))) {
        match = order;
        break;
      }
    }
    if (match != null) {
      openOrderDetail(
        context,
        order: match,
        rewardsController: controller,
        openUri: openExternalUri,
      );
      return;
    }
    openOrders(context, controller: controller);
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = (privacyPolicy ?? PrivacyPolicyConfig.fromEnvironment()).url;
    final open = openExternalUri ??
        ((target) => launchUrl(target, mode: LaunchMode.externalApplication));
    final ok = await open(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  String? _ordersSubtitle() {
    final count = controller.orders.length;
    if (controller.ordersLoading && count == 0) return 'Cargando…';
    if (count == 0) return 'Tu historial aparecerá aquí';
    return count == 1 ? '1 pedido' : '$count pedidos';
  }
}

class _PrivacyLinks extends StatelessWidget {
  const _PrivacyLinks({
    required this.onDelete,
    required this.onPrivacyPolicy,
  });

  final VoidCallback onDelete;
  final VoidCallback onPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ECard(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('account-privacy-policy'),
            onPressed: onPrivacyPolicy,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, BoutiqueSpace.tapTarget),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: palette.ink,
            ),
            child: Text(
              'Política de privacidad',
              style: boutiqueText(
                size: 14,
                color: palette.ink,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('account-delete'),
            onPressed: onDelete,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, BoutiqueSpace.tapTarget),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: palette.sale,
            ),
            child: Text(
              'Eliminar mi cuenta',
              style: boutiqueText(size: 14, color: palette.sale),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bandeja compartida de respaldo hasta que la integración global alimente
/// una por sesión. Aislada por cuenta igual que cualquier otra.
final NotificationInbox _sharedAccountInbox = NotificationInbox();

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.controller,
    required this.onRelogin,
  });

  final AccountController controller;
  final VoidCallback? onRelogin;

  @override
  Widget build(BuildContext context) {
    final account = controller.account!;
    final palette = context.boutique;
    final name = account.displayName ?? account.email ?? 'Tu cuenta';
    final initial =
        name.trim().isEmpty ? 'M' : name.trim().substring(0, 1).toUpperCase();
    final provider = account.authProvider == 'monetta'
        ? 'Cuenta Monetta verificada'
        : 'Cuenta Shopify verificada';
    final sessionExpired =
        controller.lastError?.kind == CustomerAuthErrorKind.sessionExpired;
    return ECard(
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.action,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: boutiqueDisplay(24, color: palette.onAction),
              ),
            ),
            const SizedBox(width: BoutiqueSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sesión iniciada',
                    style: boutiqueEyebrow(
                      size: 11,
                      color: palette.goldText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: boutiqueScreenTitle(
                      context: context,
                      color: palette.ink,
                    ),
                  ),
                  if (account.displayName != null && account.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      account.email!,
                      style: boutiqueText(
                        size: 12,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: palette.goldText,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          provider,
                          style: boutiqueText(
                            size: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (sessionExpired) ...[
          const SizedBox(height: BoutiqueSpace.md),
          ENotice(
            message: 'Tu sesión terminó. Inicia sesión de nuevo para '
                'actualizar tus pedidos y tu saldo.',
            actionLabel: 'Iniciar sesión',
            onAction: onRelogin,
            icon: Icons.lock_outline_rounded,
          ),
        ],
      ],
    );
  }
}

/// Vista previa del historial dentro de Cuenta. Conserva los mensajes y la
/// acción de actualización existentes; el historial completo vive en
/// [OrdersScreen].
class _OrdersPreview extends StatelessWidget {
  const _OrdersPreview({required this.controller});

  final AccountController controller;

  @override
  Widget build(BuildContext context) {
    final muted = sans(size: 13, color: context.monettaColors.contentMuted);
    if (controller.ordersLoading && controller.orders.isEmpty) {
      return ECard(
        children: [Text('Cargando…', style: muted)],
      );
    }

    return ECard(
      children: [
        if (_statusMessage(controller) case final message?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(message, style: muted),
          ),
        for (final order in controller.orders.take(3)) _OrderRow(order: order),
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const ValueKey('refresh-orders'),
                onPressed: controller.ordersLoading
                    ? null
                    : () => controller.loadOrders(),
                child: Text(
                  controller.ordersLoading
                      ? 'Actualizando…'
                      : 'Actualizar pedidos',
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('account-view-all-orders'),
              onPressed: () => openOrders(
                context,
                controller: controller,
              ),
              child: const Text('Ver todos'),
            ),
          ],
        ),
      ],
    );
  }

  String? _statusMessage(AccountController controller) {
    switch (controller.ordersStatus) {
      case OrderHistoryStatus.empty:
        return controller.orders.isEmpty ? 'Aún no tienes pedidos.' : null;
      case OrderHistoryStatus.populated:
        return null;
      case OrderHistoryStatus.unavailable:
        return 'El historial de pedidos no está disponible en esta versión.';
      case OrderHistoryStatus.failed:
        return 'No pudimos cargar tus pedidos. Intenta actualizar.';
      case OrderHistoryStatus.staleCache:
        return 'Mostrando pedidos guardados. No pudimos actualizar ahora.';
    }
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    final status = orderDisplayStatus(order);
    // Wrap, no Row con total fijo: a texto ampliado el importe baja a su
    // propia línea en vez de comprimir la identidad del pedido.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: BoutiqueSpace.sm,
        runSpacing: 2,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                orderLabelOf(order),
                style: sans(size: 13, weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${orderDateLabel(order.placedAt)} · ${status.label}',
                style: sans(
                  size: 11,
                  color: context.monettaColors.contentMuted,
                ),
              ),
            ],
          ),
          Text(kMoney.format(order.totalAmount), style: sans(size: 13)),
        ],
      ),
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
          color: context.monettaColors.surfaceMuted,
          borderRadius: BoutiqueRadius.card,
          border: Border.all(color: context.monettaColors.divider),
        ),
        child: Row(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 21,
              color: context.monettaColors.accent,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VENDE CON MONETTA', style: eyebrow(size: 9)),
                  const SizedBox(height: 3),
                  Text(
                    'Catálogos y cotizaciones para tu negocio',
                    style: sans(
                      size: 11.5,
                      color: context.monettaColors.contentMuted,
                    ),
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
      // Nunca se muestra — `AccountError.isSilent` lo filtra antes de que la
      // UI pida una frase. Presente para que el switch siga exhaustivo.
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
