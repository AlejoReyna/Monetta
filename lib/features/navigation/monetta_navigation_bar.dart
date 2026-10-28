/// The storefront's bottom navigation: a flat, full-width bar on the safe area
/// (style guideline §3). It replaces the floating pill; the active destination
/// is carried by colour, weight *and* a short rule, never by colour alone.
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import 'monetta_bottom_navigation.dart';

const Object _kHeroTag = 'monetta-floating-bottom-nav';

/// Inclusive height of the bar's content, above the system inset.
const double kMonettaNavigationBarHeight = 64;

class MonettaNavigationBar extends StatelessWidget {
  const MonettaNavigationBar({
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
    final colors = context.monettaColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    return Hero(
      // One bar for the whole stack: the shuttle is painted in the navigator
      // overlay, above both routes, so the page slide runs behind it.
      tag: _kHeroTag,
      transitionOnUserGestures: true,
      // The incoming route lays its bar out off-screen while it slides in;
      // staying on the origin keeps the bar where the shopper already sees it.
      createRectTween: (begin, end) => RectTween(begin: begin, end: begin),
      child: Material(
        key: const Key('bottom-nav-surface'),
        // Dark keeps the dock surface it always had; light uses the shared bar.
        color: dark ? const Color(0xFF191A18) : colors.navigationSurface,
        shape: Border(top: BorderSide(color: colors.divider)),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Row(
                children: [
                  for (final destination in MonettaBottomDestination.values)
                    _NavigationItem(
                      destination: destination,
                      selected: destination == current,
                      bagCount: bagCount,
                      labelSize: MonettaTokens.navLabel.sizeFor(width),
                      onTap: () => onSelected(destination),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.bagCount,
    required this.labelSize,
    required this.onTap,
  });

  final MonettaBottomDestination destination;
  final bool selected;
  final int bagCount;
  final double labelSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final label = switch (destination) {
      MonettaBottomDestination.home => 'Inicio',
      MonettaBottomDestination.catalog => 'Catálogo',
      MonettaBottomDestination.bag => 'Carrito',
      MonettaBottomDestination.account => 'Cuenta',
    };
    final icon = switch (destination) {
      MonettaBottomDestination.home =>
        selected ? Icons.home_rounded : Icons.home_outlined,
      MonettaBottomDestination.catalog =>
        selected ? Icons.grid_view_rounded : Icons.grid_view_outlined,
      MonettaBottomDestination.bag =>
        selected ? Icons.shopping_bag : Icons.shopping_bag_outlined,
      MonettaBottomDestination.account =>
        selected ? Icons.person : Icons.person_outline,
    };
    final count = destination == MonettaBottomDestination.bag ? bagCount : 0;
    // Dark keeps the dock's own greys; its selection is the gold accent.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? (dark ? colors.accent : colors.navigationForeground)
        : (dark ? const Color(0xFFC2C3BB) : colors.navigationForegroundMuted);
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
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kMonettaNavigationBarHeight,
            ),
            padding: const EdgeInsets.fromLTRB(3, 8, 3, 10),
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Badge(
                      isLabelVisible: count > 0,
                      key: count > 0 ? const Key('bottom-nav-bag-badge') : null,
                      label: Text(
                        count > 9 ? '9+' : '$count',
                        textScaler: TextScaler.noScaling,
                      ),
                      backgroundColor: colors.actionPrimary,
                      textColor: colors.onActionPrimary,
                      child: Icon(
                        icon,
                        key: Key('bottom-nav-${destination.name}-icon'),
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      key: Key('bottom-nav-${destination.name}-label'),
                      textAlign: TextAlign.center,
                      style: sans(
                        size: labelSize,
                        color: color,
                        weight: selected ? FontWeight.w600 : FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                if (selected)
                  Positioned(
                    bottom: -6,
                    child: Container(
                      key: Key('bottom-nav-${destination.name}-rule'),
                      width: 28,
                      height: 2,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
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
