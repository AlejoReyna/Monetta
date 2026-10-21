/// Editorial navigation drawer for shopper-facing shortcuts and services.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

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

  void _select(BuildContext context, VoidCallback callback) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(300.0, 366.0);
    final colors = context.monettaColors;

    return Drawer(
      key: const Key('monetta-side-menu'),
      width: width,
      elevation: 0,
      backgroundColor: colors.surfaceRaised,
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
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Material(
                color: colors.inputFill,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  key: const Key('side-menu-search'),
                  onTap: () => _select(context, onSearch),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 20),
                        const SizedBox(width: 13),
                        Text('Buscar una pieza', style: sans(size: 13)),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_rounded, size: 17),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
                children: [
                  if (onCategories != null)
                    _MenuLink(
                      key: const Key('side-menu-categories'),
                      label: 'Categorías',
                      onTap: () => _select(context, onCategories!),
                    ),
                  _MenuLink(
                    key: const Key('side-menu-bags'),
                    label: 'Bolsas',
                    onTap: () => _select(context, onBags),
                  ),
                  _MenuLink(
                    label: 'Carteras',
                    onTap: () => _select(context, onWallets),
                  ),
                  _MenuLink(
                    label: 'Relojes',
                    onTap: () => _select(context, onWatches),
                  ),
                  _MenuLink(
                    label: 'Perfumes',
                    onTap: () => _select(context, onPerfumes),
                  ),
                  _MenuLink(
                    label: 'Maquillaje y skincare',
                    onTap: () => _select(context, onBeauty),
                  ),
                  _MenuLink(
                    label: 'Todas las marcas',
                    onTap: () => _select(context, onCatalog),
                  ),
                  _MenuLink(
                    label: 'Mayoreo',
                    onTap: () => _select(context, onPartner),
                  ),
                  _MenuLink(
                    label: 'Contacto',
                    onTap: () => _select(context, onSupport),
                  ),
                  const SizedBox(height: 28),
                  _MenuLink(
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

class _MenuLink extends StatelessWidget {
  const _MenuLink({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.divider, width: .5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: editorial(18, color: colors.contentPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
