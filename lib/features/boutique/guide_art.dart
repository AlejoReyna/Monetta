/// Decorative stills supplied for the client guide.
///
/// Product photographs and brand marks are not in these files. A missing file
/// falls back to the warm canvas so a later drop-in replaces it with no code
/// change. `producto_fondo` is intentionally not registered: Shopify photos in
/// this catalog are opaque packshots, not cutouts.
library;

import 'package:flutter/material.dart';

import '../../app/monetta_tokens.g.dart';
import 'boutique_tokens.dart';

const String kGuideWelcomeBackground =
    'assets/images/guide/bienvenida_fondo.jpg';
const String kGuideStudioBanner = 'assets/images/guide/studio_banner_fondo.jpg';
const String kGuideShareBanner =
    'assets/images/guide/comparte_banner_fondo.jpg';

// Owner photographs (about 2.4:1). Each one leaves one side empty for text.
const String kGuideHomeBannerEasy =
    'assets/images/guide/home_banner_compra_facil.jpg';
const String kGuideHomeBannerNew =
    'assets/images/guide/home_banner_nueva_coleccion.jpg';
const String kGuideHomeBannerPerfumes =
    'assets/images/guide/home_banner_perfumes.jpg';
const String kGuideHomeWholesale =
    'assets/images/guide/home_precios_mayoreo.jpg';
const String kGuideWholesaleHero = 'assets/images/guide/mayoreo_hero.jpg';
const String kGuideWholesaleBags =
    'assets/images/guide/mayoreo_bolsos_carteras.jpg';
const String kGuideWholesalePerfumes =
    'assets/images/guide/mayoreo_perfumes.jpg';
const String kGuideContactHero = 'assets/images/guide/contacto_hero.jpg';
const String kGuideShareCatalog =
    'assets/images/guide/comparte_gana_catalogo.jpg';
const String kGuideShareRewards =
    'assets/images/guide/comparte_gana_rewards.jpg';

// Gold and silver line icons (transparent PNG) drawn for the guide.
const String kGuideIconStyleCrossbody =
    'assets/images/guide/icons/estilo_crossbody.png';
const String kGuideIconStyleTote = 'assets/images/guide/icons/estilo_tote.png';
const String kGuideIconStyleShoulder =
    'assets/images/guide/icons/estilo_shoulder.png';
const String kGuideIconStyleSatchel =
    'assets/images/guide/icons/estilo_satchel.png';
const String kGuideIconStylePerfumes =
    'assets/images/guide/icons/estilo_perfumes.png';
const String kGuideIconServiceShipping =
    'assets/images/guide/icons/servicio_envios.png';
const String kGuideIconServicePayments =
    'assets/images/guide/icons/servicio_pagos.png';
const String kGuideIconServiceOriginals =
    'assets/images/guide/icons/servicio_originales.png';
const String kGuideIconServiceSupport =
    'assets/images/guide/icons/servicio_atencion.png';
const String kGuideIconContactWhatsApp =
    'assets/images/guide/icons/contacto_whatsapp.png';
const String kGuideIconContactGroup =
    'assets/images/guide/icons/contacto_grupo.png';
const String kGuideIconCategoryCrossbody =
    'assets/images/guide/icons/categoria_crossbody.png';
const String kGuideIconCategoryTote =
    'assets/images/guide/icons/categoria_tote.png';
const String kGuideIconCategoryShoulder =
    'assets/images/guide/icons/categoria_shoulder.png';
const String kGuideIconCategoryHandbags =
    'assets/images/guide/icons/categoria_handbags.png';
const String kGuideIconCategoryWallets =
    'assets/images/guide/icons/categoria_carteras.png';
const String kGuideIconCategoryPerfumes =
    'assets/images/guide/icons/categoria_perfumes.png';
const String kGuideIconCategoryAccessories =
    'assets/images/guide/icons/categoria_accesorios.png';
const String kGuideIconInstagram =
    'assets/images/guide/icons/red_instagram.png';
const String kGuideIconFacebook = 'assets/images/guide/icons/red_facebook.png';
const String kGuideIconTikTok = 'assets/images/guide/icons/red_tiktok.png';

/// Serif of the text that sits on the guide's photographs and banner buttons.
///
/// The guide uses Reglarik, which is licensed; Cormorant Garamond (OFL) is
/// the free stand-in. Screen titles keep the app's own serif.
const String kGuideSerifFamily = 'Cormorant Garamond';

