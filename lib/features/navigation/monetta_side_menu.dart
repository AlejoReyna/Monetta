/// Editorial navigation drawer for shopper-facing shortcuts and services.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

class MonettaSideMenu extends StatelessWidget {
  const MonettaSideMenu({
    required this.onSearch,
    required this.onCatalog,
    required this.onBags,
    required this.onWallets,
    required this.onWatches,
    required this.onPerfumes,
    required this.onBeauty,
    this.onNotifications,
    required this.onAbout,
    required this.onPartner,
    required this.onSupport,
    super.key,
  });

  final VoidCallback onSearch;
  final VoidCallback onCatalog;
  final VoidCallback onBags;
  final VoidCallback onWallets;
  final VoidCallback onWatches;
  final VoidCallback onPerfumes;
  final VoidCallback onBeauty;
  final VoidCallback? onNotifications;
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

    return Drawer(
      key: const Key('monetta-side-menu'),
      width: width,
      elevation: 0,
      backgroundColor: const Color(0xFFFAF8F4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 14, 0),
              child: Row(
                children: [
                  const Expanded(child: MonettaWordmark(height: 21)),
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
                color: const Color(0xFFF0ECE5),
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
                  const _MenuSectionLabel('TIENDA'),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  const _MenuSectionLabel('MÁS DE MONETTA'),
                  if (onNotifications != null)
                    _MenuLink(
                      label: 'Mis notificaciones',
                      onTap: () => _select(context, onNotifications!),
                    ),
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

class _MenuSectionLabel extends StatelessWidget {
  const _MenuSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: Text(label, style: eyebrow(size: 8.5)),
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
    return Material(
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
                  style: editorial(18),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}
