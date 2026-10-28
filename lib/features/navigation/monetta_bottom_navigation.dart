/// Persistent shopper actions shared by the home and catalog screens.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/storefront_layout.dart';
import '../../app/theme.dart';
import 'storefront_pane_scope.dart';

enum MonettaBottomDestination { home, catalog, bag, account }

// Layout of the docked bar. The theme is the only source of its colors.
const double _kBarMinHeight = 56;
const double _kBarSidePadding = 10;
const double _kBarMaxContentWidth = 480;
const double _kItemHorizontalPadding = 4;
const double _kItemVerticalPadding = 6;
const double _kIconBox = 24;
const double _kIconStroke = 1.7;
const double _kIconLabelGap = 3;
const double _kLabelSize = 13;
const double _kLabelHeight = 1.25;
const double _kPressedOpacity = 0.55;

String _labelOf(MonettaBottomDestination destination) => switch (destination) {
      MonettaBottomDestination.home => 'Inicio',
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
/// selected destination has semantic, weight and underline/border cues. Labels
/// retain the requested system text scale and reflow when space is limited.
class MonettaBottomNavigation extends StatelessWidget {
  const MonettaBottomNavigation({
    required this.current,
    required this.bagCount,
    required this.onSelected,
    this.vertical = false,
    super.key,
  });

  final bool vertical;

  MonettaBottomNavigation asRail() => MonettaBottomNavigation(
        current: current,
        bagCount: bagCount,
        onSelected: onSelected,
        vertical: true,
      );

  final MonettaBottomDestination? current;
  final int bagCount;
  final ValueChanged<MonettaBottomDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    if (!StorefrontPaneScope.ownsNavigationOf(context)) {
      return const SizedBox.shrink();
    }
    final colors = context.monettaColors;
    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final destination in MonettaBottomDestination.values)
            Semantics(
              selected: destination == current,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: IconButton(
                  key: Key('bottom-nav-${destination.name}'),
                  tooltip: destination == MonettaBottomDestination.bag &&
                          bagCount > 0
                      ? '${_labelOf(destination)}, $bagCount ${bagCount == 1 ? 'artículo' : 'artículos'}'
                      : _labelOf(destination),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    side: destination == current
                        ? BorderSide(color: colors.navigationForeground)
                        : null,
                    backgroundColor: destination == current
                        ? colors.navigationForeground.withValues(alpha: .08)
                        : null,
                  ),
                  onPressed: () => onSelected(destination),
                  icon: destination == MonettaBottomDestination.bag &&
                          bagCount > 0 &&
                          StorefrontLayout.enlargedText(
                            MediaQuery.textScalerOf(context),
                          )
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NavGlyph(destination: destination),
                            Text(
                              bagCount > 9 ? '9+' : '$bagCount',
                              key: const Key('rail-bag-count'),
                              style: sans(size: 10),
                            ),
                          ],
                        )
                      : Badge(
                          isLabelVisible:
                              destination == MonettaBottomDestination.bag &&
                                  bagCount > 0,
                          label: Text('$bagCount'),
                          child: _NavGlyph(destination: destination),
                        ),
                ),
              ),
            ),
        ],
      );
    }
    final media = MediaQuery.maybeOf(context);
    final animationsDisabled =
        media?.disableAnimations == true || media?.accessibleNavigation == true;

    return DecoratedBox(
      key: const Key('bottom-nav-surface'),
      decoration: BoxDecoration(
        color: colors.navigationSurface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      // Ink and focus paint on the bar's surface.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          maintainBottomViewPadding: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kBarSidePadding),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _kBarMaxContentWidth),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scaler = MediaQuery.textScalerOf(context);
                    var widest = 0.0;
                    for (final destination in MonettaBottomDestination.values) {
                      final painter = TextPainter(
                        text: TextSpan(
                          text: _labelOf(destination),
                          style: DefaultTextStyle.of(context).style.merge(
                                _labelStyle(
                                  weight: MediaQuery.boldTextOf(context)
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                ),
                              ),
                        ),
                        textDirection: Directionality.of(context),
                        textScaler: scaler,
                        maxLines: 1,
                      )..layout();
                      widest = math.max(widest, painter.width);
                      painter.dispose();
                    }
                    var columns = 4;
                    while (columns > 1 &&
                        widest >
                            constraints.maxWidth / columns -
                                2 * _kItemHorizontalPadding) {
                      columns ~/= 2;
                    }
                    final wrapLabel = widest >
                        constraints.maxWidth - 2 * _kItemHorizontalPadding;
                    final itemHeight = math.max(
                      _kBarMinHeight,
                      _kIconBox +
                          _kIconLabelGap +
                          scaler.scale(_kLabelSize) * _kLabelHeight +
                          2 * _kItemVerticalPadding,
                    );
                    final usableHeight =
                        (media?.size.height ?? constraints.maxHeight) -
                            (media?.viewInsets.bottom ?? 0);
                    if (usableHeight -
                            itemHeight * (4 / columns) -
                            (media?.viewPadding.bottom ?? 0) <
                        StorefrontLayout.minimumTaskHeight) {
                      return SizedBox(
                        height: _kBarMinHeight,
                        width: double.infinity,
                        child: PopupMenuButton<MonettaBottomDestination>(
                          key: const Key('navigation-overflow'),
                          tooltip:
                              'Destinos${current == null ? '' : '. ${_labelOf(current!)} seleccionado'}',
                          onSelected: onSelected,
                          itemBuilder: (context) => [
                            for (final destination
                                in MonettaBottomDestination.values)
                              CheckedPopupMenuItem(
                                value: destination,
                                checked: current == destination,
                                child: Text(
                                  '${_labelOf(destination)}${destination == MonettaBottomDestination.bag && bagCount > 0 ? ' ($bagCount)' : ''}',
                                ),
                              ),
                          ],
                          icon: const Icon(Icons.more_horiz),
                        ),
                      );
                    }
                    final items = [
                      for (final destination in MonettaBottomDestination.values)
                        SizedBox(
                          width: constraints.maxWidth / columns,
                          child: _NavItem(
                            destination: destination,
                            selected: destination == current,
                            bagCount: bagCount,
                            labelScaler: scaler,
                            wrapLabel: wrapLabel,
                            animationsDisabled: animationsDisabled,
                            onSelected: onSelected,
                          ),
                        ),
                    ];
                    return Wrap(children: items);
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

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.bagCount,
    required this.labelScaler,
    this.wrapLabel = false,
    required this.animationsDisabled,
    required this.onSelected,
  });

  final MonettaBottomDestination destination;
  final bool selected;
  final int bagCount;
  final TextScaler labelScaler;
  final bool wrapLabel;
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
                          maxLines: widget.wrapLabel ? null : 1,
                          softWrap: widget.wrapLabel,
                          textAlign: TextAlign.center,
                          textScaler: widget.labelScaler,
                          style: _labelStyle(
                            weight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: color,
                          ).copyWith(
                            decoration:
                                selected ? TextDecoration.underline : null,
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
      // Categories: four cells, matching the directory destination.
      case MonettaBottomDestination.catalog:
        final inset = MonettaTokens.space[0];
        final gap = MonettaTokens.space[0];
        final cell = (MonettaTokens.logoHeight - inset * 2 - gap) / 2;
        for (final x in [inset, inset + cell + gap]) {
          for (final y in [inset, inset + cell + gap]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x, y, cell, cell),
                Radius.circular(inset / 2),
              ),
              paint,
            );
          }
        }
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
