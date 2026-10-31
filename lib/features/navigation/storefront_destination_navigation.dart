import 'dart:async';

import 'package:flutter/material.dart';

import '../../main.dart';
import '../account/account_screen.dart';
import '../catalog/categories_screen.dart';
import '../checkout/checkout_screen.dart';
import 'duo_workspace.dart';
import 'monetta_bottom_navigation.dart';

/// Secondary routes share the same four destinations without inventing a
/// browsing source for a direct product or changing authentication ownership.
MonettaBottomNavigation storefrontNavigation(
  BuildContext context, {
  required MonettaBottomDestination? current,
}) =>
    MonettaBottomNavigation(
      current: current,
      bagCount: StoreScope.maybeOf(context)?.bagQuantity ?? 0,
      onSelected: (destination) {
        switch (destination) {
          case MonettaBottomDestination.home:
            DuoWorkspace.navigatorFor(context)
                .popUntil((route) => route.isFirst);
          case MonettaBottomDestination.catalog:
            unawaited(openCategories(context));
          case MonettaBottomDestination.bag:
            unawaited(openBag(context));
          case MonettaBottomDestination.account:
            final account = AccountScope.maybeOf(context);
            if (account != null) {
              unawaited(openAccount(context, controller: account));
            }
        }
      },
    );
