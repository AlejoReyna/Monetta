/// Mayoreo and its continuation (client guide pages 10–11).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/monetta_tokens.g.dart';
import '../../domain/editorial_content.dart';
import '../../main.dart';
import '../about/about_monetta_screen.dart';
import '../account/account_screen.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import '../boutique/client_guide_sections.dart';
import '../boutique/guide_art.dart';
import '../catalog/collection_screen.dart';
import '../contact/contact_screen.dart';
import '../home/home_account_invitation.dart';
import '../home/home_boutique_sections.dart';
import 'wholesale_content.dart';

class WholesaleScreen extends StatelessWidget {
  const WholesaleScreen({this.openUri, super.key});
  final Future<bool> Function(Uri)? openUri;

  Future<void> _quote(BuildContext context) async {
    try {
      final ok =
          await (openUri ??
              ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)))(
            wholesaleQuoteUri(),
          );
      if (ok || !context.mounted) return;
    } on Exception {
      if (!context.mounted) return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp. Intenta de nuevo.'),
        ),
      );
    }
  }

  void _catalog(BuildContext context, {String? category}) => openCollection(
    context,
    CollectionScreen(
      title: category == 'perfume'
          ? 'Perfumes'
          : category == 'bolsa'
          ? 'Bolsas y carteras'
          : 'Catálogo',
      filter: CollectionFilter(
        queryTerms: category == 'bolsa' ? const ['bolsa', 'cartera'] : const [],
        category: category == 'perfume' ? category : null,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.maybeOf(context);
    final account = AccountScope.maybeOf(context);
    final palette = context.boutique;
    return ClientGuideScaffold(
      current: null,
      body: ListView(
        key: const ValueKey('wholesale-scroll'),
        padding: EdgeInsets.zero,
        children: [
          GuideHero(
            asset: kGuideWholesaleHero,
            title: 'MAYOREO',
            titleItalic: true,
            titleSize: (MediaQuery.sizeOf(context).width * 0.115).clamp(
              36.0,
              64.0,
            ),
            subtitle: 'Obtén precios especiales en productos originales importados de tus',
            subtitleAccent: 'marcas favoritas',
            imageAlignment: const Alignment(0.5, 0),
            textWidthFactor: 0.55,
            subtitleWidthFactor: 0.46,
            height: guidePhotoHeroHeight(context),
          ),
          Padding(
            padding: EdgeInsets.all(MonettaTokens.space[4]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Cómo comprar?',
                  style: clientGuideStyle(context, MonettaTokens.sectionTitle),
                ),
                SizedBox(height: MonettaTokens.space[3]),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = 3;
                    final gap = MonettaTokens.space[1];
                    const steps = [
                      (
                        Icons.shopping_bag_outlined,
                        'Elige tus productos',
                        'Bolsas, carteras y perfumes.',
                      ),
                      (
                        Icons.shopping_cart_outlined,
                        'Agrega tus piezas',
                        WholesalePresentation.minimum,
                      ),
                      (
                        Icons.credit_card_outlined,
                        'Consulta las opciones de pago',
                        WholesalePresentation.reservation,
                      ),
                    ];
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < steps.length; i++)
                            SizedBox(
                              width:
                                  ((constraints.maxWidth -
                                              gap * (columns - 1)) /
                                          columns)
                                      .clamp(220.0, 360.0),
                              child: Container(
                                padding: EdgeInsets.all(MonettaTokens.space[2]),
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  borderRadius: BorderRadius.circular(
                                    MonettaTokens.radiusCard,
                                  ),
                                  border: Border.all(color: palette.hairline),
                                ),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: MonettaTokens.space[2],
                                      backgroundColor: palette.action,
                                      child: Text(
                                        '${i + 1}',
                                        style: clientGuideStyle(
                                          context,
                                          MonettaTokens.navLabel,
                                          color: palette.onAction,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: MonettaTokens.space[2]),
                                    Icon(
                                      steps[i].$1,
                                      size: MonettaTokens.space[5],
                                      color: palette.goldText,
                                    ),
                                    SizedBox(height: MonettaTokens.space[2]),
                                    Text(
                                      steps[i].$2,
                                      textAlign: TextAlign.center,
                                      style: clientGuideStyle(
                                        context,
                                        MonettaTokens.accountRow,
                                      ),
                                    ),
                                    SizedBox(height: MonettaTokens.space[1]),
                                    Text(
                                      steps[i].$3,
                                      textAlign: TextAlign.center,
                                      style: clientGuideStyle(
                                        context,
                                        MonettaTokens.navLabel,
                                        color: palette.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          for (final category in ['bolsa', 'perfume']) ...[
            ClientGuideEditorial(
              title: category == 'bolsa' ? 'BOLSOS Y CARTERAS' : 'PERFUMES',
              subtitle: category == 'bolsa'
                  ? 'Explora nuestro catálogo de mayoreo'
                  : 'Descubre nuestra selección de fragancias originales',
              imageAsset: category == 'bolsa'
                  ? kGuideWholesaleBags
                  : kGuideWholesalePerfumes,
              overlaySide: GuideTextSide.left,
              action: GuidePillButton(
                key: ValueKey('wholesale-catalog-$category'),
                label: 'VER CATÁLOGO',
                onPressed: store == null
                    ? null
                    : () => _catalog(context, category: category),
              ),
            ),
          ],
          ClientGuideServices(services: kClientGuideWholesaleServices),
          Padding(
            padding: EdgeInsets.all(MonettaTokens.space[3]),
            child: _WholesaleQuoteBanner(
              key: const ValueKey('wholesale-quote-bottom'),
              onTap: () => unawaited(_quote(context)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(MonettaTokens.space[3]),
            child: Text(
              'Precios del catálogo de menudeo; cotización de mayoreo pendiente.',
              style: clientGuideStyle(
                context,
                MonettaTokens.navLabel,
                color: palette.inkMuted,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: MonettaTokens.space[4]),
            child: store == null || store.products.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(MonettaTokens.space[4]),
                    child: Text(
                      'Productos que te pueden interesar · Catálogo no disponible por ahora.',
                      style: clientGuideStyle(context, MonettaTokens.body),
                    ),
                  )
                : HomeNewArrivalsRail(
                    products: store.products.take(6).toList(),
                    title: 'Productos que te pueden interesar',
                    onOpenAll: () => _catalog(context),
                  ),
          ),
          HomeAccountInvitation(
            isSignedIn: account?.isSignedIn ?? false,
            onRegister: account == null
                ? null
                : () => unawaited(openAccount(context, controller: account)),
          ),
          ClientGuideFooter(
            onContact: () => unawaited(openContact(context)),
            onAbout: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AboutMonettaScreen(
                  content:
                      (EditorialContentScope.maybeOf(context)?.content ??
                              MonettaEditorialContent.fallback)
                          .about,
                  onOpenCatalog: () => _catalog(context),
                  onOpenPartner: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «¿Tienes dudas? / Escríbenos por WhatsApp»: the WhatsApp mark on the left,
/// the owner's photograph on the right and a chevron. The whole banner opens
/// WhatsApp.
class _WholesaleQuoteBanner extends StatelessWidget {
  const _WholesaleQuoteBanner({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: '¿Tienes dudas? Escríbenos por WhatsApp',
      excludeSemantics: true,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BoutiqueRadius.card,
        child: Stack(
          children: [
            const Positioned.fill(
              child: GuideArt(
                asset: kGuideWholesaleBags,
                alignment: Alignment.centerRight,
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xF2FBF6EE),
                        Color(0xE6FBF6EE),
                        Color(0x00FBF6EE),
                      ],
                      stops: [0, 0.5, 0.82],
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 96),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MonettaTokens.space[3],
                      vertical: MonettaTokens.space[2],
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          kGuideIconContactWhatsApp,
                          height: 48,
                          width: 48,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.square(dimension: 48),
                        ),
                        SizedBox(width: MonettaTokens.space[2]),
                        Container(
                          width: 1,
                          height: 44,
                          color: palette.gold.withValues(alpha: 0.6),
                        ),
                        SizedBox(width: MonettaTokens.space[2]),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '¿Tienes dudas?',
                                style: clientGuideStyle(
                                  context,
                                  MonettaTokens.sectionTitle,
                                ).copyWith(fontStyle: FontStyle.italic),
                              ),
                              Text(
                                'Escríbenos por WhatsApp',
                                style: clientGuideStyle(
                                  context,
                                  MonettaTokens.body,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.canvas.withValues(alpha: 0.85),
                          ),
                          child: Icon(
                            Icons.chevron_right,
                            color: palette.ink,
                            size: MonettaTokens.space[4],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
