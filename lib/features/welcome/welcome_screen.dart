/// Screen 01 — the editorial welcome.
///
/// Distinct from the *technical* launch surface (`app/startup_reveal.dart`),
/// which covers the first frame while the catalog hydrates and is untouched by
/// this package. This screen is the first-visit boutique window: it never
/// delays startup, and a returning shopper never sees it — see
/// [WelcomeGate] for the persistence rule.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/guide_art.dart';

/// Sunset and curtains supplied for the welcome screen. The official wordmark
/// is drawn on top; a catalog bag is not composited because Shopify photos
/// are opaque packshots, not cutouts.
const String kWelcomePhotoAsset = kGuideWelcomeBackground;

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onStart, super.key});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MonettaTokens.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const GuideArt(
            key: ValueKey('welcome-photo'),
            asset: kWelcomePhotoAsset,
          ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCCFBF6EE),
                    Color(0x55FBF6EE),
                    Color(0x00FBF6EE),
                    Color(0x66000000),
                  ],
                  stops: [0, 0.28, 0.55, 1],
                ),
              ),
            ),
          ),
          // Center on the full screen: mirror the larger side inset (e.g. the
          // iPhone Duo right bar edge) instead of shifting content left.
          SafeArea(
            left: false,
            right: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: math.max(
                  MediaQuery.paddingOf(context).left,
                  MediaQuery.paddingOf(context).right,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, bounds) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: bounds.maxHeight),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: EdgeInsets.all(
                            MonettaTokens.gutterFor(bounds.maxWidth),
                          ),
                          child: Column(
                            children: [
                              SizedBox(height: MonettaTokens.space[5]),
                              _Entrance(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: MonettaTokens.breakpointMedium,
                                  ),
                                  child: Column(
                                    children: [
                                      const MonettaWordmark(
                                        height: MonettaTokens.logoHeight * 2,
                                      ),
                                      SizedBox(height: MonettaTokens.space[3]),
                                      Text(
                                        'Un paraíso de marcas\npor descubrir',
                                        textAlign: TextAlign.center,
                                        style: clientGuideStyle(
                                          context,
                                          MonettaTokens.screenTitle,
                                          color: MonettaTokens.ink,
                                        ),
                                      ),
                                      SizedBox(height: MonettaTokens.space[3]),
                                      SizedBox(
                                        width: MonettaTokens.space[7],
                                        child: const Divider(
                                          color: MonettaTokens.gold,
                                        ),
                                      ),
                                      SizedBox(height: MonettaTokens.space[2]),
                                      Text(
                                        'BOUTIQUE ONLINE DE\nPRODUCTOS ORIGINALES',
                                        textAlign: TextAlign.center,
                                        style: clientGuideStyle(
                                          context,
                                          MonettaTokens.eyebrow,
                                          color: MonettaTokens.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: MonettaTokens.space[7]),
                              const Spacer(),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: MonettaTokens.breakpointMedium,
                                ),
                                child: ClientGuideButton(
                                  key: const ValueKey('welcome-start-button'),
                                  label: 'COMENZAR',
                                  chevron: true,
                                  onPressed: onStart,
                                ),
                              ),
                              SizedBox(height: MonettaTokens.space[3]),
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
        ],
      ),
    );
  }
}

class _Entrance extends StatefulWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kEnter,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      child: widget.child,
    );
  }
}
