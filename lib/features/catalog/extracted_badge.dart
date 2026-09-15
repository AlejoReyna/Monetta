import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Compact visual marker for listings sourced from external merchant sites.
///
/// It intentionally sits on the product image so it remains visible in the
/// home feed, the external rail, and the full catalog without consuming an
/// additional caption line.
class ExtractedBadge extends StatelessWidget {
  const ExtractedBadge({super.key});

  static const String label = 'extracted';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Artículo extraído de un sitio externo',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.monettaColors.contentPrimary.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text(
            label,
            style: sans(
              size: 8,
              color: Colors.white,
              weight: FontWeight.w600,
            ).copyWith(letterSpacing: 0.45),
          ),
        ),
      ),
    );
  }
}
