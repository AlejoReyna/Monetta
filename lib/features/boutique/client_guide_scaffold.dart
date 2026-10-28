/// Client-guide chrome over the app's existing shopping destinations.
library;

import '../navigation/adaptive_storefront_scaffold.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/account_controller.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../catalog/categories_screen.dart';
import '../catalog/search_screen.dart';
import '../checkout/checkout_screen.dart';
import '../navigation/guide_chrome.dart';
import '../navigation/guide_drawer.dart';
import '../navigation/monetta_bottom_navigation.dart';
import 'boutique_tokens.dart';

enum ClientGuideDestination { home, categories, bag, account }

class ClientGuideScaffold extends StatelessWidget {
  const ClientGuideScaffold({
    required this.current,
    required this.body,
    this.accountController,
    super.key,
  });
  final ClientGuideDestination? current;
  final Widget body;
  final AccountController? accountController;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.maybeOf(context);
    final account = accountController ?? AccountScope.maybeOf(context);
    void select(ClientGuideDestination destination) {
      switch (destination) {
        case ClientGuideDestination.home:
          Navigator.of(context).popUntil((route) => route.isFirst);
        case ClientGuideDestination.categories:
          if (current != ClientGuideDestination.categories) {
            unawaited(openCategories(context));
          }
        case ClientGuideDestination.bag:
          unawaited(openBag(context));
        case ClientGuideDestination.account:
          if (account != null) {
            unawaited(openAccount(context, controller: account));
          }
      }
    }

    MonettaBottomDestination? selected;
    switch (current) {
      case ClientGuideDestination.home:
        selected = MonettaBottomDestination.home;
      case ClientGuideDestination.categories:
        selected = MonettaBottomDestination.catalog;
      case ClientGuideDestination.bag:
        selected = MonettaBottomDestination.bag;
      case ClientGuideDestination.account:
        selected = MonettaBottomDestination.account;
      case null:
        selected = null;
    }

    return AdaptiveStorefrontScaffold(
      avoidReservedRegions: true,
      backgroundColor: palette.canvas,
      appBar: guideAppBar(
        context,
        searchEnabled: store != null,
        onSearch: () => unawaited(openSearch(context)),
      ),
      drawer: guideDrawer(context),
      body: body,
      bottomNavigationBar: MonettaBottomNavigation(
        current: selected,
        bagCount: store?.bagQuantity ?? 0,
        onSelected: (destination) {
          switch (destination) {
            case MonettaBottomDestination.home:
              select(ClientGuideDestination.home);
            case MonettaBottomDestination.catalog:
              select(ClientGuideDestination.categories);
            case MonettaBottomDestination.bag:
              if (store != null) select(ClientGuideDestination.bag);
            case MonettaBottomDestination.account:
              select(ClientGuideDestination.account);
          }
        },
      ),
    );
  }
}
