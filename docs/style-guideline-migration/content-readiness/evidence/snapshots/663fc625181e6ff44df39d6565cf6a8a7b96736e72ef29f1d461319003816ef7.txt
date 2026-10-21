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
import '../../app/theme.dart';
import '../boutique/boutique_tokens.dart';

/// The welcome photograph.
///
/// Chosen by looking at every candidate, not by filename: `campaign_welcome.png`
/// is a screenshot of a web card, and `hero_poster.jpg` is a blown-out video
/// poster frame. `campaign_terracotta.jpg` is the only bundled asset that is
/// actually the brief's scene — a dark brown leather top-handle bag on a plinth
/// in warm arch light, with empty sky at the top for the identity.
///
/// Pending brief: it is 4:5 (1122×1402); a true 9:19.5 frame would stop the
/// cover crop from discarding ~40% of its width on a phone. See
/// `docs/` handoff note in the package summary.
const String kWelcomePhotoAsset = 'assets/images/campaign_terracotta.jpg';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1411),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _WelcomePhoto(),
          // Legibility floor for the identity in the upper third and for the
          // action at the foot, without flattening the piece in the middle.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x8A000000),
                    Color(0x66000000),
                    Color(0x1F000000),
                    Color(0x99000000),
                    Color(0xDB000000),
                  ],
                  stops: <double>[0, .22, .5, .82, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.gutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identity sits in the upper quarter, as on figure 01 — the
                // piece owns the middle of the frame.
                const Spacer(flex: 22),
                _Entrance(
                  child: Column(
                    children: [
                      const MonettaWordmark(height: 42),
                      const SizedBox(height: BoutiqueSpace.md),
                      Text(
                        'Tu boutique de marcas originales\nimportadas de EE.UU.'
                            .toUpperCase(),
                        textAlign: TextAlign.center,
                        style: boutiqueEyebrow(
                          size: 11,
                          color: palette.onDark.withValues(alpha: .88),
                        ).copyWith(height: 1.7),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 66),
                BoutiqueButton.onPhoto(
                  key: const ValueKey('welcome-start-button'),
                  label: 'Comenzar',
                  onPressed: onStart,
                ),
                const SizedBox(height: BoutiqueSpace.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Figure 01 carries four page indicators under the action. Only one welcome
/// slide exists here — there is one bundled photograph that fits the scene and
/// no approved copy for three more — so the dots are deliberately absent: a
/// single dot is noise, not navigation. The asset brief for the other three
/// slides is in `docs/REDISENO_PAQUETE_A.md`.
class _WelcomePhoto extends StatelessWidget {
  const _WelcomePhoto();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kWelcomePhotoAsset,
      key: const ValueKey('welcome-photo'),
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      // A missing or undecodable asset must still leave the wordmark and the
      // action legible, so the fallback is a warm ground, not a blank box.
      errorBuilder: (_, __, ___) => const DecoratedBox(
        key: ValueKey('welcome-photo-fallback'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF3A2A1E), Color(0xFF17110D)],
          ),
        ),
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
