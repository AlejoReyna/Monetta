/// Shopper menu from the client guide: identity, shortcuts and sharing.
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../../domain/home_content.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';

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

  /// Switches immediately between the light and dark storefront themes.
  ///
  /// This deliberately does not use [_select]: changing appearance should not
  /// dismiss the drawer or route the shopper to a separate selection view.
  final VoidCallback onToggleTheme;
  final VoidCallback onAbout;
  final VoidCallback onPartner;
  final VoidCallback onSupport;
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
    final width = MediaQuery.sizeOf(context).width.clamp(300.0, 366.0);
    final palette = context.boutique;
    final name = identityName?.trim();
    final detail = identityDetail?.trim();
    final shownName = (name == null || name.isEmpty) ? 'Invitado' : name;
    final initial = shownName.substring(0, 1).toUpperCase();

    return Drawer(
      key: const Key('monetta-side-menu'),
      width: width,
      elevation: 0,
      backgroundColor: palette.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(MonettaTokens.radiusSheet),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                MonettaTokens.space[3],
                MonettaTokens.space[3],
                MonettaTokens.space[1],
                0,
              ),
              child: Row(
                children: [
                  const MonettaWordmark(height: MonettaTokens.logoHeight),
                  const Spacer(),
                  if (onNotifications != null)
                    IconButton(
                      key: const Key('side-menu-notifications'),
                      tooltip: 'Notificaciones',
                      onPressed: () => _select(context, onNotifications!),
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  IconButton(
                    key: const Key('side-menu-appearance'),
                    tooltip: Theme.of(context).brightness == Brightness.dark
                        ? 'Activar modo claro'
                        : 'Activar modo oscuro',
                    onPressed: onToggleTheme,
                    icon: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      size: 21,
                    ),
                  ),
                  IconButton(
                    key: const Key('close-side-menu'),
                    tooltip: 'Cerrar menú',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 22),
                  ),
                ],
              ),
            ),
            Padding(
              key: const Key('side-menu-identity'),
              padding: EdgeInsets.fromLTRB(
                MonettaTokens.space[3],
                MonettaTokens.space[3],
                MonettaTokens.space[3],
                0,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: palette.actionDark,
                    foregroundColor: palette.onActionDark,
                    child: Text(initial),
                  ),
                  SizedBox(width: MonettaTokens.space[2]),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shownName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: clientGuideStyle(
                            context,
                            MonettaTokens.cardLabel,
                          ),
                        ),
                        if (detail != null && detail.isNotEmpty)
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.navLabel,
                              color: palette.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MonettaTokens.space[3]),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MonettaTokens.space[3]),
              child: Material(
                color: palette.surfaceDeep,
                borderRadius: BoutiqueRadius.control,
                child: InkWell(
                  key: const Key('side-menu-search'),
                  onTap: () => _select(context, onSearch),
                  borderRadius: BoutiqueRadius.control,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MonettaTokens.space[3],
                      vertical: MonettaTokens.space[2],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 20),
                        SizedBox(width: MonettaTokens.space[2]),
                        Text(
                          'Buscar una pieza',
                          style: clientGuideStyle(
                            context,
                            MonettaTokens.navLabel,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MonettaTokens.space[3]),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  MonettaTokens.space[3],
                  0,
                  MonettaTokens.space[3],
                  MonettaTokens.space[4],
                ),
                children: [
                  if (onCategories != null)
                    _MenuLink(
                      key: const Key('side-menu-categories'),
                      icon: Icons.grid_view_outlined,
                      label: 'Categorías',
                      onTap: () => _select(context, onCategories!),
                    ),
                  _MenuLink(
                    key: const Key('side-menu-bags'),
                    icon: Icons.shopping_bag_outlined,
                    label: 'Bolsas',
                    onTap: () => _select(context, onBags),
                  ),
                  _MenuLink(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Carteras',
                    onTap: () => _select(context, onWallets),
                  ),
                  _MenuLink(
                    icon: Icons.watch_outlined,
                    label: 'Relojes',
                    onTap: () => _select(context, onWatches),
                  ),
                  _MenuLink(
                    icon: Icons.water_drop_outlined,
                    label: 'Perfumes',
                    onTap: () => _select(context, onPerfumes),
                  ),
                  _MenuLink(
                    icon: Icons.brush_outlined,
                    label: 'Maquillaje y skincare',
                    onTap: () => _select(context, onBeauty),
                  ),
                  _MenuLink(
                    icon: Icons.sell_outlined,
                    label: 'Todas las marcas',
                    onTap: () => _select(context, onCatalog),
                  ),
                  _MenuLink(
                    icon: Icons.storefront_outlined,
                    label: 'Mayoreo',
                    onTap: () => _select(context, onPartner),
                  ),
                  _MenuLink(
                    icon: Icons.chat_outlined,
                    label: 'Contacto',
                    onTap: () => _select(context, onSupport),
                  ),
                  SizedBox(height: MonettaTokens.space[3]),
                  _ShareCard(
                    onShare: onShare == null
                        ? null
                        : () => _select(context, onShare!),
                  ),
                  if (onWhatsApp != null)
                    _MenuLink(
                      key: const Key('side-menu-whatsapp'),
                      icon: Icons.chat_outlined,
                      label: 'Contacto por WhatsApp',
                      onTap: () => _select(context, onWhatsApp!),
                    ),
                  if (socialLinks.isNotEmpty) ...[
                    SizedBox(height: MonettaTokens.space[2]),
                    Row(
                      children: [
                        for (final link in socialLinks)
                          if (link.uri != null)
                            IconButton(
                              key: Key('side-menu-social-${link.id}'),
                              tooltip: link.label,
                              onPressed: onOpenSocial == null
                                  ? null
                                  : () => _select(
                                        context,
                                        () => onOpenSocial!(link.uri!),
                                      ),
                              icon: Icon(_socialIcon(link.id)),
                            ),
                      ],
                    ),
                  ],
                  SizedBox(height: MonettaTokens.space[3]),
                  _MenuLink(
                    icon: Icons.auto_stories_outlined,
                    label: 'Nuestra historia',
                    onTap: () => _select(context, onAbout),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _socialIcon(String id) => switch (id) {
      'instagram' => Icons.camera_alt_outlined,
      'facebook' => Icons.facebook,
      'tiktok' => Icons.music_note,
      _ => Icons.open_in_new,
    };

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.onShare});

  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: EdgeInsets.only(bottom: MonettaTokens.space[3]),
      child: DecoratedBox(
        key: const Key('side-menu-share'),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BoutiqueRadius.card,
          border: Border.all(color: palette.hairline),
        ),
        child: Padding(
          padding: EdgeInsets.all(MonettaTokens.space[3]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comparte el catálogo y gana',
                style: clientGuideStyle(context, MonettaTokens.cardLabel),
              ),
              SizedBox(height: MonettaTokens.space[1]),
              Text(
                'Únete al mundo de Monetta',
                style: clientGuideStyle(
                  context,
                  MonettaTokens.navLabel,
                  color: palette.inkMuted,
                ),
              ),
              SizedBox(height: MonettaTokens.space[1]),
              Text(
                'Enlace público: pendiente de contrato',
                style: clientGuideStyle(
                  context,
                  MonettaTokens.navLabel,
                  color: palette.goldText,
                ),
              ),
              SizedBox(height: MonettaTokens.space[2]),
              FilledButton(
                key: const Key('side-menu-share-button'),
                onPressed: onShare,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.actionDark,
                  foregroundColor: palette.onActionDark,
                  minimumSize: const Size.fromHeight(MonettaTokens.tapTarget),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Compartir catálogo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuLink extends StatelessWidget {
  const _MenuLink({
    required this.label,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.hairline, width: .5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MonettaTokens.radiusCard),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: MonettaTokens.tapTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MonettaTokens.space[1],
                vertical: MonettaTokens.space[2],
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: palette.goldText),
                    SizedBox(width: MonettaTokens.space[2]),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.accountRow,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: palette.inkMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
