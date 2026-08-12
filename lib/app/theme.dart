/// Visual language for Monetta's editorial storefront: crisp black type,
/// generous white space, pale catalog grounds, fine dividers, and the brand's
/// own gold reserved for identity and high-value states.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/catalog_item.dart' show Money;

// ---------------------------------------------------------------------------
// Palette
// ---------------------------------------------------------------------------

const Color kInk = Color(0xFF111111);

const Color kInkMuted = Color(0xFF737373);

/// Monetta's accent, rationed. See the library note.
const Color kGold = Color(0xFFAA7D44);

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

const double kSectionGap = 52;

/// Matches the store's `money_format` of `$ {{amount}}` in MXN.
final NumberFormat kMoney = NumberFormat.currency(
  locale: 'es_MX',
  symbol: r'$ ',
  decimalDigits: 2,
);

/// The neutral label shown in place of a price line when [Money] is `null` —
/// an unknown price is never rendered as `$0`, which would read as "free."
const String kUnknownPriceLabel = 'Consultar precio';

/// Renders a mixed-feed [Money] with an explicit currency code — `$1,999
/// MXN`, `$350 USD` — never converted, never inferred. `null` (a genuinely
/// unknown price — see `domain/catalog_item.dart`) renders
/// [kUnknownPriceLabel] rather than being coerced to a number. Used by the
/// external research section (`features/home/external_catalog_section.dart`)
/// and the unified feed/browse screens; the existing Monetta-only screens
/// keep using [kMoney] unchanged.
String formatCatalogMoney(Money? money) {
  if (money == null) return kUnknownPriceLabel;
  final isWhole = money.amount == money.amount.roundToDouble();
  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: isWhole ? 0 : 2,
  );
  return '${formatter.format(money.amount)} ${money.currencyCode}';
}

// ---------------------------------------------------------------------------
// Typography
// ---------------------------------------------------------------------------

const String _displayFamily = 'Helvetica Neue';
const List<String> _displayFallback = <String>[
  'Helvetica',
  'Arial',
  'sans-serif',
];

/// Editorial headline. Clean geometric sans with restrained tracking.
TextStyle display(
  double size, {
  Color color = kInk,
  FontWeight weight = FontWeight.w300,
  double height = 1.3,
}) =>
    TextStyle(
      fontFamily: _displayFamily,
      fontFamilyFallback: _displayFallback,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: size * -0.025,
      height: height,
      color: color,
    );

/// Text fallback for the bitmap wordmark.
TextStyle wordmark({double size = 19, Color color = kInk}) => TextStyle(
      fontFamily: _displayFamily,
      fontFamilyFallback: _displayFallback,
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
  Color color = kInkMuted,
  FontWeight weight = FontWeight.w500,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 1.8,
      height: 1.4,
      color: color,
    );

/// Running text and UI labels — the geometric-sans half of the pairing.
TextStyle sans({
  double size = 13,
  Color color = kInk,
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
  TextDecoration? decoration,
}) =>
    TextStyle(
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
    this.color = kInk,
    this.size = 12,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: sans(size: size, color: color, height: 1.2)),
          const SizedBox(height: 4),
          Container(
            width: label.length * size * 0.55,
            height: 0.8,
            color: color,
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
      errorBuilder: (context, _, __) =>
          Text('MONETTA', style: wordmark(size: height * 0.82)),
    );
  }
}

/// Section opener: tracked kicker over a serif title, on the 64px rhythm.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.kicker,
    required this.title,
    this.trailing,
    super.key,
  });

  final String kicker;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kicker.toUpperCase(), style: eyebrow()),
                const SizedBox(height: 8),
                Text(title, style: display(24)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ThemeData
// ---------------------------------------------------------------------------

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kGold,
    primary: kInk,
    secondary: kGold,
    surface: Colors.white,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerTheme: const DividerThemeData(
      color: kLine,
      thickness: 0.5,
      space: 0.5,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: wordmark(),
      iconTheme: const IconThemeData(color: kInk, size: 21),
    ),
    textTheme: TextTheme(
      displayLarge: display(34),
      displayMedium: display(28),
      titleLarge: display(22),
      titleMedium: sans(size: 14, weight: FontWeight.w500),
      bodyMedium: sans(),
      bodySmall: sans(size: 12, color: kInkMuted),
      labelSmall: eyebrow(),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.transparent,
      side: kHairline,
      shape: RoundedRectangleBorder(borderRadius: kSquare),
      labelStyle: TextStyle(fontSize: 11, color: kInk, letterSpacing: 0.3),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    // Ink, not gold. Dior's committing action is the darkest thing on screen;
    // reserving gold for the apartado makes that CTA the one that stands out.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kInk,
        foregroundColor: Colors.white,
        disabledBackgroundColor: kLine,
        disabledForegroundColor: kInkMuted,
        shape: const RoundedRectangleBorder(borderRadius: kSquare),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kGold,
        side: const BorderSide(color: kGold, width: 0.8),
        shape: const RoundedRectangleBorder(borderRadius: kSquare),
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kInk,
      contentTextStyle: sans(size: 12.5, color: Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: kSquare),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: kSquare),
    ),
  );
}
