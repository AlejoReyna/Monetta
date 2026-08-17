/// Persistent shopper actions shared by the home and catalog screens.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum MonettaBottomDestination { home, shuffle, menu, bag, account }

enum _MonettaNavIcon { home, shuffle, menu, bag, account }

class MonettaBottomNavigation extends StatelessWidget {
  const MonettaBottomNavigation({
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
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kLine, width: 0.5)),
          ),
          // Keep the actions visually anchored to the lower edge, above
          // only the iOS home-indicator safe area.
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
          child: Row(
            children: [
              _NavItem(
                destination: MonettaBottomDestination.home,
                current: current,
                icon: _MonettaNavIcon.home,
                label: 'Home',
                onSelected: onSelected,
              ),
              _NavItem(
                destination: MonettaBottomDestination.shuffle,
                current: current,
                icon: _MonettaNavIcon.shuffle,
                label: 'Shuffle',
                showDot: true,
                onSelected: onSelected,
              ),
              _NavItem(
                destination: MonettaBottomDestination.menu,
                current: current,
                icon: _MonettaNavIcon.menu,
                label: 'Menu',
                onSelected: onSelected,
              ),
              _NavItem(
                destination: MonettaBottomDestination.bag,
                current: current,
                icon: _MonettaNavIcon.bag,
                label: 'Basket',
                badge: bagCount,
                onSelected: onSelected,
              ),
              _NavItem(
                destination: MonettaBottomDestination.account,
                current: current,
                icon: _MonettaNavIcon.account,
                label: 'Account',
                onSelected: onSelected,
              ),
            ],
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
    required this.onSelected,
    this.badge = 0,
    this.showDot = false,
  });

  final MonettaBottomDestination destination;
  final MonettaBottomDestination current;
  final _MonettaNavIcon icon;
  final String label;
  final int badge;
  final bool showDot;
  final ValueChanged<MonettaBottomDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = destination == current;
    final color = selected ? kInk : kInkMuted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkResponse(
          onTap: () => onSelected(destination),
          radius: 34,
          child: SizedBox(
            height: 57,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 29,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      _NavGlyph(icon: icon, color: color),
                      if (showDot)
                        const Positioned(
                          top: -1,
                          right: 20,
                          child: _BlueDot(),
                        ),
                      if (badge > 0)
                        Positioned(
                          top: -4,
                          right: 17,
                          child: _BagBadge(count: badge),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: sans(
                    size: 10.5,
                    color: color,
                    weight: selected ? FontWeight.w500 : FontWeight.w400,
                    height: 1.1,
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
      case _MonettaNavIcon.shuffle:
        canvas.save();
        canvas.translate(2.5, 1.5);
        canvas.rotate(-0.18);
        canvas.drawRect(const Rect.fromLTWH(2, 3, 15, 19), p);
        canvas.restore();
        canvas.drawRect(const Rect.fromLTWH(9, 7, 15, 19), p);
        final play = Path()
          ..moveTo(14, 13)
          ..lineTo(14, 20)
          ..lineTo(20, 16.5)
          ..close();
        canvas.drawPath(play, p);
      case _MonettaNavIcon.menu:
        canvas.drawLine(const Offset(2.5, 8), const Offset(8, 8), p);
        canvas.drawLine(const Offset(2.5, 14), const Offset(8, 14), p);
        canvas.drawLine(const Offset(2.5, 20), const Offset(8, 20), p);
        canvas.drawCircle(const Offset(17, 13), 8, p);
        canvas.drawLine(const Offset(22.5, 19), const Offset(26, 23), p);
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

class _BlueDot extends StatelessWidget {
  const _BlueDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF3D72E5),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BagBadge extends StatelessWidget {
  const _BagBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: kInk,
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: sans(
          size: 8,
          color: Colors.white,
          weight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}
