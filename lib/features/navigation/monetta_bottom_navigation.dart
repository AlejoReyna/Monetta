/// Persistent shopper actions shared by the home and catalog screens.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';

enum MonettaBottomDestination { home, catalog, bag, account }

// Layout of the docked bar. The theme is the only source of its colors.
const double _kBarMinHeight = 56;
const double _kBarSidePadding = 10;
const double _kBarMaxContentWidth = 480;
const double _kItemHorizontalPadding = 4;
const double _kItemVerticalPadding = 5;
const double _kIconBox = 24;
const double _kIconStroke = 1.7;
const double _kIconLabelGap = 3;
const double _kLabelSize = 13;
const double _kLabelHeight = 1.25;
const double _kPressedOpacity = 0.55;

String _labelOf(MonettaBottomDestination destination) => switch (destination) {
      MonettaBottomDestination.home => 'Home',
      MonettaBottomDestination.catalog => 'Catálogo',
      MonettaBottomDestination.bag => 'Carrito',
      MonettaBottomDestination.account => 'Cuenta',
    };

TextStyle _labelStyle({required FontWeight weight, Color? color}) => sans(
      size: _kLabelSize,
      height: _kLabelHeight,
      weight: weight,
      color: color,
    );

/// Flat bar docked to the bottom edge on the theme's navigation surface. The
/// selected destination is shown only through color and label weight; nothing
/// moves or scales.
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
    final colors = context.monettaColors;
    final media = MediaQuery.maybeOf(context);
    final animationsDisabled =
        media?.disableAnimations == true || media?.accessibleNavigation == true;

    return DecoratedBox(
      key: const Key('bottom-nav-surface'),
      decoration: BoxDecoration(
        color: colors.navigationSurface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      // Ink and focus paint on the bar's surface. Compact by decision: no
      // bottom safe-area inset, so the bar is always 56 px of content docked
      // to the edge; the OS home indicator floats over the surface.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kBarSidePadding),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kBarMaxContentWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final labelScaler = _fittedLabelScaler(
                    context,
                    constraints.maxWidth /
                        MonettaBottomDestination.values.length,
                  );
                  return Row(
                    children: [
                      for (final destination in MonettaBottomDestination.values)
                        Expanded(
                          child: _NavItem(
                            destination: destination,
                            selected: destination == current,
                            bagCount: bagCount,
                            labelScaler: labelScaler,
                            animationsDisabled: animationsDisabled,
                            onSelected: onSelected,
                          ),
                        ),
                    ],
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

/// Follows the system text scale until the widest label fills its column;
/// from there the four labels stop growing together, so they stay uniform
/// and are never clipped. [context] must sit below the bar's [Material] so
/// the measured style matches the one the labels render with.
TextScaler _fittedLabelScaler(BuildContext context, double columnWidth) {
  final requested = MediaQuery.textScalerOf(context);
  final room = columnWidth - 2 * _kItemHorizontalPadding;
  if (!room.isFinite || room <= 0) return requested;

  // Measure in the selected weight (bold when the platform asks for bold
  // text) so the fit never changes when the selection moves.
  final weight =
      MediaQuery.boldTextOf(context) ? FontWeight.bold : FontWeight.w600;
  final style = DefaultTextStyle.of(context).style.merge(
        _labelStyle(weight: weight),
      );
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  double widestAt(TextScaler scaler) {
    var widest = 0.0;
    for (final destination in MonettaBottomDestination.values) {
      final painter = TextPainter(
        text: TextSpan(text: _labelOf(destination), style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest;
  }

  final widest = widestAt(requested);
  if (widest <= room) return requested;

  // The theme's text style may carry letter spacing, which does not scale, so
  // the width is affine in the font size (`a * size + b`) rather than
  // proportional. Two measurements give both terms.
  final size = requested.scale(_kLabelSize);
  final half = widestAt(TextScaler.linear(size / 2 / _kLabelSize));
  final slope = (widest - half) / (size / 2);
  if (slope <= 0) return requested;
  final offset = widest - slope * size;
  final fitted = math.min((room - offset) / slope, size);
  return TextScaler.linear(math.max(fitted, 1) / _kLabelSize);
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.bagCount,
    required this.labelScaler,
    required this.animationsDisabled,
    required this.onSelected,
  });

  final MonettaBottomDestination destination;
  final bool selected;
  final int bagCount;
  final TextScaler labelScaler;
  final bool animationsDisabled;
  final ValueChanged<MonettaBottomDestination> onSelected;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final selected = widget.selected;
    final colors = context.monettaColors;
    final label = _labelOf(destination);
    final badge =
        destination == MonettaBottomDestination.bag ? widget.bagCount : 0;
    final semanticLabel = badge > 0
        ? '$label, $badge ${badge == 1 ? 'artículo' : 'artículos'}'
        : label;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        key: Key('bottom-nav-${destination.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onSelected(destination),
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        // The visible label and the badge are already in [semanticLabel].
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kBarMinHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kItemHorizontalPadding,
                vertical: _kItemVerticalPadding,
              ),
              child: Opacity(
                opacity: _pressed ? _kPressedOpacity : 1,
                child: TweenAnimationBuilder<double>(
                  duration: widget.animationsDisabled ? Duration.zero : kSnap,
                  curve: kMotionCurve,
                  tween: Tween(end: selected ? 1 : 0),
                  builder: (context, progress, _) {
                    final color = Color.lerp(
                      colors.navigationForegroundMuted,
                      colors.navigationForeground,
                      progress,
                    )!;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconTheme.merge(
                          data: IconThemeData(color: color),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _NavGlyph(
                                key: Key('bottom-nav-${destination.name}-icon'),
                                destination: destination,
                              ),
                              if (badge > 0)
                                Positioned(
                                  left: 16,
                                  top: -6,
                                  child: _BagBadge(count: badge),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: _kIconLabelGap),
                        Text(
                          label,
                          key: Key('bottom-nav-${destination.name}-label'),
                          maxLines: 1,
                          softWrap: false,
                          textAlign: TextAlign.center,
                          textScaler: widget.labelScaler,
                          style: _labelStyle(
                            weight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: color,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin outline icons painted locally instead of relying on platform-specific
/// Material glyphs, whose proportions and silhouettes differ between iOS and
/// Android. The painter works on a 24-unit base canvas that is scaled and
/// centred into its box, so the shapes keep their proportions at any size.
/// The color comes from the ambient [IconTheme].
class _NavGlyph extends StatelessWidget {
  const _NavGlyph({required this.destination, super.key});

  final MonettaBottomDestination destination;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size.square(_kIconBox),
        painter: _NavGlyphPainter(
          destination: destination,
          color: IconTheme.of(context).color ?? const Color(0xFF000000),
        ),
      );
}

class _NavGlyphPainter extends CustomPainter {
  _NavGlyphPainter({required this.destination, required this.color});

  static const double _canvas = 24;

  final MonettaBottomDestination destination;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _canvas;
    canvas
      ..save()
      ..translate(
        (size.width - _canvas * scale) / 2,
        (size.height - _canvas * scale) / 2,
      )
      ..scale(scale);
    // Keep the stroke at a constant number of logical pixels.
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kIconStroke / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (destination) {
      // One continuous outline with a centred arched door.
      case MonettaBottomDestination.home:
        canvas.drawPath(
          Path()
            ..moveTo(9.16, 20.92)
            ..lineTo(3, 20.92)
            ..lineTo(3, 10.34)
            ..lineTo(12, 3.08)
            ..lineTo(21, 10.34)
            ..lineTo(21, 20.92)
            ..lineTo(14.84, 20.92)
            ..lineTo(14.84, 16.45)
            ..arcTo(
              Rect.fromCircle(center: const Offset(12, 16.45), radius: 2.84),
              0,
              -math.pi,
              false,
            )
            ..close(),
          paint,
        );
      // Three index lines beside a magnifier.
      case MonettaBottomDestination.catalog:
        canvas
          ..drawLine(const Offset(1.5, 4.19), const Offset(7.18, 4.19), paint)
          ..drawLine(const Offset(1.5, 7.72), const Offset(5.29, 7.72), paint)
          ..drawLine(const Offset(1.5, 11.61), const Offset(3.71, 11.61), paint)
          ..drawCircle(const Offset(14.13, 11.76), 6.63, paint)
          ..drawLine(
            const Offset(18.82, 16.45),
            const Offset(22.5, 19.81),
            paint,
          );
      // Body narrowing towards the base, curved handle.
      case MonettaBottomDestination.bag:
        canvas
          ..drawPath(
            Path()
              ..moveTo(3.95, 7.58)
              ..lineTo(20.05, 7.58)
              ..lineTo(18.80, 19.41)
              ..quadraticBezierTo(18.63, 21, 17.03, 21)
              ..lineTo(6.97, 21)
              ..quadraticBezierTo(5.37, 21, 5.20, 19.41)
              ..close(),
            paint,
          )
          ..drawPath(
            Path()
              ..moveTo(7.82, 9.32)
              ..lineTo(7.82, 7.18)
              ..arcTo(
                Rect.fromCircle(center: const Offset(12, 7.18), radius: 4.18),
                math.pi,
                math.pi,
                false,
              )
              ..lineTo(16.18, 9.32),
            paint,
          );
      // Round head over curved shoulders.
      case MonettaBottomDestination.account:
        canvas
          ..drawCircle(const Offset(12, 8.05), 3.95, paint)
          ..drawArc(
            Rect.fromCenter(
              center: const Offset(12, 19.89),
              width: 18,
              height: 10.42,
            ),
            math.pi,
            math.pi,
            false,
            paint,
          );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NavGlyphPainter oldDelegate) =>
      oldDelegate.destination != destination || oldDelegate.color != color;
}

class _BagBadge extends StatelessWidget {
  const _BagBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Container(
      key: const Key('bottom-nav-bag-badge'),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: colors.navigationForeground,
        shape: StadiumBorder(
          side: BorderSide(
            color: colors.navigationSurface,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textScaler: TextScaler.noScaling,
        style: sans(
          size: 10,
          weight: FontWeight.w600,
          height: 1,
          color: colors.navigationSurface,
        ),
      ),
    );
  }
}