/// Script of the guide's accent words («fácil», «mayoreo», «Comparte»,
/// «confianza.»). Stand-in for Above the Beyond Script; Mrs Saint Delafield
/// is OFL.
const String kGuideScriptFamily = 'Mrs Saint Delafield';

const String kGuideCollectionCoach = 'assets/images/guide/coleccion_coach.jpg';
const String kGuideCollectionMichaelKors =
    'assets/images/guide/coleccion_michael_kors.jpg';
const String kGuideCollectionSteveMadden =
    'assets/images/guide/coleccion_steve_madden.jpg';
const String kGuideCollectionToryBurch =
    'assets/images/guide/coleccion_tory_burch.jpg';
const String kGuideCollectionKateSpade =
    'assets/images/guide/coleccion_kate_spade.jpg';
const String kGuideCollectionMarcJacobs =
    'assets/images/guide/coleccion_marc_jacobs.jpg';
const String kGuideCollectionTotes = 'assets/images/guide/coleccion_totes.jpg';
const String kGuideCollectionShoulder =
    'assets/images/guide/coleccion_shoulder.jpg';
const String kGuideCollectionCrossbody =
    'assets/images/guide/coleccion_crossbody.jpg';
const String kGuideCollectionHandbags =
    'assets/images/guide/coleccion_bolsos_de_mano.jpg';
const String kGuideCollectionWallets =
    'assets/images/guide/coleccion_carteras.jpg';
const String kGuideCollectionPerfumes =
    'assets/images/guide/coleccion_perfumes.jpg';
const String kGuideCollectionAccessories =
    'assets/images/guide/coleccion_accesorios.jpg';

/// Side of a photograph that stays empty so text can sit on it.
enum GuideTextSide { left, right }

/// A guide photograph and the side of it that carries the text.
@immutable
class GuidePhoto {
  const GuidePhoto(this.asset, this.textSide);

  final String asset;
  final GuideTextSide textSide;

  @override
  bool operator ==(Object other) =>
      other is GuidePhoto && other.asset == asset && other.textSide == textSide;

  @override
  int get hashCode => Object.hash(asset, textSide);

  @override
  String toString() => 'GuidePhoto($asset, $textSide)';
}

const Map<String, GuidePhoto> _kBrandPhotos = <String, GuidePhoto>{
  'coach': GuidePhoto(kGuideCollectionCoach, GuideTextSide.right),
  'michael_kors': GuidePhoto(kGuideCollectionMichaelKors, GuideTextSide.right),
  'steve_madden': GuidePhoto(kGuideCollectionSteveMadden, GuideTextSide.right),
  'tory_burch': GuidePhoto(kGuideCollectionToryBurch, GuideTextSide.right),
  'kate_spade': GuidePhoto(kGuideCollectionKateSpade, GuideTextSide.right),
  'marc_jacobs': GuidePhoto(kGuideCollectionMarcJacobs, GuideTextSide.left),
};

const Map<String, GuidePhoto> _kSilhouettePhotos = <String, GuidePhoto>{
  'tote': GuidePhoto(kGuideCollectionTotes, GuideTextSide.left),
  'totes': GuidePhoto(kGuideCollectionTotes, GuideTextSide.left),
  'shoulder': GuidePhoto(kGuideCollectionShoulder, GuideTextSide.left),
  'crossbody': GuidePhoto(kGuideCollectionCrossbody, GuideTextSide.left),
  'satchel': GuidePhoto(kGuideCollectionHandbags, GuideTextSide.left),
  'handbag': GuidePhoto(kGuideCollectionHandbags, GuideTextSide.left),
  'bolsa_de_mano': GuidePhoto(kGuideCollectionHandbags, GuideTextSide.left),
  'bolso_de_mano': GuidePhoto(kGuideCollectionHandbags, GuideTextSide.left),
};

const Map<String, GuidePhoto> _kCategoryPhotos = <String, GuidePhoto>{
  'cartera': GuidePhoto(kGuideCollectionWallets, GuideTextSide.left),
  'carteras': GuidePhoto(kGuideCollectionWallets, GuideTextSide.left),
  'perfume': GuidePhoto(kGuideCollectionPerfumes, GuideTextSide.left),
  'perfumes': GuidePhoto(kGuideCollectionPerfumes, GuideTextSide.left),
  // The accessories still is a watch photograph, so `reloj` shares it.
  'accesorio': GuidePhoto(kGuideCollectionAccessories, GuideTextSide.left),
  'accesorios': GuidePhoto(kGuideCollectionAccessories, GuideTextSide.left),
  'reloj': GuidePhoto(kGuideCollectionAccessories, GuideTextSide.left),
  'relojes': GuidePhoto(kGuideCollectionAccessories, GuideTextSide.left),
  'bolsa': GuidePhoto(kGuideWholesaleBags, GuideTextSide.left),
  'bolsas': GuidePhoto(kGuideWholesaleBags, GuideTextSide.left),
};

