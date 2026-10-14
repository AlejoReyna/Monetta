/// Contacto (paquete E): canales configurados y enlaces funcionales.
///
/// Solo canales verificados en el repositorio:
/// - WhatsApp conserjería y mayoreo ([conciergeWhatsAppUri],
///   [wholesaleWhatsAppUri], número `826 106 6868`).
/// - Sitio de contacto `https://monetta.mx/pages/contact` (ya referenciado en
///   el partner hub).
/// - Redes configuradas en [HomeContent.fallback] (Instagram, TikTok,
///   Facebook con URLs reales).
///
/// La lámina dibuja además un correo y un teléfono de voz con cifras
/// ilustrativas; no hay un buzón ni una línea de voz verificados en código o
/// configuración, así que no se renderizan. Ver `PAQUETE_E_ENTREGA.md`.
library;

import 'package:flutter/material.dart';

import '../navigation/monetta_page_header.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/shopper_copy.dart';
import '../../domain/home_content.dart';
import '../account/account_boutique.dart';
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
    ContactChannel(
      key: 'mayoreo',
      icon: Icons.storefront_outlined,
      title: 'Mayoreo por WhatsApp',
      subtitle: 'Desde 3 piezas',
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
    final ok = await open(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final channels = monettaContactChannels(socialLinks: socialLinks);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: buildMonettaPageAppBar(
        context,
        title: 'Contacto',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const AccountPageHeader(
              kicker: 'Ayuda',
              title: 'Contáctanos',
              subtitle: 'Estamos para ayudarte a elegir tu próxima pieza.',
            ),
            const SizedBox(height: BoutiqueSpace.lg),
            ECard(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              children: [
                for (final channel in channels)
                  _ChannelRow(
                    channel: channel,
                    onTap: () => _open(context, channel.uri),
                  ),
              ],
            ),
            const SizedBox(height: BoutiqueSpace.lg),
            Text(
              'Horario y tiempos de respuesta se confirman por WhatsApp. '
              'Nunca te pediremos contraseñas ni códigos por estos canales.',
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
          ],
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
    return Semantics(
      button: true,
      label: '${channel.title}. ${channel.subtitle}',
      child: InkWell(
        key: ValueKey('contact-channel-${channel.key}'),
        onTap: onTap,
        borderRadius: BoutiqueRadius.control,
        child: Container(
          constraints:
              const BoxConstraints(minHeight: BoutiqueSpace.tapTarget + 8),
          padding: const EdgeInsets.symmetric(vertical: BoutiqueSpace.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: palette.hairline, width: .5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.ink,
                ),
                child: Icon(channel.icon, size: 20, color: palette.canvas),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.title,
                      style: boutiqueText(
                        size: 14,
                        weight: FontWeight.w500,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      channel.subtitle,
                      style: boutiqueText(
                        size: 12,
                        color: palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: palette.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
