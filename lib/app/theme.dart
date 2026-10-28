/// Visual language for Monetta's editorial storefront: crisp black type,
/// generous white space, pale catalog grounds, fine dividers, and the brand's
/// own gold reserved for identity and high-value states.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'monetta_tokens.g.dart';
import 'motion.dart';
import 'shopper_copy.dart';

export 'money_format.dart' show formatCatalogMoney, kMoney, kUnknownPriceLabel;

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

/// Fixed light-palette values retained for brand artwork, media overlays, and
/// backwards-compatible callers while feature UI migrates to [MonettaColors].
/// Theme-dependent widgets should read `context.monettaColors` instead.
const Color kInk = Color(0xFF111111);

const Color kInkMuted = Color(0xFF737373);

/// Monetta's accent, rationed. See the library note.
const Color kGold = Color(0xFFAA7D44);

/// Purple used when an animated home-section title has fully resolved.
const Color kPurple = Color(0xFF725A82);

/// A lighter counterpart that keeps small purple copy legible on dark canvas.
const Color kPurpleOnDark = Color(0xFFB79AC7);

/// Pale ground used for catalog photography and quiet footer surfaces.
const Color kMist = Color(0xFFF5F5F5);

/// Slightly darker than [kMist] so the rounded search field remains visible.
const Color kSearchFill = Color(0xFFF1F1F1);

/// Sale copy follows common retail convention and stays distinct from gold.
const Color kSale = Color(0xFFA3342B);

/// The 0.5px hairline colour: ink at 15%.
const Color kLine = Color(0x26111111);

const BorderRadius kSquare = BorderRadius.zero;

/// A true hairline. `0.5` renders as one physical pixel on every ≥2x screen,
/// which is the whole point — a 1.0 border looks drawn, a 0.5 looks printed.
const BorderSide kHairline = BorderSide(color: kLine, width: 0.5);

/// Monetta's semantic colors. Unlike the legacy `kInk`/`kMist` constants,
/// these describe intent and can therefore change with brightness.
@immutable
class MonettaColors extends ThemeExtension<MonettaColors> {
  const MonettaColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.mediaPlaceholder,
    required this.contentPrimary,
    required this.contentMuted,
    required this.divider,
    required this.inputFill,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.accent,
    required this.accentContent,
    required this.sale,
    required this.success,
    required this.warningSurface,
    required this.successSurface,
    required this.scrim,
    required this.navigationSurface,
    required this.navigationSelection,
    required this.navigationForeground,
    required this.navigationForegroundMuted,
    required this.surfaceWarm,
    required this.surfaceTile,
    required this.borderControl,
    required this.actionPrimary,
    required this.onActionPrimary,
    required this.actionDark,
    required this.onActionDark,
    required this.saleSurface,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color mediaPlaceholder;
  final Color contentPrimary;
  final Color contentMuted;
  final Color divider;
  final Color inputFill;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color accent;
  final Color accentContent;
  final Color sale;
  final Color success;
  final Color warningSurface;
  final Color successSurface;
  final Color scrim;

  /// Surface of the docked bottom navigation bar.
  final Color navigationSurface;
  final Color navigationSelection;

  /// Icon and label of the current bottom navigation destination.
  final Color navigationForeground;

  /// Icon and label of the other destinations; at least 4.5:1 on
  /// [navigationSurface].
  final Color navigationForegroundMuted;

  /// Campaign and service panels, selected fills.
  final Color surfaceWarm;

  /// Product tiles, chips and category mosaics: a step under [surfaceWarm].
  final Color surfaceTile;

  /// Boundary of outlined controls and fields; at least 3:1 on [canvas].
  final Color borderControl;

  /// Purchase and principal conversion actions.
  final Color actionPrimary;
  final Color onActionPrimary;

  /// Dark chocolate pill (share and secondary campaign actions).
  final Color actionDark;
  final Color onActionDark;

  /// Discount and stock chips: [sale] text sits on it.
  final Color saleSurface;