/// `Michael Kors`, `michael-kors` and `michael_kors` are the same key.
String? _guideKey(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return null;
  return value.replaceAll(RegExp(r'[\s\-]+'), '_');
}

/// The guide photograph for a collection or brand, or null when there is none
/// (the caller then keeps its current banner).
///
/// Precedence is brand, then silhouette, then category: the narrowest scope
/// that has artwork wins. A brand without its own still never borrows the
/// still of another brand; it falls through to silhouette and category.
GuidePhoto? guideCollectionPhoto({
  String? brand,
  String? silhouette,
  String? category,
}) {
  final byBrand = _kBrandPhotos[_guideKey(brand)];
  if (byBrand != null) return byBrand;
  final bySilhouette = _kSilhouettePhotos[_guideKey(silhouette)];
  if (bySilhouette != null) return bySilhouette;
  return _kCategoryPhotos[_guideKey(category)];
}

/// Whether [photo] is a brand's still. A brand title reads upright on the
/// guide's collection banner («COACH»); a silhouette or category reads in
/// italic («TOTES»).
bool guidePhotoIsBrand(GuidePhoto photo) => _kBrandPhotos.containsValue(photo);

/// Upright guide serif (Cormorant Garamond) for titles on photographs.
TextStyle guideSerifStyle(
  BuildContext context, {
  required double size,
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.08,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: kGuideSerifFamily,
    fontFamilyFallback: kBoutiqueSerifFallback,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color ?? context.boutique.ink,
  );
}

/// Italic guide serif, for the bodies on photographs and for category titles.
TextStyle guideSerifItalicStyle(
  BuildContext context, {
  required double size,
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.12,
  double letterSpacing = 0,
}) {
  return guideSerifStyle(
    context,
    size: size,
    color: color,
    weight: weight,
    height: height,
    letterSpacing: letterSpacing,
  ).copyWith(fontStyle: FontStyle.italic);
}

/// Accent face of the guide: the script, in gold unless told otherwise.
///
/// [underline] draws the guide's gold stroke under the word («mayoreo»,
/// «confianza.»).
TextStyle guideAccentStyle(
  BuildContext context, {
  required double size,
  Color? color,
  bool underline = false,
}) {
  final palette = context.boutique;
  return TextStyle(
    fontFamily: kGuideScriptFamily,
    fontFamilyFallback: kBoutiqueSerifFallback,
    fontStyle: FontStyle.normal,
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: 1.05,
    color: color ?? palette.goldText,
    decoration: underline ? TextDecoration.underline : TextDecoration.none,
    decorationColor: palette.gold,
    decorationThickness: underline ? 1.6 : null,
  );
}

/// Light-gold pill of the guide's photo banners («VER CATÁLOGO», «CONOCE
/// MÁS»): dark label in capitals of the guide serif.
///
/// The pill itself is low, but its tap target is never under 44 logical
/// pixels tall or wide.
class GuidePillButton extends StatelessWidget {
  const GuidePillButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  /// Light gold of the pill. Fixed in both brightness modes: it sits on a
  /// photograph that is itself light.
  static const Color fill = Color(0xFFCDB48D);

  /// Dark brown of the label (9:1 on [fill]).
  static const Color labelColor = Color(0xFF2B2118);

  /// Minimum tap target, in logical pixels.
  static const double minTarget = 44;

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final width = MediaQuery.sizeOf(context).width;
    final size = (width * 0.033).clamp(12.0, 16.0);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(minTarget),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: minTarget,
              minHeight: minTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Opacity(
                opacity: enabled ? 1 : 0.55,
                child: DecoratedBox(
                  decoration: const ShapeDecoration(
                    color: fill,
                    shape: StadiumBorder(),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size * 1.4,
                      vertical: size * 0.45,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: guideSerifStyle(
                          context,
                          size: size,
                          color: labelColor,
                          weight: FontWeight.w500,
                          height: 1.1,
                          letterSpacing: size * 0.08,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Loads a guide still. Failure paints the warm surface and nothing else.
class GuideArt extends StatelessWidget {
  const GuideArt({
    required this.asset,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    super.key,
  });

  final String asset;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: fit,
      alignment: alignment,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          ColoredBox(color: context.boutique.surfaceDeep),
    );
  }
}

/// Height of a hero that shows an owner photograph close to its own 2.4:1
/// proportions, so the empty side stays wide enough for the text.
double guidePhotoHeroHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).width / 1.6).clamp(200.0, 340.0);

/// Cream wash on the text side of a photograph, fading toward the subject.
class GuideScrim extends StatelessWidget {
  const GuideScrim({required this.textSide, super.key});

