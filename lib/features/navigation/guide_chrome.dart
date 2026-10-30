/// Header shared by the client-guide screens.
///
/// Hamburger on the left, the official wordmark in the center, search on
/// the right. The button opens whatever drawer the surrounding [Scaffold]
/// installed.
library;

import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../boutique/boutique_tokens.dart';

AppBar guideAppBar(
  BuildContext context, {
  required VoidCallback onSearch,
  bool searchEnabled = true,
  VoidCallback? onBack,
}) {
  final palette = context.boutique;
  final goBack = onBack ??
      (Navigator.canPop(context)
          ? () => unawaited(Navigator.of(context).maybePop())
          : null);
  return AppBar(
    automaticallyImplyLeading: false,
    backgroundColor: palette.bar,
    foregroundColor: palette.ink,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    titleSpacing: 0,
    leadingWidth: 56,
    leading: goBack != null
        ? IconButton(
            tooltip: 'Volver',
            onPressed: goBack,
            icon: const Icon(Icons.arrow_back),
          )
        : Builder(
            builder: (scaffoldContext) => IconButton(
              key: const Key('home-menu-button'),
              tooltip: 'Abrir menú',
              onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              icon: const Icon(Icons.menu_rounded, size: 22),
            ),
          ),
    title: const MonettaWordmark.appBar(),
    actions: [
      if (goBack != null)
        Builder(
          builder: (scaffoldContext) => IconButton(
            key: const Key('home-menu-button'),
            tooltip: 'Abrir menú',
            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
            icon: const Icon(Icons.menu_rounded, size: 22),
          ),
        ),
      IconButton(
        key: const ValueKey('guide-search-button'),
        tooltip: 'Buscar',
        onPressed: searchEnabled ? onSearch : null,
        icon: const Icon(Icons.search, size: 22),
      ),
      const SizedBox(width: BoutiqueSpace.xs),
    ],
  );
}