  static const light = MonettaColors(
    canvas: MonettaTokens.canvas,
    surface: MonettaTokens.surface,
    surfaceRaised: MonettaTokens.surface,
    surfaceMuted: MonettaTokens.surfaceWarm,
    mediaPlaceholder: MonettaTokens.surfaceTile,
    contentPrimary: MonettaTokens.ink,
    contentMuted: MonettaTokens.inkMuted,
    divider: MonettaTokens.divider,
    inputFill: MonettaTokens.surface,
    inverseSurface: MonettaTokens.ink,
    onInverseSurface: MonettaTokens.canvas,
    // Legacy callers read [accent] as text (eyebrows, kickers) as well as marks, so it
    // keeps the darker gold until they move to [accentContent]; the decorative
    // gold of the guideline lives in BoutiquePalette.gold.
    accent: kGold,
    accentContent: MonettaTokens.accentText,
    sale: MonettaTokens.sale,
    success: MonettaTokens.success,
    warningSurface: MonettaTokens.surfaceWarm,
    successSurface: MonettaTokens.successSurface,
    scrim: MonettaTokens.scrim,
    navigationSurface: MonettaTokens.bar,
    navigationSelection: Color(0x29C5A052),
    navigationForeground: MonettaTokens.navigationActive,
    navigationForegroundMuted: MonettaTokens.navigationInactive,
    surfaceWarm: MonettaTokens.surfaceWarm,
    surfaceTile: MonettaTokens.surfaceTile,
    borderControl: MonettaTokens.borderControl,
    actionPrimary: MonettaTokens.actionPrimary,
    onActionPrimary: MonettaTokens.onActionPrimary,
    actionDark: MonettaTokens.actionDark,
    onActionDark: MonettaTokens.onActionDark,
    saleSurface: MonettaTokens.saleSurface,
  );

  static const dark = MonettaColors(
    canvas: Color(0xFF11100F),
    surface: Color(0xFF171615),
    surfaceRaised: Color(0xFF201E1C),
    surfaceMuted: Color(0xFF282521),
    mediaPlaceholder: Color(0xFF242220),
    contentPrimary: Color(0xFFF5F2EC),
    contentMuted: Color(0xFFB9B3AA),
    divider: Color(0x33FFFFFF),
    inputFill: Color(0xFF242220),
    inverseSurface: Color(0xFFF5F2EC),
    onInverseSurface: Color(0xFF171615),
    accent: Color(0xFFC49A65),
    accentContent: Color(0xFFC49A65),
    sale: Color(0xFFE48176),
    success: Color(0xFF9ABC75),
    warningSurface: Color(0xFF33281D),
    successSurface: Color(0xFF1C3022),
    scrim: Color(0xA6000000),
    navigationSurface: Color(0xFF171615),
    navigationSelection: Color(0x3DC49A65),
    navigationForeground: Color(0xFFF5F2EC),
    navigationForegroundMuted: Color(0xFF8E8A85),
    surfaceWarm: MonettaTokens.darkSurfaceWarm,
    surfaceTile: MonettaTokens.darkSurfaceTile,
    borderControl: MonettaTokens.darkBorderControl,
    actionPrimary: MonettaTokens.darkActionPrimary,
    onActionPrimary: MonettaTokens.darkOnActionPrimary,
    actionDark: MonettaTokens.darkActionDark,
    onActionDark: MonettaTokens.darkOnActionDark,
    saleSurface: MonettaTokens.darkSaleSurface,
  );

