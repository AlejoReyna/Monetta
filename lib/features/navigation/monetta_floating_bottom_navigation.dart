/// Compatibility name for the storefront's bottom navigation.
///
/// The floating pill is gone: this widget now draws the flat full-width
/// [MonettaNavigationBar]. Callers move to the new name screen by screen and
/// this wrapper is deleted when the last one has moved.
library;

import 'package:flutter/material.dart';

import 'monetta_bottom_navigation.dart';
import 'monetta_navigation_bar.dart';

export 'monetta_bottom_navigation.dart' show MonettaBottomDestination;
export 'monetta_navigation_bar.dart' show kMonettaNavigationBarHeight;

class MonettaFloatingBottomNavigation extends StatelessWidget {
  const MonettaFloatingBottomNavigation({
    required this.current,
    required this.bagCount,
    required this.onSelected,
    super.key,
  });

  final MonettaBottomDestination current;
  final int bagCount;
  final ValueChanged<MonettaBottomDestination> onSelected;

  @override
  Widget build(BuildContext context) => MonettaNavigationBar(
        current: current,
        bagCount: bagCount,
        onSelected: onSelected,
      );
}

/// Put inside the scrolling body of an extendBody Scaffold. Its MediaQuery
/// includes the complete navigation height.
class MonettaFloatingNavigationClearance extends StatelessWidget {
  const MonettaFloatingNavigationClearance({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.paddingOf(context).bottom + 16,
      );
}
