/// Shared catalog chrome: capsule chips, the editorial banner, result counts
/// and the empty states. One vocabulary for search, the product list,
/// collections and the brand page.
library;

import 'package:flutter/material.dart';

import '../../app/media/monetta_image.dart';
import '../../app/motion.dart';
import '../boutique/boutique_tokens.dart';

/// Capsule control from the reference's component strip.
///
/// Selection is carried by fill, border *and* a mark, never by colour alone.
class MonettaCapsuleChip extends StatelessWidget {
  const MonettaCapsuleChip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.showCaret = false,
    this.leading,
    this.badgeCount,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// Marks a chip that opens a picker rather than toggling on the spot.
  final bool showCaret;
  final Widget? leading;

  /// Small count on a chip that currently has selections behind it.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final count = badgeCount ?? 0;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.selectedFill : Colors.transparent,
        borderRadius: BoutiqueRadius.capsule,
        child: InkWell(
          onTap: onTap,
          borderRadius: BoutiqueRadius.capsule,
          child: AnimatedContainer(
            duration: reduceMotion(context) ? Duration.zero : kSnap,
            curve: kMotionCurve,
            constraints: const BoxConstraints(
              minHeight: BoutiqueSpace.tapTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.lg,
            ),
            decoration: BoxDecoration(
              borderRadius: BoutiqueRadius.capsule,
              border: Border.all(
                color: selected ? palette.selectedBorder : palette.hairline,
                width: selected ? 1.2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded, size: 15, color: palette.ink),
                  const SizedBox(width: 6),
                ] else if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: boutiqueText(
                      size: 14,
                      weight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? palette.ink : palette.inkMuted,
                      height: 1.2,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '($count)',
                    style: boutiqueText(
                      size: 13,
                      weight: FontWeight.w600,
                      color: palette.goldText,
                      height: 1.2,
                    ),
                  ),
                ],
                if (showCaret) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: selected ? palette.ink : palette.inkMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of capsule chips with the page gutter.
class MonettaChipRail extends StatelessWidget {
  const MonettaChipRail({
    required this.children,
    this.padding = const EdgeInsets.symmetric(
      horizontal: BoutiqueSpace.gutter,
    ),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    // Grows with the shopper's text size instead of clipping the chips.
    final height = MediaQuery.textScalerOf(context).scale(
      BoutiqueSpace.tapTarget,
    );
    return SizedBox(
      height: height + BoutiqueSpace.sm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: BoutiqueSpace.sm),
        itemBuilder: (context, index) => Center(child: children[index]),
      ),
    );
  }
}

/// "124 piezas" — always computed from the very list being rendered.
class CatalogResultCount extends StatelessWidget {
  const CatalogResultCount({
    required this.count,
    this.noun = 'pieza',
    this.pluralNoun = 'piezas',
    super.key,
  });

  final int count;
  final String noun;
  final String pluralNoun;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count ${count == 1 ? noun : pluralNoun}',
      style: boutiqueText(
        size: 13,
        color: context.boutique.inkMuted,
        height: 1.2,
      ),
    );
  }
}

/// The filter-and-sort glyph: two slider rails with offset stops.
///
/// Painted rather than taken from an icon font so the stroke stays fine
/// (1.5 units of a 24-unit grid) at the size the header uses. [size] and
/// [color] fall back to the ambient [IconTheme], like an [Icon].
class AdjustmentsIcon extends StatelessWidget {
  const AdjustmentsIcon({this.size, this.color, super.key});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    return SizedBox.square(
      dimension: size ?? theme.size ?? 24,
      child: CustomPaint(
        painter: _AdjustmentsPainter(
          color: color ?? theme.color ?? const Color(0xFF111111),
        ),
      ),
    );
  }
}

class _AdjustmentsPainter extends CustomPainter {
  const _AdjustmentsPainter({required this.color});

  final Color color;

  /// Side of the design grid every coordinate below is expressed in.
  static const double _grid = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _grid;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    void line(double x1, double y1, double x2, double y2) {
      canvas.drawLine(
        Offset(x1 * scale, y1 * scale),
        Offset(x2 * scale, y2 * scale),
        paint,
      );
    }