  @override
  MonettaColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? mediaPlaceholder,
    Color? contentPrimary,
    Color? contentMuted,
    Color? divider,
    Color? inputFill,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? accent,
    Color? accentContent,
    Color? sale,
    Color? success,
    Color? warningSurface,
    Color? successSurface,
    Color? scrim,
    Color? navigationSurface,
    Color? navigationSelection,
    Color? navigationForeground,
    Color? navigationForegroundMuted,
    Color? surfaceWarm,
    Color? surfaceTile,
    Color? borderControl,
    Color? actionPrimary,
    Color? onActionPrimary,
    Color? actionDark,
    Color? onActionDark,
    Color? saleSurface,
  }) {
    return MonettaColors(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      mediaPlaceholder: mediaPlaceholder ?? this.mediaPlaceholder,
      contentPrimary: contentPrimary ?? this.contentPrimary,
      contentMuted: contentMuted ?? this.contentMuted,
      divider: divider ?? this.divider,
      inputFill: inputFill ?? this.inputFill,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      accent: accent ?? this.accent,
      accentContent: accentContent ?? this.accentContent,
      sale: sale ?? this.sale,
      success: success ?? this.success,
      warningSurface: warningSurface ?? this.warningSurface,
      successSurface: successSurface ?? this.successSurface,
      scrim: scrim ?? this.scrim,
      navigationSurface: navigationSurface ?? this.navigationSurface,
      navigationSelection: navigationSelection ?? this.navigationSelection,
      navigationForeground: navigationForeground ?? this.navigationForeground,
      navigationForegroundMuted:
          navigationForegroundMuted ?? this.navigationForegroundMuted,
      surfaceWarm: surfaceWarm ?? this.surfaceWarm,
      surfaceTile: surfaceTile ?? this.surfaceTile,
      borderControl: borderControl ?? this.borderControl,
      actionPrimary: actionPrimary ?? this.actionPrimary,
      onActionPrimary: onActionPrimary ?? this.onActionPrimary,
      actionDark: actionDark ?? this.actionDark,
      onActionDark: onActionDark ?? this.onActionDark,
      saleSurface: saleSurface ?? this.saleSurface,
    );
  }

  @override
  MonettaColors lerp(ThemeExtension<MonettaColors>? other, double t) {
    if (other is! MonettaColors) return this;
    return MonettaColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      mediaPlaceholder:
          Color.lerp(mediaPlaceholder, other.mediaPlaceholder, t)!,
      contentPrimary: Color.lerp(contentPrimary, other.contentPrimary, t)!,
      contentMuted: Color.lerp(contentMuted, other.contentMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inverseSurface: Color.lerp(inverseSurface, other.inverseSurface, t)!,
      onInverseSurface:
          Color.lerp(onInverseSurface, other.onInverseSurface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentContent: Color.lerp(accentContent, other.accentContent, t)!,
      sale: Color.lerp(sale, other.sale, t)!,
      success: Color.lerp(success, other.success, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      navigationSurface:
          Color.lerp(navigationSurface, other.navigationSurface, t)!,
      navigationSelection:
          Color.lerp(navigationSelection, other.navigationSelection, t)!,
      navigationForeground:
          Color.lerp(navigationForeground, other.navigationForeground, t)!,
      navigationForegroundMuted: Color.lerp(
        navigationForegroundMuted,
        other.navigationForegroundMuted,
        t,
      )!,
      surfaceWarm: Color.lerp(surfaceWarm, other.surfaceWarm, t)!,
      surfaceTile: Color.lerp(surfaceTile, other.surfaceTile, t)!,
      borderControl: Color.lerp(borderControl, other.borderControl, t)!,
      actionPrimary: Color.lerp(actionPrimary, other.actionPrimary, t)!,
      onActionPrimary: Color.lerp(onActionPrimary, other.onActionPrimary, t)!,
      actionDark: Color.lerp(actionDark, other.actionDark, t)!,
      onActionDark: Color.lerp(onActionDark, other.onActionDark, t)!,
      saleSurface: Color.lerp(saleSurface, other.saleSurface, t)!,
    );
  }
}

extension MonettaThemeContext on BuildContext {
  MonettaColors get monettaColors =>
      Theme.of(this).extension<MonettaColors>() ?? MonettaColors.light;
}

const double kSectionGap = 52;

/// Canonical logo height for every top navigation bar.
///
/// Keep navigation wordmarks on this token so routes and scroll states cannot
/// silently render the Monetta identity at different sizes.
const double kAppBarWordmarkHeight = 24;

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

/// Sans family bundled with the app (Inter, SIL OFL; see `assets/fonts/`).
///
/// Single source of the app's sans face: every sans helper and the Material
/// theme read it. The fallbacks only matter if the bundled files fail to load.
const String kSansFontFamily = 'Inter';
const List<String> kSansFontFallback = <String>[
  'SF Pro Text',
  'Helvetica Neue',
  'Helvetica',
  'Arial',
  'sans-serif',
];

/// Serif family bundled with the app (Playfair Display, SIL OFL; see
/// `assets/fonts/`), used by storefront navigation and editorial titles.
const String kSerifFontFamily = 'Playfair Display';
const List<String> kSerifFontFallback = <String>[
  'New York',
  'Iowan Old Style',
  'Baskerville',
  'Georgia',
  'Times New Roman',
  'serif',
];

/// Serif used by Monetta's storefront navigation and editorial section titles.
const String kEditorialFontFamily = kSerifFontFamily;

/// Editorial headline. Clean geometric sans with restrained tracking.
TextStyle display(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w300,
  double height = 1.3,
}) =>
    TextStyle(
      fontFamily: kSansFontFamily,
      fontFamilyFallback: kSansFontFallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * -0.025,
      height: height,
      color: color,
    );

