/// Client-guide chrome over the app's existing shopping destinations.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/account_controller.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../../main.dart';
import '../account/account_screen.dart';
import '../catalog/categories_screen.dart';
import '../contact/contact_screen.dart';
import '../wholesale/wholesale_screen.dart';
import '../catalog/search_screen.dart';
import '../checkout/checkout_screen.dart';
import 'boutique_tokens.dart';
import 'client_guide_components.dart';

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

    bool enabled(ClientGuideDestination destination) => switch (destination) {
          ClientGuideDestination.home ||
          ClientGuideDestination.categories =>
            true,
          ClientGuideDestination.account => account != null,
          _ => store != null,
        };
    String label(ClientGuideDestination destination) => switch (destination) {
          ClientGuideDestination.home => 'Inicio',
          ClientGuideDestination.categories => 'Categorías',
          ClientGuideDestination.bag => 'Carrito',
          ClientGuideDestination.account => 'Cuenta',
        };
    IconData icon(ClientGuideDestination destination) => switch (destination) {
          ClientGuideDestination.home => Icons.home_outlined,
          ClientGuideDestination.categories => Icons.grid_view_outlined,
          ClientGuideDestination.bag => Icons.shopping_bag_outlined,
          ClientGuideDestination.account => Icons.person_outline,
        };
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.bar,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const MonettaWordmark(height: MonettaTokens.logoHeight),
        actions: [
          if (Navigator.of(context).canPop()) const BackButton(),
          IconButton(
            key: const ValueKey('guide-search-button'),
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed:
                store == null ? null : () => unawaited(openSearch(context)),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: palette.canvas,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.all(MonettaTokens.space[3]),
            children: [
              const MonettaWordmark(height: MonettaTokens.logoHeight),
              SizedBox(height: MonettaTokens.space[4]),
              for (final destination in ClientGuideDestination.values)
                ListTile(
                  key: ValueKey('guide-menu-${destination.name}'),
                  leading: Icon(icon(destination)),
                  title: Text(label(destination)),
                  enabled: enabled(destination),
                  onTap: () {
                    Navigator.of(context).pop();
                    select(destination);
                  },
                ),
              ListTile(
                key: const ValueKey('guide-menu-wholesale'),
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Mayoreo'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WholesaleScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                key: const ValueKey('guide-menu-contact'),
                leading: const Icon(Icons.chat_outlined),
                title: const Text('Contacto'),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(openContact(context));
                },
              ),
            ],
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: Material(
        color: palette.bar,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: MonettaTokens.space[1]),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final destination in ClientGuideDestination.values)
                  Expanded(
                    child: Semantics(
                      selected: current == destination,
                      child: InkWell(
                        key: ValueKey('guide-nav-${destination.name}'),
                        onTap: enabled(destination)
                            ? () => select(destination)
                            : null,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: MonettaTokens.tapTarget,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(MonettaTokens.space[0]),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon(destination),
                                  size: MonettaTokens.logoHeight,
                                  color: current == destination
                                      ? palette.goldText
                                      : palette.ink,
                                ),
                                SizedBox(height: MonettaTokens.space[0]),
                                Text(
                                  label(destination),
                                  textAlign: TextAlign.center,
                                  style: clientGuideStyle(
                                    context,
                                    MonettaTokens.navLabel,
                                    color: current == destination
                                        ? palette.goldText
                                        : palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
