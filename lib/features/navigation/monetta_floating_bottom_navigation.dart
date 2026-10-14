/// The floating navigation shared by the storefront and account screens.
/// The original docked MonettaBottomNavigation remains available separately.
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import 'monetta_bottom_navigation.dart';

export 'monetta_bottom_navigation.dart' show MonettaBottomDestination;

const Object _kHeroTag = 'monetta-floating-bottom-nav';

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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // The iOS home-indicator inset leaves room for a closer floating dock.
    final bottomGap = Theme.of(context).platform == TargetPlatform.iOS
        ? (bottomInset - 12).clamp(12.0, double.infinity)
        : bottomInset + 12;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = context.boutique;
    // Light mode matches the page ground; dark mode keeps the current dock.
    final barColor = dark ? const Color(0xFF191A18) : palette.canvas;
    return Hero(
      // One bar for the whole stack. The shuttle is painted in the navigator
      // overlay, above both routes, so the page slide runs behind it.
      tag: _kHeroTag,
      transitionOnUserGestures: true,
      // The incoming route lays its bar out off-screen while it slides in.
      // A normal flight would follow that rect; staying on the origin keeps
      // the dock where the shopper already sees it.
      createRectTween: (begin, end) => RectTween(begin: begin, end: begin),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, bottomGap),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Material(
                key: const Key('bottom-nav-surface'),
                color: barColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                  side: BorderSide(
                    color: dark ? Colors.transparent : palette.hairline,
                    width: .5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      for (final destination in MonettaBottomDestination.values)
                        _item(context, destination),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, MonettaBottomDestination destination) {
    final label = switch (destination) {
      MonettaBottomDestination.home => 'Inicio',
      MonettaBottomDestination.catalog => 'Catálogo',
      MonettaBottomDestination.bag => 'Carrito',
      MonettaBottomDestination.account => 'Cuenta',
    };
    final icon = switch (destination) {
      MonettaBottomDestination.home => Icons.home_outlined,
      MonettaBottomDestination.catalog => Icons.grid_view_outlined,
      MonettaBottomDestination.bag => Icons.shopping_bag_outlined,
      MonettaBottomDestination.account => Icons.person_outline,
    };
    final selected = destination == current;
    final count = destination == MonettaBottomDestination.bag ? bagCount : 0;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? const Color(0xFF171715)
        : dark
            ? const Color(0xFFC2C3BB)
            : context.boutique.inkMuted;
    return Expanded(
      child: Semantics(
        selected: selected,
        label: count > 0
            ? '$label, $count ${count == 1 ? 'artículo' : 'artículos'}'
            : label,
        button: true,
        excludeSemantics: true,
        child: InkWell(
          key: Key('bottom-nav-${destination.name}'),
          borderRadius: BorderRadius.circular(32),
          onTap: () => onSelected(destination),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              color: selected ? context.boutique.gold : null,
              borderRadius: BorderRadius.circular(32),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: count > 0,
                  key: count > 0 ? const Key('bottom-nav-bag-badge') : null,
                  label: Text(
                    count > 9 ? '9+' : '$count',
                    textScaler: TextScaler.noScaling,
                  ),
                  backgroundColor: context.boutique.gold,
                  textColor: const Color(0xFF171715),
                  child: Icon(
                    icon,
                    key: Key('bottom-nav-${destination.name}-icon'),
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  key: Key('bottom-nav-${destination.name}-label'),
                  textAlign: TextAlign.center,
                  style: boutiqueText(size: 10, color: color, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Put inside the scrolling body of an extendBody Scaffold. Its MediaQuery
/// includes the complete navigation height, including the floating gap.
class MonettaFloatingNavigationClearance extends StatelessWidget {
  const MonettaFloatingNavigationClearance({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.paddingOf(context).bottom + 16,
      );
}
