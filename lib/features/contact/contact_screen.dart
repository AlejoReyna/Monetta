library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/monetta_tokens.g.dart';
import '../../app/shopper_copy.dart';
import '../../domain/home_content.dart';
import '../../main.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import '../boutique/guide_art.dart';
import 'contact_links.dart';

/// Accessible name of the hero. The visible title and description are the
/// delivered B31 lettering layers, not a second typeface.
const String kContactHeroAccessibleLabel =
    'Tu boutique y proveedor de confianza. '
    'Bienvenida a nuestro paraíso de modelos originales de marcas que amas, '
    'importados y con envíos garantizados a todo México.';

const String kContactWhatsAppLabel =
    'Enviar Whatsapp al $kWhatsAppNumberDisplay';

/// Mobile lettering from v4.1 B31, already on main as
/// `storefront-theme/assets/monetta-v41-b31-*.png`.
const String kContactLetteringTitle =
    'assets/images/guide/monetta-v41-b31-titulo.png';
const String kContactLetteringDescription =
    'assets/images/guide/monetta-v41-b31-descripcion.png';

const double _kLetteringTitleAspect = 720 / 406;
const double _kLetteringDescriptionAspect = 720 / 240;

class ContactChannel {
  const ContactChannel({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.uri,
    this.iconAsset,
  });

  final String key;
  final IconData icon;

  /// Gold line icon of the guide. The Material [icon] is the fallback.
  final String? iconAsset;
  final String title;
  final String subtitle;
  final Uri uri;
}

/// A configured http(s) destination. Empty, blank, and unusable values are
/// not links: the screen hides that button instead of claiming it opens.
Uri? contactCommunityUri(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

/// Canales reales de la app. [socialLinks] permite a un propietario
/// sobreescribir las redes (p. ej. desde Shopify); por defecto, las
/// configuradas en el contenido editorial. Un grupo sin URI no entra
/// en la lista.
List<ContactChannel> monettaContactChannels({
  List<HomeSocialLink>? socialLinks,
  List<String> whatsAppGroups = monettaWhatsAppGroups,
  String facebookGroup = monettaFacebookGroup,
}) {
  final socials = socialLinks ?? HomeContent.fallback.socialLinks;
  return [
    ContactChannel(
      key: 'whatsapp',
      icon: Icons.chat_outlined,
      iconAsset: kGuideIconContactWhatsApp,
      title: kContactWhatsAppLabel,
      subtitle: '',
      uri: conciergeWhatsAppUri(),
    ),
    for (var i = 0; i < whatsAppGroups.length; i++)
      if (contactCommunityUri(whatsAppGroups[i]) case final uri?)
        ContactChannel(
          key: 'grupo-${i + 1}',
          icon: Icons.groups_outlined,
          iconAsset: kGuideIconContactGroup,
          title: 'Grupo ${i + 1}',
          subtitle: 'Únete a nuestro grupo de WhatsApp',
          uri: uri,
        ),
    if (contactCommunityUri(facebookGroup) case final uri?)
      ContactChannel(
        key: 'facebook-group',
        icon: Icons.facebook,
        iconAsset: kGuideIconContactGroup,
        title: 'Grupo de Facebook',
        subtitle: 'Únete a nuestra comunidad',
        uri: uri,
      ),
    for (final link in socials)
      if (link.uri != null)
        ContactChannel(
          key: 'social-${link.id}',
          icon: _socialIcon(link.id),
          iconAsset: _socialAsset(link.id),
          title: link.label,
          subtitle: 'Síguenos',
          uri: link.uri!,
        ),
  ];
}

String? _socialAsset(String id) => switch (id) {
      'instagram' => kGuideIconInstagram,
      'facebook' => kGuideIconFacebook,
      'tiktok' => kGuideIconTikTok,
      _ => null,
    };

IconData _socialIcon(String id) => switch (id) {
      'instagram' => Icons.camera_alt_outlined,
      'facebook' => Icons.facebook,
      'tiktok' => Icons.music_note,
      _ => Icons.open_in_new_rounded,
    };

Future<void> openContact(
  BuildContext context, {
  List<HomeSocialLink>? socialLinks,
  Future<bool> Function(Uri uri)? openUri,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ContactScreen(
        socialLinks: socialLinks,
        openUri: openUri,
      ),
    ),
  );
}