TextStyle editorial(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.2,
}) =>
    TextStyle(
      fontFamily: kSerifFontFamily,
      fontFamilyFallback: kSerifFontFallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * -0.012,
      height: height,
      color: color,
    );

/// Text fallback for the bitmap wordmark.
TextStyle wordmark({double size = 19, Color? color}) => TextStyle(
      fontFamily: kSansFontFamily,
      fontFamilyFallback: kSansFontFallback,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: size * 0.18,
      color: color,
    );

/// Small-caps eyebrow: category kickers, section labels, reason lines.
/// Always paired with `.toUpperCase()` at the call site so the string that
/// reaches a screen reader stays readable.
TextStyle eyebrow({
  double size = 10,
  Color? color,
  FontWeight weight = FontWeight.w500,
}) =>
    TextStyle(
      fontFamily: kSansFontFamily,
      fontFamilyFallback: kSansFontFallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 1.8,
      height: 1.4,
      color: color,
    );

/// Running text and UI labels — the geometric-sans half of the pairing.
TextStyle sans({
  double size = 13,
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
  TextDecoration? decoration,
}) =>
    TextStyle(
      fontFamily: kSansFontFamily,
      fontFamilyFallback: kSansFontFallback,
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
      decoration: decoration,
    );

// ---------------------------------------------------------------------------
// Shared components
// ---------------------------------------------------------------------------

/// Dior's primary CTA in editorial context is not a button — it is a text link
/// with a rule under it, offset from the baseline. Reproduced here rather than
/// faked with `TextDecoration.underline`, because the decoration sits too tight
/// and cannot be given its own colour or weight.
class UnderlineLink extends StatelessWidget {
  const UnderlineLink({
    required this.label,
    required this.onTap,
    this.color,
    this.size = 12,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.monettaColors.contentPrimary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: sans(size: size, color: resolvedColor, height: 1.2),
          ),
          const SizedBox(height: 4),
          Container(
            width: label.length * size * 0.55,
            height: 0.8,
            color: resolvedColor,
          ),
        ],
      ),
    );
  }
}

/// The real wordmark, taken from the storefront's own asset
/// (`monetta.mx/cdn/shop/files/FINAL_12.png`), trimmed of its transparent
/// margin and emitted at 1x/2x/3x into `assets/images/`.
///
/// It is a gold-gradient didone with a teardrop accent on the M — high stroke
/// contrast, which is the same class of face Dior sets its own logotype in. So
/// the mark was already speaking this language; the app just wasn't.
///
/// This supersedes [wordmark] as the app's identity. That text style stays for
/// the two places a bitmap will not do: anywhere the mark must be a single
/// flat colour, and as the fallback if the asset ever fails to decode.
///
/// Note this is the one sanctioned exception to the rationing rule in the
/// library note — the gold here is the brand's own mark, not decoration.
class MonettaWordmark extends StatelessWidget {
  const MonettaWordmark({this.height = 22, super.key});

  const MonettaWordmark.appBar({super.key}) : height = kAppBarWordmarkHeight;

  /// Logical height. The asset is ~3.47:1, so 22 gives a ~76pt mark — close to
  /// the 21%-of-viewport ratio Dior sets its logotype at.
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_monetta.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Monetta',
      errorBuilder: (context, _, __) => Text(
        'MONETTA',
        style: wordmark(
          size: height * 0.82,
          color: context.monettaColors.contentPrimary,
        ),
      ),
    );
  }
}

