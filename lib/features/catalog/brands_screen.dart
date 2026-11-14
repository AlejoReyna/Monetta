/// All configured, resolvable brands, independent of category navigation.
library;

import 'package:flutter/material.dart';
import '../../domain/home_content.dart';
import '../../main.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import '../boutique/boutique_tokens.dart';
import '../../app/monetta_tokens.g.dart';
import '../navigation/duo_workspace.dart';
import 'brand_screen.dart';
import 'categories_screen.dart';

Future<void> openBrands(BuildContext context) async {
  final store = StoreScope.maybeOf(context);
  final account = AccountScope.maybeOf(context);
  final contentController = HomeContentScope.maybeOf(context);
  final content = contentController?.content;
  Widget screen = BrandsScreen(content: content);
  if (store != null) screen = StoreScope(notifier: store, child: screen);
  if (account != null) screen = AccountScope(notifier: account, child: screen);
  if (contentController != null) {
    screen = HomeContentScope(notifier: contentController, child: screen);
  }
  await DuoWorkspace.navigatorFor(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/brands'),
      builder: (_) => screen,
    ),
  );
}

class BrandsScreen extends StatelessWidget {
  const BrandsScreen({this.content, super.key});
  final HomeContent? content;
  @override
  Widget build(BuildContext context) => ClientGuideScaffold(
        current: ClientGuideDestination.categories,
        body: Center(
          child: SizedBox(
            width: 800,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Todas las marcas',
                  style: clientGuideStyle(context, MonettaTokens.screenTitle),
                ),
                BrandDirectory(content: content),
              ],
            ),
          ),
        ),
      );
}

class BrandDirectory extends StatelessWidget {
  const BrandDirectory({this.content, super.key});
  final HomeContent? content;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.maybeOf(context);
    final source = content ??
        HomeContentScope.maybeOf(context)?.content ??
        HomeContent.fallback;
    if (store != null && !store.ready) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final seen = <String>{};
    final brands = source.brands.where((brand) {
      final slug = guideBrandSlug(brand, store);
      return slug.isNotEmpty && seen.add(slug);
    }).toList();
    return Column(
      children: [
        if (brands.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No hay marcas disponibles.'),
          ),
        for (final brand in brands)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _DirectoryBrandCard(
              key: ValueKey('directory-brand-${guideBrandSlug(brand, store)}'),
              brand: brand,
              onTap: () => openBrand(
                context,
                brandSlug: guideBrandSlug(brand, store),
                title: brand.title,
              ),
            ),
          ),
      ],
    );
  }
}

class _DirectoryBrandCard extends StatelessWidget {
  const _DirectoryBrandCard({
    required this.brand,
    required this.onTap,
    super.key,
  });
  final HomeBrandCard brand;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => Center(
          child: Text(
            brand.title,
            textAlign: TextAlign.center,
            style: boutiqueText(size: 20, color: context.boutique.goldText),
          ),
        );
    Widget bundled() => Image.asset(
          brand.fallbackAsset,
          fit: BoxFit.fitWidth,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => fallback(),
        );
    return Semantics(
      label: brand.title,
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: GuideGlassSurface(
        opaque: true,
        radius: 32,
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: AspectRatio(
              aspectRatio: 3.2,
              child: ClipRect(
                child: brand.imageUrl == null || brand.imageUrl!.isEmpty
                    ? bundled()
                    : Image.network(
                        brand.imageUrl!,
                        fit: BoxFit.fitWidth,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => bundled(),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
