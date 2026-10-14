/// Closing band of the shopper home: signup, promises, payment marks,
/// WhatsApp, and the small footer.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/home_content.dart';
import '../boutique/boutique_tokens.dart';
import 'home_payment_methods.dart';
import 'monetta_m_mark.dart';

/// May change to "100% originales". One constant, one place.
const String kHomeOriginalsPromise = 'Originales garantizados';

/// Storefront ivory (`#F8F5EE` is the token; this step is the same hue,
/// used so the closing band reads as cream on the white page).
const Color kHomeClosingCream = Color(0xFFF8F5EE);

/// Gap between the last footer line and the top of the floating navigation.
const double kHomeClosingNavGap = 24;

const String kHomePrivacyPolicyUrl =
    'https://monetta.mx/policies/privacy-policy';

const String kHomeTermsUrl = 'https://monetta.mx/policies/terms-of-service';

const String kHomeFooterCopyright = '© Monetta 2026';

/// Used only when the storefront publishes no social links.
const List<HomeSocialLink> kHomeFooterSocialPlaceholders = <HomeSocialLink>[
  HomeSocialLink(
    id: 'instagram',
    label: 'Instagram',
    url: 'https://www.instagram.com/_monetta.mx',
  ),
  HomeSocialLink(
    id: 'tiktok',
    label: 'TikTok',
    url: 'https://www.tiktok.com/@monetta.oficial',
  ),
  HomeSocialLink(
    id: 'facebook',
    label: 'Facebook',
    url: 'https://www.facebook.com/profile.php?id=100091065527635',
  ),
];

double homeClosingNavClearance(BuildContext context) {
  return MediaQuery.paddingOf(context).bottom + kHomeClosingNavGap;
}

class HomePromise {
  const HomePromise({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const List<HomePromise> kHomePromises = <HomePromise>[
  HomePromise(
    id: 'originals',
    label: kHomeOriginalsPromise,
    icon: Icons.verified_outlined,
  ),
  HomePromise(
    id: 'shipping',
    label: 'Envíos rápidos a todo México',
    icon: Icons.local_shipping_outlined,
  ),
  HomePromise(
    id: 'payments',
    label: 'Pagos seguros',
    icon: Icons.lock_outline,
  ),
];

class HomeClosingSection extends StatelessWidget {
  const HomeClosingSection({
    required this.onRegister,
    this.isSignedIn = false,
    this.socialLinks = const <HomeSocialLink>[],
    this.onOpenWhatsApp,
    this.onOpenUrl,
    this.platform,
    this.expressPayLogosEnabled = kExpressPayLogosEnabled,
    super.key,
  });

  final VoidCallback onRegister;
  final bool isSignedIn;
  final List<HomeSocialLink> socialLinks;
  final VoidCallback? onOpenWhatsApp;
  final ValueChanged<Uri>? onOpenUrl;

  /// Test seam. Production follows the app platform.
  final TargetPlatform? platform;

  /// Test seam. Production uses [kExpressPayLogosEnabled].
  final bool expressPayLogosEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cream = dark ? palette.surface : kHomeClosingCream;
    return ColoredBox(
      key: const ValueKey<String>('home-closing-section'),
      color: cream,
      child: Center(
        child: ConstrainedBox(
          key: const ValueKey<String>('home-closing-column'),
          constraints: const BoxConstraints(maxWidth: 720),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Wide means the column itself is the iPad measure, so a
              // phone-width band stays a three-up row even on a large window.
              final wide = constraints.maxWidth >= 720;
              return _ClosingColumn(
                wide: wide,
                isSignedIn: isSignedIn,
                onRegister: onRegister,
                platform: platform,
                expressPayLogosEnabled: expressPayLogosEnabled,
                onOpenWhatsApp: onOpenWhatsApp,
                onOpenUrl: onOpenUrl,
                links: _links(),
              );
            },
          ),
        ),
      ),
    );
  }

  List<HomeSocialLink> _links() {
    final usable = <HomeSocialLink>[
      for (final link in socialLinks)
        if (link.uri != null) link,
    ];
    if (usable.isNotEmpty) return usable;
    return <HomeSocialLink>[
      for (final link in kHomeFooterSocialPlaceholders)
        if (link.uri != null) link,
    ];
  }
}

/// Previous name of this band. Signup still enters through [onRegister].
typedef HomeAccountInvitation = HomeClosingSection;

class _ClosingColumn extends StatelessWidget {
  const _ClosingColumn({
    required this.wide,
    required this.isSignedIn,
    required this.onRegister,
    required this.links,
    required this.expressPayLogosEnabled,
    this.platform,
    this.onOpenWhatsApp,
    this.onOpenUrl,
  });

