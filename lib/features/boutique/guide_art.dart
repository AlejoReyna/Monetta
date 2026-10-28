/// Decorative stills supplied for the client guide.
///
/// Product photographs and brand marks are not in these files. A missing file
/// falls back to the warm canvas so a later drop-in replaces it with no code
/// change. `producto_fondo` is intentionally not registered: Shopify photos in
/// this catalog are opaque packshots, not cutouts.
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
import 'boutique_tokens.dart';
import 'client_guide_components.dart';

const String kGuideWelcomeBackground =
    'assets/images/guide/bienvenida_fondo.jpg';
const String kGuideHomeHero = 'assets/images/guide/home_hero_fondo.jpg';
const String kGuideStudioBanner = 'assets/images/guide/studio_banner_fondo.jpg';
const String kGuideFollowupHero =
    'assets/images/guide/seguimiento_hero_fondo.jpg';
const String kGuideRewardsPhone =
    'assets/images/guide/rewards_phone_mockup.jpg';
const String kGuideShareBanner =
    'assets/images/guide/comparte_banner_fondo.jpg';

/// Home capture composited onto the rewards phone glass.
const String kGuideRewardsAppScreen =
    'assets/images/guide/rewards_app_screen.jpg';

/// Loads a guide still. Failure paints the warm surface and nothing else.
class GuideArt extends StatelessWidget {
  const GuideArt({
    required this.asset,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    super.key,
  });

  final String asset;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          ColoredBox(color: context.boutique.surfaceDeep),
    );
  }
}

/// Full-bleed banner: guide still, headline on the left, optional action.
class GuideHero extends StatelessWidget {
  const GuideHero({
    required this.asset,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.action,
    this.height,
    this.onTap,
    super.key,
  });

  final String asset;
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? action;
  final double? height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final width = MediaQuery.sizeOf(context).width;
    final resolved = height ?? (width / 1.85).clamp(180.0, 280.0);
    return SizedBox(
      height: resolved,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GuideArt(asset: asset),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xE6FBF6EE),
                  Color(0x99FBF6EE),
                  Color(0x00FBF6EE),
                ],
                stops: [0, 0.42, 0.78],
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(MonettaTokens.gutterFor(width)),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: (width - MonettaTokens.gutterFor(width) * 2).clamp(
                        0,
                        width,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (eyebrow != null)
                            Text(
                              eyebrow!,
                              style: clientGuideStyle(
                                context,
                                MonettaTokens.eyebrow,
                                color: palette.ink,
                              ),
                            ),
                          Text(
                            title,
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.campaign,
                              color: palette.ink,
                            ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: MonettaTokens.space[2]),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: width * 0.62,
                              ),
                              child: Text(
                                subtitle!,
                                style: clientGuideStyle(
                                  context,
                                  MonettaTokens.body,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                          ],
                          if (action != null) ...[
                            SizedBox(height: MonettaTokens.space[3]),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                child: action!,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wide cream banner used by the share card and the WhatsApp prompt.
class GuideShareBanner extends StatelessWidget {
  const GuideShareBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BoutiqueRadius.card,
      child: Stack(
        children: [
          const Positioned.fill(
            child: GuideArt(
              asset: kGuideShareBanner,
              alignment: Alignment.centerRight,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Phone still with a real home-screen capture on the glass.
///
/// The glass rectangle was measured on the 1024×620 source: a dark bezel
/// sits at x=648 and the near-white interior runs about x=668–800, y=12–540.
/// The overlay is `rewards_app_screen.jpg`, a capture of this app's home,
/// not a generated product. No bag is drawn.
class GuidePhoneMockup extends StatelessWidget {
  const GuidePhoneMockup({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1024 / 620,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              const GuideArt(asset: kGuideRewardsPhone, fit: BoxFit.contain),
              Positioned(
                left: width * 0.653,
                top: height * 0.02,
                width: width * 0.140,
                height: height * 0.84,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const GuideArt(
                    asset: kGuideRewardsAppScreen,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
