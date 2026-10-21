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

import 'dart:async';

import 'package:flutter/material.dart';

import '../navigation/monetta_page_header.dart';
import '../navigation/monetta_floating_bottom_navigation.dart';

import '../../app/account_controller.dart';
import '../../main.dart' show StoreScope;
import '../catalog/catalog_browse_screen.dart';
import '../checkout/checkout_screen.dart';
import '../orders/order_detail_screen.dart';
import 'profile_components.dart';
import 'profile_rewards_card.dart';
import '../../app/theme.dart';
import '../../data/customer_auth/customer_auth_error.dart';
import '../../data/customer_auth/customer_identity.dart';
import '../../data/repositories/order_history_repository.dart';
import '../contact/contact_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notification_inbox.dart';
import '../notifications/notifications_screen.dart';
import '../orders/order_status.dart';
import '../orders/orders_screen.dart';
import '../rewards/rewards_section.dart';
import 'account_boutique.dart';
import '../boutique/boutique_tokens.dart';

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
}) async {
  if (controller.isLoading) return;
  if (controller.isSignedIn) unawaited(controller.refreshProfile());

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

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.maybeOf(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      extendBody: true,
      bottomNavigationBar: store == null
          ? null
          : MonettaFloatingBottomNavigation(
              current: MonettaBottomDestination.account,
              bagCount: store.bagQuantity,
              onSelected: (destination) {
                switch (destination) {
                  case MonettaBottomDestination.home:
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  case MonettaBottomDestination.catalog:
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CatalogBrowseScreen(
                          products: store.products,
                          facetsById: store.facetsById,
                          bagCount: store.bagQuantity,
                        ),
                      ),
                    );
                  case MonettaBottomDestination.bag:
                    unawaited(openBag(context));
                  case MonettaBottomDestination.account:
                    break;
                }
              },
            ),
      appBar: buildMonettaPageAppBar(
        context,
        title: 'Mi cuenta',
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
  });

  final AccountController controller;
  final bool showAdmin;
  final VoidCallback? onOpenAdmin;
  final VoidCallback? onOpenPartner;
  final RewardsReader? rewardsReader;
  final NotificationInbox? notificationInbox;
  final VoidCallback? onOpenInvite;

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
    final store = StoreScope.maybeOf(context);
    final inbox = notificationInbox ?? _sharedAccountInbox;
    final favorites = store?.wishlist ?? <String>{};
    final saved =
        store?.products.where((p) => favorites.contains(p.id)).firstOrNull;
    final inTransit =
        filterOrders(controller.orders, OrderFilter.inTransit).length;
    void openAccountNotifications() => openNotifications(
          context,
          inbox: inbox,
          ownerId: account.localAccountId,
          accountController: controller,
          rewardsReader: rewardsReader,
        );
    // Desplazamiento con construcción total (no diferida): los accesos de
    // administración y partner hub deben existir en el árbol aunque queden
    // bajo el primer pantallazo, igual que antes del rediseño.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IdentityCard(
            controller: controller,
            onRelogin: controller.canLogin && !controller.isLoading
                ? () => controller.login()
                : null,
            inbox: inbox,
            onNotifications: openAccountNotifications,
          ),
          const SizedBox(height: 24),
          ProfileRewardsCard(
            key: ValueKey(account.localAccountId),
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
          ProfileSectionHeading(
            title: 'Tu cuenta',
            action: Text(
              'Todo a mano',
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 300 &&
                      MediaQuery.textScalerOf(context).scale(14) < 23
                  ? 2
                  : 1;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width:
                        (constraints.maxWidth - (columns - 1) * 14) / columns,
                    child: ProfileQuickAccess(
                      key: const ValueKey('account-open-orders'),
                      title: 'Mis pedidos',
                      icon: Icons.shopping_bag_outlined,
                      count:
                          controller.ordersLoading && controller.orders.isEmpty
                              ? '…'
                              : controller.orders.isEmpty &&
                                      controller.ordersStatus !=
                                          OrderHistoryStatus.empty
                                  ? '—'
                                  : controller.orders.length
                                      .toString()
                                      .padLeft(2, '0'),
                      unit:
                          controller.orders.length == 1 ? 'pedido' : 'pedidos',
                      subtitle: inTransit > 0
                          ? '$inTransit en camino'
                          : _ordersSubtitle(),
                      onTap: () => openOrders(
                        context,
                        controller: controller,
                        rewardsReader: rewardsReader,
                      ),
                    ),
                  ),
                  SizedBox(
                    width:
                        (constraints.maxWidth - (columns - 1) * 14) / columns,
                    child: ProfileQuickAccess(
                      key: const ValueKey('account-open-favorites'),
                      title: 'Mis favoritos',
                      icon: Icons.favorite_border_rounded,
                      count: favorites.length.toString().padLeft(2, '0'),
                      unit: favorites.length == 1 ? 'pieza' : 'piezas',
                      subtitle: 'Elegidas por ti',
                      onTap: () => openFavorites(context),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _OrdersPreview(controller: controller, rewardsReader: rewardsReader),
          const SizedBox(height: 16),
          ProfileFavoritesFeature(
            count: favorites.length,
            product: saved,
            onTap: () => openFavorites(context),
          ),
          const SizedBox(height: 28),
          const ProfileSectionHeading(title: 'A tu manera'),
          EAccessRow(
            key: const ValueKey('account-open-information'),
            icon: Icons.person_outline_rounded,
            title: 'Tu información',
            subtitle: 'Nombre y correo de tu cuenta',
            onTap: () => _showAccountInformation(context, controller),
          ),
          EAccessRow(
            key: const ValueKey('account-open-notifications'),
            icon: Icons.notifications_none_rounded,
            title: 'Notificaciones',
            subtitle: 'Avisos de pedidos y saldo',
            onTap: openAccountNotifications,
          ),
          EAccessRow(
            key: const ValueKey('account-open-contact'),
            icon: Icons.chat_outlined,
            title: 'Estamos para ti',
            subtitle: 'Contacto y ayuda',
            onTap: () => openContact(context),
          ),
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
              key: const ValueKey('account-logout'),
              onPressed: controller.isLoading ? null : () => _logout(context),
              child: controller.isLoading
                  ? const Text('Cerrando…')
                  : const Text('CERRAR SESIÓN'),
            ),
          ),
          Center(
            child: Text(
              'Hecho para ti, por Monetta.',
              style: boutiqueText(size: 11, color: palette.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  String _ordersSubtitle() {
    final count = controller.orders.length;
    if (controller.ordersLoading && count == 0) return 'Cargando…';
    if (count == 0) {
      return controller.ordersStatus == OrderHistoryStatus.empty
          ? 'Tu historial aparecerá aquí'
          : 'Consulta tu historial';
    }
    return count == 1 ? '1 pedido' : '$count pedidos';
  }
}

/// Bandeja compartida de respaldo hasta que la integración global alimente
/// una por sesión. Aislada por cuenta igual que cualquier otra.
final NotificationInbox _sharedAccountInbox = NotificationInbox();

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.controller,
    required this.onRelogin,
    required this.inbox,
    required this.onNotifications,
  });

  final AccountController controller;
  final VoidCallback? onRelogin;
  final NotificationInbox inbox;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final account = controller.account!;
    final palette = context.boutique;
    final name = customerProfileName(account.displayName) ?? 'Tu cuenta';
    final words = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final initials =
        words.take(2).map((s) => s.characters.first.toUpperCase()).join();
    final sessionExpired =
        controller.lastError?.kind == CustomerAuthErrorKind.sessionExpired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.action,
              ),
              child: Text(
                initials.isEmpty ? 'M' : initials,
                style: boutiqueDisplay(24, color: palette.onAction),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qué gusto verte,',
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: boutiqueScreenTitle(
                      context: context,
                      color: palette.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ListenableBuilder(
              listenable: inbox,
              builder: (context, _) {
                final count = inbox.unreadCountFor(account.localAccountId);
                return IconButton(
                  key: const ValueKey('profile-notifications'),
                  tooltip: count == 0
                      ? 'Notificaciones'
                      : 'Notificaciones, $count sin leer',
                  style: IconButton.styleFrom(backgroundColor: palette.surface),
                  onPressed: onNotifications,
                  icon: Badge(
                    isLabelVisible: count > 0,
                    backgroundColor: palette.gold,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                );
              },
            ),
          ],
        ),
        if (sessionExpired) ...[
          const SizedBox(height: 12),
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

void _showAccountInformation(
  BuildContext context,
  AccountController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: context.boutique.canvas,
    builder: (_) => _AccountInformationSheet(controller: controller),
  );
}

class _AccountInformationSheet extends StatefulWidget {
  const _AccountInformationSheet({required this.controller});

  final AccountController controller;

  @override
  State<_AccountInformationSheet> createState() =>
      _AccountInformationSheetState();
}

class _AccountInformationSheetState extends State<_AccountInformationSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final String _accountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = widget.controller.account!;
    _accountId = account.localAccountId;
    _name = TextEditingController(
      text: customerProfileName(account.displayName) ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    if (widget.controller.account?.localAccountId != _accountId) return;
    setState(() => _saving = true);
    try {
      await widget.controller.saveProfileName(_name.text);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showAccountMessage(
        context,
        'No pudimos guardar tu nombre. Inténtalo de nuevo.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.controller.account!;
    final palette = context.boutique;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Tu información', style: boutiqueDisplay(26)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('profile-name-field'),
                controller: _name,
                enabled: !_saving,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                style: boutiqueText(),
                decoration: const InputDecoration(
                  labelText: 'Nombre en Monetta',
                  hintText: '¿Cómo te llamas?',
                ),
                validator: (value) => customerProfileName(value) == null
                    ? 'Escribe tu nombre, no tu correo.'
                    : null,
                onFieldSubmitted: (_) => _save(),
              ),
              Text(
                'Este nombre se guarda para tu cuenta en este dispositivo.',
                style: boutiqueText(size: 12, color: palette.inkMuted),
              ),
              if (account.email case final email?) ...[
                const SizedBox(height: 20),
                Text(email, style: boutiqueText(color: palette.inkMuted)),
              ],
              const SizedBox(height: 12),
              Text(
                account.authProvider == 'monetta'
                    ? 'Cuenta Monetta verificada'
                    : 'Cuenta Shopify verificada',
                style: boutiqueText(size: 12, color: palette.goldText),
              ),
              const SizedBox(height: 24),
              BoutiqueButton(
                key: const ValueKey('profile-save-name'),
                label: _saving ? 'Guardando…' : 'Guardar nombre',
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vista previa del historial dentro de Cuenta. Conserva los mensajes y la
/// acción de actualización existentes; el historial completo vive en
/// [OrdersScreen].
class _OrdersPreview extends StatelessWidget {
  const _OrdersPreview({required this.controller, this.rewardsReader});

  final AccountController controller;
  final RewardsReader? rewardsReader;

  @override
  Widget build(BuildContext context) {
    final muted = sans(size: 13, color: context.monettaColors.contentMuted);
    if (controller.ordersLoading && controller.orders.isEmpty) {
      return ECard(
        children: [Text('Cargando…', style: muted)],
      );
    }

    final orders = [...controller.orders]
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    final latest = orders.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeading(
          title: 'Tu última compra',
          action: TextButton(
            key: const ValueKey('account-view-all-orders'),
            onPressed: () => openOrders(
              context,
              controller: controller,
              rewardsReader: rewardsReader,
            ),
            child: Text(
              'Ver todas',
              style: boutiqueText(size: 12, color: context.boutique.goldText),
            ),
          ),
        ),
        if (_statusMessage(controller) case final message?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(message, style: muted),
          ),
        if (latest != null)
          ProfileLatestOrder(
            order: latest,
            onTap: () => openOrderDetail(
              context,
              order: latest,
              rewardsReader: rewardsReader,
              rewardsController: controller,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('refresh-orders'),
            onPressed:
                controller.ordersLoading ? null : () => controller.loadOrders(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              controller.ordersLoading ? 'Actualizando…' : 'Actualizar pedidos',
            ),
          ),
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
