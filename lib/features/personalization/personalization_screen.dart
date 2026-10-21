/// Personalización (guía del cliente, página 2).
///
/// Brands come from the catalog already loaded. The eight styles are the same
/// directory as Categorías. Menudeo and Mayoreo are stored per account and are
/// never applied to a price.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/monetta_tokens.g.dart';
import '../../main.dart';
import '../../reco/explainer.dart';
import '../boutique/boutique_tokens.dart';
import '../boutique/client_guide_components.dart';
import '../boutique/client_guide_scaffold.dart';
import '../catalog/categories_screen.dart';
import 'shopper_preferences.dart';

const String kPersonalizationSaved = 'Preferencias guardadas';
const String kMayoreoPreferenceNote =
    'Mayoreo se guarda solo como preferencia. No cambia los precios.';

const Map<String, String> _brandLogoAssets = <String, String>{
  'anne_klein': 'assets/images/brands/anne_klein.webp',
  'coach': 'assets/images/brands/coach.webp',
  'christian_dior': 'assets/images/brands/dior.webp',
  'dior': 'assets/images/brands/dior.webp',
  'guess': 'assets/images/brands/guess.webp',
  'laneige': 'assets/images/brands/laneige.webp',
  'michael_kors': 'assets/images/brands/michael_kors.webp',
  'olaplex': 'assets/images/brands/olaplex.webp',
  'rhode': 'assets/images/brands/rhode.webp',
  'steve_madden': 'assets/images/brands/steve_madden.webp',
  'summer_fridays': 'assets/images/brands/summer_fridays.webp',
  'the_ordinary': 'assets/images/brands/the_ordinary.webp',
  'tommy_hilfiger': 'assets/images/brands/tommy_hilfiger.webp',
};