  final bool wide;
  final bool isSignedIn;
  final VoidCallback onRegister;
  final TargetPlatform? platform;
  final bool expressPayLogosEnabled;
  final VoidCallback? onOpenWhatsApp;
  final ValueChanged<Uri>? onOpenUrl;
  final List<HomeSocialLink> links;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              key: const ValueKey<String>('home-signup-gold-line'),
              width: 40,
              height: 1,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isSignedIn ? 'TU CUENTA' : 'OBTÉN TU PRIMER ENVÍO GRATIS',
            textAlign: TextAlign.center,
            style: editorial(
              wide ? 34 : 28,
              color: palette.ink,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSignedIn
                ? 'Consulta tus pedidos y datos de compra'
                : 'Porque tú lo vales',
            textAlign: TextAlign.center,
            style: boutiqueText(size: 16, color: palette.inkMuted),
          ),
          const SizedBox(height: 24),
          _SignupButton(
            label: isSignedIn ? 'VER MI CUENTA' : 'REGISTRARME AHORA',
            onPressed: onRegister,
          ),
          if (!isSignedIn) ...[
            const SizedBox(height: 12),
            Text(
              'Aplica en tu primera compra.',
              key: const ValueKey<String>('home-signup-fine-print'),
              textAlign: TextAlign.center,
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
          ],
          const SizedBox(height: 36),
          _Promises(wide: wide),
          const SizedBox(height: 28),
          HomePaymentMethodRow(
            platform: platform,
            expressPayLogosEnabled: expressPayLogosEnabled,
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey<String>('home-whatsapp-link'),
            onPressed: onOpenWhatsApp,
            child: Text(
              '¿Dudas? Escríbenos por WhatsApp',
              textAlign: TextAlign.center,
              style: boutiqueText(
                size: 14,
                weight: FontWeight.w500,
                color: palette.goldText,
                decoration: TextDecoration.underline,
              ).copyWith(decorationColor: palette.goldText),
            ),
          ),
          const SizedBox(height: 28),
          Semantics(
            label: 'Monetta',
            excludeSemantics: true,
            child: MonettaMMark(
              key: const ValueKey<String>('home-footer-mark'),
              size: 42,
              color: palette.gold,
            ),
          ),
          const SizedBox(height: 4),
          _SocialRow(links: links, onOpenUrl: onOpenUrl),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            children: [
              _FooterLink(
                key: const ValueKey<String>('home-footer-privacy'),
                label: 'Política de privacidad',
                url: kHomePrivacyPolicyUrl,
                onOpenUrl: onOpenUrl,
              ),
              _FooterLink(
                key: const ValueKey<String>('home-footer-terms'),
                label: 'Términos',
                url: kHomeTermsUrl,
                onOpenUrl: onOpenUrl,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            kHomeFooterCopyright,
            key: const ValueKey<String>('home-footer-copyright'),
            textAlign: TextAlign.center,
            style: boutiqueText(size: 12, color: palette.inkMuted),
          ),
          SizedBox(
            key: const ValueKey<String>('home-closing-nav-clearance'),
            height: homeClosingNavClearance(context),
          ),
        ],
      ),
    );
  }
}

class _SignupButton extends StatelessWidget {
  const _SignupButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = dark ? context.boutique.ink : const Color(0xFF111111);
    final labelColor = dark ? context.boutique.canvas : const Color(0xFFFFFFFF);
    return SizedBox(
      key: const ValueKey<String>('home-register-button'),
      height: 52,
      width: double.infinity,
      child: Material(
        color: fill,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kBoutiqueSansFamily,
                fontFamilyFallback: kBoutiqueSansFallback,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                height: 1,
                color: labelColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Promises extends StatelessWidget {
  const _Promises({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final tiles = <Widget>[
      for (final promise in kHomePromises)
        _PromiseTile(promise: promise, color: palette.gold, ink: palette.ink),
    ];
    return KeyedSubtree(
      key: const ValueKey<String>('home-closing-promises'),
      child: wide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < tiles.length; index++) ...[
                  if (index > 0) const SizedBox(width: 28),
                  SizedBox(width: 180, child: tiles[index]),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final tile in tiles) Expanded(child: tile),
              ],
            ),
    );
  }
}

class _PromiseTile extends StatelessWidget {
  const _PromiseTile({
    required this.promise,
    required this.color,
    required this.ink,
  });

  final HomePromise promise;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(promise.icon, size: 26, color: color),
        const SizedBox(height: 8),
        Text(
          promise.label,
          textAlign: TextAlign.center,
          style: boutiqueText(size: 12, height: 1.3, color: ink),
        ),
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.links, required this.onOpenUrl});

  final List<HomeSocialLink> links;
  final ValueChanged<Uri>? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey<String>('home-footer-social'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final link in links)
          IconButton(
            key: ValueKey<String>('home-social-${link.id}'),
            tooltip: link.label,
            onPressed: onOpenUrl == null || link.uri == null
                ? null
                : () => onOpenUrl!(link.uri!),
            color: context.boutique.ink,
            icon: Icon(_socialIcon(link.id), size: 22),
          ),
      ],
    );
  }

  IconData _socialIcon(String id) => switch (id) {
        'instagram' => Icons.camera_alt_outlined,
        'facebook' => Icons.facebook_outlined,
        'tiktok' => Icons.music_note_outlined,
        _ => Icons.open_in_new,
      };
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.url,
    required this.onOpenUrl,
    super.key,
  });

  final String label;
  final String url;
  final ValueChanged<Uri>? onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final color = context.boutique.inkMuted;
    return TextButton(
      onPressed: onOpenUrl == null ? null : () => onOpenUrl!(Uri.parse(url)),
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      child: Text(
        label,
        style: boutiqueText(
          size: 12,
          color: color,
          decoration: TextDecoration.underline,
        ).copyWith(decorationColor: color),
      ),
    );
  }
}
