/// Shared presentation for the continuation pages of the client guide.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/monetta_tokens.g.dart';
import '../../app/shopper_copy.dart';
import '../../app/theme.dart';
import '../../domain/home_content.dart';
import 'boutique_tokens.dart';
import 'client_guide_components.dart';
import 'guide_art.dart';
import '../help/policy_reader.dart';
import '../../data/shopify/shop_policy_repository.dart';
import '../../data/customer_auth/customer_graphql_client.dart';

class ClientGuideEditorial extends StatelessWidget {
  const ClientGuideEditorial({
    required this.title,
    required this.subtitle,
    this.imageAsset,
    this.action,
    this.overlaySide,
    this.titleAccent,
    super.key,
  });
  final String title;
  final String subtitle;
  final String? imageAsset;
  final Widget? action;

  /// When set (and [imageAsset] is present) the photo runs full-bleed and the
  /// copy sits on the given empty side of it, instead of the split layout.
  final GuideTextSide? overlaySide;

  /// Word set under [title] in the italic accent face (guide: «mayoreo»).
  final String? titleAccent;

  @override
  Widget build(BuildContext context) {
    if (imageAsset == kGuideHomeWholesale) {
      return GuideBanner(id: 'B04-editorial', action: action);
    }
    final palette = context.boutique;
    final side = overlaySide;
    if (side != null && imageAsset != null) {
      return _buildOverlay(context, side);
    }
    return ColoredBox(
      color: palette.surfaceDeep,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < MonettaTokens.breakpointMedium;
          final copy = Padding(
            padding: EdgeInsets.all(
              MonettaTokens.gutterFor(constraints.maxWidth),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: clientGuideStyle(context, MonettaTokens.campaign),
                ),
                SizedBox(height: MonettaTokens.space[2]),
                Text(
                  subtitle,
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                if (action != null) ...[
                  SizedBox(height: MonettaTokens.space[3]),
                  action!,
                ],
              ],
            ),
          );
          final photo = imageAsset == null
              ? ColoredBox(
                  color: palette.surface,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(MonettaTokens.space[3]),
                      child: Text(
                        'Imagen pendiente',
                        textAlign: TextAlign.center,
                        style: clientGuideStyle(
                          context,
                          MonettaTokens.cardLabel,
                          color: palette.inkMuted,
                        ),
                      ),
                    ),
                  ),
                )
              : Image.asset(
                  imageAsset!,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) =>
                      ColoredBox(color: palette.surface),
                );
          // At large text sizes the copy gets the full width and natural height.
          if (compact && MediaQuery.textScalerOf(context).scale(1) > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                AspectRatio(aspectRatio: 2, child: photo),
              ],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: compact ? 3 : 2, child: copy),
                Expanded(flex: 2, child: photo),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, GuideTextSide side) {
    final onRight = side == GuideTextSide.right;
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = MonettaTokens.gutterFor(width);
        final titleSize = (width * 0.075).clamp(24.0, 40.0);
        final titleStyle = guideSerifStyle(
          context,
          size: titleSize,
          color: Colors.black,
          height: 1.05,
          letterSpacing: titleSize * 0.02,
        );
        return Stack(
          children: [
            Positioned.fill(
              child: GuideArt(
                asset: imageAsset!,
                alignment:
                    onRight ? Alignment.centerLeft : Alignment.centerRight,
              ),
            ),
            Positioned.fill(child: GuideScrim(textSide: side)),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: width / 2.3),
              child: Align(
                alignment:
                    onRight ? Alignment.centerRight : Alignment.centerLeft,
                child: SizedBox(
                  width: width * (large ? 1.0 : 0.5),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MonettaTokens.space[1],
                      vertical: gutter,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: title,
                            style: titleStyle,
                            children: [
                              if (titleAccent != null) ...[
                                const TextSpan(text: '\n'),
                                TextSpan(
                                  text: titleAccent,
                                  style: guideAccentStyle(
                                    context,
                                    size: titleSize * 2.0,
                                    color: Colors.black,
                                    underline: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: MonettaTokens.space[2]),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: guideSerifItalicStyle(
                            context,
                            size: (width * 0.039).clamp(13.0, 19.0),
                            color: Colors.black,
                            weight: FontWeight.w500,
                          ),
                        ),
                        if (action != null) ...[
                          SizedBox(height: MonettaTokens.space[2]),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child:
                                Theme(data: buildLightTheme(), child: action!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One entry of [ClientGuideServices].
@immutable
class ClientGuideService {
  const ClientGuideService({
    required this.iconAsset,
    required this.title,
    required this.subtitle,
  });

  final String iconAsset;
  final String title;
  final String subtitle;
}

/// Services row of the guide's home («PÁGINA PRINCIPAL (SEGUIMIENTO)»).
const List<ClientGuideService> kClientGuideHomeServices = [
  ClientGuideService(
    iconAsset: kGuideIconServiceShipping,
    title: 'Envíos seguros',
    subtitle: 'Seguros y garantizados a todo México',
  ),
  ClientGuideService(
    iconAsset: kGuideIconServicePayments,
    title: 'Pagos seguros',
    subtitle: 'Compra con confianza',
  ),
  ClientGuideService(
    iconAsset: kGuideIconServiceOriginals,
    title: 'Productos 100% originales',
    subtitle: 'Garantía de autenticidad',
  ),
  ClientGuideService(
    iconAsset: kGuideIconServiceSupport,
    title: 'Atención personalizada',
    subtitle: 'Estamos para ayudarte',
  ),
];

/// Services row of the guide's wholesale page: the first entry is the free
/// shipping threshold; the other three match the home.
final List<ClientGuideService> kClientGuideWholesaleServices = [
  const ClientGuideService(
    iconAsset: kGuideIconServiceShipping,
    title: 'Envíos seguros',
    subtitle: 'Seguros y garantizados a todo México',
  ),
  ...kClientGuideHomeServices.skip(1),
];

class ClientGuideServices extends StatelessWidget {
  const ClientGuideServices({
    this.services = kClientGuideHomeServices,
    super.key,
  });

  final List<ClientGuideService> services;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across, as in the guide; two at large text sizes so the
        // captions keep their words whole.
        final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final columns = large ? 2 : 4;
        final gap = MonettaTokens.space[2];
        final cell = (constraints.maxWidth - gap * 2) / columns;
        final iconSize = (cell * 0.62).clamp(40.0, 72.0);
        return ColoredBox(
          color: palette.canvas,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: gap,
              vertical: MonettaTokens.space[3],
            ),
            child: Wrap(
              runSpacing: MonettaTokens.space[3],
              children: [
                for (final service in services)
                  SizedBox(
                    key: ValueKey('client-guide-service-${service.title}'),
                    width: cell,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MonettaTokens.space[0],
                      ),
                      child: Column(
                        children: [
                          Image.asset(
                            service.iconAsset,
                            height: iconSize,
                            width: iconSize,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            errorBuilder: (_, __, ___) =>
                                SizedBox.square(dimension: iconSize),
                          ),
                          SizedBox(height: MonettaTokens.space[1]),
                          Text(
                            service.title,
                            textAlign: TextAlign.center,
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.accountRow,
                            ).copyWith(fontSize: 12.5, height: 1.15),
                          ),
                          SizedBox(height: MonettaTokens.space[0]),
                          Text(
                            service.subtitle,
                            textAlign: TextAlign.center,
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.navLabel,
                              color: palette.inkMuted,
                            ).copyWith(fontSize: 11, height: 1.25),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// UI v4.1 footer (Corrección 5): a very soft grey band with the wordmark and
/// the social icons on one line, an «Ayuda» column (Contacto, Envíos, Cambios y
/// devoluciones) and an «Información» column (Mayoreo, Aviso de privacidad,
/// Términos y condiciones), then the rights line. No search and no payments
/// line. A policy link appears only when the store has published that policy.
class ClientGuideFooter extends StatelessWidget {
  const ClientGuideFooter({
    required this.onContact,
    required this.onAbout,
    this.onWholesale,
    this.socialLinks = const <HomeSocialLink>[],
    this.openUri,
    super.key,
  });
  final VoidCallback onContact;

  /// Retained for existing callers; not part of the correction 5 footer.
  final VoidCallback onAbout;
  final VoidCallback? onWholesale;

  /// Instagram, TikTok and Facebook in that order when configured; WhatsApp
  /// always closes the row.
  final List<HomeSocialLink> socialLinks;

  /// Test seam; defaults to opening the link outside the app.
  final Future<bool> Function(Uri uri)? openUri;

  static const Color background = Color(0xfff5f5f4);

  @override
  Widget build(BuildContext context) {
    final controller = PolicyScope.maybeOf(context);
    final palette = context.boutique;
    bool published(ShopPolicyKind kind) =>
        controller?.policies?[kind]?.status == CapabilityReadStatus.supported;

    Widget link(String label, VoidCallback onTap, {Key? key}) => Semantics(
          button: true,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.control,
                    color: palette.ink,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w400),
                ),
              ),
            ),
          ),
        );

    Widget column(String title, List<Widget> links) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                title.toUpperCase(),
                style: clientGuideStyle(
                  context,
                  MonettaTokens.navLabel,
                  color: palette.inkMuted,
                ).copyWith(fontSize: 12, letterSpacing: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            ...links,
          ],
        );

    final help = column('Ayuda', [
      link('Contacto', onContact, key: const ValueKey('footer-contact')),
      if (published(ShopPolicyKind.shipping))
        link('Envíos', () => openPolicy(context, ShopPolicyKind.shipping),
            key: const ValueKey('footer-shipping')),
      if (published(ShopPolicyKind.refund))
        link('Cambios y devoluciones',
            () => openPolicy(context, ShopPolicyKind.refund),
            key: const ValueKey('footer-refund')),
    ]);
    final info = column('Información', [
      if (onWholesale != null)
        link('Mayoreo', onWholesale!, key: const ValueKey('footer-wholesale')),
      if (published(ShopPolicyKind.privacy))
        link('Aviso de privacidad',
            () => openPolicy(context, ShopPolicyKind.privacy),
            key: const ValueKey('footer-privacy')),
      if (published(ShopPolicyKind.terms))
        link('Términos y condiciones',
            () => openPolicy(context, ShopPolicyKind.terms),
            key: const ValueKey('footer-terms')),
      if (controller?.failed == true)
        link('Reintentar políticas', controller!.refresh,
            key: const ValueKey('footer-policies-retry')),
    ]);

    return Container(
      key: const ValueKey('client-guide-footer'),
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            spacing: 16,
            children: [
              Semantics(
                label: 'MONETTA',
                excludeSemantics: true,
                child: const MonettaWordmark(height: MonettaTokens.logoHeight),
              ),
              _FooterSocialRow(links: socialLinks, openUri: openUri),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two columns down to 320 px; at large text sizes they stack.
              final scale = MediaQuery.textScalerOf(context).scale(1);
              if (constraints.maxWidth < 300 || scale > 1.6) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [help, const SizedBox(height: 16), info],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: help),
                  const SizedBox(width: 16),
                  Expanded(child: info),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            '© ${DateTime.now().year} MONETTA',
            style: clientGuideStyle(
              context,
              MonettaTokens.navLabel,
              color: palette.inkMuted,
            ).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FooterSocialRow extends StatelessWidget {
  const _FooterSocialRow({required this.links, this.openUri});

  final List<HomeSocialLink> links;
  final Future<bool> Function(Uri uri)? openUri;

  static const _order = ['instagram', 'tiktok', 'facebook'];
  static const _assets = <String, String>{
    'instagram': 'assets/images/v41/icons/instagram.svg',
    'tiktok': 'assets/images/v41/icons/tiktok.svg',
    'facebook': 'assets/images/v41/icons/facebook.svg',
    'whatsapp': 'assets/images/v41/icons/whatsapp.svg',
  };

  @override
  Widget build(BuildContext context) {
    bool safe(Uri? uri) =>
        uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    final entries = <(String, String, Uri)>[
      for (final id in _order)
        for (final link in links)
          if (link.id == id && safe(link.uri)) (id, link.label, link.uri!),
      (
        'whatsapp',
        'WhatsApp $kWhatsAppNumberDisplay',
        Uri.https('wa.me', '/$kWhatsAppE164')
      ),
    ];
    final open = openUri ??
        (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (id, label, uri) in entries)
          Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: InkResponse(
              key: ValueKey('footer-social-$id'),
              radius: 24,
              onTap: () => unawaited(open(uri)),
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: SvgPicture.asset(_assets[id]!, width: 26, height: 26),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
