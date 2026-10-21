library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../../domain/home_content.dart';
import '../../main.dart';
import '../../app/monetta_tokens.g.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import '../boutique/client_guide_sections.dart';
import 'contact_links.dart';
import '../boutique/boutique_tokens.dart';

/// Contacto web verificado (partner hub lo usa como "contacto").
final Uri kMonettaContactPageUri =
    Uri.parse('https://monetta.mx/pages/contact');

class ContactChannel {
  const ContactChannel({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.uri,
  });

  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  final Uri uri;
}

/// Canales reales de la app. [socialLinks] permite a un propietario
/// sobreescribir las redes (p. ej. desde Shopify); por defecto, las
/// configuradas en el contenido editorial.
List<ContactChannel> monettaContactChannels({
  List<HomeSocialLink>? socialLinks,
}) {
  final socials = socialLinks ?? HomeContent.fallback.socialLinks;
  return [
    ContactChannel(
      key: 'whatsapp',
      icon: Icons.chat_outlined,
      title: 'WhatsApp',
      subtitle: kWhatsAppNumberDisplay,
      uri: conciergeWhatsAppUri(),
    ),
    for (var i = 0; i < monettaWhatsAppGroups.length; i++)
      ContactChannel(
        key: 'grupo-${i + 1}',
        icon: Icons.groups_outlined,
        title: 'Grupo ${i + 1}',
        subtitle: 'Únete a nuestro grupo de WhatsApp',
        uri: Uri.parse(monettaWhatsAppGroups[i]),
      ),
    ContactChannel(
      key: 'facebook-group',
      icon: Icons.facebook,
      title: 'Grupo de Facebook',
      subtitle: 'Únete a nuestra comunidad',
      uri: Uri.parse(monettaFacebookGroup),
    ),
    ContactChannel(
      key: 'mayoreo',
      icon: Icons.storefront_outlined,
      title: 'Mayoreo por WhatsApp',
      subtitle: 'Consulta las condiciones vigentes',
      uri: wholesaleWhatsAppUri(),
    ),
    ContactChannel(
      key: 'sitio',
      icon: Icons.language_rounded,
      title: 'Contacto en monetta.mx',
      subtitle: 'Formulario y datos del sitio',
      uri: kMonettaContactPageUri,
    ),
    for (final link in socials)
      if (link.uri != null)
        ContactChannel(
          key: 'social-${link.id}',
          icon: _socialIcon(link.id),
          title: link.label,
          subtitle: 'Síguenos',
          uri: link.uri!,
        ),
  ];
}

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
    super.key,
  });

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
      socialLinks:
          socialLinks ?? HomeContentScope.maybeOf(context)?.content.socialLinks,
    );
    final primary = channels.where(
      (c) =>
          c.key == 'whatsapp' ||
          c.key.startsWith('grupo-') ||
          c.key == 'facebook-group',
    );
    final socials = channels.where((c) => c.key.startsWith('social-'));
    final secondary =
        channels.where((c) => c.key == 'mayoreo' || c.key == 'sitio');
    return ClientGuideScaffold(
      current: null,
      body: ListView(
        key: const ValueKey('contact-scroll'),
        padding: EdgeInsets.zero,
        children: [
          const ClientGuideEditorial(
            title: 'Tu boutique y proveedor de confianza.',
            subtitle:
                'Descubre nuestras marcas favoritas. Estamos para ayudarte.',
            imageAsset: 'assets/images/home_bag_shoulder.webp',
          ),
          Padding(
            padding: EdgeInsets.all(MonettaTokens.space[4]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contáctanos',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.screenTitle,
                  ),
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
                for (final channel in primary) ...[
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
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.sectionTitle,
                  ),
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
                    style: clientGuideStyle(
                      context,
                      MonettaTokens.cardLabel,
                    ),
                  ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: MonettaTokens.space[2],
                  runSpacing: MonettaTokens.space[2],
                  children: [
                    for (final channel in socials)
                      TextButton.icon(
                        key: ValueKey(
                          'contact-channel-${channel.key}',
                        ),
                        onPressed: () => _open(context, channel.uri),
                        icon: Icon(
                          channel.icon,
                          size: MonettaTokens.logoHeight,
                        ),
                        label: Text(
                          channel.title,
                          style: clientGuideStyle(
                            context,
                            MonettaTokens.cardLabel,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: MonettaTokens.space[4]),
                Text(
                  'Más ayuda',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.sectionTitle,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[2]),
                for (final channel in secondary) ...[
                  _ChannelRow(
                    channel: channel,
                    onTap: () => _open(context, channel.uri),
                  ),
                  SizedBox(height: MonettaTokens.space[1]),
                ],
                SizedBox(height: MonettaTokens.space[3]),
                Text(
                  'Horario, correo y teléfono de voz: pendientes de confirmación.',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.cardLabel,
                    color: palette.inkMuted,
                  ),
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
          constraints:
              const BoxConstraints(minHeight: MonettaTokens.controlHeight),
          child: Padding(
            padding: EdgeInsets.all(MonettaTokens.space[2]),
            child: Row(
              children: [
                CircleAvatar(
                  radius: MonettaTokens.space[4],
                  backgroundColor: palette.action,
                  child: Icon(
                    channel.icon,
                    size: MonettaTokens.logoHeight,
                    color: palette.onAction,
                  ),
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
