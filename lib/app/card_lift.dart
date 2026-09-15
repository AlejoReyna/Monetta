import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

/// A visual response that leaves taps, nested controls and scrolling to the
/// child. Its hit area stays still while the card lifts above the page.
class MonettaCardLift extends StatefulWidget {
  const MonettaCardLift({
    required this.child,
    this.enabled = true,
    this.mouseCursor = SystemMouseCursors.click,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final MouseCursor mouseCursor;
  final BorderRadius borderRadius;

  @override
  State<MonettaCardLift> createState() => _MonettaCardLiftState();
}

class _MonettaCardLiftState extends State<MonettaCardLift> {
  bool _hovered = false;
  bool _pressed = false;
  int? _pointer;
  Offset? _pressOrigin;
  Timer? _releaseTimer;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled ||
        _pointer != null ||
        event.buttons != kPrimaryButton) {
      return;
    }
    _releaseTimer?.cancel();
    _pointer = event.pointer;
    _pressOrigin = event.position;
    setState(() => _pressed = true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || !_pressed) return;
    // A drag belongs to the scroll view, even when it began on a card.
    if ((event.position - _pressOrigin!).distance > kTouchSlop) {
      setState(() => _pressed = false);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _pressOrigin = null;
    if (!_pressed) return;
    // Keep quick taps visible while the child opens its route. Scrolling and
    // cancelled gestures release immediately instead of leaving a raised card.
    if (event is PointerUpEvent) {
      _releaseTimer = Timer(kSnap, () {
        if (mounted) setState(() => _pressed = false);
      });
    } else {
      _releaseTimer?.cancel();
      setState(() => _pressed = false);
    }
  }

  @override
  void didUpdateWidget(covariant MonettaCardLift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _releaseTimer?.cancel();
      _hovered = false;
      _pressed = false;
      _pointer = null;
      _pressOrigin = null;
    }
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (_hovered || _pressed);
    final reduced = reduceMotion(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: widget.enabled ? widget.mouseCursor : MouseCursor.defer,
      onEnter: (_) {
        if (widget.enabled) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: active ? 1 : 0),
          duration: reduced ? Duration.zero : (active ? kSnap : kSwap),
          curve: kMotionCurve,
          child: widget.child,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, reduced ? 0 : -4 * value),
            transformHitTests: false,
            child: Transform.scale(
              scale: reduced ? 1 : 1 + .012 * value,
              transformHitTests: false,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  // Paint a solid surface only while raised so the resting
                  // editorial layout keeps its original background.
                  color: context.monettaColors.surfaceRaised
                      .withValues(alpha: value),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: (dark ? .28 : .10) * value),
                      blurRadius: 18 * value,
                      offset: Offset(0, 8 * value),
                    ),
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: (dark ? .14 : .04) * value),
                      blurRadius: 4 * value,
                      offset: Offset(0, 2 * value),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
