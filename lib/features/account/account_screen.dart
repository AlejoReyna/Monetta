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

import '../../platform/system_layout_context.dart';
import '../navigation/adaptive_storefront_scaffold.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/account_controller.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../main.dart';
import '../../data/accounts_orders/account_deletion_client.dart';
import '../../data/accounts_orders/accounts_orders_config.dart';
import '../rewards/rewards_api.dart';
import '../wholesale/wholesale_screen.dart';
import '../../data/customer_auth/customer_auth_error.dart';
import '../../data/local/database.dart' show OrderSummary;
import '../catalog/categories_screen.dart';
import '../catalog/search_screen.dart';
import '../checkout/checkout_screen.dart';
import '../contact/contact_screen.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notification_inbox.dart';
import '../notifications/notifications_screen.dart';
import '../orders/order_detail_screen.dart';
import '../orders/orders_screen.dart';
import '../personalization/personalization_screen.dart';
import '../boutique/guide_art.dart';
import '../navigation/guide_chrome.dart';
import '../navigation/guide_drawer.dart';
import '../navigation/monetta_bottom_navigation.dart';
import '../rewards/rewards_guide_screen.dart';
import '../rewards/rewards_section.dart';
import '../rewards/rewards_share_screen.dart';
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
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
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
    final store = StoreScope.maybeOf(context);
    return AdaptiveStorefrontScaffold(
      backgroundColor: palette.canvas,
      drawer: guideDrawer(context),
      appBar: guideAppBar(
        context,
        searchEnabled: store != null,
        onSearch: () => unawaited(openSearch(context)),
      ),
      body: SystemUsableSurface(
        child: SafeArea(
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
      ),
      bottomNavigationBar: MonettaBottomNavigation(
        current: MonettaBottomDestination.account,
        bagCount: store?.bagQuantity ?? 0,
        onSelected: (destination) {
          switch (destination) {
            case MonettaBottomDestination.home:
              Navigator.of(context).popUntil((route) => route.isFirst);
            case MonettaBottomDestination.catalog:
              unawaited(openCategories(context));
            case MonettaBottomDestination.bag:
              if (store != null) unawaited(openBag(context));
            case MonettaBottomDestination.account:
              break;
          }
        },
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IdentityCard(
            controller: controller,
            onRelogin: controller.isLoading ? null : () => controller.login(),
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          _RewardsRow(controller: controller, reader: rewardsReader),
          const SizedBox(height: BoutiqueSpace.md),
          ECard(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            children: [
              EAccessRow(
                key: const ValueKey('account-open-orders'),
                icon: Icons.inventory_2_outlined,
                title: 'Mis pedidos',
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
                onTap: () => openFavorites(context),
              ),
              EAccessRow(
                key: const ValueKey('account-open-notifications'),
                icon: Icons.notifications_none_rounded,
                title: 'Notificaciones',
                onTap: () => openNotifications(
                  context,
                  inbox: notificationInbox ?? sharedAccountNotificationInbox,
                  ownerId: account.localAccountId,
                  accountController: controller,
                  rewardsReader: rewardsReader,
                ),
              ),
              EAccessRow(
                key: const ValueKey('account-open-addresses'),
                icon: Icons.location_on_outlined,
                title: 'Direcciones',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'Direcciones',
                  message: kAccountAddressesInfo,
                ),
              ),
              EAccessRow(
                key: const ValueKey('account-open-payments'),
                icon: Icons.credit_card_outlined,
                title: 'Métodos de pago',
                onTap: () => _showInfoSheet(
                  context,
                  title: 'Métodos de pago',
                  message: kAccountPaymentsInfo,
                ),
              ),
              EAccessRow(
                key: const ValueKey('account-open-personalization'),
                icon: Icons.settings_outlined,
                title: 'Preferencias',
                onTap: () => openPersonalization(context),
              ),
              EAccessRow(
                key: const ValueKey('account-open-wholesale'),
                icon: Icons.shopping_bag_outlined,
                title: 'Modo Mayoreo',
                subtitle: 'Desde 3 piezas',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WholesaleScreen(),
                  ),
                ),
              ),
              EAccessRow(
                key: const ValueKey('account-open-contact'),
                icon: Icons.help_outline_rounded,
                title: 'Ayuda y contacto',
                onTap: () => openContact(context),
              ),
              if (onOpenInvite != null)
                EAccessRow(
                  key: const ValueKey('account-invite'),
                  icon: Icons.card_giftcard_outlined,
                  title: 'Invitar a Monetta',
                  subtitle: 'Comparte tu enlace y gana saldo con referidos',
                  onTap: onOpenInvite,
                ),
            ],
          ),
          const SizedBox(height: BoutiqueSpace.lg),
          GuideShareEarnBanner(
            asset: kGuideShareCatalog,
            action: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: GuidePillButton(
                key: const ValueKey('account-share-catalog'),
                label: 'VER CATÁLOGO',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        RewardsShareScreen(accountController: controller),
                  ),
                ),
              ),
            ),
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
          // Legal links are required by the App Store: they stay, compact.
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
}

