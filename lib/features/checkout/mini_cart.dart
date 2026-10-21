/// Confirmación de añadido: sheet, no toast, no ruta nueva.
library;

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/monetta_tokens.g.dart';
import '../boutique/client_guide_components.dart';
import 'purchase_notices.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../main.dart';
import '../boutique/boutique_tokens.dart';
import 'checkout_screen.dart';

Future<void> showMiniCart(BuildContext context) {
  final store = StoreScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => StoreScope(
      notifier: store,
      child: const MiniCartSheet(),
    ),
  );
}

class MiniCartSheet extends StatelessWidget {
  const MiniCartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final store = StoreScope.of(context);
    final lines = store.bagLines;
    final subtotal = store.bagSubtotal;
    final last = lines.isEmpty ? null : lines.last;
    final count = store.bagQuantity;
    return Material(
      color: palette.canvas,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(MonettaTokens.radiusSheet),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(
            MonettaTokens.gutterFor(MediaQuery.sizeOf(context).width),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: palette.goldText,
                    size: MonettaTokens.logoHeight,
                  ),
                  SizedBox(width: MonettaTokens.space[2]),
                  Expanded(
                    child: Text(
                      'En tu bolsa',
                      style: clientGuideStyle(
                        context,
                        MonettaTokens.sectionTitle,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  '$count ${count == 1 ? 'artículo' : 'artículos'}',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.cardLabel,
                    color: palette.inkMuted,
                  ),
                ),
              ),
              SizedBox(height: MonettaTokens.space[3]),
              if (last != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BoutiqueRadius.tile,
                      child: SizedBox(
                        width: MonettaTokens.space[7],
                        height: MonettaTokens.space[7],
                        child: MonettaImage(
                          url: last.product.primaryImage,
                          cacheWidth: MediaUrl.thumbWidth,
                          fallbackLabel: last.product.title,
                        ),
                      ),
                    ),
                    SizedBox(width: MonettaTokens.space[3]),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            last.product.title,
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.cardLabel,
                            ),
                          ),
                          SizedBox(height: MonettaTokens.space[1]),
                          Text(
                            'Cantidad ${last.quantity}',
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.cardLabel,
                              color: palette.inkMuted,
                            ),
                          ),
                          SizedBox(height: MonettaTokens.space[1]),
                          Text(
                            kMoney.format(last.lineTotal),
                            style: clientGuideStyle(
                              context,
                              MonettaTokens.price,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MonettaTokens.space[3]),
                const Divider(),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: MonettaTokens.space[3],
                  children: [
                    Text(
                      'Subtotal',
                      style: clientGuideStyle(context, MonettaTokens.body),
                    ),
                    Text(
                      kMoney.format(subtotal),
                      style: clientGuideStyle(context, MonettaTokens.price),
                    ),
                  ],
                ),
              ] else
                Text(
                  'Tu bolsa está vacía.',
                  style: clientGuideStyle(context, MonettaTokens.body),
                ),
              SizedBox(height: MonettaTokens.space[3]),
              const PurchasePolicyNotice(),
              SizedBox(height: MonettaTokens.space[4]),
              ClientGuideButton(
                label: 'VER BOLSA',
                chevron: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  openBag(context);
                },
              ),
              SizedBox(height: MonettaTokens.space[1]),
              ClientGuideButton(
                label: 'Seguir viendo',
                outlined: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
