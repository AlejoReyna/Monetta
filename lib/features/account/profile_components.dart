import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/theme.dart';
import '../../data/local/database.dart' show OrderSummary;
import '../../domain/product.dart';
import '../boutique/boutique_tokens.dart';
import '../orders/order_status.dart';
import 'account_boutique.dart';

class ProfileSectionHeading extends StatelessWidget {
  const ProfileSectionHeading({required this.title, this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: boutiqueTitle(size: 20, weight: FontWeight.w500),
              ),
            ),
            if (action case final action?) ...[
              const SizedBox(width: 12),
              action,
            ],
          ],
        ),
      );
}

class ProfileQuickAccess extends StatelessWidget {
  const ProfileQuickAccess({
    required this.title,
    required this.icon,
    required this.count,
    required this.unit,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final String count;
  final String unit;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Material(
      color: palette.canvas,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        Text(title, style: boutiqueText(size: 15, height: 1.3)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 19, color: palette.ink),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(count, style: boutiqueText(size: 30, height: 1.1)),
                  Text(
                    unit,
                    style: boutiqueText(size: 12, color: palette.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: boutiqueText(size: 12, color: palette.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileLatestOrder extends StatelessWidget {
  const ProfileLatestOrder({
    required this.order,
    required this.onTap,
    super.key,
  });

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = orderDisplayStatus(order);
    final title = switch (status.key) {
      'in_transit' || 'partial' => 'Algo especial\nva hacia ti.',
      'delivered' => 'Una pieza más\nen tu historia.',
      'apartado' => 'Algo especial,\napartado para ti.',
      'adjusted' => 'El detalle de\ntu compra.',
      _ => 'Tu próxima pieza,\nen preparación.',
    };
    return Container(
      key: const ValueKey('profile-latest-order'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark ? palette.surfaceDeep : const Color(0xFFF1E9DB),
        borderRadius: BorderRadius.circular(26),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showArt = constraints.maxWidth >= 270 &&
              MediaQuery.textScalerOf(context).scale(14) < 21;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EStatusCapsule.forOrderKey(status.key, label: status.label),
                    const SizedBox(height: 14),
                    Text(title, style: boutiqueDisplay(27, color: palette.ink)),
                    const SizedBox(height: 10),
                    Text(
                      orderLabelOf(order),
                      style: boutiqueText(size: 13, color: palette.inkMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${orderDateLabel(order.placedAt)} · '
                      '${order.currencyCode == 'MXN' ? kMoney.format(order.totalAmount) : '${order.totalAmount.toStringAsFixed(2)} ${order.currencyCode}'}',
                      style: boutiqueText(size: 12, color: palette.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('profile-open-latest-order'),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.ink,
                        foregroundColor: palette.canvas,
                        minimumSize: const Size(0, 48),
                        textStyle:
                            boutiqueText(size: 12, weight: FontWeight.w500),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: onTap,
                      child: const Text('Ver pedido'),
                    ),
                  ],
                ),
              ),
              if (showArt) ...[
                const SizedBox(width: 8),
                ExcludeSemantics(
                  child: Transform.rotate(
                    angle: -.12,
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 90,
                      color: palette.gold.withValues(alpha: .5),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class ProfileFavoritesFeature extends StatelessWidget {
  const ProfileFavoritesFeature({
    required this.count,
    required this.product,
    required this.onTap,
    super.key,
  });

  final int count;
  final Product? product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('profile-favorites-feature'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark ? palette.surfaceDeep : const Color(0xFFEAF0E4),
        borderRadius: BorderRadius.circular(26),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showArt = constraints.maxWidth >= 270 &&
              MediaQuery.textScalerOf(context).scale(14) < 21;
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TU SELECCIÓN PERSONAL',
                      style: boutiqueEyebrow(size: 10, color: palette.inkMuted),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      count == 0
                          ? 'Encuentra tu\npróxima favorita.'
                          : 'Tu próxima\nfavorita.',
                      style: boutiqueDisplay(27, color: palette.ink),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      count == 0
                          ? 'Guarda las piezas que te encantan.'
                          : 'Esas piezas que te encantan.',
                      style: boutiqueText(size: 12, color: palette.inkMuted),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.ink,
                        side: BorderSide(
                          color: palette.inkMuted.withValues(alpha: .4),
                        ),
                        minimumSize: const Size(0, 48),
                        textStyle:
                            boutiqueText(size: 12, weight: FontWeight.w500),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: onTap,
                      child: const Text('Ver favoritos'),
                    ),
                  ],
                ),
              ),
              if (showArt) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 115,
                  height: 140,
                  child: product?.primaryImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: MonettaImage(
                            url: product!.primaryImage,
                            fit: BoxFit.contain,
                            fallbackLabel: product!.title,
                            backgroundColor: dark
                                ? palette.surfaceDeep
                                : const Color(0xFFEAF0E4),
                          ),
                        )
                      : ExcludeSemantics(
                          child: Icon(
                            Icons.favorite_border_rounded,
                            size: 72,
                            color: palette.gold.withValues(alpha: .6),
                          ),
                        ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