class _PrivacyLinks extends StatelessWidget {
  const _PrivacyLinks({required this.onDelete, required this.onPrivacyPolicy});

  final VoidCallback onDelete;
  final VoidCallback onPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: BoutiqueSpace.lg,
      children: [
        TextButton(
          key: const ValueKey('account-privacy-policy'),
          onPressed: onPrivacyPolicy,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, BoutiqueSpace.tapTarget),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: palette.ink,
          ),
          child: Text(
            'Política de privacidad',
            style: boutiqueText(
              size: 13,
              color: palette.ink,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('account-delete'),
          onPressed: onDelete,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, BoutiqueSpace.tapTarget),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: palette.sale,
          ),
          child: Text(
            'Eliminar mi cuenta',
            style: boutiqueText(size: 13, color: palette.sale),
          ),
        ),
      ],
    );
  }
}

/// Texto informativo de «Direcciones»: la app no guarda direcciones.
const String kAccountAddressesInfo =
    'Tus direcciones se capturan en el checkout seguro de Shopify al pagar.';

/// Texto informativo de «Métodos de pago»: sólo informa, no guarda tarjetas.
const String kAccountPaymentsInfo =
    'Aceptamos tarjeta de crédito o débito y transferencia bancaria.';

void _showInfoSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final palette = context.boutique;
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.canvas,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          key: const ValueKey('account-info-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: boutiqueScreenTitle(
                  context: sheetContext,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: BoutiqueSpace.sm),
              Text(
                message,
                style: boutiqueText(size: 15, color: palette.inkMuted),
              ),
              const SizedBox(height: BoutiqueSpace.lg),
              BoutiqueButton(
                key: const ValueKey('account-info-sheet-close'),
                label: 'Entendido',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Bandeja compartida de respaldo hasta que la integración global alimente
/// una por sesión. Aislada por cuenta igual que cualquier otra.
final NotificationInbox sharedAccountNotificationInbox = NotificationInbox();

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.controller, required this.onRelogin});

  final AccountController controller;
  final VoidCallback? onRelogin;

  @override
  Widget build(BuildContext context) {
    final account = controller.account!;
    final palette = context.boutique;
    final name = account.displayName ?? account.email ?? 'Tu cuenta';
    final initial =
        name.trim().isEmpty ? 'M' : name.trim().substring(0, 1).toUpperCase();
    final sessionExpired =
        controller.lastError?.kind == CustomerAuthErrorKind.sessionExpired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const ValueKey('account-identity'),
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.action,
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: boutiqueDisplay(26, color: palette.onAction),
              ),
            ),
            const SizedBox(width: BoutiqueSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueScreenTitle(
                      context: context,
                      color: palette.ink,
                    ),
                  ),
                  if (account.displayName != null && account.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      account.email!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: boutiqueText(size: 13, color: palette.inkMuted),
                    ),
                  ],
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

