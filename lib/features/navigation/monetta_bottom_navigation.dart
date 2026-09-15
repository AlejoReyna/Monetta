/// Persistent shopper actions shared by the home and catalog screens.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';

enum MonettaBottomDestination { home, catalog, bag, account }

enum _MonettaNavIcon { home, catalog, bag, account }

enum _MonettaNavHero { selectionIndicator }

class MonettaBottomNavigation extends StatelessWidget {
  const MonettaBottomNavigation({
    required this.current,
    required this.bagCount,
    required this.onSelected,
    this.surfaceColor,
    this.selectedColor,
    this.selectedIconColor,
    this.selectedForegroundColor,
    this.unselectedColor,
    this.dividerColor,
    super.key,
  });

  final MonettaBottomDestination current;
  final int bagCount;
  final ValueChanged<MonettaBottomDestination> onSelected;
  final Color? surfaceColor;
  final Color? selectedColor;
  final Color? selectedIconColor;
  final Color? selectedForegroundColor;
  final Color? unselectedColor;
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final resolvedSurface = surfaceColor ?? colors.navigationSurface;
    final resolvedSelection = selectedColor ?? colors.navigationSelection;
    final resolvedSelectedIcon = selectedIconColor ?? colors.accent;
    final resolvedSelectedForeground =
        selectedForegroundColor ?? colors.navigationForeground;
    final resolvedUnselected = unselectedColor ?? colors.contentMuted;
    final resolvedDivider = dividerColor ?? colors.divider;
    final media = MediaQuery.maybeOf(context);
    final animationsDisabled =
        media?.disableAnimations == true || media?.accessibleNavigation == true;
    final bottomPadding =
        (media?.padding.bottom ?? 0).clamp(0.0, 18.0).toDouble();

