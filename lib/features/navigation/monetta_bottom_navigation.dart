/// Persistent shopper actions shared by the home and catalog screens.
library;

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/account_controller.dart';
import '../notifications/notification_inbox.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/storefront_layout.dart';
import '../../app/theme.dart';
import '../../main.dart' show AccountScope;
import 'storefront_pane_scope.dart';

enum MonettaBottomDestination { home, catalog, bag, account }

// Layout of the docked bar. The theme is the only source of its colors.
const double _kBarMinHeight = 56;

/// Radius of the v4.1 selection capsule behind the current destination.
const double _kSelectionRadius = 24;
const double _kBarSidePadding = 10;
const double _kBarMaxContentWidth = 480;
// 2 (was 4) so that «Categorías» (about 69 pt in Inter 600 at 13) still fits
// a quarter of a 320 pt bar: 75 - 2 * 2 = 71 pt available per column.
const double _kItemHorizontalPadding = 2;
const double _kItemVerticalPadding = 6;
const double _kIconBox = 24;
const double _kIconStroke = 1.7;
// Ring around the profile photo that stands in for the «Cuenta» glyph.
const double _kIconLabelGap = 3;
const double _kLabelSize = 13;
const double _kLabelHeight = 1.25;
const double _kPressedOpacity = 0.55;

// iOS-only floating glass capsule. The fill is the theme's navigation surface,
// so dark mode and high contrast need no special colors.
const double _kGlassHorizontalMargin = 16;
const double _kGlassTopMargin = 6;
const double _kGlassMinBottomMargin = 12;
const double _kGlassRadius = 28;
const double _kGlassBlurSigma = 24;
const double _kGlassFillAlpha = 0.82;
const double _kGlassEdgeWidth = 0.5;
const double _kGlassShadowAlpha = 0.08;
const double _kGlassShadowBlur = 24;
const Offset _kGlassShadowOffset = Offset(0, 8);

String _labelOf(MonettaBottomDestination destination) => switch (destination) {
      MonettaBottomDestination.home => 'Inicio',
      MonettaBottomDestination.catalog => 'Categorías',
      MonettaBottomDestination.bag => 'Carrito',
      MonettaBottomDestination.account => 'Cuenta',
    };

TextStyle _labelStyle({required FontWeight weight, Color? color}) => sans(
      size: _kLabelSize,
      height: _kLabelHeight,
      weight: weight,
      color: color,
    );

/// Persistent bar on the theme's navigation surface. On iOS it floats as a
/// translucent, rounded glass capsule above the home indicator; on every other
/// platform it stays a flat bar docked to the bottom edge. The selected
/// destination has semantic, weight and colour cues (the rail also a border).
/// Labels retain the requested system text scale and reflow when space is
/// limited.
class MonettaBottomNavigation extends StatelessWidget {
  const MonettaBottomNavigation({
    required this.current,
    required this.bagCount,
    required this.onSelected,
    this.notificationInbox,
    this.accountController,
    this.wholesaleEligible = false,
    this.secondary,
    this.vertical = false,
    super.key,
  });

  final NotificationInbox? notificationInbox;
  final AccountController? accountController;

  /// Set only from the checkout's authoritative eligibility response.
  final bool wholesaleEligible;
  final bool vertical;

  MonettaBottomNavigation asRail() => MonettaBottomNavigation(
        current: current,
        secondary: secondary,
        bagCount: bagCount,
        onSelected: onSelected,
        vertical: true,
        notificationInbox: notificationInbox,
        accountController: accountController,
        wholesaleEligible: wholesaleEligible,
      );

  final MonettaBottomDestination? current;

