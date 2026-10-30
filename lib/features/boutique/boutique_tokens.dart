/// Boutique layer for the welcome / onboarding / home package.
///
/// Since the style-guideline migration (docs/MONETTA_STYLE_GUIDELINE_MIGRATION_PLAN.md)
/// this layer is an adapter over the generated tokens in `app/monetta_tokens.g.dart`
/// (source of truth: `design-system/monetta.tokens.json`). It keeps its public
/// names (`BoutiquePalette`, `boutiqueText`, `BoutiqueRadius`, ...) so every caller
/// keeps compiling while screens move to the warm identity:
///
/// * Page ground is warm ivory; bars share one slightly deeper ivory
///   ([BoutiquePalette.bar]); product tiles and chips use [BoutiquePalette.surface].
/// * The principal action is the brown pill ([BoutiquePalette.action]); gold stays a
///   mark and line colour, never type.
/// * Screen, section and product-name roles are serif (Playfair Display); UI
///   labels, prices and controls stay sans (Inter).
///
/// Dark mode defers to [MonettaColors.dark] instead of inventing a second palette.
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
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

/// Section and panel titles that are not editorial: kept in the sans for UI
/// chrome (bars, dialogs, card captions).
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

/// Sizes of the product-related title roles below, at the compact width class.
/// Pass `MonettaTokens.<role>.sizeFor(width)` to step up on tablets.
final double kBoutiqueScreenTitleSize = MonettaTokens.screenTitle.compact;
const double kBoutiqueHeaderNameSize = 19;
final double kBoutiqueProductNameSize = MonettaTokens.productName.compact;
final double kBoutiqueSectionHeadingSize = MonettaTokens.sectionTitle.compact;

TextStyle _serifRole(
  MonettaTypeRole role,
  double? size,
  Color? color,
  BuildContext? context,
) {
  // An explicit size wins; otherwise the role steps up with the available width.
  final resolved = size ??
      (context == null
          ? role.compact
          : role.sizeFor(MediaQuery.sizeOf(context).width));
  return TextStyle(
    fontFamily: kBoutiqueSerifFamily,
    fontFamilyFallback: kBoutiqueSerifFallback,
    fontSize: resolved,
    fontWeight: FontWeight.values[(role.weight ~/ 100) - 1],
    letterSpacing: resolved * role.tracking,
    height: role.lineHeight,
    color: color,
  );
}

/// Title of a screen or banner (Categorías, a collection, a brand): serif. Pass
/// [context] to step up on tablets and desktops (26 / 30 / 36).
TextStyle boutiqueScreenTitle({
  Color? color,
  double? size,
  BuildContext? context,
}) =>
    _serifRole(MonettaTokens.screenTitle, size, color, context);

/// A product name set in a bar, next to the back and bag actions. Bars keep
/// the sans: a serif at 19 px loses its hairlines on the bar ground.
TextStyle boutiqueHeaderName({Color? color}) =>
    boutiqueTitle(size: kBoutiqueHeaderNameSize, color: color);

/// The main name of a product on its page or quick view: serif (25 / 29 / 32).
TextStyle boutiqueProductName({
  Color? color,
  double? size,
  BuildContext? context,
}) =>
    _serifRole(MonettaTokens.productName, size, color, context);

/// Heading of a section inside a product page or a catalog screen: serif
/// (23 / 27 / 30).
TextStyle boutiqueSectionHeading({
  Color? color,
  double? size,
  BuildContext? context,
}) =>
    _serifRole(MonettaTokens.sectionTitle, size, color, context);

/// Row label of the account, menu and settings lists: serif (18 / 19 / 20).
TextStyle boutiqueRowLabel({
  Color? color,
  double? size,
  BuildContext? context,
}) =>
    _serifRole(MonettaTokens.accountRow, size, color, context);

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
  static const double control = MonettaTokens.controlHeight;
  static const double tapTarget = MonettaTokens.tapTarget;
}

abstract final class BoutiqueRadius {
  static const BorderRadius card =
      BorderRadius.all(Radius.circular(MonettaTokens.radiusCard));
  static const BorderRadius control =
      BorderRadius.all(Radius.circular(MonettaTokens.radiusControl));
  static const BorderRadius tile =
      BorderRadius.all(Radius.circular(MonettaTokens.radiusTile));

  /// Chips and short editorial actions.
  static const BorderRadius capsule = BorderRadius.all(Radius.circular(999));
}

// ---------------------------------------------------------------------------
// Colour
// ---------------------------------------------------------------------------

// Light values come from the generated tokens; the aliases keep the names the
// rest of this file (and its callers) already read.
const Color _ivory = MonettaTokens.onPhoto;
const Color _pageGround = MonettaTokens.canvas;
const Color _tile = MonettaTokens.surfaceTile;
const Color _warm = MonettaTokens.surfaceWarm;
const Color _boutiqueInk = MonettaTokens.ink;
const Color _mutedBoutiqueInk = MonettaTokens.inkMuted;

/// Decorative gold: 2.3:1 on the ground, so a *line and mark* colour only.
const Color _gold = MonettaTokens.gold;

