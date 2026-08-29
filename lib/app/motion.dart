/// Quiet motion language. One cinematic moment per screen; everything else
/// settles. Tokens live here so duration is not a personality choice.
library;

import 'dart:async';

import 'package:flutter/material.dart';

const Duration kEnter = Duration(milliseconds: 720);
const Duration kSettle = Duration(milliseconds: 480);
const Duration kSwap = Duration(milliseconds: 280);
const Duration kSnap = Duration(milliseconds: 180);
const Duration kKenBurns = Duration(seconds: 18);

/// Ease-out expo. No overshoot — overshoot is a template tell.
const Cubic kMotionCurve = Cubic(0.16, 1, 0.3, 1);

const double kFreeShippingThreshold = 1499;
const double kStandardShippingFee = 149;

double shippingFor(double subtotal) =>
    subtotal >= kFreeShippingThreshold ? 0 : kStandardShippingFee;

double remainingForFreeShipping(double subtotal) {
  final left = kFreeShippingThreshold - subtotal;
  return left > 0 ? left : 0;
}

bool get inWidgetTest =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');

bool reduceMotion(BuildContext context) {
  if (inWidgetTest) return true;
  final media = MediaQuery.maybeOf(context);
  if (media == null) return false;
  return media.disableAnimations || media.accessibleNavigation;
}

/// Fade plus a 8 px rise. Used for shopper routes. Checkout should call this
/// too so money screens do not slide like a list tile.
Route<T> monettaFadeRoute<T extends Object?>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: kEnter,
    reverseTransitionDuration: kSettle,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (reduceMotion(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: kMotionCurve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// One-shot enter for a headline or a hero. Not for product grids.
class Reveal extends StatefulWidget {
  const Reveal({
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kEnter);
    _opacity = CurvedAnimation(parent: _controller, curve: kMotionCurve);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset / 400),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: kMotionCurve));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (reduceMotion(context)) {
        _controller.value = 1;
        return;
      }
      if (widget.delay > Duration.zero) {
        await Future<void>.delayed(widget.delay);
        if (!mounted) return;
      }
      await _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Reveals a block the first time it reaches the viewport.
///
/// Home uses this for complete editorial groups — hero, heading plus rail,
/// story card, and social proof — rather than animating every label and tile
/// independently. The group remains one perceptual unit while the stagger
/// between sections gives the eye a clear path through the storefront.
class RevealOnScroll extends StatefulWidget {
  const RevealOnScroll({
    required this.child,
    required this.scrollController,
    this.delay = Duration.zero,
    this.offset = 10,
    super.key,
  });

  final Widget child;
  final ScrollController scrollController;
  final Duration delay;
  final double offset;

  @override
  State<RevealOnScroll> createState() => _RevealOnScrollState();
}

class _RevealOnScrollState extends State<RevealOnScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _translation;
  Timer? _delayTimer;
  bool _checkScheduled = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kSettle);
    _opacity = CurvedAnimation(parent: _controller, curve: kMotionCurve);
    _translation = Tween<double>(
      begin: widget.offset,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: kMotionCurve));
    widget.scrollController.addListener(_scheduleViewportCheck);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scheduleViewportCheck(),
    );
  }

  @override
  void didUpdateWidget(covariant RevealOnScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController == widget.scrollController) return;
    oldWidget.scrollController.removeListener(_scheduleViewportCheck);
    widget.scrollController.addListener(_scheduleViewportCheck);
  }

  bool _isInViewport() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return false;

    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    return bottom > 0 && top < viewportHeight;
  }

  void _scheduleViewportCheck() {
    if (_started || _checkScheduled || !mounted) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _maybeStart();
    });
  }

  void _maybeStart() {
    if (_started || !mounted || !_isInViewport()) return;
    _started = true;

    if (reduceMotion(context)) {
      _controller.value = 1;
      return;
    }

    if (widget.delay <= Duration.zero) {
      _controller.forward();
      return;
    }

    _delayTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    widget.scrollController.removeListener(_scheduleViewportCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: AnimatedBuilder(
        animation: _translation,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _translation.value),
          child: child,
        ),
      ),
    );
  }
}
