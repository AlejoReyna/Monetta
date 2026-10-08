/// Header shared by the Monetta ficha and the external ficha.
///
/// Carries the identity of the piece (its name, in the face of the card names)
/// instead of the wordmark. Back sits on the left; the actions of each ficha
/// sit on the right. Both sides reserve the same width, so the title is
/// centred exactly whether there are two actions or none.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';

/// Gap between a screen edge and the first 48 px action.
const double kProductHeaderEdgeInset = 4;

/// Side of a tappable action.
const double kProductHeaderActionExtent = 48;

/// Horizontal air around the title inside its reserved band.
const double _kTitlePadding = 4;

/// Vertical air around a two-line title.
const double _kTitleVerticalAir = 16;

const int _kTitleMaxLines = 2;

double _slotWidth(int slots) =>
    kProductHeaderEdgeInset + kProductHeaderActionExtent * math.max(1, slots);

/// Height the header needs for [title]: 56 for one line, taller when the
/// title wraps to a second line or the text scale grows. Never clips.
double productHeaderToolbarHeight(
  BuildContext context, {
  required String title,
  required int slots,
}) {
  final width = MediaQuery.sizeOf(context).width -
      2 * _slotWidth(slots) -
      2 * _kTitlePadding;
  final painter = TextPainter(
    text: TextSpan(text: title, style: boutiqueHeaderName()),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: _kTitleMaxLines,
    ellipsis: '…',
  )..layout(maxWidth: math.max(0, width));
  final height = painter.height;
  painter.dispose();
  return math.max(kToolbarHeight, height + _kTitleVerticalAir);
}

/// App bar of a product page.
///
/// [actions] are the 48 px buttons on the right and [actionSlots] their
/// count (0 when there are none). The left and right bands both reserve
/// room for `max(1, actionSlots)` buttons.
AppBar buildProductDetailAppBar(
  BuildContext context, {
  required String title,
  required VoidCallback onBack,
  List<Widget> actions = const [],
  int actionSlots = 0,
}) {
  final palette = context.boutique;
  final slots = math.max(1, actionSlots);
  final slot = _slotWidth(slots);
  return AppBar(
    backgroundColor: palette.bar,
    foregroundColor: palette.ink,
    centerTitle: true,
    titleSpacing: 0,
    leadingWidth: slot,
    toolbarHeight: productHeaderToolbarHeight(
      context,
      title: title,
      slots: slots,
    ),
    leading: Padding(
      padding: const EdgeInsets.only(left: kProductHeaderEdgeInset),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          key: const Key('product-header-back'),
          icon: const Icon(Icons.arrow_back, size: 20),
          tooltip: 'Volver',
          onPressed: onBack,
        ),
      ),
    ),
    title: Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kTitlePadding),
      child: Text(
        title,
        key: const Key('product-header-title'),
        maxLines: _kTitleMaxLines,
        // The app bar sets `softWrap: false` for its titles; a name that may
        // take two lines has to opt back in.
        softWrap: true,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: boutiqueHeaderName(color: palette.ink),
      ),
    ),
    actions: [
      ...actions,
      // Fills the right band up to the left one when there are fewer than
      // `slots` buttons, and supplies the matching edge inset.
      SizedBox(
        width: slot - kProductHeaderActionExtent * actionSlots,
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(0.5),
      child: Divider(height: 0.5, color: palette.hairline),
    ),
  );
}