Future<void> openPersonalization(
  BuildContext context, {
  ShopperPreferenceStore? store,
  String? scopeKey,
}) {
  final catalog = StoreScope.maybeOf(context);
  final account = AccountScope.maybeOf(context);
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/personalizacion'),
      builder: (_) {
        Widget screen = PersonalizationScreen(store: store, scopeKey: scopeKey);
        if (catalog != null) {
          screen = StoreScope(notifier: catalog, child: screen);
        }
        if (account != null) {
          screen = AccountScope(notifier: account, child: screen);
        }
        return screen;
      },
    ),
  );
}

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({this.store, this.scopeKey, super.key});

  /// Injected in tests. Production uses shared preferences on this device.
  final ShopperPreferenceStore? store;

  /// Overrides the signed-in account id. Tests use it to prove isolation.
  final String? scopeKey;

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  ShopperPreferenceStore? _store;
  String? _loadedScope;
  var _loading = true;
  var _saving = false;
  final Set<String> _brands = <String>{};
  final Set<String> _styles = <String>{};
  ShopperPurchaseType? _purchaseType;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = _scope();
    if (_loadedScope == scope && _store != null) return;
    _loadedScope = scope;
    unawaited(_load(scope));
  }

  String _scope() =>
      widget.scopeKey ??
      AccountScope.maybeOf(context)?.account?.localAccountId ??
      '';

  Future<ShopperPreferenceStore> _resolveStore() async {
    final injected = widget.store;
    if (injected != null) {
      _store = injected;
      return injected;
    }
    final cached = _store;
    if (cached != null) return cached;
    final resolved = SharedPreferencesShopperPreferenceStore(
      await SharedPreferences.getInstance(),
    );
    _store = resolved;
    return resolved;
  }

  Future<void> _load(String scope) async {
    setState(() => _loading = true);
    final store = await _resolveStore();
    final saved = await store.read(scope);
    if (!mounted || scope != _scope()) return;
    setState(() {
      _brands
        ..clear()
        ..addAll(saved.brands);
      _styles
        ..clear()
        ..addAll(saved.styles);
      _purchaseType = saved.purchaseType;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final scope = _scope();
    final value = ShopperPreferences(
      brands: Set<String>.of(_brands),
      styles: Set<String>.of(_styles),
      purchaseType: _purchaseType,
    );
    try {
      final store = await _resolveStore();
      await store.write(scope, value);
      if (!mounted || scope != _scope()) return;
      _seedRecommendations();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kPersonalizationSaved)),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron guardar las preferencias'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _seedRecommendations() {
    final catalog = StoreScope.maybeOf(context);
    if (catalog == null) return;
    final categories = <String>{
      for (final style in clientGuideCategories)
        if (_styles.contains(style.id) && style.filter.category != null)
          style.filter.category!,
    };
    final silhouettes = <String>[
      for (final style in clientGuideCategories)
        if (_styles.contains(style.id) && style.filter.silhouette != null)
          style.filter.silhouette!,
    ];
    if (_brands.isEmpty && categories.isEmpty && silhouettes.isEmpty) return;
    catalog.seedFrom(
      brands: _brands.toList(),
      categories: categories.toList(),
      silhouettes: silhouettes,
    );
  }

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (!target.remove(value)) target.add(value);
    });
  }

  void _selectPurchase(ShopperPurchaseType value) {
    setState(() {
      _purchaseType = _purchaseType == value ? null : value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final width = MediaQuery.sizeOf(context).width;
    final catalog = StoreScope.maybeOf(context);
    final brands = catalog == null
        ? _brands.toList()
        : <String>[for (final slug in catalog.availableBrands) slug];
    return ClientGuideScaffold(
      current: ClientGuideDestination.account,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                key: ValueKey('personalization-loading'),
              ),
            )
          : ListView(
              key: const ValueKey('personalization-scroll'),
              padding: EdgeInsets.fromLTRB(
                MonettaTokens.gutterFor(width),
                MonettaTokens.space[4],
                MonettaTokens.gutterFor(width),
                MonettaTokens.space[6],
              ),
              children: [
                Text(
                  'Personalización',
                  style: clientGuideStyle(context, MonettaTokens.screenTitle),
                ),
                SizedBox(height: MonettaTokens.space[2]),
                Text(
                  'Cuéntanos cuáles son tus marcas, categorías y tipo de '
                  'compra favoritas para recibir recomendaciones personalizadas.',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[5]),
                Text(
                  'Marcas favoritas',
                  style: clientGuideStyle(context, MonettaTokens.sectionTitle),
                ),
                SizedBox(height: MonettaTokens.space[1]),
                Text(
                  'Selecciona tus marcas preferidas.',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[3]),
                if (brands.isEmpty)
                  Text(
                    'El catálogo no tiene marcas para elegir.',
                    style: clientGuideStyle(
                      context,
                      MonettaTokens.body,
                      color: palette.inkMuted,
                    ),
                  )
                else
                  _ChoiceGrid(
                    columns: _columns(width),
                    children: [
                      for (final slug in brands)
                        _BrandChoice(
                          slug: slug,
                          selected: _brands.contains(slug),
                          onTap: () => _toggle(_brands, slug),
                        ),
                    ],
                  ),
                SizedBox(height: MonettaTokens.space[5]),
                Text(
                  'Categorías de interés',
                  style: clientGuideStyle(context, MonettaTokens.sectionTitle),
                ),
                SizedBox(height: MonettaTokens.space[1]),
                Text(
                  'Selecciona las categorías que más te interesan.',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[3]),
                _ChoiceGrid(
                  columns: _columns(width),
                  children: [
                    for (final style in clientGuideCategories)
                      _StyleChoice(
                        style: style,
                        selected: _styles.contains(style.id),
                        onTap: () => _toggle(_styles, style.id),
                      ),
                  ],
                ),
                SizedBox(height: MonettaTokens.space[5]),
                Text(
                  'Tipo de compra favorita',
                  style: clientGuideStyle(context, MonettaTokens.sectionTitle),
                ),
                SizedBox(height: MonettaTokens.space[1]),
                Text(
                  'Cuéntanos cómo prefieres comprar.',
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.body,
                    color: palette.inkMuted,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[3]),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PurchaseChoice(
                        id: 'menudeo',
                        title: 'Menudeo',
                        subtitle: 'Una a dos piezas',
                        icon: Icons.shopping_bag_outlined,
                        selected: _purchaseType == ShopperPurchaseType.menudeo,
                        onTap: () =>
                            _selectPurchase(ShopperPurchaseType.menudeo),
                      ),
                    ),
                    SizedBox(width: MonettaTokens.space[2]),
                    Expanded(
                      child: _PurchaseChoice(
                        id: 'mayoreo',
                        title: 'Mayoreo',
                        subtitle: 'Más de tres piezas',
                        icon: Icons.storefront_outlined,
                        selected: _purchaseType == ShopperPurchaseType.mayoreo,
                        onTap: () =>
                            _selectPurchase(ShopperPurchaseType.mayoreo),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: MonettaTokens.space[2]),
                Text(
                  kMayoreoPreferenceNote,
                  style: clientGuideStyle(
                    context,
                    MonettaTokens.navLabel,
                    color: palette.inkMuted,
                  ),
                ),
                SizedBox(height: MonettaTokens.space[4]),
                FilledButton(
                  key: const ValueKey('personalization-save'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.actionDark,
                    foregroundColor: palette.onActionDark,
                    disabledBackgroundColor: palette.surfaceDeep,
                    minimumSize:
                        const Size.fromHeight(MonettaTokens.controlHeight),
                    shape: const StadiumBorder(),
                    textStyle: clientGuideStyle(context, MonettaTokens.control),
                  ),
                  child: const Text('Guardar preferencias'),
                ),
              ],
            ),
    );
  }

  int _columns(double width) {
    if (width >= MonettaTokens.breakpointMedium) {
      return MonettaTokens.categoryColumnsMedium;
    }
    return MonettaTokens.categoryColumnsCompact;
  }
}

