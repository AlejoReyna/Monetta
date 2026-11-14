library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../../domain/home_content.dart';
import '../../app/monetta_tokens.g.dart';
import '../../app/theme.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import '../boutique/guide_art.dart';
import '../boutique/boutique_tokens.dart';

/// Contacto web verificado (partner hub lo usa como "contacto").
final Uri kMonettaContactPageUri = Uri.parse(
  'https://monetta.mx/pages/contact',
);

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

/// Only explicit configured community and social bindings are presented.
List<ContactChannel> monettaContactChannels({
  List<HomeSocialLink>? socialLinks,
  Map<String, Uri> groups = const {},
}) {
  final socials = socialLinks ?? const <HomeSocialLink>[];
  bool safe(Uri? uri) =>
      uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
  return [
    ContactChannel(
      key: 'whatsapp',
      icon: Icons.chat_outlined,
      iconAsset: kGuideIconContactWhatsApp,
      title: 'Enviar Whatsapp al 826 106 6868',
      // The guide shows the number with its country code.
      subtitle: '+52 $kWhatsAppNumberDisplay',
      uri: Uri.https('wa.me', '/$kWhatsAppE164'),
    ),
    for (final entry in const [
      ('grupo-1', 'Grupo 1'),
      ('grupo-2', 'Grupo 2'),
      ('facebook-group', 'Grupo de Facebook')
    ])
      if (safe(groups[entry.$1]))
        ContactChannel(
            key: entry.$1,
            icon: Icons.groups_outlined,
            iconAsset: kGuideIconContactGroup,
            title: entry.$2,
            subtitle: entry.$1 == 'facebook-group'
                ? 'Únete a nuestra comunidad'
                : 'Únete a nuestro grupo de WhatsApp',
            uri: groups[entry.$1]!),
    for (final link in socials)
      if (safe(link.uri))
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
  Map<String, Uri> groups = const {},
  Future<bool> Function(Uri uri)? openUri,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ContactScreen(
          socialLinks: socialLinks, groups: groups, openUri: openUri),
    ),
  );
}

class ContactScreen extends StatelessWidget {
  const ContactScreen(
      {this.socialLinks, this.groups = const {}, this.openUri, super.key});
  final Map<String, Uri> groups;

  final List<HomeSocialLink>? socialLinks;

  /// Inyectable para pruebas; por defecto abre la app externa real.
  final Future<bool> Function(Uri uri)? openUri;

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
      socialLinks: socialLinks,
      groups: groups,
    );
    final primary = channels.where(
      (c) =>
          c.key == 'whatsapp' ||
          c.key.startsWith('grupo-') ||
          c.key == 'facebook-group',
    );
    // The guide lists Instagram, Facebook and TikTok, in that order.
    const socialOrder = ['instagram', 'facebook', 'tiktok'];
    int socialRank(ContactChannel c) {
      final index = socialOrder.indexOf(c.key.substring('social-'.length));
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
          GuideHero(
            asset: kGuideContactHero,
            imageAlignment: const Alignment(0.25, 0),
            textWidthFactor: 0.52,
            height: guidePhotoHeroHeight(context),
            titleSize: (MediaQuery.sizeOf(context).width * 0.075).clamp(
              24.0,
              40.0,
            ),
            subtitleSize: (MediaQuery.sizeOf(context).width * 0.032).clamp(
              11.0,
              16.0,
            ),
            title: 'Tu boutique y proveedor de',
            titleAccent: 'confianza.',
            subtitle:
                'Bienvenida a nuestro paraíso de modelos originales de marcas que amas, importados y con envíos garantizados a todo México.',
          ),
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
                for (final channel in primary.where((c) => c.key == 'whatsapp'))
                  Row(children: [
                    SvgPicture.asset('assets/images/v41/icons/whatsapp.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                            MonettaTokens.success, BlendMode.srcIn),
                        excludeFromSemantics: true),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Theme(
                          data: buildLightTheme(),
                          child: GuideGlassSurface(
                            child: OutlinedButton(
                              key: const ValueKey('contact-channel-whatsapp'),
                              onPressed: () => _open(context, channel.uri),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 12),
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                                textStyle: clientGuideStyle(
                                        context, MonettaTokens.control)
                                    .copyWith(fontSize: 12),
                              ),
                              child: Text(channel.title,
                                  textAlign: TextAlign.center),
                            ),
                          )),
                    ),
                  ]),
                const SizedBox(height: 24),
                Text('Únete',
                    style:
                        clientGuideStyle(context, MonettaTokens.sectionTitle)),
                Text('A nuestros grupos de emprendedores',
                    style: clientGuideStyle(context, MonettaTokens.body)),
                const SizedBox(height: 16),
                for (final channel
                    in primary.where((c) => c.key != 'whatsapp')) ...[
                  _ChannelRow(
                      channel: channel,
                      onTap: () => _open(context, channel.uri)),
                  const SizedBox(height: 8),
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
                  size:
                      MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 32 : 52,
                ),
                SizedBox(width: MonettaTokens.space[1]),
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