/// Accent that reads as type (5.7:1 on the ground). Never use [_gold] for type.
const Color _goldText = MonettaTokens.accentText;

const Color _hairline = MonettaTokens.divider;

/// Semantic colours for this package, resolved per brightness.
@immutable
class BoutiquePalette {
  const BoutiquePalette._({
    required this.canvas,
    required this.surface,
    required this.surfaceDeep,
    required this.bar,
    required this.ink,
    required this.inkMuted,
    required this.gold,
    required this.goldText,
    required this.hairline,
    required this.selectedFill,
    required this.selectedBorder,
    required this.sale,
    required this.onDark,
    required this.action,
    required this.onAction,
    required this.actionDark,
    required this.onActionDark,
    required this.borderControl,
    required this.saleSurface,
  });

  /// Page ground. White in light, the app's dark canvas in dark.
  final Color canvas;

  /// Cards and raised panels. A very light neutral grey in light (1.04:1
  /// against [canvas]).
  final Color surface;

  /// Secondary surface: photo grounds, chips, search field. A light neutral
  /// grey in light (1.05:1 against [bar]).
  final Color surfaceDeep;

  /// Surface of the top bars (the app bars). In light it is the same grey as
  /// the bottom navigation
  /// (`MonettaColors.navigationSurface`, 1.09:1 against [canvas]), so the
  /// chrome reads as a band at each edge. In dark it keeps the canvas.
  final Color bar;

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

  /// Principal purchase action (brown) and its label colour.
  final Color action;
  final Color onAction;

  /// Dark chocolate pill and its label colour.
  final Color actionDark;
  final Color onActionDark;

  /// Boundary of outlined controls; at least 3:1 on [canvas].
  final Color borderControl;

  /// Ground of discount and stock chips; [sale] text sits on it.
  final Color saleSurface;

  factory BoutiquePalette.of(BuildContext context) {
    final shared = context.monettaColors;
    if (Theme.of(context).brightness == Brightness.dark) {
      return BoutiquePalette._(
        canvas: shared.canvas,
        surface: shared.surfaceRaised,
        surfaceDeep: shared.surfaceMuted,
        bar: shared.canvas,
        ink: shared.contentPrimary,
        inkMuted: shared.contentMuted,
        gold: shared.accent,
        goldText: shared.accentContent,
        hairline: shared.divider,
        selectedFill: shared.surfaceMuted,
        selectedBorder: shared.contentPrimary,
        sale: shared.sale,
        onDark: const Color(0xFFF8F5EE),
        action: shared.actionPrimary,
        onAction: shared.onActionPrimary,
        actionDark: shared.actionDark,
        onActionDark: shared.onActionDark,
        borderControl: shared.borderControl,
        saleSurface: shared.saleSurface,
      );
    }
    return BoutiquePalette._(
      canvas: _pageGround,
      surface: _tile,
      surfaceDeep: _warm,
      bar: shared.navigationSurface,
      ink: _boutiqueInk,
      inkMuted: _mutedBoutiqueInk,
      gold: _gold,
      goldText: _goldText,
      hairline: _hairline,
      selectedFill: _warm,
      selectedBorder: MonettaTokens.actionPrimary,
      sale: MonettaTokens.sale,
      onDark: _ivory,
      action: MonettaTokens.actionPrimary,
      onAction: MonettaTokens.onActionPrimary,
      actionDark: MonettaTokens.actionDark,
      onActionDark: MonettaTokens.onActionDark,
      borderControl: MonettaTokens.borderControl,
      saleSurface: MonettaTokens.saleSurface,
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

/// The package's principal action: brown pill, 52pt (style guideline §3).
///
/// `filled: false` draws the outlined companion; [BoutiqueButton.onPhoto] is the
/// welcome's action. The label keeps the case the caller gives it; the web
/// uppercases its commerce buttons with CSS, which Flutter cannot, so the app
/// passes the case it wants.
class BoutiqueButton extends StatelessWidget {
  const BoutiqueButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.onPhoto = false,
    super.key,
  });

  /// The welcome's action: the brown pill held by a single gold hairline, so it
  /// reads as part of the photograph.
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
    final enabled = onPressed != null;
    final background = onPhoto
        ? palette.action.withValues(alpha: .94)
        : filled
            ? (enabled
                ? palette.action
                : Color.alphaBlend(
                    palette.canvas.withValues(alpha: .45),
                    palette.action,
                  ))
            : Colors.transparent;
    final foreground = onPhoto || filled ? palette.onAction : palette.ink;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: background,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: Container(
            constraints: const BoxConstraints(minHeight: BoutiqueSpace.control),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: BoutiqueSpace.xl,
              vertical: BoutiqueSpace.sm,
            ),
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: onPhoto
                    ? BorderSide(color: _gold.withValues(alpha: .85))
                    : filled
                        ? BorderSide.none
                        : BorderSide(color: palette.borderControl),
              ),
            ),
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: boutiqueText(
                size: 14,
                weight: FontWeight.w600,
                color: foreground,
                height: 1.15,
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
                Text(title, style: boutiqueSectionHeading(color: palette.ink)),
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
