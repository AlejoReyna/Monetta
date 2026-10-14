/// The product header mirrors Home's brand navigation, with back in place
/// of the menu. The photograph and the product name remain in the content.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../boutique/boutique_tokens.dart';

const double kProductHeaderEdgeInset = 4;
const double kProductHeaderActionExtent = 48;

AppBar buildProductDetailAppBar(
  BuildContext context, {
  required VoidCallback onBack,
  required VoidCallback onSearch,
  List<Widget> actions = const [],
}) {
  final palette = context.boutique;
  final sideWidth = kProductHeaderEdgeInset + kProductHeaderActionExtent * 2;
  return AppBar(
    toolbarHeight: 60,
    backgroundColor: palette.canvas,
    foregroundColor: palette.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: false,
    centerTitle: true,
    titleSpacing: 8,
    leadingWidth: sideWidth,
    leading: Padding(
      padding: const EdgeInsets.only(left: kProductHeaderEdgeInset),
      child: Row(
        children: [
          SizedBox.square(
            dimension: kProductHeaderActionExtent,
            child: IconButton(
              key: const Key('product-header-back'),
              icon: const Icon(Icons.arrow_back, size: 20),
              tooltip: 'Volver',
              onPressed: onBack,
            ),
          ),
          SizedBox.square(
            dimension: kProductHeaderActionExtent,
            child: IconButton(
              key: const Key('product-header-search'),
              icon: const Icon(Icons.search, size: 22),
              tooltip: 'Buscar productos',
              onPressed: onSearch,
            ),
          ),
        ],
      ),
    ),
    title: const FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: kAppBarWordmarkHeight * 3.47,
        height: kAppBarWordmarkHeight,
        child: MonettaWordmark.appBar(key: Key('product-header-title')),
      ),
    ),
    actions: [
      for (final action in actions)
        SizedBox.square(
          dimension: kProductHeaderActionExtent,
          child: Center(child: action),
        ),
      SizedBox(
        width: sideWidth - kProductHeaderActionExtent * actions.length,
      ),
    ],
  );
}