/// Quiet service facts. Type only — no icons, no ticker.
class MonettaTrustRows extends StatelessWidget {
  const MonettaTrustRows({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kTrustRows.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 0.5),
            ),
          Text(kTrustRows[i], style: sans(size: 13, height: 1.45)),
        ],
      ],
    );
  }
}

/// A continuous left-to-right glyph reveal for editorial titles.
///
/// The soft mask lets each letter resolve progressively instead of appearing
/// in discrete typewriter steps. It runs once, only when the text reaches the
/// viewport, and leaves the underlying [Text] intact for layout and semantics.
class EditorialTitleReveal extends StatefulWidget {
  const EditorialTitleReveal({
    required this.text,
    required this.style,
    this.onCompleted,
    super.key,
  });

  final String text;
  final TextStyle style;
  final VoidCallback? onCompleted;

  @override
  State<EditorialTitleReveal> createState() => _EditorialTitleRevealState();
}

class _EditorialTitleRevealState extends State<EditorialTitleReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 920),
  );
  ScrollPosition? _scrollPosition;
  bool _checkScheduled = false;
  bool _started = false;
  bool _completionNotified = false;

  bool get _motionDisabled {
    final media = MediaQuery.maybeOf(context);
    return WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
        media?.disableAnimations == true ||
        media?.accessibleNavigation == true;
  }

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_handleStatus);
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _notifyCompleted();
  }

  void _notifyCompleted() {
    if (_completionNotified) return;
    _completionNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCompleted?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (nextPosition != _scrollPosition) {
      _scrollPosition?.removeListener(_scheduleVisibilityCheck);
      _scrollPosition = nextPosition;
      _scrollPosition?.addListener(_scheduleVisibilityCheck);
    }
    if (_motionDisabled) {
      _started = true;
      _controller.value = 1;
    } else {
      _scheduleVisibilityCheck();
    }
  }

  void _scheduleVisibilityCheck() {
    if (_started || _checkScheduled || !mounted) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || _started) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) return;
      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      final viewportHeight = MediaQuery.sizeOf(context).height;
      if (bottom <= 0 || top >= viewportHeight - 20) return;
      _started = true;
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Text(widget.text, style: widget.style),
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_controller.value);
        final revealEdge = (progress * 1.16).clamp(0.0, 1.16);
        final solidUntil = (revealEdge - .16).clamp(0.0, 1.0);
        final fadeUntil = revealEdge.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 5 * (1 - progress)),
          child: Opacity(
            opacity: (progress * 3).clamp(0.0, 1.0),
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => LinearGradient(
                colors: const [
                  Colors.white,
                  Colors.white,
                  Colors.transparent,
                  Colors.transparent,
                ],
                stops: [0, solidUntil, fadeUntil, 1],
              ).createShader(bounds),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Section opener: tracked kicker over a serif title, on the 64px rhythm.
class SectionHeading extends StatefulWidget {
  const SectionHeading({
    required this.kicker,
    required this.title,
    this.trailing,
    this.animateKickerColor = false,
    super.key,
  });

  final String kicker;
  final String title;
  final Widget? trailing;
  final bool animateKickerColor;

  @override
  State<SectionHeading> createState() => _SectionHeadingState();
}

class _SectionHeadingState extends State<SectionHeading> {
  bool _titleRevealed = false;

  void _handleTitleRevealed() {
    if (_titleRevealed || !mounted) return;
    setState(() => _titleRevealed = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.monettaColors;
    final completedKickerColor = Theme.of(context).brightness == Brightness.dark
        ? kPurpleOnDark
        : kPurple;
    final kickerColor = widget.animateKickerColor
        ? (_titleRevealed ? completedKickerColor : colors.accent)
        : colors.contentMuted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: reduceMotion(context) ? Duration.zero : kSwap,
                  curve: kMotionCurve,
                  style: eyebrow(color: kickerColor),
                  child: Text(widget.kicker.toUpperCase()),
                ),
                const SizedBox(height: 8),
                EditorialTitleReveal(
                  text: widget.title,
                  style: editorial(25, color: colors.contentPrimary),
                  onCompleted:
                      widget.animateKickerColor ? _handleTitleRevealed : null,
                ),
              ],
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ThemeData
// ---------------------------------------------------------------------------

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final colors =
      brightness == Brightness.dark ? MonettaColors.dark : MonettaColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.accent,
    primary: colors.actionPrimary,
    onPrimary: colors.onActionPrimary,
    secondary: colors.accent,
    surface: colors.surface,
    onSurface: colors.contentPrimary,
    error: colors.sale,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: MonettaPageTransitionsBuilder(),
        TargetPlatform.iOS: MonettaPageTransitionsBuilder(),
        TargetPlatform.macOS: MonettaPageTransitionsBuilder(),
      },
    ),
    fontFamily: kSansFontFamily,
    fontFamilyFallback: kSansFontFallback,
    brightness: brightness,
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[colors],
    scaffoldBackgroundColor: colors.canvas,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: colors.divider,
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: 0.5,
      space: 0.5,
    ),
    appBarTheme: AppBarTheme(
      // Light app bars share the bottom bar's grey; dark keeps its surface.
      backgroundColor: brightness == Brightness.dark
          ? colors.surface
          : colors.navigationSurface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colors.contentPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: wordmark(color: colors.contentPrimary),
      iconTheme: IconThemeData(color: colors.contentPrimary, size: 21),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
        systemNavigationBarColor: colors.canvas,
        systemNavigationBarDividerColor: colors.divider,
        systemNavigationBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: display(34, color: colors.contentPrimary),
      displayMedium: display(28, color: colors.contentPrimary),
      titleLarge: display(22, color: colors.contentPrimary),
      titleMedium: sans(
        size: 14,
        weight: FontWeight.w500,
        color: colors.contentPrimary,
      ),
      bodyMedium: sans(color: colors.contentPrimary),
      bodySmall: sans(size: 12, color: colors.contentMuted),
      labelSmall: eyebrow(color: colors.contentMuted),
    ),
    iconTheme: IconThemeData(color: colors.contentPrimary),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceTile,
      selectedColor: colors.actionPrimary,
      side: BorderSide(color: colors.divider),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontSize: 13,
        color: colors.contentPrimary,
        letterSpacing: 0.1,
      ),
      secondaryLabelStyle: TextStyle(
        fontSize: 13,
        color: colors.onActionPrimary,
        letterSpacing: 0.1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    // Brown pill: the principal purchase action (style guideline §3). Dark mode
    // keeps its own accent through [MonettaColors.dark.actionPrimary].
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.actionPrimary,
        foregroundColor: colors.onActionPrimary,
        disabledBackgroundColor: colors.surfaceMuted,
        disabledForegroundColor: colors.contentMuted,
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(MonettaTokens.controlHeight),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.contentPrimary,
        side: BorderSide(color: colors.borderControl),
        shape: const StadiumBorder(),
        minimumSize: const Size.fromHeight(MonettaTokens.controlHeight),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.inverseSurface,
      contentTextStyle: sans(size: 12.5, color: colors.onInverseSurface),
      shape: const RoundedRectangleBorder(borderRadius: kSquare),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: colors.surfaceRaised,
      modalBarrierColor: colors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MonettaTokens.radiusSheet),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MonettaTokens.radiusSheet),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.inputFill,
      labelStyle: sans(size: 12.5, color: colors.contentMuted),
      hintStyle: sans(size: 12.5, color: colors.contentMuted),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.borderControl),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.contentPrimary),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.sale),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.surface
            : colors.contentMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.accent
            : colors.surfaceMuted,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.surfaceMuted,
      circularTrackColor: colors.surfaceMuted,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.contentPrimary,
      selectionColor: colors.accent.withValues(alpha: 0.28),
      selectionHandleColor: colors.accent,
    ),
  );
}

ThemeData buildLightTheme() => buildTheme();

ThemeData buildDarkTheme() => buildTheme(brightness: Brightness.dark);
