/// Shared brand tile of the client guide (Inicio, Categorías, Personalización):
/// a rectangular tile with the brand's gold wordmark, large and centred.
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
import '../../data/media/media_url.dart';
import 'boutique_tokens.dart';
import 'client_guide_components.dart';

/// Selection radio of the guide: an empty ring, filled with a dot when
/// [selected]. Selection is never carried by colour alone: the dot is shape.
class GuideRadioMark extends StatelessWidget {
  const GuideRadioMark({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.action : Colors.transparent,
        border: Border.all(
          color: selected ? palette.action : palette.borderControl,
        ),
      ),
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.onAction,
              ),
            )
          : null,
    );
  }
}

/// A tile with a brand wordmark.
///
/// The bundled wordmarks are gold on an opaque white square. In light mode the
/// image is multiplied with the tile colour so the white vanishes and only the
/// mark remains on the tile, as in the guide.
///
/// [selected] null draws no radio (a plain link); non-null draws the radio at
/// the top right and reports selection to assistive technology.
class GuideBrandTile extends StatelessWidget {
  const GuideBrandTile({
    required this.label,
    required this.onTap,
    this.asset,
    this.imageUrl,
    this.selected,
    this.aspectRatio = 1.55,
    super.key,
  });

  /// Bundled wordmark and fallback of [imageUrl]. Null (a brand with no
  /// artwork) shows the brand name in gold type instead.
  final String? asset;

  /// Remote wordmark published by the store, preferred when it loads.
  final String? imageUrl;

  /// Brand name, used for semantics.
  final String label;
  final VoidCallback? onTap;
  final bool? selected;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The tile keeps the wordmark's white plate in dark mode: gold on dark
    // grey would lose the white the artwork was drawn on.
    final tileColor = dark ? MonettaTokens.onPhoto : palette.surfaceDeep;
    final blend = dark ? null : tileColor;

    Widget nameOnly() => Center(
          child: Padding(
            padding: EdgeInsets.all(MonettaTokens.space[1]),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: clientGuideStyle(
                context,
                MonettaTokens.cardLabel,
                color: palette.goldText,
              ),
            ),
          ),
        );

    Widget wordmark() {
      final path = asset;
      final bundled = path == null
          ? nameOnly()
          : Image.asset(
              path,
              fit: BoxFit.fitWidth,
              color: blend,
              colorBlendMode: blend == null ? null : BlendMode.multiply,
              excludeFromSemantics: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => nameOnly(),
            );
      final url = imageUrl;
      if (url == null || url.isEmpty) return bundled;
      return Image.network(
        MediaUrl.sized(url, width: MediaUrl.cardWidth),
        fit: BoxFit.fitWidth,
        color: blend,
        colorBlendMode: blend == null ? null : BlendMode.multiply,
        excludeFromSemantics: true,
        filterQuality: FilterQuality.medium,
        cacheWidth: MediaUrl.cardWidth,
        errorBuilder: (_, __, ___) => bundled,
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: tileColor,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(MonettaTokens.radiusTile),
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Wordmarks occupy about 60% of a square file: scaling the
                // plate makes them read large without cropping the mark.
                ClipRect(
                  child: asset == null
                      ? wordmark()
                      : Transform.scale(scale: 1.15, child: wordmark()),
                ),
                if (selected != null)
                  Positioned(
                    top: MonettaTokens.space[0],
                    right: MonettaTokens.space[0],
                    child: GuideRadioMark(selected: selected!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
