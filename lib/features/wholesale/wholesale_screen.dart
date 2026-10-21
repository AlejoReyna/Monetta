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
      final ok = await (openUri ??
          ((uri) => launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              )))(wholesaleQuoteUri());
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
            queryTerms:
                category == 'bolsa' ? const ['bolsa', 'cartera'] : const [],
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
          const ClientGuideEditorial(
            title: 'MAYOREO',
            subtitle:
                'Descubre productos de tus marcas favoritas para tu negocio.',
            imageAsset: 'assets/images/home_collection_bags.webp',
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
                    final columns =
                        MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 3;
                    final gap = MonettaTokens.space[1];
                    const steps = [
                      (
                        Icons.shopping_bag_outlined,
                        'Elige tus productos',
                        'Explora bolsas, carteras y perfumes.'
                      ),
                      (
                        Icons.shopping_cart_outlined,
                        'Consulta el mínimo',
                        WholesalePresentation.minimum
                      ),
                      (
                        Icons.credit_card_outlined,
                        'Liquida o aparta',
                        WholesalePresentation.reservation
                      ),
                    ];
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var i = 0; i < steps.length; i++)
                          SizedBox(
                            width:
                                (constraints.maxWidth - gap * (columns - 1)) /
                                    columns,
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
                    );
                  },
                ),
                SizedBox(height: MonettaTokens.space[3]),
                Text(
                  WholesalePresentation.pricing,
                  style: clientGuideStyle(context, MonettaTokens.cardLabel),
                ),
              ],
            ),
          ),
          for (final category in ['bolsa', 'perfume']) ...[
            Padding(
              padding: EdgeInsets.all(MonettaTokens.space[2]),
              child: ClientGuideEditorial(
                title: category == 'bolsa' ? 'BOLSAS Y CARTERAS' : 'PERFUMES',
                subtitle: category == 'bolsa'
                    ? 'Explora nuestro catálogo.'
                    : 'Descubre nuestra selección de fragancias.',
                imageAsset: category == 'bolsa'
                    ? 'assets/images/home_bag_crossbody.webp'
                    : null,
                action: ClientGuideButton(
                  key: ValueKey('wholesale-catalog-$category'),
                  label: 'VER CATÁLOGO',
                  chevron: true,
                  onPressed: store == null
                      ? null
                      : () => _catalog(context, category: category),
                ),
              ),
            ),
          ],
          const ClientGuideServices(),
          Padding(
            padding: EdgeInsets.all(MonettaTokens.space[4]),
            child: Text(
              WholesalePresentation.shipping,
              style: clientGuideStyle(
                context,
                MonettaTokens.cardLabel,
                color: palette.inkMuted,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(MonettaTokens.space[3]),
            child: ClientGuideEditorial(
              title: '¿Tienes dudas?',
              subtitle: 'Escríbenos por WhatsApp',
              imageAsset: 'assets/images/home_bag_shoulder.webp',
              action: ClientGuideButton(
                key: const ValueKey('wholesale-quote-bottom'),
                label: 'ESCRÍBENOS',
                chevron: true,
                onPressed: () => unawaited(_quote(context)),
              ),
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
                  content: (EditorialContentScope.maybeOf(context)?.content ??
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
