/// One editorial heading for every interior page, matching the bag.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../boutique/boutique_tokens.dart';

TextStyle monettaPageTitleStyle(BuildContext context) => boutiqueDisplay(
      MediaQuery.sizeOf(context).width >= 860 ? 32 : 28,
      color: context.boutique.ink,
    );

class MonettaSheetHeading extends StatelessWidget {
  const MonettaSheetHeading({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
          ),
          Expanded(child: Text(title, style: monettaPageTitleStyle(context))),
        ],
      );
}

AppBar buildMonettaPageAppBar(
  BuildContext context, {
  required String title,
  VoidCallback? onBack,
  List<Widget> actions = const [],
  double actionsWidth = 0,
  String? trailingLabel,
  Widget? subtitle,
  Key? titleKey,
  Key? backKey,
  Key? titleRowKey,
}) {
  final palette = context.boutique;
  final style = monettaPageTitleStyle(context);
  final scaler = MediaQuery.textScalerOf(context);
  final actionExtent = actionsWidth > 0 ? actionsWidth : actions.length * 48.0;
  var trailingExtent = 0.0;
  if (trailingLabel != null) {
    final trailingPainter = TextPainter(
      text: TextSpan(text: trailingLabel, style: boutiqueText(size: 12)),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    trailingExtent = trailingPainter.width + 16;
    trailingPainter.dispose();
  }
  final painter = TextPainter(
    text: TextSpan(text: title, style: style),
    textDirection: Directionality.of(context),
    textScaler: scaler,
    maxLines: 2,
    ellipsis: '…',
  )..layout(
      maxWidth: math.max(
        1,
        MediaQuery.sizeOf(context).width -
            MediaQuery.paddingOf(context).horizontal -
            48 -
            20 -
            actionExtent -
            trailingExtent,
      ),
    );
  final toolbarHeight = math.max(
    76.0,
    painter.height + (subtitle == null ? 0 : scaler.scale(12) * 1.5 + 2) + 16,
  );
  painter.dispose();

  return AppBar(
    toolbarHeight: toolbarHeight,
    backgroundColor: palette.canvas,
    foregroundColor: palette.ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: false,
    centerTitle: false,
    titleSpacing: 0,
    leadingWidth: 48,
    leading: IconButton(
      key: backKey ?? const ValueKey('monetta-page-back'),
      tooltip: 'Volver',
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back, size: 20),
    ),
    title: Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        key: titleRowKey,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  key: titleKey ?? const ValueKey('monetta-page-title'),
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: style,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  subtitle,
                ],
              ],
            ),
          ),
          if (trailingLabel != null) ...[
            const SizedBox(width: 16),
            Text(
              trailingLabel,
              style: boutiqueText(size: 12, color: palette.inkMuted),
            ),
          ],
        ],
      ),
    ),
    actions: actions,
  );
}