class ContactScreen extends StatelessWidget {
  const ContactScreen({
    this.socialLinks,
    this.openUri,
    this.whatsAppGroups = monettaWhatsAppGroups,
    this.facebookGroup = monettaFacebookGroup,
    super.key,
  });

  final List<HomeSocialLink>? socialLinks;

  /// Inyectable para pruebas; por defecto abre la app externa real.
  final Future<bool> Function(Uri uri)? openUri;

  /// Invitaciones de Grupo 1, Grupo 2, … Un valor vacío oculta ese botón.
  final List<String> whatsAppGroups;

  /// Invitación del grupo de Facebook. Vacía oculta ese botón.
  final String facebookGroup;

  Future<void> _open(BuildContext context, Uri uri) async {
    final open =
        openUri ?? ((u) => launchUrl(u, mode: LaunchMode.externalApplication));
    try {
      if (await open(uri) || !context.mounted) return;
    } on Exception {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final channels = monettaContactChannels(
      socialLinks:
          socialLinks ?? HomeContentScope.maybeOf(context)?.content.socialLinks,
      whatsAppGroups: whatsAppGroups,
      facebookGroup: facebookGroup,
    );
    final whatsapp =
        channels.firstWhere((channel) => channel.key == 'whatsapp');
    final groups = channels.where(
      (channel) =>
          channel.key.startsWith('grupo-') || channel.key == 'facebook-group',
    );
    const socialOrder = ['instagram', 'facebook', 'tiktok'];
    int socialRank(ContactChannel channel) {
      final index = socialOrder.indexOf(
        channel.key.substring('social-'.length),
      );
      return index < 0 ? socialOrder.length : index;
    }

    final socials = channels.where((c) => c.key.startsWith('social-')).toList()
      ..sort((a, b) => socialRank(a).compareTo(socialRank(b)));
    return ClientGuideScaffold(
      current: null,
      body: ListView(
        key: const ValueKey('contact-scroll'),
        padding: EdgeInsets.zero,
        children: [
          const _ContactHero(),
          Padding(
            padding: EdgeInsets.all(MonettaTokens.space[4]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contáctanos',
                  style: clientGuideStyle(context, MonettaTokens.screenTitle),
                ),
                SizedBox(height: MonettaTokens.space[1]),
                Text(
                  'Estamos para ayudarte',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[3]),
                _WhatsAppButton(
                  onTap: () => _open(context, whatsapp.uri),
                ),
                SizedBox(height: MonettaTokens.space[5]),
                Text(
                  'Únete',
                  style: clientGuideStyle(context, MonettaTokens.sectionTitle),
                ),
                SizedBox(height: MonettaTokens.space[1]),
                Text(
                  'A nuestros grupos de emprendedores',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[3]),
                for (final channel in groups) ...[
                  _ChannelRow(
                    channel: channel,
                    onTap: () => _open(context, channel.uri),
                  ),
                  SizedBox(height: MonettaTokens.space[1]),
                ],
                SizedBox(height: MonettaTokens.space[3]),
                Divider(color: palette.hairline),
                Text(
                  'Síguenos en redes',
                  style: clientGuideStyle(context, MonettaTokens.sectionTitle),
                ),
                SizedBox(height: MonettaTokens.space[1]),
                Text(
                  'Descubre novedades, lanzamientos y más.',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[3]),
                if (socials.isEmpty)
                  Text(
                    'Redes sociales: enlaces pendientes.',
                    style: clientGuideStyle(context, MonettaTokens.cardLabel),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final channel in socials)
                      _SocialIconButton(
                        channel: channel,
                        onTap: () => _open(context, channel.uri),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Photograph with the B31 title and description layered on the free side.
/// The copy is not a text block under the image, and it is not redrawn in
/// another font.
class _ContactHero extends StatelessWidget {
  const _ContactHero();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = MonettaTokens.gutterFor(width);
    final maxColumn = width > gutter ? width - gutter : 0.0;
    final preferred = width * 0.42;
    final columnWidth = preferred < maxColumn ? preferred : maxColumn;
    return Semantics(
      container: true,
      header: true,
      label: kContactHeroAccessibleLabel,
      child: SizedBox(
        key: const ValueKey('contact-hero'),
        height: guidePhotoHeroHeight(context),
        width: double.infinity,
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const GuideArt(
                asset: kGuideContactHero,
                alignment: Alignment(0.25, 0),
              ),
              Positioned(
                left: gutter,
                top: MonettaTokens.space[2],
                bottom: MonettaTokens.space[2],
                width: columnWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: columnWidth,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LetteringLayer(
                          asset: kContactLetteringTitle,
                          aspectRatio: _kLetteringTitleAspect,
                          layerKey: ValueKey('contact-hero-title'),
                        ),
                        SizedBox(height: 6),
                        _LetteringLayer(
                          asset: kContactLetteringDescription,
                          aspectRatio: _kLetteringDescriptionAspect,
                          layerKey: ValueKey('contact-hero-body'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LetteringLayer extends StatelessWidget {
  const _LetteringLayer({
    required this.asset,
    required this.aspectRatio,
    required this.layerKey,
  });

  final String asset;
  final double aspectRatio;
  final Key layerKey;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.asset(
        asset,
        key: layerKey,
        fit: BoxFit.fill,
        excludeFromSemantics: true,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// One control: the guide's WhatsApp mark and the concierge label on one
/// line at the body size. Opening it does not send the message.
class _WhatsAppButton extends StatelessWidget {
  const _WhatsAppButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final oneLine = scale <= 1.15;
    final label = Text(
      kContactWhatsAppLabel,
      key: const ValueKey('contact-whatsapp-label'),
      maxLines: oneLine ? 1 : null,
      softWrap: !oneLine,
      overflow: TextOverflow.visible,
      textAlign: TextAlign.center,
      style: clientGuideStyle(context, MonettaTokens.body),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('contact-channel-whatsapp'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(MonettaTokens.radiusPill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MonettaTokens.tapTarget),
          child: Row(
            children: [
              const _ChannelIcon(
                asset: kGuideIconContactWhatsApp,
                fallback: Icons.chat_outlined,
                size: 40,
              ),
              SizedBox(width: MonettaTokens.space[2]),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(
                      MonettaTokens.radiusPill,
                    ),
                    border: Border.all(color: palette.hairline),
                    boxShadow: [
                      BoxShadow(
                        color: palette.ink.withValues(alpha: 0.08),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MonettaTokens.space[3],
                      vertical: MonettaTokens.space[2],
                    ),
                    child: oneLine
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: label,
                          )
                        : label,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel, required this.onTap});

  final ContactChannel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Material(
      color: palette.surfaceDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MonettaTokens.radiusCard),
        side: BorderSide(color: palette.hairline),
      ),
      child: InkWell(
        key: ValueKey('contact-channel-${channel.key}'),
        borderRadius: BorderRadius.circular(MonettaTokens.radiusCard),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: MonettaTokens.controlHeight,
          ),
          child: Padding(
            padding: EdgeInsets.all(MonettaTokens.space[2]),
            child: Row(
              children: [
                _ChannelIcon(
                  asset: channel.iconAsset,
                  fallback: channel.icon,
                  size: 52,
                ),
                SizedBox(width: MonettaTokens.space[3]),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.title,
                        style: clientGuideStyle(
                          context,
                          MonettaTokens.accountRow,
                        ),
                      ),
                      SizedBox(height: MonettaTokens.space[0]),
                      Text(
                        channel.subtitle,
                        style: clientGuideStyle(
                          context,
                          MonettaTokens.navLabel,
                          color: palette.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: MonettaTokens.space[1]),
                Icon(
                  Icons.chevron_right,
                  size: MonettaTokens.logoHeight,
                  color: palette.goldText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gold line icon of the guide. A channel without artwork keeps a Material
/// glyph in the same gold.
class _ChannelIcon extends StatelessWidget {
  const _ChannelIcon({
    required this.asset,
    required this.fallback,
    required this.size,
  });

  final String? asset;
  final IconData fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(
      fallback,
      size: size * 0.6,
      color: context.boutique.goldText,
    );
    return SizedBox(
      width: size,
      height: size,
      child: asset == null
          ? Center(child: glyph)
          : Image.asset(
              asset!,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => Center(child: glyph),
            ),
    );
  }
}

/// A social network as a gold icon on its own, without text. The label is
/// for assistive technology only.
class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({required this.channel, required this.onTap});

  final ContactChannel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: channel.title,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: ValueKey('contact-channel-${channel.key}'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(MonettaTokens.space[1]),
          child: _ChannelIcon(
            asset: channel.iconAsset,
            fallback: channel.icon,
            size: 56,
          ),
        ),
      ),
    );
  }
}
