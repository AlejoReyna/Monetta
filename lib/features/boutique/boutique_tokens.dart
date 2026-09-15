/// Boutique layer for the welcome / onboarding / home package.
///
/// The shared system in `app/theme.dart` is a *white* editorial theme with
/// square corners. The boutique redesign asks for an ivory ground, softened
/// rectangles and a lighter gold. Rather than repaint the whole app from a
/// feature package — which would silently restyle checkout, account and the
/// admin panel — this file is a **local** token layer used only by the screens
/// this package owns.
///
/// ## Pending global adoption
///
/// Everything here is written so it can move into `app/theme.dart` verbatim
/// once the orchestrator decides to flip the whole app:
///
/// * `MonettaColors.light.canvas` → [_ivory], `surfaceMuted` → [_ivoryDeep],
///   `accent` → [_gold], `accentContent` → [_goldText].
/// * `kSquare` → [BoutiqueRadius.card] / [BoutiqueRadius.control].
/// * The font families below want `Playfair Display` and `Inter` registered in
///   `pubspec.yaml`. They are named *first* in every family list, so the moment
///   those assets land the screens pick them up with no further edit; until
///   then the platform serif/sans fallbacks render (New York, SF Pro).
///
/// Dark mode deliberately defers to [MonettaColors.dark] instead of inventing
/// a second palette, so the existing dark theme stays usable.
///
/// ## Where the values came from
///
/// Sampled from `docs/design-reference/monetta-client-layout.png` rather than
/// copied from its printed swatch row, because the two disagree: the strip
/// labels the ground `#FBF9F2` and the gold `#D4AF37`, while the screens
/// themselves render `#F8F5EE` and `#C5A052`. The rendered values win — they
/// are what the figures actually look like — and they are also the values the
/// brief proposed. Other measured points, for anyone re-deriving this:
/// card surface `#F6F5EC`, search field `#F6F0E9`, silhouette tile `#F5EEE6`,
/// filter chip `#E6E2D8`, `NUEVO` badge `#DBBE93`.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

// ---------------------------------------------------------------------------
// Type
// ---------------------------------------------------------------------------

/// Editorial serif. Playfair Display when registered; platform serif until then.
const String kBoutiqueSerifFamily = 'Playfair Display';
const List<String> kBoutiqueSerifFallback = <String>[
  'New York',
  'Iowan Old Style',
  'Baskerville',
  'Georgia',
  'Times New Roman',
  'serif',
];

/// Controls, prices, navigation. Inter when registered; platform sans until then.
const String kBoutiqueSansFamily = 'Inter';
const List<String> kBoutiqueSansFallback = <String>[
  'SF Pro Text',
  'Helvetica Neue',
  'Helvetica',
  'Arial',
  'sans-serif',
];

/// Editorial headline. 24–32 depending on the space it is given — never the
/// 8–11px the mockup's pixel density implies.
TextStyle boutiqueDisplay(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.12,
}) =>
    TextStyle(
      fontFamily: kBoutiqueSerifFamily,
      fontFamilyFallback: kBoutiqueSerifFallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * -0.012,
      height: height,
      color: color,
    );

/// Section and panel titles.
///
/// Inter, not Playfair: on the reference, Playfair is reserved for editorial
/// and brand moments — the welcome wordmark, the home banner headline, brand
/// and collection covers — while every UI title (`Novedades`, `Compra por
/// estilo`, `Personaliza tu experiencia`, `Marcas favoritas`) is set in the
/// sans. The strip says as much: *Playfair Display — títulos y acentos*,
/// *Inter — texto y botones*.
TextStyle boutiqueTitle({
  double size = 17,
  Color? color,
  FontWeight weight = FontWeight.w600,
}) =>
    TextStyle(
      fontFamily: kBoutiqueSansFamily,
      fontFamilyFallback: kBoutiqueSansFallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: -0.1,
      height: 1.25,
      color: color,
    );

/// Running copy, labels, prices. Floor of 12 for secondary, 14 for body.
TextStyle boutiqueText({
  double size = 14,
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.45,
  TextDecoration? decoration,
}) =>
    TextStyle(
      fontFamily: kBoutiqueSansFamily,
      fontFamilyFallback: kBoutiqueSansFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      decoration: decoration,
    );

/// Tracked small caps. Always paired with `.toUpperCase()` at the call site.
TextStyle boutiqueEyebrow({
  double size = 11,
  Color? color,
  FontWeight weight = FontWeight.w500,
}) =>
    TextStyle(
      fontFamily: kBoutiqueSansFamily,
      fontFamilyFallback: kBoutiqueSansFallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 1.4,
      height: 1.3,
      color: color,
    );

// ---------------------------------------------------------------------------
// Metrics
// ---------------------------------------------------------------------------

abstract final class BoutiqueSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Horizontal page margin. The brief allows 16–20; 20 matches the margin the
  /// rest of the app already uses, so package A does not visibly re-indent.
  static const double gutter = 20;

  /// Module rhythm. Replaces the 64–72px gaps the home used to carry.
  static const double sectionGap = 32;
  static const double sectionGapTight = 24;

  /// Primary button height, and the minimum any tap target may be.
  static const double control = 52;
  static const double tapTarget = 48;
}

abstract final class BoutiqueRadius {
  static const BorderRadius card = BorderRadius.all(Radius.circular(12));
  static const BorderRadius control = BorderRadius.all(Radius.circular(10));
  static const BorderRadius tile = BorderRadius.all(Radius.circular(8));

  /// Chips and short editorial actions.
  static const BorderRadius capsule = BorderRadius.all(Radius.circular(999));
}

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

const Color _ivory = Color(0xFFF8F5EE);
const Color _ivoryDeep = Color(0xFFF0EBE2);
const Color _boutiqueInk = Color(0xFF111111);

