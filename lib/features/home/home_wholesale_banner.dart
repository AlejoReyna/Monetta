/// Single B04 wholesale banner with «Comenzar a vender».
library;

import 'package:flutter/material.dart';

import '../boutique/client_guide_components.dart';
import '../boutique/guide_art.dart';

class HomeWholesaleBanner extends StatelessWidget {
  const HomeWholesaleBanner({required this.onOpenWholesale, super.key});

  final VoidCallback onOpenWholesale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('home-section-offers'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GuideBanner(
        id: 'B04',
        action: ClientGuideButton(
          key: const ValueKey('home-wholesale-button'),
          label: 'Comenzar a vender',
          onPressed: onOpenWholesale,
        ),
        onTap: onOpenWholesale,
      ),
    );
  }
}
