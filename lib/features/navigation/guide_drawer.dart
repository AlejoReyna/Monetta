/// Shopper drawer shared by the client-guide screens.
///
/// Lives outside the scaffold so product, search and collection can open the
/// same menu without an import cycle through those screens.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../../app/theme_controller.dart';
import '../../domain/editorial_content.dart';
import '../../domain/home_content.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../about/about_monetta_screen.dart';
import '../catalog/categories_screen.dart';
import '../catalog/collection_screen.dart';
import '../catalog/search_screen.dart';
import '../contact/contact_screen.dart';
import '../notifications/notifications_screen.dart';
import '../wholesale/wholesale_screen.dart';
import 'monetta_side_menu.dart';

Widget guideDrawer(BuildContext context) {
  final content = HomeContentScope.maybeOf(context)?.content;
  final accountScope = AccountScope.maybeOf(context);
  Future<void> openExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
  return MonettaSideMenu(
    // Same bell, share action, WhatsApp and networks as the Inicio menu, so
    // the guide's menu reads the same on every screen that opens it.
    onNotifications: () => unawaited(
      openNotifications(
        context,
        inbox: sharedAccountNotificationInbox,
        ownerId: accountScope?.account?.localAccountId ?? '',
        accountController: accountScope,
      ),
    ),
    onShare: () => unawaited(Share.share('Únete al mundo de Monetta')),
    onWhatsApp: () => unawaited(openExternal(conciergeWhatsAppUri())),
    socialLinks: content?.socialLinks ?? HomeContent.fallback.socialLinks,
    onOpenSocial: (uri) => unawaited(openExternal(uri)),
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
