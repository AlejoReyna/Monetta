/// Shared shopper drawer. Private balance always follows the active identity.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/account_controller.dart';
import '../../app/theme.dart';
import '../../data/accounts_orders/accounts_orders_config.dart';
import '../../domain/home_content.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../catalog/brands_screen.dart';
import '../catalog/category_tree.dart';
import '../catalog/collection_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/guide_art.dart';
import '../rewards/rewards_api.dart';
import '../rewards/rewards_section.dart';
import 'duo_workspace.dart';

class MonettaSideMenu extends StatelessWidget {
  const MonettaSideMenu({
    required this.onSearch,
    required this.onCatalog,
    this.onCategories,
    required this.onBags,
    required this.onWallets,
    required this.onWatches,
    required this.onPerfumes,
    required this.onBeauty,
    required this.onToggleTheme,
    required this.onAbout,
    required this.onPartner,
    required this.onSupport,
    this.rewardsReader,
    this.onAllBrands,
    this.onAccount,
    this.tierLabel,
    this.balanceLabel,
    this.categoryBindings = const {},
    this.identityName,
    this.identityDetail,
    this.onNotifications,
    this.onShare,
    this.onWhatsApp,
    this.socialLinks = const <HomeSocialLink>[],
    this.onOpenSocial,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onCatalog;
  final VoidCallback? onCategories;
  final VoidCallback onBags;
  final VoidCallback onWallets;
  final VoidCallback onWatches;
  final VoidCallback onPerfumes;
  final VoidCallback onBeauty;

  // Legacy callbacks retained for existing callers. Retired controls stay hidden.
  final VoidCallback onToggleTheme;
  final VoidCallback onAbout;
  final VoidCallback onPartner;
  final VoidCallback onSupport;
  final RewardsReader? rewardsReader;
  final VoidCallback? onAllBrands;
  final VoidCallback? onAccount;
  final String? tierLabel;
  final String? balanceLabel;
  final Map<String, CollectionFilter> categoryBindings;
  final String? identityName;
  final String? identityDetail;
  final VoidCallback? onNotifications;
  final VoidCallback? onShare;
  final VoidCallback? onWhatsApp;
  final List<HomeSocialLink> socialLinks;
  final void Function(Uri uri)? onOpenSocial;

  void _select(BuildContext context, VoidCallback callback) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final controller = AccountScope.maybeOf(context);
    final store = StoreScope.maybeOf(context);
    final content =
        HomeContentScope.maybeOf(context)?.content ?? HomeContent.fallback;
    final navigator = DuoWorkspace.navigatorFor(context);
    final signedIn =
        controller?.isSignedIn ?? (identityName?.isNotEmpty ?? false);
    final name = controller == null
        ? identityName?.trim()
        : controller.account?.displayName?.trim();
    final shownName = signedIn
        ? (name == null || name.isEmpty ? 'Tu cuenta' : name)
        : 'Invitado';
    Widget scopes(Widget child) {
      if (store != null) child = StoreScope(notifier: store, child: child);
      if (controller != null) {
        child = AccountScope(notifier: controller, child: child);
      }
      return child;
    }

    void brands() => navigator.push<void>(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/brands'),
            builder: (_) => scopes(BrandsScreen(content: content)),
          ),
        );
    final accountAction = onAccount ??
        (controller == null
            ? null
            : () => unawaited(
                  openAccount(navigator.context, controller: controller),
                ));
    final socials = socialLinks
        .where(
          (link) =>
              const ['instagram', 'tiktok', 'facebook'].contains(link.id) &&
              link.uri?.scheme == 'https' &&
              onOpenSocial != null,
        )
        .toList()
      ..sort(
        (a, b) => const ['instagram', 'tiktok', 'facebook']
            .indexOf(a.id)
            .compareTo(const ['instagram', 'tiktok', 'facebook'].indexOf(b.id)),
      );
    return Drawer(
      key: const Key('monetta-side-menu'),
      width: MediaQuery.sizeOf(context).width.clamp(0.0, 366.0),
      backgroundColor: palette.canvas,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MonettaWordmark(height: 32),
                  ),
                ),
                IconButton(
                  key: const Key('side-menu-close'),
                  tooltip: 'Cerrar menú',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            ListTile(
              key: const Key('side-menu-identity'),
              contentPadding: EdgeInsets.zero,
              leading: GuideGlassSurface(
                radius: 28,
                child: SizedBox.square(
                  dimension: 52,
                  child: Center(
                    child: name != null && name.isNotEmpty && signedIn
                        ? Text(
                            name.characters.first.toUpperCase(),
                            style: boutiqueText(
                              size: 24,
                              color: const Color(0xFF242622),
                            ),
                          )
                        : Icon(
                            Icons.person_outline,
                            color: palette.goldText,
                          ),
                  ),
                ),
              ),
              title: Text(shownName),
              subtitle: signedIn
                  ? const Text('Miembro')
                  : accountAction == null
                      ? null
                      : const Text('Iniciar sesión'),
              onTap: accountAction == null
                  ? null
                  : () => _select(context, accountAction),
            ),
            if (controller != null && signedIn)
              SidebarBalance(
                key: ValueKey(
                  'sidebar-balance-${controller.account?.localAccountId}',
                ),
                controller: controller,
                reader: rewardsReader,
              ),
            if (controller == null && signedIn && balanceLabel != null) ...[
              const Text('Saldo'),
              Text(
                balanceLabel!,
                style: boutiqueText(
                  size: 22,
                  color: context.monettaColors.success,
                ),
              ),
            ],
            if (onNotifications != null)
              ListTile(
                key: const Key('side-menu-notifications'),
                leading:
                    Icon(Icons.notifications_none, color: palette.goldText),
                title: const Text('Notificaciones'),
                onTap: () => _select(context, onNotifications!),
              ),
            CategoryTree(
              bindings: {
                ...configuredCategoryBindings(content, store),
                ...categoryBindings,
              },
              onOpen: store == null
                  ? null
                  : (node, filter) => _select(
                        context,
                        () => navigator.push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => scopes(
                              CollectionScreen(
                                title: node.label,
                                filter: filter,
                              ),
                            ),
                          ),
                        ),
                      ),
            ),
            ListTile(
              key: const Key('side-menu-brands'),
              leading: const GuideSemanticImage(
                id: 'icon:marcas',
                width: 28,
                height: 28,
              ),
              title: const Text('Todas las marcas'),
              onTap: () => _select(context, onAllBrands ?? brands),
            ),
            ListTile(
              key: const Key('side-menu-wholesale'),
              leading: const GuideSemanticImage(
                id: 'icon:mayoreo',
                width: 28,
                height: 28,
              ),
              title: const Text('Mayoreo'),
              onTap: () => _select(context, onPartner),
            ),
            if (socials.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final enlarged =
                        MediaQuery.textScalerOf(context).scale(1) > 1.3;
                    final width = enlarged
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 32) / 3;
                    return Wrap(
                      key: const Key('side-menu-social'),
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final link in socials)
                          SizedBox(
                            width: width,
                            child: Column(
                              children: [
                                GuideGlassSurface(
                                  radius: 28,
                                  child: IconButton(
                                    key: Key(
                                      'side-menu-social-${link.id}',
                                    ),
                                    tooltip: link.label,
                                    onPressed: () => _select(
                                      context,
                                      () => onOpenSocial!(link.uri!),
                                    ),
                                    icon: GuideSemanticImage(
                                      id: 'icon:${link.id}',
                                      width: 26,
                                      height: 26,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  link.label,
                                  textAlign: TextAlign.center,
                                  style: boutiqueText(
                                    size: 14,
                                    color: palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            if (onWhatsApp != null)
              ListTile(
                key: const Key('side-menu-whatsapp'),
                leading: Image.asset(
                  kGuideIconContactWhatsApp,
                  color: context.monettaColors.success,
                  colorBlendMode: BlendMode.srcIn,
                  width: 28,
                  height: 28,
                  excludeFromSemantics: true,
                ),
                title: const Text('Contacto por WhatsApp'),
                onTap: () => _select(context, onWhatsApp!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Stateful read with account-change invalidation, including A -> B -> A.
class SidebarBalance extends StatefulWidget {
  const SidebarBalance({required this.controller, this.reader, super.key});
  final AccountController controller;
  final RewardsReader? reader;
  @override
  State<SidebarBalance> createState() => _SidebarBalanceState();
}

class _SidebarBalanceState extends State<SidebarBalance> {
  RewardsApi? _api;
  RewardsReader? _reader;
  String? _owner, _balance;
  int _generation = 0;
  bool _loading = false, _failed = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_identityChanged);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SidebarBalance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_identityChanged);
      widget.controller.addListener(_identityChanged);
    }
    if (oldWidget.reader != widget.reader ||
        oldWidget.controller != widget.controller) {
      _resolve();
    }
  }

  void _resolve() {
    _api?.clearSession();
    _api?.close();
    _api = widget.reader == null
        ? resolveRewardsApi(
            config: AccountsOrdersConfig.fromEnvironment(),
            tokenProvider: widget.controller.accessTokenForBackend,
          )
        : null;
    _reader = widget.reader ?? (_api == null ? null : ApiRewardsReader(_api!));
    _owner = widget.controller.account?.localAccountId;
    _request();
  }

  void _identityChanged() {
    final next = widget.controller.account?.localAccountId;
    if (_owner == next) return;
    _api?.clearSession();
    _owner = next;
    setState(_request);
  }

  void _request() {
    final generation = ++_generation;
    _balance = null;
    _failed = false;
    _loading = _owner != null && _reader != null;
    if (!_loading) return;
    unawaited(
      _reader!.summary().then(
        (value) {
          if (!mounted ||
              generation != _generation ||
              _owner != widget.controller.account?.localAccountId) {
            return;
          }
          setState(() {
            _balance = value.availableLabel;
            _loading = false;
          });
        },
        onError: (Object _) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _loading = false;
            _failed = true;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_identityChanged);
    _generation++;
    _api?.clearSession();
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_owner == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo'),
          Text(
            _balance ??
                (_loading
                    ? 'Consultando…'
                    : _failed
                        ? 'No pudimos consultar tu saldo'
                        : 'Saldo no disponible'),
            style: boutiqueText(
              size: 20,
              color: _balance == null
                  ? context.boutique.inkMuted
                  : context.monettaColors.success,
            ),
          ),
          if (_failed)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.boutique.ink,
                textStyle: boutiqueText(size: 14),
              ),
              onPressed: () => setState(_request),
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}
