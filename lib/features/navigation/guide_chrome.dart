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
import '../boutique/client_guide_components.dart';
import '../boutique/guide_art.dart';

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
    leadingWidth: 64,
    toolbarHeight: 64,
    leading: goBack != null
        ? GuideGlassIconButton(
            tooltip: 'Volver',
            onPressed: goBack,
            icon: const GuideSemanticImage(
                id: 'icon:back', width: 22, height: 22),
          )
        : Builder(
            builder: (scaffoldContext) => GuideGlassIconButton(
              key: const Key('home-menu-button'),
              tooltip: 'Abrir menú',
              onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              icon: const GuideSemanticImage(
                  id: 'icon:menu', width: 22, height: 22),
            ),
          ),
    title: const MonettaWordmark.appBar(),
    actions: [
      if (goBack != null)
        Builder(
          builder: (scaffoldContext) => GuideGlassIconButton(
            key: const Key('home-menu-button'),
            tooltip: 'Abrir menú',
            onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
            icon: const GuideSemanticImage(
                id: 'icon:menu', width: 22, height: 22),
          ),
        ),
      GuideGlassIconButton(
        key: const ValueKey('guide-search-button'),
        tooltip: 'Buscar',
        onPressed: searchEnabled ? onSearch : null,
        icon:
            const GuideSemanticImage(id: 'icon:search', width: 22, height: 22),
      ),
      const SizedBox(width: BoutiqueSpace.xs),
    ],
  );
}
