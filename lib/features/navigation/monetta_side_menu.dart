/// Shopper menu from the client guide: identity, shortcuts and sharing.
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../../domain/home_content.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/guide_art.dart';

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

  // The guide's menu no longer lists search, Categorías, Maquillaje y
  // skincare, Mayoreo, Contacto or Nuestra historia. Those callbacks stay in
  // the constructor so call sites keep compiling; Mayoreo and Contacto are
  // reached from Cuenta.
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
    final gutter = MonettaTokens.space[3];
    final dark = Theme.of(context).brightness == Brightness.dark;

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
                gutter,
                gutter,
                MonettaTokens.space[1],
                0,
              ),
              child: Row(
                children: [
                  const MonettaWordmark(height: MonettaTokens.logoHeight),
                  const Spacer(),
                  // Appearance stays reachable: this menu is the only place
                  // that switches the light and dark storefront themes.
                  IconButton(
                    key: const Key('side-menu-appearance'),
                    tooltip:
                        dark ? 'Activar modo claro' : 'Activar modo oscuro',
                    onPressed: onToggleTheme,
                    icon: Icon(
                      dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      size: 21,
                      color: palette.goldText,
                    ),
                  ),
                  if (onNotifications != null)
                    IconButton(
                      key: const Key('side-menu-notifications'),
                      tooltip: 'Notificaciones',
                      onPressed: () => _select(context, onNotifications!),
                      icon: Icon(
                        Icons.notifications_none_rounded,
                        color: palette.goldText,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              key: const Key('side-menu-identity'),
              padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, gutter),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: palette.action,
                    foregroundColor: palette.onAction,
                    child: Text(
                      initial,
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.screenTitle,
                        color: palette.onAction,
                      ),
                    ),
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
                            MonettaTokens.accountRow,
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
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  0,
                  gutter,
                  MonettaTokens.space[4],
                ),
                children: [
                  Divider(height: 1, thickness: .5, color: palette.hairline),
                  _MenuLink(
                    key: const Key('side-menu-bags'),
                    icon: Icons.shopping_bag_outlined,
                    label: 'Bolsas',
                    onTap: () => _select(context, onBags),
                  ),
                  _MenuLink(
                    key: const Key('side-menu-wallets'),
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Carteras',
                    onTap: () => _select(context, onWallets),
                  ),
                  _MenuLink(
                    key: const Key('side-menu-watches'),
                    icon: Icons.watch_outlined,
                    label: 'Relojes',
                    onTap: () => _select(context, onWatches),
                  ),
                  _MenuLink(
                    key: const Key('side-menu-perfumes'),
                    icon: Icons.spa_outlined,
                    label: 'Perfumes',
                    onTap: () => _select(context, onPerfumes),
                  ),
                  _MenuLink(
                    key: const Key('side-menu-brands'),
                    icon: Icons.storefront_outlined,
                    label: 'Todas las marcas',
                    onTap: () => _select(context, onCatalog),
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
                      assetIcon: kGuideIconContactWhatsApp,
                      label: 'Contacto por WhatsApp',
                      onTap: () => _select(context, onWhatsApp!),
                    ),
                  if (_orderedSocial().isNotEmpty) ...[
                    SizedBox(height: MonettaTokens.space[2]),
                    Row(
                      key: const Key('side-menu-social'),
                      children: [
                        for (final link in _orderedSocial())
                          Expanded(
                            child: IconButton(
                              key: Key('side-menu-social-${link.id}'),
                              tooltip: link.label,
                              onPressed: onOpenSocial == null
                                  ? null
                                  : () => _select(
                                        context,
                                        () => onOpenSocial!(link.uri!),
                                      ),
                              icon: _socialIcon(link.id, palette.goldText),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The guide's order (TikTok, Instagram, Facebook), then any other network
  /// the owner configured. Links without a URL are not shown.
  List<HomeSocialLink> _orderedSocial() {
    const order = <String>['tiktok', 'instagram', 'facebook'];
    int rank(HomeSocialLink link) {
      final index = order.indexOf(link.id);
      return index < 0 ? order.length : index;
    }

    final links = <HomeSocialLink>[
      for (final link in socialLinks)
        if (link.uri != null) link,
    ];
    final position = <HomeSocialLink, int>{
      for (var i = 0; i < links.length; i++) links[i]: i,
    };
    links.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : position[a]!.compareTo(position[b]!);
    });
    return links;
  }
}

Widget _socialIcon(String id, Color fallbackColor) {
  final asset = switch (id) {
    'instagram' => kGuideIconInstagram,
    'facebook' => kGuideIconFacebook,
    'tiktok' => kGuideIconTikTok,
    _ => null,
  };
  if (asset == null) {
    return Icon(Icons.open_in_new, color: fallbackColor);
  }
  // The three networks are drawn with different stroke weights; tinting them
  // with one solid colour makes them read with the same intensity.
  return Image.asset(
    asset,
    width: 30,
    height: 30,
    fit: BoxFit.contain,
    color: fallbackColor,
    colorBlendMode: BlendMode.srcIn,
    excludeFromSemantics: true,
    errorBuilder: (_, __, ___) => Icon(Icons.open_in_new, color: fallbackColor),
  );
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.onShare});

  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MonettaTokens.space[3]),
      child: KeyedSubtree(
        key: const Key('side-menu-share'),
        // The callback opens the system share sheet directly with the same
        // action as before; only the button is the guide's small pill.
        child: GuideShareEarnBanner(
          asset: kGuideShareCatalog,
          action: Align(
            alignment: Alignment.centerLeft,
            child: GuidePillButton(
              key: const Key('side-menu-share-button'),
              label: 'VER CATÁLOGO',
              onPressed: onShare,
            ),
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
    this.assetIcon,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  /// Gold line icon drawn for the guide; wins over [icon].
  final String? assetIcon;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.hairline, width: .5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MonettaTokens.radiusCard),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MonettaTokens.tapTarget,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MonettaTokens.space[1],
                vertical: MonettaTokens.space[2],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: assetIcon != null
                        ? Image.asset(
                            assetIcon!,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          )
                        : Icon(icon, size: 24, color: palette.goldText),
                  ),
                  SizedBox(width: MonettaTokens.space[3]),
                  Expanded(
                    child: Text(
                      label,
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.accountRow,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: palette.goldText),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
