/// Editorial navigation drawer for shopper-facing shortcuts and services.
///
/// X-style account header: when the shopper is signed in the drawer opens
/// with their avatar, name and email; otherwise it offers an
/// "Inicia sesión" entry. Links are plain icon rows with no separators, and
/// the app settings live behind the "Ajustes" gear row. Type is the home
/// hero's serif at its regular weight, with light-stroke icons.
library;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app/theme.dart';
import '../boutique/boutique_tokens.dart';

/// Stroke weight of the drawer's Material Symbols (100–700; 400 is regular).
const double _kIconWeight = 300;

TextStyle _menuSerif(double size, Color color) => boutiqueDisplay(
      size,
      color: color,
      height: 1.2,
    );

class MonettaSideMenu extends StatelessWidget {
  const MonettaSideMenu({
    required this.onCatalog,
    required this.onBags,
    required this.onWallets,
    required this.onWatches,
    required this.onPerfumes,
    required this.onBeauty,
    required this.onAbout,
    required this.onPartner,
    required this.onSupport,
    this.isSignedIn = false,
    this.accountName,
    this.accountEmail,
    this.onAccount,
    this.onSettings,
    super.key,
  });

  final VoidCallback onCatalog;
  final VoidCallback onBags;
  final VoidCallback onWallets;
  final VoidCallback onWatches;
  final VoidCallback onPerfumes;
  final VoidCallback onBeauty;

  final VoidCallback onAbout;
  final VoidCallback onPartner;
  final VoidCallback onSupport;

  /// Whether a shopper session is active. When true the header shows the
  /// account's data; otherwise it shows an "Inicia sesión" entry.
  final bool isSignedIn;
  final String? accountName;
  final String? accountEmail;

  /// Opens the account flow (sign-in when signed out, account hub when
  /// signed in). When null the account header is omitted.
  final VoidCallback? onAccount;

  /// Opens the app settings ("Ajustes"). When null the row is omitted.
  final VoidCallback? onSettings;

  void _select(BuildContext context, VoidCallback callback) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(300.0, 366.0);

    return Drawer(
      key: const Key('monetta-side-menu'),
      width: width,
      elevation: 0,
      backgroundColor: context.monettaColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 14, 0),
              child: Row(
                children: [
                  // Keep the mark anchored to the drawer's editorial grid,
                  // rather than centring it inside the remaining header space.
                  const MonettaWordmark(height: 21),
                  const Spacer(),
                  IconButton(
                    key: const Key('close-side-menu'),
                    tooltip: 'Cerrar menú',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Symbols.close,
                      size: 22,
                      weight: _kIconWeight,
                    ),
                  ),
                ],
              ),
            ),
            if (onAccount != null)
              _AccountHeader(
                isSignedIn: isSignedIn,
                accountName: accountName,
                accountEmail: accountEmail,
                onTap: () {
                  final callback = onAccount;
                  if (callback != null) _select(context, callback);
                },
              ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                children: [
                  _MenuLink(
                    key: const Key('side-menu-bags'),
                    icon: Symbols.shopping_bag,
                    label: 'Bolsas',
                    onTap: () => _select(context, onBags),
                  ),
                  _MenuLink(
                    icon: Symbols.account_balance_wallet,
                    label: 'Carteras',
                    onTap: () => _select(context, onWallets),
                  ),
                  _MenuLink(
                    icon: Symbols.watch,
                    label: 'Relojes',
                    onTap: () => _select(context, onWatches),
                  ),
                  _MenuLink(
                    icon: Symbols.spa,
                    label: 'Perfumes',
                    onTap: () => _select(context, onPerfumes),
                  ),
                  _MenuLink(
                    icon: Symbols.face,
                    label: 'Maquillaje y skincare',
                    onTap: () => _select(context, onBeauty),
                  ),
                  _MenuLink(
                    icon: Symbols.storefront,
                    label: 'Todas las marcas',
                    onTap: () => _select(context, onCatalog),
                  ),
                  const SizedBox(height: 12),
                  _MenuLink(
                    icon: Symbols.handshake,
                    label: 'Mayoreo',
                    onTap: () => _select(context, onPartner),
                  ),
                  _MenuLink(
                    icon: Symbols.chat_bubble,
                    label: 'Contacto',
                    onTap: () => _select(context, onSupport),
                  ),
                  _MenuLink(
                    icon: Symbols.auto_stories,
                    label: 'Nuestra historia',
                    onTap: () => _select(context, onAbout),
                  ),
                  if (onSettings != null)
                    _MenuLink(
                      key: const Key('side-menu-settings'),
                      icon: Symbols.settings,
                      label: 'Ajustes',
                      onTap: () {
                        final callback = onSettings;
                        if (callback != null) _select(context, callback);
                      },
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

/// Account block at the top of the drawer: the shopper's data when signed
/// in, an "Inicia sesión" entry otherwise.
class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.isSignedIn,
    required this.accountName,
    required this.accountEmail,
    required this.onTap,
  });

  final bool isSignedIn;
  final String? accountName;
  final String? accountEmail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    if (!isSignedIn) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
        child: FilledButton.tonalIcon(
          key: const Key('side-menu-sign-in'),
          onPressed: onTap,
          icon: const Icon(Symbols.login, size: 20, weight: _kIconWeight),
          label: const Text('Inicia sesión'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            textStyle: boutiqueDisplay(16, height: 1.2),
          ),
        ),
      );
    }
    final name = accountName?.trim();
    final email = accountEmail?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (email != null && email.isNotEmpty)
            ? email.split('@').first
            : 'Mi cuenta';
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('side-menu-account'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.contentPrimary,
                  foregroundColor: colors.surfaceRaised,
                  child: Text(
                    initial,
                    style: boutiqueDisplay(18, height: 1.2),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _menuSerif(17, colors.contentPrimary),
                      ),
                      if (email != null && email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sans(size: 12, color: colors.contentMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain icon row: no separators, no chevrons.
class _MenuLink extends StatelessWidget {
  const _MenuLink({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                weight: _kIconWeight,
                color: colors.contentPrimary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: _menuSerif(17, colors.contentPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
