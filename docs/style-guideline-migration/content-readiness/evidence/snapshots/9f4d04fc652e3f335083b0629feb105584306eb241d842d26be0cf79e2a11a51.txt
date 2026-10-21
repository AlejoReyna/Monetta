/// Account invitation shown at the end of the shopper home.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../boutique/boutique_tokens.dart';

import '../../app/theme.dart';

/// The invitation and the trailing home clearance share one champagne ground.
Color homeAccountInvitationBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF332B1C)
        : const Color(0xFFF5E7C9);

const _invitationDuration = Duration(milliseconds: 1320);

/// Gives shoppers a clear account entry point without breaking the editorial
/// rhythm of the home page.
class HomeAccountInvitation extends StatefulWidget {
  const HomeAccountInvitation({
    required this.onRegister,
    this.isSignedIn = false,
    this.scrollController,
    super.key,
  });

  final VoidCallback onRegister;
  final bool isSignedIn;
  final ScrollController? scrollController;

  @override
  State<HomeAccountInvitation> createState() => _HomeAccountInvitationState();
}

class _HomeAccountInvitationState extends State<HomeAccountInvitation>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<HomeAccountInvitation> {
  late final AnimationController _controller;
  late final Animation<double> _reveal;
  bool _started = false;
  bool _checkScheduled = false;

  // Retain the completed reveal when the home list recycles offscreen rows.
  @override
  bool get wantKeepAlive => true;

  bool get _motionDisabled =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.accessibleNavigationOf(context);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _invitationDuration,
    );
    _reveal = _controller.drive(
      CurveTween(curve: Interval(0, 480 / 1320, curve: kMotionCurve)),
    );
    widget.scrollController?.addListener(_scheduleViewportCheck);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didUpdateWidget(covariant HomeAccountInvitation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_scheduleViewportCheck);
      widget.scrollController?.addListener(_scheduleViewportCheck);
    }
    _scheduleViewportCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started && _motionDisabled) _controller.value = 1;
    _scheduleViewportCheck();
  }

  void _scheduleViewportCheck() {
    if (!mounted || _started || _checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _maybeStart();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _maybeStart() {
    if (!mounted || _started) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    if (top >= MediaQuery.sizeOf(context).height ||
        top + box.size.height <= 0) {
      return;
    }
    _started = true;
    if (_motionDisabled) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_scheduleViewportCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = context.boutique;
    final content = Container(
      key: const ValueKey('home-account-invitation'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: homeAccountInvitationBackground(context),
        border: Border(
          top: BorderSide(color: palette.hairline, width: .5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.xxl,
        BoutiqueSpace.gutter,
        BoutiqueSpace.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Text(
                widget.isSignedIn
                    ? 'TU CUENTA'
                    : 'OBTEN TU PRIMER ENVÍO GRATIS',
                textAlign: TextAlign.center,
                style: boutiqueDisplay(28, color: palette.ink),
              ),
              const SizedBox(height: BoutiqueSpace.md),
              Text(
                widget.isSignedIn
                    ? 'Consulta tus pedidos y datos de compra'
                    : 'Porque tú lo vales :)',
                textAlign: TextAlign.center,
                style: boutiqueText(size: 14, color: palette.inkMuted),
              ),
              const SizedBox(height: BoutiqueSpace.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BoutiqueButton(
                  key: const ValueKey('home-register-button'),
                  label:
                      widget.isSignedIn ? 'VER MI CUENTA' : 'REGISTRARME AHORA',
                  onPressed: widget.onRegister,
                ),
              ),
              const SizedBox(height: BoutiqueSpace.xxl),
              Text(
                'ENVÍOS RÁPIDOS Y PAGOS SEGUROS',
                textAlign: TextAlign.center,
                style: boutiqueEyebrow(size: 11, color: palette.inkMuted),
              ),
              const SizedBox(height: BoutiqueSpace.lg),
              _PaymentMethods(animation: _controller),
            ],
          ),
        ),
      ),
    );
    return FadeTransition(
      key: const ValueKey('home-account-invitation-reveal'),
      opacity: _reveal,
      child: AnimatedBuilder(
        animation: _reveal,
        child: content,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - _reveal.value)),
          child: child,
        ),
      ),
    );
  }
}

class _PaymentMethods extends StatelessWidget {
  const _PaymentMethods({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    const badges = [
      _PaymentBadge(width: 47, child: _ApplePayMark()),
      _PaymentBadge(width: 52, child: _GooglePayMark()),
      _PaymentBadge(width: 46, child: _CirclesMark.maestro()),
      _PaymentBadge(width: 46, child: _CirclesMark.mastercard()),
      _PaymentBadge(width: 46, child: _PayPalMark()),
      _PaymentBadge(width: 54, child: _ShopPayMark()),
      _PaymentBadge(width: 46, child: _VisaMark()),
    ];
    return Semantics(
      key: const ValueKey('home-payment-methods'),
      label:
          'Métodos de pago: Apple Pay, Google Pay, Maestro, Mastercard, PayPal, Shop Pay y Visa',
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < badges.length; index++) ...[
                if (index > 0) const SizedBox(width: 7),
                _PaymentReveal(
                  index: index,
                  animation: animation,
                  child: badges[index],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentReveal extends StatelessWidget {
  const _PaymentReveal({
    required this.index,
    required this.animation,
    required this.child,
  });

  final int index;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = 240 + index * 120;
    final reveal = animation.drive(
      CurveTween(
        curve:
            Interval(start / 1320, (start + 360) / 1320, curve: kMotionCurve),
      ),
    );
    return FadeTransition(
      key: ValueKey('home-payment-reveal-$index'),
      opacity: reveal,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .25), end: Offset.zero)
            .animate(reveal),
        child: child,
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    return Container(
      width: width,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.divider, width: .6),
      ),
      child: child,
    );
  }
}

class _ApplePayMark extends StatelessWidget {
  const _ApplePayMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.apple,
          size: 14,
          color: context.monettaColors.contentPrimary,
        ),
        const SizedBox(width: 1),
        Text(
          'Pay',
          style: sans(
            size: 9,
            weight: FontWeight.w600,
            color: context.monettaColors.contentPrimary,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _GooglePayMark extends StatelessWidget {
  const _GooglePayMark();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: sans(
          size: 8.5,
          weight: FontWeight.w600,
          color: context.monettaColors.contentPrimary,
          height: 1,
        ),
        children: const [
          TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
          TextSpan(text: ' Pay'),
        ],
      ),
    );
  }
}

class _CirclesMark extends StatelessWidget {
  const _CirclesMark.maestro()
      : left = const Color(0xFFE32636),
        right = const Color(0xFF2575C8);

  const _CirclesMark.mastercard()
      : left = const Color(0xFFEB001B),
        right = const Color(0xFFF79E1B);

  final Color left;
  final Color right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 17,
      child: Stack(
        children: [
          Positioned(left: 1, child: _circle(left)),
          Positioned(right: 1, child: _circle(right)),
        ],
      ),
    );
  }

  Widget _circle(Color color) => Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _PayPalMark extends StatelessWidget {
  const _PayPalMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'P',
      style: TextStyle(
        color: Color(0xFF166AB5),
        fontSize: 16,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        height: 1,
      ),
    );
  }
}

class _ShopPayMark extends StatelessWidget {
  const _ShopPayMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF5A31F4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: const Text(
        'shop',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _VisaMark extends StatelessWidget {
  const _VisaMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'VISA',
      style: TextStyle(
        color: Color(0xFF1434CB),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -.4,
        height: 1,
      ),
    );
  }
}
