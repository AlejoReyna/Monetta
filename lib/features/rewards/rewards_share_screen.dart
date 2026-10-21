/// Client-guide catalog sharing (page 15).
///
/// Copy and share run only when a real link is supplied. The guide's sample
/// URLs are not a contract, so the default cards say the link is pending.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/account_controller.dart';
import '../../app/monetta_tokens.g.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';

const String kRewardsContractPlaceholder = 'Pendiente de contrato';

class RewardsCatalogLink {
  const RewardsCatalogLink({
    required this.id,
    required this.title,
    required this.icon,
    this.asset,
    this.url,
  });

  final String id;
  final String title;
  final IconData icon;
  final String? asset;

  /// Public catalog URL. Null until a contract provides one.
  final String? url;
}

const List<RewardsCatalogLink> kRewardsCatalogLinks = <RewardsCatalogLink>[
  RewardsCatalogLink(
    id: 'bags',
    title: 'Copiar enlace de catálogo de bolsos',
    icon: Icons.shopping_bag_outlined,
    asset: 'assets/images/home_collection_bags.webp',
  ),
  RewardsCatalogLink(
    id: 'perfumes',
    title: 'Copiar enlace de catálogo de perfumes',
    icon: Icons.water_drop_outlined,
  ),
];

class RewardsShareScreen extends StatelessWidget {
  const RewardsShareScreen({
    this.links = kRewardsCatalogLinks,
    this.accountController,
    this.onShare,
    super.key,
  });

  final List<RewardsCatalogLink> links;
  final AccountController? accountController;
  final Future<void> Function(String text)? onShare;

  Future<void> _copy(BuildContext context, RewardsCatalogLink link) async {
    final url = link.url;
    if (url == null || url.isEmpty) {
      _notify(context, 'Enlace pendiente de contrato');
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    _notify(context, 'Enlace copiado');
  }

  Future<void> _share(BuildContext context, RewardsCatalogLink link) async {
    final url = link.url;
    if (url == null || url.isEmpty) {
      _notify(context, 'Enlace pendiente de contrato');
      return;
    }
    final share = onShare;
    try {
      if (share != null) {
        await share(url);
      } else {
        await Share.share(url, subject: link.title);
      }
    } on Object {
      if (!context.mounted) return;
      _notify(context, 'No se pudo compartir el catálogo');
    }
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final width = MediaQuery.sizeOf(context).width;
    return ClientGuideScaffold(
      current: ClientGuideDestination.account,
      accountController: accountController,
      body: ListView(
        key: const ValueKey('rewards-share-scroll'),
        padding: EdgeInsets.fromLTRB(
          MonettaTokens.gutterFor(width),
          MonettaTokens.space[4],
          MonettaTokens.gutterFor(width),
          MonettaTokens.space[6],
        ),
        children: [
          Text(
            'Comparte y gana',
            style: clientGuideStyle(context, MonettaTokens.screenTitle),
          ),
          SizedBox(height: MonettaTokens.space[2]),
          Text(
            'Comparte el catálogo de Monetta y gana puntos por cada persona '
            'que lo vea o compre.',
            style: clientGuideStyle(
              context,
              MonettaTokens.body,
              color: palette.inkMuted,
            ),
          ),
          SizedBox(height: MonettaTokens.space[2]),
          Text(
            'Puntos por compartir: $kRewardsContractPlaceholder.',
            key: const ValueKey('rewards-share-placeholder'),
            style: clientGuideStyle(
              context,
              MonettaTokens.navLabel,
              color: palette.goldText,
            ),
          ),
          SizedBox(height: MonettaTokens.space[4]),
          for (final link in links) ...[
            _CatalogCard(
              link: link,
              onCopy: () => unawaited(_copy(context, link)),
              onShare: () => unawaited(_share(context, link)),
            ),
            SizedBox(height: MonettaTokens.space[3]),
          ],
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.link,
    required this.onCopy,
    required this.onShare,
  });

  final RewardsCatalogLink link;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final asset = link.asset;
    final url = link.url;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        border: Border.all(color: palette.hairline),
      ),
      child: Padding(
        padding: EdgeInsets.all(MonettaTokens.space[3]),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BoutiqueRadius.tile,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: asset == null
                        ? ColoredBox(
                            color: palette.surfaceDeep,
                            child: Icon(link.icon, color: palette.inkMuted),
                          )
                        : Image.asset(
                            asset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: palette.surfaceDeep,
                              child: Icon(link.icon, color: palette.inkMuted),
                            ),
                          ),
                  ),
                ),
                SizedBox(width: MonettaTokens.space[2]),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.title,
                        style:
                            clientGuideStyle(context, MonettaTokens.cardLabel),
                      ),
                      Text(
                        'Comparte esta colección.',
                        style: clientGuideStyle(
                          context,
                          MonettaTokens.navLabel,
                          color: palette.inkMuted,
                        ),
                      ),
                      if (asset == null)
                        Text(
                          'Imagen pendiente',
                          style: clientGuideStyle(
                            context,
                            MonettaTokens.navLabel,
                            color: palette.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('rewards-share-${link.id}'),
                  tooltip: 'Compartir enlace',
                  onPressed: onShare,
                  icon: Icon(Icons.share_outlined, color: palette.goldText),
                ),
              ],
            ),
            SizedBox(height: MonettaTokens.space[2]),
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BoutiqueRadius.control,
                border: Border.all(color: palette.hairline),
              ),
              child: Row(
                children: [
                  SizedBox(width: MonettaTokens.space[2]),
                  Expanded(
                    child: Text(
                      url == null || url.isEmpty
                          ? kRewardsContractPlaceholder
                          : url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.navLabel,
                        color: palette.inkMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('rewards-copy-${link.id}'),
                    tooltip: 'Copiar enlace',
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
