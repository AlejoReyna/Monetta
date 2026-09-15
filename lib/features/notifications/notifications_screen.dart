/// Notificaciones (paquete E): lista, lectura, destinos y estados vacíos.
///
/// Secciones:
/// 1. Permiso del sistema y preferencias (datos reales de
///    [NotificationController]).
/// 2. Bandeja ([NotificationInbox], aislada por cuenta): lista con lectura,
///    destinos verificables y vacío honesto.
///
/// Cada aviso tiene un destino real: al tocarlo se marca como leído y se
/// entrega su ruta al manejador de navegación de la app. Sin ruta soportada,
/// se informa en vez de abrir algo incorrecto.
library;

import 'package:flutter/material.dart';

import '../../app/account_controller.dart';
import '../../app/notification_controller.dart';
import '../../data/notifications/notification_models.dart';
import '../account/account_boutique.dart';
import '../boutique/boutique_tokens.dart';
import '../rewards/rewards_section.dart';
import 'notification_inbox.dart';

Future<void> openNotifications(
  BuildContext context, {
  required NotificationInbox inbox,
  required String ownerId,
  NotificationController? controller,
  AccountController? accountController,
  RewardsReader? rewardsReader,
  void Function(NotificationRouteData route)? onOpenRoute,
  VoidCallback? onManagePreferences,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NotificationsScreen(
        inbox: inbox,
        ownerId: ownerId,
        controller: controller,
        accountController: accountController,
        rewardsReader: rewardsReader,
        onOpenRoute: onOpenRoute,
        onManagePreferences: onManagePreferences,
      ),
    ),
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    required this.inbox,
    required this.ownerId,
    this.controller,
    this.accountController,
    this.rewardsReader,
    this.onOpenRoute,
    this.onManagePreferences,
    super.key,
  });

  final NotificationInbox inbox;
  final String ownerId;
  final NotificationController? controller;
  final AccountController? accountController;
  final RewardsReader? rewardsReader;
  final void Function(NotificationRouteData route)? onOpenRoute;
  final VoidCallback? onManagePreferences;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notificaciones',
          style: boutiqueTitle(size: 15, color: palette.ink),
        ),
        actions: [
          ListenableBuilder(
            listenable: inbox,
            builder: (context, _) {
              final unread = inbox.unreadCountFor(ownerId);
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                key: const ValueKey('notifications-mark-all-read'),
                onPressed: () => inbox.markAllRead(ownerId),
                child: const Text('Leer todas'),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(.5),
          child: Container(height: .5, color: palette.hairline),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const AccountPageHeader(
              kicker: 'Avisos',
              title: 'Notificaciones',
            ),
            const SizedBox(height: BoutiqueSpace.lg),
            _PermissionSection(
              controller: controller,
              onManagePreferences: onManagePreferences,
            ),
            const SizedBox(height: BoutiqueSpace.lg),
            const ESectionTitle(title: 'Recientes'),
            const SizedBox(height: BoutiqueSpace.sm),
            _InboxList(
              inbox: inbox,
              ownerId: ownerId,
              onOpenRoute: onOpenRoute,
            ),
            if (accountController != null || rewardsReader != null) ...[
              const SizedBox(height: BoutiqueSpace.lg),
              const ESectionTitle(title: 'Tu saldo Monetta'),
              const SizedBox(height: BoutiqueSpace.sm),
              RewardsSection(
                controller: accountController,
                reader: rewardsReader,
                showMovements: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionSection extends StatelessWidget {
  const _PermissionSection({
    required this.controller,
    required this.onManagePreferences,
  });

  final NotificationController? controller;
  final VoidCallback? onManagePreferences;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) {
      return const ENotice(
        message: 'Las notificaciones aún no están configuradas en esta '
            'versión de la app.',
        icon: Icons.notifications_off_outlined,
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.available) {
          return const ENotice(
            message: 'Las notificaciones aún no están configuradas en esta '
                'versión de la app.',
            icon: Icons.notifications_off_outlined,
          );
        }
        switch (controller.permission) {
          case NotificationPermissionState.notDetermined:
            return ENotice(
              message: 'Activa los avisos para enterarte de pedidos, '
                  'reposiciones y tu saldo Monetta.',
              actionLabel: 'Activar avisos',
              onAction: controller.saving
                  ? null
                  : () => controller.requestSystemPermission(),
              icon: Icons.notifications_outlined,
            );
          case NotificationPermissionState.denied:
            return ENotice(
              message: 'Las notificaciones están desactivadas en los ajustes '
                  'del dispositivo. Actívalas ahí para recibir avisos.',
              actionLabel:
                  onManagePreferences == null ? null : 'Ver preferencias',
              onAction: onManagePreferences,
              icon: Icons.notifications_off_outlined,
            );
          case NotificationPermissionState.granted:
          case NotificationPermissionState.provisional:
            if (onManagePreferences == null) {
              return const SizedBox.shrink();
            }
            return ENotice(
              message: 'Recibes avisos en este dispositivo.',
              actionLabel: 'Gestionar preferencias',
              onAction: onManagePreferences,
              icon: Icons.notifications_outlined,
            );
        }
      },
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({
    required this.inbox,
    required this.ownerId,
    required this.onOpenRoute,
  });

  final NotificationInbox inbox;
  final String ownerId;
  final void Function(NotificationRouteData route)? onOpenRoute;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: inbox,
      builder: (context, _) {
        final items = inbox.itemsFor(ownerId);
        if (items.isEmpty) {
          return EEmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Aún no tienes notificaciones',
            body: 'Cuando Monetta te avise de un pedido, una reposición o tu '
                'saldo, aparecerá aquí.',
          );
        }
        return Column(
          children: [
            for (final item in items)
              _NotificationRow(
                item: item,
                onTap: () {
                  inbox.markRead(ownerId, item.id);
                  final open = onOpenRoute;
                  if (open == null) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Este aviso no tiene un destino configurado.',
                        ),
                      ),
                    );
                    return;
                  }
                  if (!notificationRouteIsSupported(item.route)) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Este aviso ya no tiene un destino disponible.',
                        ),
                      ),
                    );
                    return;
                  }
                  open(item.route);
                },
              ),
          ],
        );
      },
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final MonettaNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: '${item.read ? '' : 'Sin leer. '}${item.title}. ${item.body}',
      child: InkWell(
        key: ValueKey('notification-row-${item.id}'),
        onTap: onTap,
        borderRadius: BoutiqueRadius.card,
        child: Container(
          padding: const EdgeInsets.all(BoutiqueSpace.lg),
          decoration: BoxDecoration(
            color: item.read ? Colors.transparent : palette.surface,
            borderRadius: BoutiqueRadius.card,
            border: Border.all(color: palette.hairline, width: 1),
          ),
          margin: const EdgeInsets.only(bottom: BoutiqueSpace.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.read ? Colors.transparent : palette.goldText,
                  shape: BoxShape.circle,
                  border: item.read
                      ? Border.all(color: palette.hairline, width: 1)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: boutiqueText(
                              size: 14,
                              weight:
                                  item.read ? FontWeight.w400 : FontWeight.w700,
                              color: palette.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notificationKindLabel(item.kind),
                          style: boutiqueText(
                            size: 11,
                            color: palette.inkMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: boutiqueText(
                        size: 13,
                        color: palette.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeLabel(item.receivedAt),
                      style: boutiqueText(
                        size: 11,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: palette.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeLabel(DateTime at) {
    final now = DateTime.now();
    final diff = now.difference(at);
    if (diff.isNegative) return 'Ahora mismo';
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }
}
