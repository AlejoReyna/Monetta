/// Screen 01 — the editorial welcome.
///
/// Distinct from the *technical* launch surface (`app/startup_reveal.dart`),
/// which covers the first frame while the catalog hydrates and is untouched by
/// this package. This screen is the first-visit boutique window: it never
/// delays startup, and a returning shopper never sees it — see
/// [WelcomeGate] for the persistence rule.
library;

import 'package:flutter/material.dart';

import '../../app/motion.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../boutique/client_guide_components.dart';

/// The bundled campaign remains until the original portrait artwork is supplied.
const String kWelcomePhotoAsset = 'assets/images/campaign_terracotta.jpg';

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
          Image.asset(
            kWelcomePhotoAsset,
            key: const ValueKey('welcome-photo'),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              key: ValueKey('welcome-photo-fallback'),
              color: MonettaTokens.surfaceWarm,
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    MonettaTokens.canvas,
                    MonettaTokens.canvas.withValues(alpha: .94),
                    MonettaTokens.canvas.withValues(alpha: 0),
                    MonettaTokens.scrim,
                  ],
                  stops: const [
                    0,
                    .34,
                    .62,
                    1,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
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
