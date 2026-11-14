/// Brand destinations share the collection query and recovery contract.
library;

import 'package:flutter/material.dart';
import '../../app/motion.dart';
import '../../main.dart';
import '../../reco/explainer.dart' show brandLabel;
import '../navigation/duo_workspace.dart';
import 'browse_detail_layout.dart';
import 'collection_screen.dart';

String brandLogoAsset(String slug) => 'assets/images/brands/$slug.webp';

Future<void> openBrand(
  BuildContext context, {
  required String brandSlug,
  String? title,
  String? tagline,
  String? story,
  String? heroImageUrl,
  String? heroImageAsset,
}) async {
  final store = StoreScope.of(context);
  final account = AccountScope.maybeOf(context);
  final content = HomeContentScope.maybeOf(context);
  Widget screen = StoreScope(
    notifier: store,
    child: BrowseDetailLayout(
      child: BrandScreen(
        brandSlug: brandSlug,
        title: title,
        tagline: tagline,
        story: story,
        heroImageUrl: heroImageUrl,
        heroImageAsset: heroImageAsset,
      ),
    ),
  );
  if (account != null) screen = AccountScope(notifier: account, child: screen);
  if (content != null) {
    screen = HomeContentScope(notifier: content, child: screen);
  }
  await DuoWorkspace.navigatorFor(context).push<void>(monettaFadeRoute(screen));
}

class BrandScreen extends StatelessWidget {
  const BrandScreen({
    required this.brandSlug,
    this.title,
    this.tagline,
    this.story,
    this.heroImageUrl,
    this.heroImageAsset,
    super.key,
  });

  /// Canonical facet value — `coach`, `michael_kors`, `guess`. Never a raw
  /// Shopify `vendor`, which is the shop name on most of this catalog.
  final String brandSlug;

  /// Defaults to the shopper-facing label for [brandSlug].
  final String? title;

  /// One short owner-authored line under the wordmark. Hidden when null.
  final String? tagline;

  /// "Sobre la marca". The whole block disappears when there is no text —
  /// no placeholder paragraph, no invented authenticity claims.
  final String? story;

  /// Brand photography. Only pass artwork that is verifiably this brand's;
  /// with none, the header is the wordmark on a neutral ground.
  final String? heroImageUrl;
  final String? heroImageAsset;

  @override
  Widget build(BuildContext context) => CollectionScreen(
        title: title ?? brandLabel(brandSlug),
        filter: CollectionFilter(brand: brandSlug),
        description: tagline,
        story: story,
        heroImageUrl: heroImageUrl,
        heroImageAsset: heroImageAsset,
      );
}