  /// What the second side of a two-sided window shows (the bag or the
  /// account). Only the vertical rail marks it, the same way as [current].
  final MonettaBottomDestination? secondary;
  final int bagCount;
  final ValueChanged<MonettaBottomDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final account = accountController ?? AccountScope.maybeOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([account, notificationInbox]),
      builder: (context, _) {
        final owner = account?.account?.localAccountId;
        final unread = account?.isSignedIn == true && owner != null
            ? notificationInbox?.unreadCountFor(owner) ?? 0
            : 0;
        return _build(context, unread);
      },
    );
  }

  Widget _build(BuildContext context, int unread) {
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
              selected: destination == current || destination == secondary,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: IconButton(
                  key: Key('bottom-nav-${destination.name}'),
                  tooltip: destination == MonettaBottomDestination.bag &&
                          bagCount > 0
                      ? '${_labelOf(destination)}, $bagCount ${bagCount == 1 ? 'artículo' : 'artículos'}'
                      : destination == MonettaBottomDestination.account &&
                              unread > 0
                          ? 'Cuenta, $unread avisos sin leer'
                          : _labelOf(destination),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    side: destination == current || destination == secondary
                        ? BorderSide(color: colors.navigationForeground)
                        : null,
                    backgroundColor:
                        destination == current || destination == secondary
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
                          isLabelVisible: destination ==
                                      MonettaBottomDestination.bag &&
                                  bagCount > 0 ||
                              destination == MonettaBottomDestination.account &&
                                  unread > 0,
                          backgroundColor:
                              destination == MonettaBottomDestination.account
                                  ? const Color(0xFFA58248)
                                  : null,
                          textColor:
                              destination == MonettaBottomDestination.account
                                  ? Colors.black
                                  : null,
                          label: Text(
                              destination == MonettaBottomDestination.account
                                  ? (unread > 99 ? '99+' : '$unread')
                                  : '$bagCount'),
                          child: _NavGlyph(destination: destination),
                        ),
                ),
              ),
            ),
        ],
      );
    }
    // UI v4.1: the floating glass capsule with halo C on every platform.
    return _buildGlassCapsule(context, colors, unread);
  }

  /// Floating translucent capsule (UI v4.1 on iOS, Android and web) ringed
  /// by halo C: gold at 18 %, 10 px blur, 2 px spread, transparent centre.
  /// The blur is dropped under high contrast and the fill becomes opaque.
  Widget _buildGlassCapsule(
      BuildContext context, MonettaColors colors, int unread) {
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(_kGlassRadius);
    // Space the capsule adds around the destinations, so the overflow
    // decision keeps at least the task height the flat bar leaves.
    final bottomInset = MediaQuery.maybeViewPaddingOf(context)?.bottom ?? 0;
    final reservedHeight =
        _kGlassTopMargin + math.max(0.0, _kGlassMinBottomMargin - bottomInset);
    Widget capsule = DecoratedBox(
      decoration: ShapeDecoration(
        color: highContrast
            ? colors.navigationSurface.withValues(alpha: 1)
            : colors.navigationSurface.withValues(alpha: _kGlassFillAlpha),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.divider, width: _kGlassEdgeWidth),
        ),
      ),
      // Ink and focus paint on the capsule.
      child: Material(
        type: MaterialType.transparency,
        child: _buildHorizontalContent(
          context,
          reservedHeight: reservedHeight,
          unread: unread,
        ),
      ),
    );
    if (!highContrast) {
      capsule = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: _kGlassBlurSigma,
          sigmaY: _kGlassBlurSigma,
        ),
        child: capsule,
      );
    }
    return SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.only(bottom: _kGlassMinBottomMargin),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _kGlassHorizontalMargin,
          _kGlassTopMargin,
          _kGlassHorizontalMargin,
          0,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _kBarMaxContentWidth + 2 * _kBarSidePadding,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000)
                        .withValues(alpha: _kGlassShadowAlpha),
                    blurRadius: _kGlassShadowBlur,
                    offset: _kGlassShadowOffset,
                  ),
                  const BoxShadow(
                    color: MonettaTokens.haloColor,
                    blurRadius: MonettaTokens.haloBlur,
                    spreadRadius: MonettaTokens.haloSpread,
                  ),
                ],
              ),
              child: ClipRRect(
                key: const Key('bottom-nav-glass'),
                borderRadius: radius,
                child: capsule,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Destinations of the horizontal bar, shared by the flat bar and the iOS
  /// capsule. [reservedHeight] is extra vertical space the surrounding chrome
  /// takes besides the bar itself.
  Widget _buildHorizontalContent(
    BuildContext context, {
    double reservedHeight = 0,
    int unread = 0,
  }) {
    final media = MediaQuery.maybeOf(context);
    final animationsDisabled =
        media?.disableAnimations == true || media?.accessibleNavigation == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kBarSidePadding),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kBarMaxContentWidth),
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
              final wrapLabel =
                  widest > constraints.maxWidth - 2 * _kItemHorizontalPadding;
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
                      (media?.viewPadding.bottom ?? 0) -
                      reservedHeight <
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
                      for (final destination in MonettaBottomDestination.values)
                        CheckedPopupMenuItem(
                          value: destination,
                          checked: current == destination,
                          child: Text(
                            '${_labelOf(destination)}${destination == MonettaBottomDestination.bag && bagCount > 0 ? ' ($bagCount)' : destination == MonettaBottomDestination.account && unread > 0 ? ', $unread avisos sin leer' : ''}',
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
                      unreadCount: unread,
                      wholesaleEligible: wholesaleEligible,
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
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.bagCount,
    required this.unreadCount,
    required this.wholesaleEligible,
    required this.labelScaler,
    this.wrapLabel = false,
    required this.animationsDisabled,
    required this.onSelected,
  });

  final MonettaBottomDestination destination;
  final bool selected;
  final int bagCount;
  final int unreadCount;
  final bool wholesaleEligible;
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
    final badge = destination == MonettaBottomDestination.bag
        ? widget.bagCount
        : destination == MonettaBottomDestination.account
            ? widget.unreadCount
            : 0;
    final semanticLabel = badge > 0
        ? destination == MonettaBottomDestination.account
            ? '$label, $badge avisos sin leer'
            : '$label, $badge ${badge == 1 ? 'artículo' : 'artículos'}'
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
          // v4.1 (nav_0–nav_3): the current destination sits on a soft capsule;
          // icon and label stay ink. The capsule cross-fades, nothing moves.
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
              return DecoratedBox(
                key: Key('bottom-nav-${destination.name}-selection'),
                decoration: BoxDecoration(
                  color: colors.navigationSelection.withValues(
                    alpha: colors.navigationSelection.a * progress,
                  ),
                  borderRadius: BorderRadius.circular(_kSelectionRadius),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _kBarMinHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _kItemHorizontalPadding,
                      vertical: _kItemVerticalPadding,
                    ),
                    child: Opacity(
                      opacity: _pressed ? _kPressedOpacity : 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconTheme.merge(
                            data: IconThemeData(
                                color: destination ==
                                            MonettaBottomDestination.bag &&
                                        widget.wholesaleEligible
                                    ? const Color(0xFFA58248)
                                    : color),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _NavGlyph(
                                  key: Key(
                                    'bottom-nav-${destination.name}-icon',
                                  ),
                                  destination: destination,
                                ),
                                if (badge > 0)
                                  Positioned(
                                    left: 16,
                                    top: -6,
                                    child: _BagBadge(
                                        count: badge,
                                        account: destination ==
                                            MonettaBottomDestination.account),
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? const Color(0xFF000000);
    return CustomPaint(
      size: const Size.square(_kIconBox),
      painter: _NavGlyphPainter(destination: destination, color: color),
    );
  }
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
      // One continuous outline with a centred rectangular door.
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
            ..lineTo(14.84, 14.4)
            ..lineTo(9.16, 14.4)
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
      // Shopping cart: handle, basket with its rim and two wheels.
      case MonettaBottomDestination.bag:
        canvas
          ..drawPath(
            Path()
              ..moveTo(2.4, 3.2)
              ..lineTo(4.6, 3.2)
              ..lineTo(7.1, 14.6)
              ..quadraticBezierTo(7.4, 16, 8.9, 16)
              ..lineTo(18.6, 16)
              ..quadraticBezierTo(20.1, 16, 20.4, 14.6)
              ..lineTo(21.9, 7.4)
              ..lineTo(5.6, 7.4),
            paint,
          )
          ..drawCircle(const Offset(9.4, 20.1), 1.15, paint)
          ..drawCircle(const Offset(18, 20.1), 1.15, paint);
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
  const _BagBadge({required this.count, this.account = false});

  final int count;
  final bool account;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Container(
      key: Key(account ? 'bottom-nav-account-badge' : 'bottom-nav-bag-badge'),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: account ? const Color(0xFFA58248) : colors.navigationForeground,
        shape: StadiumBorder(
          side: BorderSide(
            color: colors.navigationSurface,
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
      child: Text(
        account
            ? (count > 99 ? '99+' : '$count')
            : (count > 9 ? '9+' : '$count'),
        textScaler: TextScaler.noScaling,
        style: sans(
          size: 10,
          weight: FontWeight.w600,
          height: 1,
          color: account ? Colors.black : colors.navigationSurface,
        ),
      ),
    );
  }
}