  final GuideTextSide textSide;

  @override
  Widget build(BuildContext context) {
    final fromLeft = textSide == GuideTextSide.left;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: fromLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: fromLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [
              Color(0xE6FBF6EE),
              Color(0x99FBF6EE),
              Color(0x00FBF6EE),
            ],
            stops: const [0, 0.42, 0.78],
          ),
        ),
      ),
    );
  }
}

/// Full-bleed banner: guide still, headline on the free side, optional action.
///
/// The headline and its body are set in the guide serif (Cormorant); the
/// body is italic. [titleAccent] adds a script word under the title and
/// [subtitleAccent] an underlined italic run after the subtitle.
class GuideHero extends StatelessWidget {
  const GuideHero({
    required this.asset,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.subtitleAccent,
    this.titleAccent,
    this.action,
    this.height,
    this.onTap,
    this.textSide = GuideTextSide.left,
    this.imageAlignment,
    this.textWidthFactor,
    this.subtitleWidthFactor,
    this.titleItalic = false,
    this.titleSize,
    this.subtitleSize,
    super.key,
  });

  final String asset;
  final String title;

  /// Script word set under [title] with the guide's gold underline.
  final String? titleAccent;
  final String? eyebrow;
  final String? subtitle;

  /// Words that close [subtitle], in italic with a gold underline.
  final String? subtitleAccent;
  final Widget? action;
  final double? height;
  final VoidCallback? onTap;

  /// Side that carries the text. The scrim fades away from it.
  final GuideTextSide textSide;

  /// Where the still is anchored when it is cropped. Defaults to the centre
  /// for left text (the original behaviour) and to the left edge for right
  /// text.
  final Alignment? imageAlignment;

  /// Share of the banner width the title column may use. Null keeps the
  /// original full-width column.
  final double? textWidthFactor;

  /// Share of the banner width the subtitle may use. Defaults to the title
  /// column.
  final double? subtitleWidthFactor;

  /// Sets [title] in the italic serif (the guide's «MAYOREO»).
  final bool titleItalic;

  /// Title size in logical pixels. Defaults to the campaign type role.
  final double? titleSize;

