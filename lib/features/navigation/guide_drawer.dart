/// Shopper drawer shared by the client-guide screens.
///
/// Lives outside the scaffold so product, search and collection can open the
/// same menu without an import cycle through those screens.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme_controller.dart';
import '../../domain/editorial_content.dart';
import '../about/about_monetta_screen.dart';
import '../catalog/categories_screen.dart';
import '../catalog/collection_screen.dart';
import '../catalog/search_screen.dart';
import '../contact/contact_screen.dart';
import '../wholesale/wholesale_screen.dart';
import 'monetta_side_menu.dart';

Widget guideDrawer(BuildContext context) {
  return MonettaSideMenu(
    onSearch: () => openSearch(context),
    onCatalog: () => openCollection(
      context,
      const CollectionScreen(title: 'Catálogo'),
    ),
    onCategories: () => openCategories(context),
    onBags: () => openCollection(
      context,
      const CollectionScreen(
        title: 'Bolsas',
        filter: CollectionFilter(category: 'bolsa'),
      ),
    ),
    onWallets: () => openCollection(
      context,
      const CollectionScreen(
        title: 'Carteras',
        filter: CollectionFilter(category: 'cartera'),
      ),
    ),
    onWatches: () => openCollection(
      context,
      const CollectionScreen(
        title: 'Relojes',
        filter: CollectionFilter(category: 'reloj'),
      ),
    ),
    onPerfumes: () => openCollection(
      context,
      const CollectionScreen(
        title: 'Perfumes',
        filter: CollectionFilter(query: 'perfume'),
      ),
    ),
    onBeauty: () => openCollection(
      context,
      const CollectionScreen(
        title: 'Maquillaje y skincare',
        filter: CollectionFilter(query: 'maquillaje'),
      ),
    ),
    onToggleTheme: () {
      final next = Theme.of(context).brightness == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark;
      unawaited(ThemeScope.of(context).setMode(next));
    },
    onAbout: () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AboutMonettaScreen(
            content: MonettaEditorialContent.fallback.about,
            onOpenCatalog: () => openCollection(
              context,
              const CollectionScreen(title: 'Catálogo'),
            ),
            onOpenPartner: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WholesaleScreen(),
                ),
              );
            },
          ),
        ),
      );
    },
    onPartner: () {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WholesaleScreen()),
      );
    },
    onSupport: () => openContact(context),
  );
}
