/// Add-to-bag stays on the product. A sheet, not a toast, not a new route.
library;

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/media/media_url.dart';
import '../../main.dart';
import 'checkout_screen.dart';

Future<void> showMiniCart(BuildContext context) {
  final store = StoreScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => StoreScope(
      notifier: store,
      child: const MiniCartSheet(),
    ),
  );
}

class MiniCartSheet extends StatelessWidget {
  const MiniCartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lines = store.bagLines;
    final remaining = remainingForFreeShipping(store.bagSubtotal);
    final last = lines.isEmpty ? null : lines.last;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 2,
                color: kLine,
              ),
            ),
            const SizedBox(height: 22),
            Text('En tu bolsa', style: display(24)),
            const SizedBox(height: 6),
            Text(
              remaining == 0
                  ? 'Envío gratis en este pedido.'
                  : 'Envío gratis desde ${kMoney.format(kFreeShippingThreshold)} · te faltan ${kMoney.format(remaining)}',
              style: sans(size: 12.5, color: kInkMuted),
            ),
            if (last != null) ...[
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    height: 88,
                    child: MonettaImage(
                      url: last.product.primaryImage,
                      cacheWidth: MediaUrl.thumbWidth,
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
                          style: sans(size: 13.5, weight: FontWeight.w500),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          kMoney.format(last.lineTotal),
                          style: sans(size: 13, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                openBag(context);
              },
              child: const Text('VER BOLSA'),
            ),
            const SizedBox(height: 12),
            Center(
              child: UnderlineLink(
                label: 'Seguir viendo',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