class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: MonettaTokens.space[2],
      crossAxisSpacing: MonettaTokens.space[2],
      childAspectRatio: 0.92,
      children: children,
    );
  }
}

class _BrandChoice extends StatelessWidget {
  const _BrandChoice({
    required this.slug,
    required this.selected,
    required this.onTap,
  });

  final String slug;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final asset = _brandLogoAssets[slug];
    return _ChoiceCard(
      id: 'personalization-brand-$slug',
      selected: selected,
      onTap: onTap,
      label: brandLabel(slug),
      child: asset == null
          ? Icon(Icons.sell_outlined, color: palette.inkMuted, size: 28)
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.sell_outlined, color: palette.inkMuted, size: 28),
            ),
    );
  }
}

class _StyleChoice extends StatelessWidget {
  const _StyleChoice({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final GuideCategory style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    final asset = style.asset;
    return _ChoiceCard(
      id: 'personalization-style-${style.id}',
      selected: selected,
      onTap: onTap,
      label: style.title,
      child: asset == null
          ? Icon(style.icon, color: palette.inkMuted, size: 36)
          : Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(style.icon, color: palette.inkMuted, size: 36),
            ),
    );
  }
}

class _PurchaseChoice extends StatelessWidget {
  const _PurchaseChoice({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return _ChoiceCard(
      id: 'personalization-purchase-$id',
      selected: selected,
      onTap: onTap,
      label: title,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: palette.goldText),
          SizedBox(height: MonettaTokens.space[1]),
          Text(
            title,
            textAlign: TextAlign.center,
            style: clientGuideStyle(context, MonettaTokens.cardLabel),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: clientGuideStyle(
              context,
              MonettaTokens.navLabel,
              color: palette.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.id,
    required this.selected,
    required this.onTap,
    required this.label,
    required this.child,
  });

  final String id;
  final bool selected;
  final VoidCallback onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: palette.surface,
        borderRadius: BoutiqueRadius.card,
        child: InkWell(
          key: ValueKey(id),
          onTap: onTap,
          borderRadius: BoutiqueRadius.card,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BoutiqueRadius.card,
              border: Border.all(
                color: selected ? palette.selectedBorder : palette.hairline,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    MonettaTokens.space[2],
                    MonettaTokens.space[4],
                    MonettaTokens.space[2],
                    MonettaTokens.space[2],
                  ),
                  child: Center(child: child),
                ),
                Positioned(
                  top: MonettaTokens.space[1],
                  right: MonettaTokens.space[1],
                  child: _ChoiceMark(selected: selected),
                ),
                if (label.isNotEmpty && child is! Column)
                  Positioned(
                    left: MonettaTokens.space[1],
                    right: MonettaTokens.space[1],
                    bottom: MonettaTokens.space[1],
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: clientGuideStyle(context, MonettaTokens.navLabel),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceMark extends StatelessWidget {
  const _ChoiceMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? palette.action : palette.surface,
        border: Border.all(
          color: selected ? palette.action : palette.borderControl,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 14, color: palette.onAction)
          : null,
    );
  }
}
