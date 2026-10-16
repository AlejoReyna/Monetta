/// The single gold M used as a mark, not the full wordmark bitmap.
library;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../boutique/boutique_tokens.dart';

class MonettaMMark extends StatelessWidget {
  const MonettaMMark({required this.size, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'M',
      textAlign: TextAlign.center,
      style: editorial(
        size,
        color: color ?? context.boutique.gold,
        height: 1,
        weight: FontWeight.w500,
      ),
    );
  }
}