    return DecoratedBox(
      key: const Key('bottom-nav-surface'),
      decoration: BoxDecoration(
        color: resolvedSurface,
        border: Border(top: BorderSide(color: resolvedDivider, width: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = constraints.maxWidth /
                      MonettaBottomDestination.values.length;
                  const indicatorInset = 6.0;

                  return SizedBox(
                    height: 52,
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          key: const Key('bottom-nav-selection-indicator'),
                          duration: animationsDisabled ? Duration.zero : kSwap,
                          curve: kMotionCurve,
                          left: (itemWidth * current.index) + indicatorInset,
                          top: 4,
                          bottom: 4,
                          width: itemWidth - (indicatorInset * 2),
                          child: HeroMode(
                            enabled: !animationsDisabled,
                            child: Hero(
                              tag: _MonettaNavHero.selectionIndicator,
                              createRectTween: (begin, end) => RectTween(
                                begin: begin,
                                end: end,
                              ),
                              child: DecoratedBox(
                                key: const Key('bottom-nav-selection-fill'),
                                decoration: BoxDecoration(
                                  color: resolvedSelection,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _NavItem(
                              destination: MonettaBottomDestination.home,
                              current: current,
                              icon: _MonettaNavIcon.home,
                              label: 'Home',
                              selectedIconColor: resolvedSelectedIcon,
                              selectedForegroundColor:
                                  resolvedSelectedForeground,
                              unselectedColor: resolvedUnselected,
                              animationsDisabled: animationsDisabled,
                              onSelected: onSelected,
                            ),
                            _NavItem(
                              destination: MonettaBottomDestination.catalog,
                              current: current,
                              icon: _MonettaNavIcon.catalog,
                              label: 'Catálogo',
                              selectedIconColor: resolvedSelectedIcon,
                              selectedForegroundColor:
                                  resolvedSelectedForeground,
                              unselectedColor: resolvedUnselected,
                              animationsDisabled: animationsDisabled,
                              onSelected: onSelected,
                            ),
                            _NavItem(
                              destination: MonettaBottomDestination.bag,
                              current: current,
                              icon: _MonettaNavIcon.bag,
                              label: 'Carrito',
                              badge: bagCount,
                              selectedIconColor: resolvedSelectedIcon,
                              selectedForegroundColor:
                                  resolvedSelectedForeground,
                              unselectedColor: resolvedUnselected,
                              animationsDisabled: animationsDisabled,
                              onSelected: onSelected,
                            ),
                            _NavItem(
                              destination: MonettaBottomDestination.account,
                              current: current,
                              icon: _MonettaNavIcon.account,
                              label: 'Cuenta',
                              selectedIconColor: resolvedSelectedIcon,
                              selectedForegroundColor:
                                  resolvedSelectedForeground,
                              unselectedColor: resolvedUnselected,
                              animationsDisabled: animationsDisabled,
                              onSelected: onSelected,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.current,
    required this.icon,
    required this.label,
    required this.selectedIconColor,
    required this.selectedForegroundColor,
    required this.unselectedColor,
    required this.animationsDisabled,
    required this.onSelected,
    this.badge = 0,
  });

  final MonettaBottomDestination destination;
  final MonettaBottomDestination current;
  final _MonettaNavIcon icon;
  final String label;
  final Color selectedIconColor;
  final Color selectedForegroundColor;
  final Color unselectedColor;
  final bool animationsDisabled;
  final int badge;
  final ValueChanged<MonettaBottomDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = destination == current;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          key: Key('bottom-nav-${destination.name}'),
          onTap: () => onSelected(destination),
          child: SizedBox(
            height: 52,
            child: TweenAnimationBuilder<double>(
              duration: animationsDisabled ? Duration.zero : kSnap,
              curve: kMotionCurve,
              tween: Tween(end: selected ? 1 : 0),
              builder: (context, progress, _) {
                final labelColor = Color.lerp(
                  unselectedColor,
                  selectedForegroundColor,
                  progress,
                )!;
                return Transform.translate(
                  offset: const Offset(0, 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 27,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Transform.scale(
                              scale: 1 + (progress * 0.05),
                              child: _NavGlyph(
                                icon: icon,
                                color: selectedIconColor,
                              ),
                            ),
                            if (badge > 0)
                              Positioned(
                                top: -4,
                                right: 17,
                                child: _BagBadge(
                                  count: badge,
                                  color: selectedIconColor,
                                  textColor: context.monettaColors.canvas,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        style: sans(
                          size: 9.5,
                          color: labelColor,
                          weight: selected ? FontWeight.w600 : FontWeight.w400,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin line icons matching the reference navigation bar. These are painted
/// locally instead of relying on platform-specific Material glyphs, whose
/// proportions and silhouettes differ between iOS and Android.
class _NavGlyph extends StatelessWidget {
  const _NavGlyph({required this.icon, required this.color});

  final _MonettaNavIcon icon;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size.square(28),
        painter: _NavGlyphPainter(icon: icon, color: color),
      );
}

class _NavGlyphPainter extends CustomPainter {
  _NavGlyphPainter({required this.icon, required this.color});

  final _MonettaNavIcon icon;
  final Color color;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final p = _stroke;
    switch (icon) {
      case _MonettaNavIcon.home:
        final roof = Path()
          ..moveTo(3.5, 13.5)
          ..lineTo(14, 3.5)
          ..lineTo(24.5, 13.5);
        canvas.drawPath(roof, p);
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 11)
            ..lineTo(6.5, 25)
            ..lineTo(21.5, 25)
            ..lineTo(21.5, 11),
          p,
        );
        canvas.drawLine(const Offset(12.5, 25), const Offset(12.5, 18), p);
        canvas.drawLine(const Offset(12.5, 18), const Offset(16.5, 18), p);
      case _MonettaNavIcon.catalog:
        canvas.drawRect(const Rect.fromLTWH(5, 5, 7.5, 7.5), p);
        canvas.drawRect(const Rect.fromLTWH(15.5, 5, 7.5, 7.5), p);
        canvas.drawRect(const Rect.fromLTWH(5, 15.5, 7.5, 7.5), p);
        canvas.drawRect(const Rect.fromLTWH(15.5, 15.5, 7.5, 7.5), p);
      case _MonettaNavIcon.bag:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 10, 18, 15),
            const Radius.circular(1.5),
          ),
          p,
        );
        canvas.drawArc(
          const Rect.fromLTWH(10, 3.5, 8, 10),
          3.14,
          3.14,
          false,
          p,
        );
      case _MonettaNavIcon.account:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 9, 21, 16),
            const Radius.circular(1),
          ),
          p,
        );
        canvas.drawCircle(const Offset(14, 14), 2.2, p);
        canvas.drawArc(
          const Rect.fromLTWH(9.5, 15, 9, 8),
          3.45,
          3.1,
          false,
          p,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _NavGlyphPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}

class _BagBadge extends StatelessWidget {
  const _BagBadge({
    required this.count,
    required this.color,
    required this.textColor,
  });

  final int count;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: sans(
          size: 8,
          color: textColor,
          weight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
