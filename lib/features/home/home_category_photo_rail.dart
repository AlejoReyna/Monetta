/// Home-only category photograph carousel (v4.1 F01–F18).
library;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/guide_art.dart';
import 'home_v41_catalog.dart';

class HomeCategoryPhotoRail extends StatelessWidget {
  const HomeCategoryPhotoRail({
    required this.onOpen,
    this.onSeeAll,
    super.key,
  });

  final void Function(HomeCategoryPhotoEntry entry) onOpen;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        (MediaQuery.sizeOf(context).width * 0.42).clamp(140.0, 200.0);
    return Column(
      key: const ValueKey('home-section-category-photos'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoutiqueSectionHeader(
          title: 'Categorías',
          actionLabel: onSeeAll == null ? null : 'Ver todo',
          onAction: onSeeAll,
        ),
        SizedBox(
          height: cardWidth * 1.15,
          child: ListView.separated(
            key: const ValueKey('home-category-photo-rail'),
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: BoutiqueSpace.gutter),
            itemCount: kHomeCategoryPhotoEntries.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: BoutiqueSpace.md),
            itemBuilder: (context, index) {
              final entry = kHomeCategoryPhotoEntries[index];
              return SizedBox(
                width: cardWidth,
                child: _CategoryPhotoTile(
                  key: ValueKey('home-category-photo-${entry.assetId}'),
                  entry: entry,
                  onTap: () => onOpen(entry),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BoutiqueSpace.gutter,
            BoutiqueSpace.md,
            BoutiqueSpace.gutter,
            0,
          ),
          child: GuideGlassIconButton(
            tooltip: 'Ver categorías',
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            onPressed: onSeeAll,
          ),
        ),
      ],
    );
  }
}

class _CategoryPhotoTile extends StatelessWidget {
  const _CategoryPhotoTile({
    required this.entry,
    required this.onTap,
    super.key,
  });

  final HomeCategoryPhotoEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final spec = guideAsset('homePhoto:${entry.assetId}', forHome: true);
    return Semantics(
      button: true,
      label: 'Ver ${entry.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BoutiqueRadius.tile,
                child: spec == null
                    ? ColoredBox(color: palette.surfaceDeep)
                    : Image.asset(
                        spec.path,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
              ),
            ),
            const SizedBox(height: BoutiqueSpace.sm),
            Text(
              entry.label,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: boutiqueText(size: 13, color: palette.ink, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