  /// Subtitle size in logical pixels.
  final double? subtitleSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final width = MediaQuery.sizeOf(context).width;
    final resolved = height ?? (width / 1.85).clamp(180.0, 280.0);
    final onRight = textSide == GuideTextSide.right;
    final gutter = MonettaTokens.gutterFor(width);
    final columnWidth = textWidthFactor == null
        ? (width - gutter * 2).clamp(0, width).toDouble()
        : (width * textWidthFactor! - gutter).clamp(0, width).toDouble();
    final subtitleWidth = subtitleWidthFactor == null
        ? (textWidthFactor == null ? width * 0.62 : columnWidth)
        : (width * subtitleWidthFactor! - gutter).clamp(0, width).toDouble();
    final align = onRight ? TextAlign.end : TextAlign.start;
    final titleFontSize =
        titleSize ?? MonettaTokens.campaign.sizeFor(width).toDouble();
    final bodySize = subtitleSize ?? (width * 0.04).clamp(14.0, 20.0);
    final titleStyle = titleItalic
        ? guideSerifItalicStyle(
            context,
            size: titleFontSize,
            color: palette.ink,
            weight: FontWeight.w300,
            height: 1.0,
          )
        : guideSerifStyle(
            context,
            size: titleFontSize,
            color: palette.ink,
            height: 1.02,
          );
    final bodyStyle = guideSerifItalicStyle(
      context,
      size: bodySize,
      color: palette.ink,
      weight: FontWeight.w500,
      height: 1.18,
    );
    return SizedBox(
      height: resolved,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GuideArt(
            asset: asset,
            alignment: imageAlignment ??
                (onRight ? Alignment.centerLeft : Alignment.center),
          ),
          GuideScrim(textSide: textSide),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(gutter),
                child: Align(
                  alignment:
                      onRight ? Alignment.centerRight : Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment:
                        onRight ? Alignment.centerRight : Alignment.centerLeft,
                    child: SizedBox(
                      width: columnWidth,
                      child: Column(
                        crossAxisAlignment: onRight
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (eyebrow != null)
                            Text(
                              eyebrow!,
                              textAlign: align,
                              style: guideSerifStyle(
                                context,
                                size: bodySize,
                                color: palette.ink,
                                letterSpacing: bodySize * 0.12,
                              ),
                            ),
                          if (title.contains(' '))
                            Text(title, textAlign: align, style: titleStyle)
                          else
                            // A single word cannot wrap: it scales to fit.
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: onRight
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Text(
                                title,
                                softWrap: false,
                                textAlign: align,
                                style: titleStyle,
                              ),
                            ),
                          if (titleAccent != null)
                            Text(
                              titleAccent!,
                              textAlign: align,
                              style: guideAccentStyle(
                                context,
                                size: titleFontSize * 1.45,
                                underline: true,
                              ),
                            ),
                          if (subtitle != null) ...[
                            SizedBox(height: MonettaTokens.space[2]),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: subtitleWidth,
                              ),
                              child: Text.rich(
                                TextSpan(
                                  text: subtitle,
                                  children: [
                                    if (subtitleAccent != null)
                                      TextSpan(
                                        text: ' $subtitleAccent',
                                        style: TextStyle(
                                          decoration: TextDecoration.underline,
                                          decorationColor: palette.gold,
                                          decorationThickness: 1.4,
                                          color: palette.goldText,
                                        ),
                                      ),
                                  ],
                                ),
                                textAlign: align,
                                style: bodyStyle,
                              ),
                            ),
                          ],
                          if (action != null) ...[
                            SizedBox(height: MonettaTokens.space[2]),
                            Align(
                              alignment: onRight
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 240,
                                ),
                                child: action!,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wide cream banner used by the WhatsApp prompt.
class GuideShareBanner extends StatelessWidget {
  const GuideShareBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BoutiqueRadius.card,
      child: Stack(
        children: [
          const Positioned.fill(
            child: GuideArt(
              asset: kGuideShareBanner,
              alignment: Alignment.centerRight,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// «Comparte y gana» over an owner photograph, text on the left.
///
/// The photograph keeps its own aspect ratio as a minimum height; a longer
/// body or a larger text size grows the card instead of overflowing it. The
/// photo is anchored to the right so the phone stays visible when the card is
/// narrow.
class GuideShareEarnBanner extends StatelessWidget {
  const GuideShareEarnBanner({
    required this.asset,
    this.body,
    this.action,
    this.actionFullWidth = false,
    super.key,
  });

  /// Aspect ratio of the supplied stills (1290 x 538).
  static const double photoAspect = 1290 / 538;

  final String asset;
  final String? body;
  final Widget? action;

  /// Lays [action] across the whole card under the text block, instead of
  /// inside the narrow text column. For cards too small for a long label.
  final bool actionFullWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return ClipRRect(
      borderRadius: BoutiqueRadius.card,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final accent = (width * 0.17).clamp(40.0, 68.0);
          final gap = MonettaTokens.space[1];
          return Stack(
            children: [
              Positioned.fill(
                child: GuideArt(
                  asset: asset,
                  alignment: Alignment.centerRight,
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: width / photoAspect),
                child: Padding(
                  padding: EdgeInsets.all(MonettaTokens.space[3]),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            // A body runs in a narrower column so it never
                            // reaches the phone.
                            width: width * (body == null ? 0.58 : 0.5) -
                                MonettaTokens.space[3],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  label: 'Comparte y gana',
                                  excludeSemantics: true,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Comparte',
                                          maxLines: 1,
                                          style: guideAccentStyle(
                                            context,
                                            size: accent,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          left: accent * 0.7,
                                        ),
                                        child: Text(
                                          'y gana',
                                          maxLines: 1,
                                          style: guideSerifItalicStyle(
                                            context,
                                            size: accent * 0.5,
                                            color: palette.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (body != null) ...[
                                  SizedBox(height: gap),
                                  Text(
                                    body!,
                                    style: guideSerifItalicStyle(
                                      context,
                                      size: (width * 0.04).clamp(13.0, 18.0),
                                      color: palette.ink,
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                if (action != null && !actionFullWidth) ...[
                                  SizedBox(height: MonettaTokens.space[2]),
                                  action!,
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (action != null && actionFullWidth) ...[
                          SizedBox(height: MonettaTokens.space[2]),
                          action!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
