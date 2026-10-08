/// Confirmación de añadido: sheet, no toast, no ruta nueva.
library;

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
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
    final remaining = remainingForFreeShipping(store.bagSubtotal);
    final last = lines.isEmpty ? null : lines.last;
    final count = store.bagQuantity;

    return SafeArea(
      child: Material(
        type: MaterialType.transparency,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            border: Border(
              top: BorderSide(color: palette.hairline, width: .5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: palette.hairline,
                      borderRadius: BoutiqueRadius.capsule,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.gold, width: 1.2),
                      ),
                      child: Icon(Icons.check, size: 16, color: palette.gold),
                    ),
                    const SizedBox(width: 12),
                    // Both sides may wrap at large text scales instead of
                    // overflowing the row; the count stays on the right edge.
                    Flexible(
                      flex: 2,
                      child: Text('En tu bolsa', style: boutiqueDisplay(22)),
                    ),
                    Expanded(
                      child: Text(
                        '$count ${count == 1 ? 'artículo' : 'artículos'}',
                        textAlign: TextAlign.end,
                        style: boutiqueText(size: 12, color: palette.inkMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    remaining == 0
                        ? 'Envío gratis en este pedido.'
                        : 'Envío gratis desde ${kMoney.format(kFreeShippingThreshold)} · te faltan ${kMoney.format(remaining)}',
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BoutiqueRadius.capsule,
                  child: LinearProgressIndicator(
                    value: (subtotal / kFreeShippingThreshold)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    minHeight: 5,
                    backgroundColor: palette.surfaceDeep,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remaining == 0 ? palette.gold : palette.ink,
                    ),
                  ),
                ),
                if (last != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BoutiqueRadius.tile,
                        child: SizedBox(
                          width: 64,
                          height: 78,
                          child: ColoredBox(
                            color: palette.surfaceDeep,
                            child: MonettaImage(
                              url: last.product.primaryImage,
                              cacheWidth: MediaUrl.thumbWidth,
                              fallbackLabel: last.product.title,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              last.product.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: boutiqueText(
                                size: 13,
                                weight: FontWeight.w500,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cantidad ${last.quantity}',
                              style: boutiqueText(
                                size: 11,
                                color: palette.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              kMoney.format(last.lineTotal),
                              style: boutiqueText(
                                size: 13,
                                weight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Subtotal',
                          style: boutiqueText(
                            size: 13,
                            color: palette.inkMuted,
                          ),
                        ),
                      ),
                      Text(
                        kMoney.format(subtotal),
                        style: boutiqueText(
                          size: 14,
                          weight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    'Tu bolsa está vacía.',
                    style: boutiqueText(size: 13, color: palette.inkMuted),
                  ),
                ],
                const SizedBox(height: 20),
                BoutiqueButton(
                  label: 'VER BOLSA',
                  onPressed: () {
                    Navigator.of(context).pop();
                    openBag(context);
                  },
                ),
                const SizedBox(height: 6),
                Center(
                  child: Semantics(
                    button: true,
                    label: 'Seguir viendo',
                    child: Material(
                      type: MaterialType.transparency,
                      borderRadius: BoutiqueRadius.capsule,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BoutiqueRadius.capsule,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 48),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Seguir viendo',
                                style: boutiqueText(
                                  size: 13,
                                  color: palette.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                height: .8,
                                width: 84,
                                color: palette.ink,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