/// Ink at ~58%, warmed. Measured at 5.2:1 on [_ivory] — the app's legacy
/// muted grey only reaches 4.1:1 there, which is why this is not reused.
const Color _mutedBoutiqueInk = Color(0xFF6B6660);

/// The brief's dorado. Contrast on ivory is 2.3:1, so it is a *line and mark*
/// colour only.
const Color _gold = Color(0xFFC5A052);

/// The same hue taken to 4.6:1 on ivory, for gold text (kickers, prices in a
/// sale state). Never use [_gold] for type.
const Color _goldText = Color(0xFF8F6838);

const Color _hairline = Color(0x1F111111);

/// Semantic colours for this package, resolved per brightness.
@immutable
class BoutiquePalette {
  const BoutiquePalette._({
    required this.canvas,
    required this.surface,
    required this.surfaceDeep,
    required this.ink,
    required this.inkMuted,
    required this.gold,
    required this.goldText,
    required this.hairline,
    required this.selectedFill,
    required this.selectedBorder,
    required this.sale,
    required this.onDark,
  });

  /// Page ground. Ivory in light, the app's dark canvas in dark.
  final Color canvas;

  /// Cards and raised panels.
  final Color surface;

  /// Secondary surface: photo grounds, chips, search field.
  final Color surfaceDeep;

  final Color ink;
  final Color inkMuted;

  /// Hairlines, rules and small marks. Not for type — see [goldText].
  final Color gold;
  final Color goldText;
  final Color hairline;

  /// Selection is carried by fill *and* border *and* a check — never colour
  /// on its own.
  final Color selectedFill;
  final Color selectedBorder;

  final Color sale;

  /// Type and controls that sit on photography.
  final Color onDark;

  factory BoutiquePalette.of(BuildContext context) {
    final shared = context.monettaColors;
    if (Theme.of(context).brightness == Brightness.dark) {
      return BoutiquePalette._(
        canvas: shared.canvas,
        surface: shared.surfaceRaised,
        surfaceDeep: shared.surfaceMuted,
        ink: shared.contentPrimary,
        inkMuted: shared.contentMuted,
        gold: shared.accent,
        goldText: shared.accentContent,
        hairline: shared.divider,
        selectedFill: shared.surfaceMuted,
        selectedBorder: shared.contentPrimary,
        sale: shared.sale,
        onDark: const Color(0xFFF8F5EE),
      );
    }
    return const BoutiquePalette._(
      canvas: _ivory,
      surface: Color(0xFFFDFAF4),
      surfaceDeep: _ivoryDeep,
      ink: _boutiqueInk,
      inkMuted: _mutedBoutiqueInk,
      gold: _gold,
      goldText: _goldText,
      hairline: _hairline,
      selectedFill: _ivoryDeep,
      selectedBorder: _boutiqueInk,
      sale: Color(0xFFA3342B),
      onDark: _ivory,
    );
  }
}

/// Reads the package palette without threading it through every constructor.
extension BoutiqueThemeContext on BuildContext {
  BoutiquePalette get boutique => BoutiquePalette.of(this);
}

// ---------------------------------------------------------------------------
// Shared package components
// ---------------------------------------------------------------------------

/// The package's primary action: ink fill, 52pt, softened rectangle.
///
/// Written here rather than leaning on `FilledButtonTheme` because the shared
/// theme squares its corners; overriding the theme globally is the
/// cross-cutting change this package is not making.
class BoutiqueButton extends StatelessWidget {
  const BoutiqueButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.onPhoto = false,
    super.key,
  });

  /// The welcome's action (figure 01): a near-black panel held by a single
  /// gold hairline, so it reads as part of the photograph instead of a pale
  /// slab dropped on top of it.
  const BoutiqueButton.onPhoto({
    required this.label,
    required this.onPressed,
    super.key,
  })  : filled = true,
        onPhoto = true;

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final background = onPhoto
        ? const Color(0xD10E0C0A)
        : filled
            ? palette.ink
            : Colors.transparent;
    final foreground = onPhoto
        ? const Color(0xFFF8F5EE)
        : filled
            ? palette.canvas
            : palette.ink;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        borderRadius: BoutiqueRadius.control,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BoutiqueRadius.control,
          child: Container(
            height: BoutiqueSpace.control,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.xl,
            ),
            decoration: BoxDecoration(
              borderRadius: BoutiqueRadius.control,
              border: onPhoto
                  ? Border.all(color: _gold.withValues(alpha: .85), width: 1)
                  : filled
                      ? null
                      : Border.all(color: palette.ink, width: 1),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: boutiqueText(
                size: 14,
                weight: FontWeight.w600,
                color: foreground,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section opener: a sans title with an optional trailing text action, sized
/// for the 24–32px module rhythm. Sans, not serif — see [boutiqueTitle].
class BoutiqueSectionHeader extends StatelessWidget {
  const BoutiqueSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.kicker,
    super.key,
  });

  final String title;
  final String? kicker;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final action = actionLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoutiqueSpace.gutter,
        0,
        BoutiqueSpace.gutter,
        BoutiqueSpace.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kicker != null) ...[
                  Text(
                    kicker!.toUpperCase(),
                    style: boutiqueEyebrow(size: 11, color: palette.goldText),
                  ),
                  const SizedBox(height: BoutiqueSpace.xs),
                ],
                Text(title, style: boutiqueTitle(color: palette.ink)),
              ],
            ),
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(width: BoutiqueSpace.md),
            _HeaderAction(label: action, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BoutiqueRadius.capsule,
        child: Container(
          constraints: const BoxConstraints(minHeight: BoutiqueSpace.tapTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: BoutiqueSpace.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: boutiqueText(
                  size: 13,
                  color: palette.inkMuted,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: palette.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