    // Upper rail with its stop at x = 8, a small gap beside the stop.
    line(2, 8, 8, 8);
    line(10, 8, 22, 8);
    line(8, 4, 8, 12);
    // Lower rail with its stop at x = 16.
    line(2, 16, 14, 16);
    line(16, 16, 22, 16);
    line(16, 12, 16, 20);
  }

  @override
  bool shouldRepaint(covariant _AdjustmentsPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Height of an editorial banner: a share of the viewport, clamped so a short
/// phone still shows a row of products above the fold and a tablet does not
/// turn the banner into a poster.
double catalogBannerHeight(BuildContext context, {double factor = 0.30}) =>
    (MediaQuery.sizeOf(context).height * factor).clamp(200.0, 340.0);

/// The editorial header for a collection or a brand.
///
/// With artwork it is a photograph carrying the title, a short line and one
/// action. Without artwork it is a careful typographic block on the ivory
/// ground — never a grey rectangle standing in for a photo that does not
/// exist.
class CatalogEditorialBanner extends StatelessWidget {
  const CatalogEditorialBanner({
    required this.title,
    this.description,
    this.imageUrl,
    this.imageAsset,
    this.logoAsset,
    this.actionLabel,
    this.onAction,
    this.heightFactor = 0.30,
    this.centerTitle = false,
    this.height,
    super.key,
  });

  final String title;
  final String? description;
  final String? imageUrl;
  final String? imageAsset;

  /// Brand artwork placed above the title. Laid out `contain` so a logo is
  /// never stretched.
  final String? logoAsset;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Share of the viewport height the photograph takes. The reference sits
  /// near 0.30; anything taller starts hiding the products.
  final double heightFactor;
  final bool centerTitle;

  /// Explicit height, when the banner shares a box with a collapsing app bar.
  final double? height;

  bool get _hasArtwork => imageUrl != null || imageAsset != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasArtwork) return _TypographicHeader(banner: this);

    final resolved =
        height ?? catalogBannerHeight(context, factor: heightFactor);

    return SizedBox(
      height: resolved,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: context.boutique.surfaceDeep,
            child: imageAsset != null
                ? Image.asset(
                    imageAsset!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : MonettaImage(url: imageUrl, fallbackLabel: title),
          ),
          const _BannerScrim(),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                BoutiqueSpace.gutter,
                BoutiqueSpace.gutter,
                BoutiqueSpace.gutter,
                BoutiqueSpace.xl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: _content(context, onPhoto: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, {required bool onPhoto}) {
    final palette = context.boutique;
    final color = onPhoto ? palette.onDark : palette.ink;
    final muted =
        onPhoto ? palette.onDark.withValues(alpha: 0.88) : palette.inkMuted;
    final align = centerTitle ? TextAlign.center : TextAlign.start;

    return <Widget>[
      if (logoAsset case final asset?) ...[
        SizedBox(
          height: 34,
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
            color: onPhoto ? palette.onDark : null,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: BoutiqueSpace.md),
      ],
      Text(
        title,
        textAlign: align,
        style: boutiqueDisplay(30, color: color),
      ),
      if (description case final text? when text.trim().isNotEmpty) ...[
        const SizedBox(height: BoutiqueSpace.sm),
        Text(
          text,
          textAlign: align,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: boutiqueText(size: 14, color: muted, height: 1.45),
        ),
      ],
      if (actionLabel case final label? when onAction != null) ...[
        const SizedBox(height: BoutiqueSpace.lg),
        Align(
          alignment: centerTitle ? Alignment.center : Alignment.centerLeft,
          child: SizedBox(
            width: 200,
            child: BoutiqueButton(
              key: const Key('catalog-banner-cta'),
              label: label,
              onPressed: onAction,
              onPhoto: onPhoto,
            ),
          ),
        ),
      ],
    ];
  }
}

class _BannerScrim extends StatelessWidget {
  const _BannerScrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0x33000000),
              Color(0x00000000),
              Color(0x99000000),
            ],
            stops: <double>[0, 0.38, 1],
          ),
        ),
      ),
    );
  }
}

class _TypographicHeader extends StatelessWidget {
  const _TypographicHeader({required this.banner});

  final CatalogEditorialBanner banner;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: double.infinity,
      color: palette.surfaceDeep,
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.xl,
        BoutiqueSpace.gutter,
        BoutiqueSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: banner.centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          ...banner._content(context, onPhoto: false),
          const SizedBox(height: BoutiqueSpace.lg),
          Container(width: 56, height: 1.4, color: palette.gold),
        ],
      ),
    );
  }
}

/// Nothing matched. Says what was searched or filtered and offers a real way
/// out — never a dead end.
class CatalogEmptyState extends StatelessWidget {
  const CatalogEmptyState({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.suggestions = const <Widget>[],
    super.key,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Real categories or collections to continue with.
  final List<Widget> suggestions;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        BoutiqueSpace.xxl,
        BoutiqueSpace.gutter,
        BoutiqueSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: boutiqueDisplay(24, color: palette.ink)),
          const SizedBox(height: BoutiqueSpace.sm),
          Text(
            body,
            style: boutiqueText(size: 14, color: palette.inkMuted),
          ),
          if (actionLabel case final label? when onAction != null) ...[
            const SizedBox(height: BoutiqueSpace.lg),
            SizedBox(
              width: 220,
              child: BoutiqueButton(
                label: label,
                onPressed: onAction,
                filled: false,
              ),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: BoutiqueSpace.xl),
            Wrap(
              spacing: BoutiqueSpace.sm,
              runSpacing: BoutiqueSpace.sm,
              children: suggestions,
            ),
          ],
        ],
      ),
    );
  }
}