/// «Monetta Rewards» row with the balance the server reports on the right.
///
/// The amount is read from the Rewards contract and shown as the server
/// returns it; without a reader, while loading or on any failure the row says
/// «Ver saldo». A late answer for another account is discarded.
class _RewardsRow extends StatefulWidget {
  const _RewardsRow({required this.controller, required this.reader});

  final AccountController controller;
  final RewardsReader? reader;

  @override
  State<_RewardsRow> createState() => _RewardsRowState();
}

class _RewardsRowState extends State<_RewardsRow> {
  RewardsApi? _api;
  RewardsReader? _effective;
  String? _balance;
  var _generation = 0;

  /// Account the shown balance (or the request in flight) belongs to.
  String? _trackedAccount;

  @override
  void initState() {
    super.initState();
    _trackedAccount = widget.controller.account?.localAccountId;
    widget.controller.addListener(_onAccountChanged);
    _resolveReader();
    _request();
  }

  @override
  void didUpdateWidget(covariant _RewardsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onAccountChanged);
      widget.controller.addListener(_onAccountChanged);
      _trackedAccount = widget.controller.account?.localAccountId;
    }
    if (oldWidget.reader != widget.reader ||
        oldWidget.controller != widget.controller) {
      _resolveReader();
      _request();
    }
  }

  /// Login, logout or a switch inside the same controller: the previous
  /// account's balance goes away at once and the new account asks for its own.
  void _onAccountChanged() {
    final current = widget.controller.account?.localAccountId;
    if (current == _trackedAccount || !mounted) return;
    _trackedAccount = current;
    setState(() => _balance = null);
    _request();
  }

  void _resolveReader() {
    _api?.close();
    _api = null;
    final fixed = widget.reader;
    if (fixed != null) {
      _effective = fixed;
      return;
    }
    _api = resolveRewardsApi(
      config: AccountsOrdersConfig.fromEnvironment(),
      tokenProvider: widget.controller.accessTokenForBackend,
    );
    final api = _api;
    _effective = api == null ? null : ApiRewardsReader(api);
  }

  void _request() {
    // Any answer still in flight belongs to the previous account or reader.
    final generation = ++_generation;
    _balance = null;
    final reader = _effective;
    final accountId = _trackedAccount;
    if (reader == null || accountId == null) return;
    unawaited(
      reader.summary().then<void>(
        (summary) {
          if (!mounted ||
              generation != _generation ||
              accountId != widget.controller.account?.localAccountId) {
            return;
          }
          setState(() => _balance = summary.availableLabel);
        },
        onError: (Object _) {},
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onAccountChanged);
    _generation++;
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: 'Monetta Rewards. ${_balance ?? 'Ver saldo'}',
      excludeSemantics: true,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BoutiqueRadius.card,
          side: BorderSide(color: palette.hairline),
        ),
        child: InkWell(
          key: const ValueKey('account-open-rewards-guide'),
          borderRadius: BoutiqueRadius.card,
          onTap: () => openRewardsGuide(
            context,
            controller: widget.controller,
            reader: widget.reader,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.md,
              vertical: BoutiqueSpace.md,
            ),
            child: Row(
              children: [
                Icon(Icons.card_giftcard_outlined, color: palette.goldText),
                const SizedBox(width: BoutiqueSpace.md),
                Expanded(
                  child: Text(
                    'Monetta Rewards',
                    style:
                        boutiqueRowLabel(context: context, color: palette.ink),
                  ),
                ),
                const SizedBox(width: BoutiqueSpace.sm),
                Icon(
                  Icons.workspace_premium_outlined,
                  size: 20,
                  color: palette.goldText,
                ),
                const SizedBox(width: BoutiqueSpace.xs),
                Flexible(
                  child: Text(
                    _balance ?? 'Ver saldo',
                    key: const ValueKey('account-rewards-balance'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueText(
                      size: 14,
                      weight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: palette.inkMuted,
                ),
              ],
            ),
          ),
        ),
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
